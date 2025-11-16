import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DataImportExportView: View {
    enum StatementType: Int, Identifiable {
        case creditSuisse
        case zkb
        var id: Int { rawValue }
    }

    struct CryptoHoldingRow: Identifiable {
        let id: Int
        let instrumentName: String
        let currency: String
        var totalQuantity: Double
        var totalValueCHF: Double
    }

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let chfFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "'"
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private static let quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.groupingSeparator = "'"
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    @EnvironmentObject private var dbManager: DatabaseManager
    @State private var logMessages: [String] = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.statementImportLog) ?? []
    @State private var statusMessage: String = "Status: \u{2B24} Idle \u{2022} No file loaded"
    @State private var showImporterFor: StatementType?
    @State private var instructionsFor: StatementType?
    @State private var selectedFiles: [StatementType: URL] = [:]
    @State private var cryptoHoldings: [CryptoHoldingRow] = []
    @State private var cryptoTotalValueCHF: Double = 0
    @State private var cryptoLoading = false
    @State private var showCryptoDetails = false

    var body: some View {
        TabView {
            importTab
                .tabItem { Text("Import") }
            ImportSessionHistoryView()
                .tabItem { Text("History") }
        }
        .navigationTitle("Data Import / Export")
        .sheet(item: $instructionsFor) { type in
            if type == .creditSuisse {
                instructionsModal
            }
        }
    }

    private var importTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                importPanel
                statusPanel
                logPanel
                cryptoAssetsPanel
            }
            .frame(minWidth: 800, minHeight: 800)
            .padding(.top, 32)
            .padding(.horizontal)
        }
        .onAppear { loadCryptoAssets() }
        .fileImporter(
            isPresented: Binding(
                get: { showImporterFor != nil },
                set: { _ in }
            ),
            allowedContentTypes: allowedContentTypes(for: showImporterFor),
            allowsMultipleSelection: false
        ) { result in
            guard let type = showImporterFor else { return }
            showImporterFor = nil
            if case let .success(urls) = result, let url = urls.first {
                selectedFiles[type] = url
                importStatement(from: url, type: type)
            }
        }
    }

    private func allowedContentTypes(for type: StatementType?) -> [UTType] {
        switch type {
        case .creditSuisse:
            return [UTType(filenameExtension: "xlsx") ?? .data]
        case .zkb:
            return [.commaSeparatedText]
        case .none:
            return []
        }
    }

    private var importPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Text("This process is adding and not replacing positions. Delete positions in the Positions Menu if required")
                .font(.system(size: 14))
                .foregroundColor(.red)
            cardsSection
        }
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Data Import / Export")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.primaryAccent)
            Text("Upload bank or custody statements (CSV, XLSX, PDF)")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 74 / 255, green: 74 / 255, blue: 74 / 255))
        }
    }

    private var cardsSection: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 600
            Group {
                if compact {
                    VStack(spacing: 16) {
                        creditSuisseCard
                        zkbCard
                    }
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        creditSuisseCard
                        zkbCard
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var creditSuisseCard: some View {
        BankStatementCard(
            bankName: "Credit-Suisse",
            expectedFilename: "Position List MM DD YYYY.xlsx",
            fileName: selectedFiles[.creditSuisse]?.lastPathComponent,
            filePath: selectedFiles[.creditSuisse]?.path,
            instructionsAvailable: true,
            onOpenInstructions: { instructionsFor = .creditSuisse },
            onSelectFile: { showImporterFor = .creditSuisse },
            onDropFiles: { handleDrop($0, type: .creditSuisse) }
        )
    }

    private var zkbCard: some View {
        BankStatementCard(
            bankName: "ZKB",
            expectedFilename: "Depotauszug MMM DD YYYY.csv",
            fileName: selectedFiles[.zkb]?.lastPathComponent,
            filePath: selectedFiles[.zkb]?.path,
            instructionsAvailable: false,
            onOpenInstructions: {},
            onSelectFile: { showImporterFor = .zkb },
            onDropFiles: { handleDrop($0, type: .zkb) }
        )
    }

    private func handleDrop(_ urls: [URL], type: StatementType) {
        let allowedExt = type == .creditSuisse ? "xlsx" : "csv"
        if let url = urls.first(where: { $0.pathExtension.lowercased() == allowedExt }) {
            if urls.count > 1 {
                statusMessage = "Status: Imported first compatible file."
            }
            selectedFiles[type] = url
            importStatement(from: url, type: type)
        } else if let first = urls.first {
            selectedFiles[type] = first
            importStatement(from: first, type: type)
        }
    }

    private var instructionsModal: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions (German) — Credit-Suisse")
                .font(.headline)
            Text("• Sprache: Deutsch")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("• In „Gesamtübersicht“ Depot „398424-05“ auswählen")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("• „PDF/Export“ wählen → „XLS“")
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Spacer()
                Button(role: .cancel) { instructionsFor = nil } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut(.cancelAction)
                .keyboardShortcut("w", modifiers: .command)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func importStatement(from url: URL, type: StatementType) {
        func startImport() {
            statusMessage = "Status: Importing \(url.lastPathComponent) …"
            let importType: ImportManager.StatementType = {
                switch type { case .creditSuisse: return .creditSuisse; case .zkb: return .zkb }
            }()
            ImportManager.shared.importPositions(at: url, type: importType, progress: { message in
                DispatchQueue.main.async { self.appendLog(message) }
            }) { result in
                DispatchQueue.main.async {
                    let stamp = Self.logDateFormatter.string(from: Date())
                    switch result {
                    case let .success(summary):
                        let errors = summary.totalRows - summary.parsedRows
                        self.statusMessage = "Status: \u{2705} \(typeName(type)) import succeeded: \(summary.parsedRows) records parsed, \(errors) errors"
                        self.appendLog("[\(stamp)] \(url.lastPathComponent) → Success: \(summary.parsedRows) records, \(errors) errors")
                        self.loadCryptoAssets(force: true)
                    case let .failure(error):
                        self.statusMessage = "Status: \u{274C} \(typeName(type)) import failed: \(error.localizedDescription)"
                        self.appendLog("[\(stamp)] \(url.lastPathComponent) → Failed: \(error.localizedDescription)")
                    }
                }
            }
        }

        startImport()
    }

    private func appendLog(_ entry: String) {
        logMessages.insert(entry, at: 0)
        if logMessages.count > 100 { logMessages.removeLast(logMessages.count - 100) }
        UserDefaults.standard.set(logMessages, forKey: UserDefaultsKeys.statementImportLog)
    }

    private var statusPanel: some View {
        Text(statusMessage)
            .font(.system(size: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statement Loading Log")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255))
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(logMessages.enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
        )
        .overlay(
            Rectangle()
                .fill(Theme.primaryAccent)
                .frame(height: 2), alignment: .top
        )
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    private var cryptoAssetsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Crypto Assets")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.primaryAccent)
                Text("Section E consolidates all crypto instruments across accounts.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            if cryptoLoading {
                ProgressView("Loading holdings...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if cryptoHoldings.isEmpty {
                Text("No crypto positions found yet. Import new statements to populate this section.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Value")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(chfString(for: cryptoTotalValueCHF))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text("\(cryptoHoldings.count) instruments consolidated")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut) { showCryptoDetails.toggle() }
                    } label: {
                        Label(showCryptoDetails ? "Hide Details" : "Show Details",
                              systemImage: showCryptoDetails ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel(showCryptoDetails ? "Hide crypto positions" : "Show crypto positions")
                }

                if showCryptoDetails {
                    cryptoDetailsList
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }

    private var cryptoDetailsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Instrument")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Amount")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .frame(width: 150, alignment: .trailing)
                Text("Value (CHF)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .frame(width: 140, alignment: .trailing)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)

            Divider()

            ForEach(Array(cryptoHoldings.enumerated()), id: \.element.id) { index, row in
                HStack {
                    Text(row.instrumentName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                    Text(quantityString(for: row))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 150, alignment: .trailing)
                    Text(chfString(for: row.totalValueCHF))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .frame(width: 140, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                if index != cryptoHoldings.count - 1 {
                    Divider()
                        .opacity(0.3)
                }
            }
        }
        .background(Theme.tileBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.tileBorder, lineWidth: 1)
        )
    }

    private func loadCryptoAssets(force: Bool = false) {
        if cryptoLoading { return }
        if !cryptoHoldings.isEmpty, !force { return }
        cryptoLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let positions = dbManager.fetchPositionReports()
            var aggregations: [Int: CryptoHoldingRow] = [:]
            var rateCache: [String: Double] = [:]

            for position in positions {
                let isCrypto = (position.assetSubClass ?? "").localizedCaseInsensitiveContains("crypto") ||
                    (position.assetClass ?? "").localizedCaseInsensitiveContains("crypto")
                guard isCrypto, let instrumentId = position.instrumentId else { continue }
                guard let priceInfo = dbManager.getLatestPrice(instrumentId: instrumentId) else { continue }

                let currency = position.instrumentCurrency.uppercased()
                var valueCHF = position.quantity * priceInfo.price
                if currency != "CHF" {
                    if let cached = rateCache[currency] {
                        valueCHF *= cached
                    } else if let fetched = dbManager.fetchExchangeRates(currencyCode: currency, upTo: nil).first?.rateToChf {
                        rateCache[currency] = fetched
                        valueCHF *= fetched
                    } else {
                        continue
                    }
                }

                var row = aggregations[instrumentId] ?? CryptoHoldingRow(
                    id: instrumentId,
                    instrumentName: position.instrumentName,
                    currency: currency,
                    totalQuantity: 0,
                    totalValueCHF: 0
                )
                row.totalQuantity += position.quantity
                row.totalValueCHF += valueCHF
                aggregations[instrumentId] = row
            }

            let rows = aggregations.values.sorted { $0.totalValueCHF > $1.totalValueCHF }
            let total = rows.reduce(0) { $0 + $1.totalValueCHF }

            DispatchQueue.main.async {
                self.cryptoHoldings = rows
                self.cryptoTotalValueCHF = total
                self.cryptoLoading = false
                if rows.isEmpty {
                    self.showCryptoDetails = false
                }
            }
        }
    }

    private func chfString(for value: Double) -> String {
        let formatted = Self.chfFormatter.string(from: NSNumber(value: value)) ?? "0"
        return "CHF \(formatted)"
    }

    private func quantityString(for row: CryptoHoldingRow) -> String {
        let formatted = Self.quantityFormatter.string(from: NSNumber(value: row.totalQuantity)) ?? "0"
        return "\(formatted) \(row.currency)"
    }

    private func typeName(_ type: StatementType) -> String {
        switch type {
        case .creditSuisse: return "Credit-Suisse"
        case .zkb: return "ZKB"
        }
    }
}

#Preview {
    DataImportExportView()
        .environmentObject(DatabaseManager())
}
