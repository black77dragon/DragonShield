// iOS Settings: Import snapshot (.sqlite) and open read-only
#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IOSSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var showImporter = false
    @State private var importError: String?
    @State private var lastImportedPath: String = ""
    @State private var lastImportedSize: Int64 = 0

    @AppStorage("tile.totalValue") private var showTotalValue: Bool = true
    @AppStorage("tile.missingPrices") private var showMissingPrices: Bool = true
    @AppStorage("tile.cryptoAlloc") private var showCryptoAlloc: Bool = true
    @AppStorage("tile.currencyExposure") private var showCurrencyExposure: Bool = true
    @AppStorage("tile.upcomingAlerts") private var showUpcomingAlerts: Bool = true
    @AppStorage("ios.dashboard.tileOrder") private var tileOrderRaw: String = ""
    @State private var tileOrder: [String] = []
    @AppStorage("privacy.blurValues") private var privacyBlur: Bool = false
    @AppStorage("ios.fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.standard.rawValue

    private var fontSizePreference: FontSizePreference { FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .standard }
    private static let aboutDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var body: some View {
        VStack(spacing: 8) {
            // Small brand/logo at the very top
            HStack {
                Spacer()
                AppBrandLogo()
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("DragonShield")
                Spacer()
            }
            .padding(.top, 8)
            Form {
                Section(header: Text("Privacy")) {
                    Toggle("Blur values (CHF)", isOn: $privacyBlur)
                }
                Section(header: Text("Data Import")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import SQLite snapshot exported from the Mac app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Import Snapshot…") { showImporter = true }
                        if !lastImportedPath.isEmpty {
                            Text("Using: \(lastImportedPath)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                Section(header: Text("Font Size")) {
                    Picker("Font Size", selection: $fontSizePreferenceRaw) {
                        ForEach(FontSizePreference.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(fontSizePreference.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section(header: HStack { Text("Dashboard Tile Settings"); Spacer(); EditButton() }) {
                    Toggle("Total Value", isOn: $showTotalValue)
                    Toggle("Missing Prices", isOn: $showMissingPrices)
                    Toggle("Crypto Allocations", isOn: $showCryptoAlloc)
                    Toggle("Portfolio by Currency", isOn: $showCurrencyExposure)
                    Toggle("Upcoming Alerts", isOn: $showUpcomingAlerts)

                    // Reorderable list of tiles
                    List {
                        ForEach(tileOrder, id: \.self) { id in
                            Text(tileName(for: id))
                                .font(.subheadline)
                                .padding(.vertical, 0)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                        }
                        .onMove { indices, newOffset in
                            tileOrder.move(fromOffsets: indices, toOffset: newOffset)
                            persistTileOrder()
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 28)
                    .frame(minHeight: 160)
                }
                Section(header: Text("About")) {
                    Text("DB Version: \(dbManager.dbVersion)")
                    if let created = dbManager.dbCreated {
                        Text("Created: \(Self.aboutDateFormatter.string(from: created))")
                    }
                    if let modified = dbManager.dbModified {
                        Text("Modified: \(Self.aboutDateFormatter.string(from: modified))")
                    }
                    if !lastImportedPath.isEmpty {
                        Text("Snapshot: \(lastImportedPath) (") + Text("\(lastImportedSize)").monospacedDigit() + Text(" bytes)")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear(perform: restoreTileOrder)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: {
                // Accept common SQLite file extensions and fall back to generic data so users can still pick a file
                var arr: [UTType] = []
                if let t = UTType(filenameExtension: "sqlite") { arr.append(t) }
                if let t = UTType(filenameExtension: "sqlite3") { arr.append(t) }
                if let t = UTType(filenameExtension: "db") { arr.append(t) }
                if let t = UTType("public.database") { arr.append(t) }
                arr.append(.data)
                return arr
            }(),
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importSnapshot(from: url)
                }
            case .failure(let err):
                importError = err.localizedDescription
            }
        }
        .alert("Import Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError ?? "")
        }
    }

    // Small helper to resolve the brand image. Tries AppIcon first, then falls back to dragonshieldAppLogo.
    @ViewBuilder
    private func AppBrandLogo() -> some View {
        if let ui = UIImage(named: "AppIcon") ?? UIImage(named: "dragonshieldAppLogo") {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: "shield.fill")
                .font(.system(size: 34))
                .foregroundColor(.orange)
        }
    }

    // MARK: - Tile order helpers
    private func defaultOrder() -> [String] { ["totalValue", "missingPrices", "cryptoAlloc", "currencyExposure", "upcomingAlerts"] }
    private func restoreTileOrder() {
        let saved = tileOrderRaw.split(separator: ",").map { String($0) }
        var set = Set(saved)
        var order: [String] = saved
        for id in defaultOrder() where !set.contains(id) { order.append(id); set.insert(id) }
        let known = Set(defaultOrder())
        tileOrder = order.filter { known.contains($0) }
        if tileOrderRaw.isEmpty { persistTileOrder() }
    }
    private func persistTileOrder() { tileOrderRaw = tileOrder.joined(separator: ",") }
    private func tileName(for id: String) -> String {
        switch id {
        case "totalValue": return "Total Value"
        case "missingPrices": return "Missing Prices"
        case "cryptoAlloc": return "Crypto Allocations"
        case "currencyExposure": return "Portfolio by Currency"
        case "upcomingAlerts": return "Upcoming Alerts"
        default: return id
        }
    }

    private func importSnapshot(from url: URL) {
        do {
            // Gain access if the provider requires security-scoped URLs
            var needsStop = false
            if url.startAccessingSecurityScopedResource() { needsStop = true }
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

            // Copy into app container (Documents)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dest = docs.appendingPathComponent("DragonShield_snapshot.sqlite", conformingTo: UTType(filenameExtension: "sqlite") ?? .data)
            if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
            try FileManager.default.copyItem(at: url, to: dest)
            // Normalize snapshot to avoid WAL dependency (DELETE journal + checkpoint)
            _ = DatabaseManager.normalizeSnapshot(at: dest.path)
            if dbManager.openReadOnly(at: dest.path) {
                lastImportedPath = dest.lastPathComponent
                if let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path), let size = attrs[.size] as? NSNumber { lastImportedSize = size.int64Value }
            } else {
                importError = "Failed to open snapshot."
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}
#endif

enum FontSizePreference: String, CaseIterable, Identifiable {
    case compact
    case standard
    case expanded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: return "Small"
        case .standard: return "Default"
        case .expanded: return "Large"
        }
    }

    var description: String {
        switch self {
        case .compact: return "Use a tighter font size across the app."
        case .standard: return "Use the standard font size."
        case .expanded: return "Use a larger font size for improved readability."
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .compact: return .medium
        case .standard: return .large
        case .expanded: return .xLarge
        }
    }
}
