import SwiftUI

private let layoutKey = "dashboardTileLayout"
private let layoutVersionKey = UserDefaultsKeys.dashboardLayoutVersion
private let currentLayoutVersion = 1

struct DashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @AppStorage(UserDefaultsKeys.dashboardShowIncomingDeadlinesEveryVisit) private var showIncomingDeadlinesEveryVisit: Bool = true
    @AppStorage(UserDefaultsKeys.dashboardIncomingPopupShownThisLaunch) private var incomingDeadlinesPopupShownThisLaunch: Bool = false
    private enum Layout {
        static let spacing: CGFloat = 24
        static let minWidth: CGFloat = 260
        static let maxWidth: CGFloat = 400
    }


    @State private var tileIDs: [String] = []
    @State private var showingPicker = false
    @State private var draggedID: String?
    @State private var columnCount = 3

    @State private var showUpcomingWeekPopup = false
    @State private var startupChecked = false
    @State private var upcomingWeek: [(id: Int, name: String, date: String)] = []
    @State private var isUpdatingFx = false
    @State private var isUpdatingPrices = false
    @State private var dashboardAlert: DashboardActionAlert?
    @State private var refreshToken = UUID()

    private struct DashboardActionAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                MasonryLayout(columns: columnCount, spacing: Layout.spacing) {
                    ForEach(tileIDs, id: \.self) { id in
                        if let tile = TileRegistry.view(for: id) {
                            tile
                                .onDrag {
                                    draggedID = id
                                    return NSItemProvider(object: id as NSString)
                                }
                                .onDrop(
                                    of: [.text],
                                    delegate: TileDropDelegate(
                                        item: id,
                                        tiles: $tileIDs,
                                        dragged: $draggedID
                                    ) {
                                        saveLayout()
                                    }
                                )
                                .accessibilityLabel(TileRegistry.info(for: id).name)
                        }
                    }
                }
                .id(refreshToken)
                .frame(maxWidth: gridWidth(for: columnCount), alignment: .topLeading)
                .padding(Layout.spacing)
                .animation(.easeInOut(duration: 0.2), value: columnCount)
            }
            .onAppear { updateColumns(width: geo.size.width) }
            .onChange(of: geo.size.width) { _, newValue in updateColumns(width: newValue) }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: triggerFxUpdate) {
                    VStack(spacing: 2) {
                        if isUpdatingFx {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("FX")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 48)
                }
                .disabled(isUpdatingFx)
                Button(action: triggerPriceUpdate) {
                    VStack(spacing: 2) {
                        if isUpdatingPrices {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                        }
                        Text("Price")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 48)
                }
                .disabled(isUpdatingPrices)
            }
            ToolbarItem(placement: .automatic) {
                Button("Configure") { showingPicker = true }
            }
        }
        .alert(item: $dashboardAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingPicker) {
            TilePickerView(tileIDs: $tileIDs)
                .onDisappear { saveLayout() }
        }
        .onAppear(perform: loadLayout)
        .sheet(isPresented: $showUpcomingWeekPopup) {
            StartupAlertsPopupView(items: upcomingWeek)
        }
        .onAppear {
            if !startupChecked {
                startupChecked = true
                loadUpcomingWeekAlerts()
            }
        }
    }

    private func triggerFxUpdate() {
        if isUpdatingFx { return }
        Task {
            await MainActor.run { isUpdatingFx = true }
            let base = await MainActor.run { dbManager.baseCurrency }
            let service = FXUpdateService(dbManager: dbManager)
            let targets = service.targetCurrencies(base: base)
            guard !targets.isEmpty else {
                await MainActor.run {
                    isUpdatingFx = false
                    refreshDashboard()
                    dashboardAlert = DashboardActionAlert(
                        title: "FX Update",
                        message: "No API-supported active currencies are configured for updates."
                    )
                }
                return
            }
            if let summary = await service.updateLatestForAll(base: base) {
                let dateText = DateFormatter.iso8601DateOnly.string(from: summary.asOf)
                var details = "Inserted: \(summary.insertedCount)"
                details += " • Failed: \(summary.failedCount)"
                details += " • Skipped: \(summary.skippedCount)"
                if !summary.updatedCurrencies.isEmpty {
                    details += "\nUpdated: \(summary.updatedCurrencies.joined(separator: ", "))"
                }
                await MainActor.run {
                    isUpdatingFx = false
                    refreshDashboard()
                    dashboardAlert = DashboardActionAlert(
                        title: "FX Update Complete",
                        message: "Provider: \(summary.provider.uppercased())\nAs of: \(dateText)\n\(details)"
                    )
                }
            } else {
                let errorText = service.lastError.map { String(describing: $0) } ?? "No update details returned."
                await MainActor.run {
                    isUpdatingFx = false
                    refreshDashboard()
                    dashboardAlert = DashboardActionAlert(
                        title: "FX Update Failed",
                        message: errorText
                    )
                }
            }
        }
    }

    private func triggerPriceUpdate() {
        if isUpdatingPrices { return }
        Task {
            await MainActor.run { isUpdatingPrices = true }
            let records = dbManager.enabledPriceSourceRecords()
            guard !records.isEmpty else {
                await MainActor.run {
                    isUpdatingPrices = false
                    refreshDashboard()
                    dashboardAlert = DashboardActionAlert(
                        title: "Price Update",
                        message: "No auto-enabled instrument price sources with provider + external ID configured."
                    )
                }
                return
            }
            let service = PriceUpdateService(dbManager: dbManager)
            let results = await service.fetchAndUpsert(records)
            let successes = results.filter { $0.status == "ok" }.count
            let failures = results.count - successes
            let failureDetails = results.filter { $0.status != "ok" }
            let previewLines = failureDetails.prefix(3).map { item -> String in
                let name = dbManager.getInstrumentName(id: item.instrumentId) ?? "Instrument #\(item.instrumentId)"
                return "\(name): \(item.message)"
            }
            let remainingIssues = max(0, failureDetails.count - previewLines.count)
            await MainActor.run {
                isUpdatingPrices = false
                refreshDashboard()
                var message = "Processed \(results.count) instrument(s). Updated \(successes)."
                if failures > 0 {
                    message += "\nIssues: \(failures)."
                    if !previewLines.isEmpty {
                        message += "\n" + previewLines.joined(separator: "\n")
                    }
                    if remainingIssues > 0 {
                        message += "\n+ \(remainingIssues) more issue(s)."
                    }
                }
                dashboardAlert = DashboardActionAlert(
                    title: failures == 0 ? "Price Update Complete" : "Price Update Completed with Issues",
                    message: message
                )
            }
        }
    }

    @MainActor
    private func refreshDashboard() {
        refreshToken = UUID()
    }

    private func loadLayout() {
        let defaults = UserDefaults.standard
        let previousVersion = defaults.integer(forKey: layoutVersionKey)

        if let saved = defaults.array(forKey: layoutKey) as? [String] {
            var layout = normalizedLayout(from: saved)
            let migrated = migrateLayout(from: layout, previousVersion: previousVersion)
            if migrated != layout {
                layout = migrated
                defaults.set(layout, forKey: layoutKey)
            }
            tileIDs = layout
        } else {
            var layout = defaultLayout()
            layout = migrateLayout(from: layout, previousVersion: previousVersion)
            tileIDs = layout
            defaults.set(layout, forKey: layoutKey)
        }

        defaults.set(currentLayoutVersion, forKey: layoutVersionKey)
    }

    private func normalizedLayout(from saved: [String]) -> [String] {
        let validIDs = Set(TileRegistry.all.map { $0.id })
        var seen = Set<String>()
        var ordered: [String] = []

        for id in saved where validIDs.contains(id) {
            if seen.insert(id).inserted {
                ordered.append(id)
            }
        }

        return ordered
    }

    private func defaultLayout() -> [String] {
        TileRegistry.all.map { $0.id }
    }

    private func migrateLayout(from layout: [String], previousVersion: Int) -> [String] {
        guard previousVersion < currentLayoutVersion else { return layout }
        var updated = layout

        if !updated.contains(CryptoTop5Tile.tileID) {
            updated.insert(CryptoTop5Tile.tileID, at: 0)
        }
        if !updated.contains(InstitutionsAUMTile.tileID) {
            updated.append(InstitutionsAUMTile.tileID)
        }

        return updated
    }

    private func saveLayout() {
        let defaults = UserDefaults.standard
        defaults.set(tileIDs, forKey: layoutKey)
        defaults.set(currentLayoutVersion, forKey: layoutVersionKey)
    }

    private func updateColumns(width: CGFloat) {
        let available = width - Layout.spacing * 2
        let fitByMax = Int(available / (Layout.maxWidth + Layout.spacing))
        switch fitByMax {
        case 4...:
            columnCount = 4
        case 3:
            columnCount = 3
        case 2:
            columnCount = 2
        default:
            columnCount = 1
        }
    }

    private func gridWidth(for columns: Int) -> CGFloat {
        Layout.maxWidth * CGFloat(columns) + Layout.spacing * CGFloat(columns - 1)
    }
}

struct TileDropDelegate: DropDelegate {
    let item: String
    @Binding var tiles: [String]
    @Binding var dragged: String?
    let onDrop: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = dragged, dragged != item,
              let from = tiles.firstIndex(of: dragged),
              let to = tiles.firstIndex(of: item) else { return }
        if tiles[to] != dragged {
            tiles.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        onDrop()
        return true
    }
}

// MARK: - Startup Alerts Popup
private struct StartupAlertsPopupView: View {
    let items: [(id: Int, name: String, date: String)]
    private static let inDf: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let outDf: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_CH"); f.dateFormat = "dd.MM.yy"; return f
    }()
    private func format(_ s: String) -> String {
        if let d = Self.inDf.date(from: s) {
            return Self.outDf.string(from: d)
        }
        return s
    }

    private func daysUntilText(_ s: String) -> String? {
        guard let dueDate = Self.inDf.date(from: s) else { return nil }
        let today = Self.inDf.date(from: Self.inDf.string(from: Date())) ?? Date()
        let diff = Calendar.current.dateComponents([.day], from: today, to: dueDate).day ?? 0
        if diff <= 0 { return "Today" }
        if diff == 1 { return "1 day" }
        return "\(diff) days"
    }

    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image("dragonshieldAppLogo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                Text("Incoming Deadlines Detected")
                    .font(.title2).bold()
                Spacer()
            }
            .padding(.top, 8)
            Text("A long time ago in a galaxy not so far away… upcoming alerts began to stir. Use the Force to stay on target!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.0) { _, it in
                    HStack {
                        Text(it.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        HStack(spacing: 8) {
                            Text(format(it.date))
                                .foregroundColor(.secondary)
                            if let daysText = daysUntilText(it.date) {
                                Text(daysText)
                                    .bold()
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Spacer()
                Button("Dismiss") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

private extension DashboardView {
    func loadUpcomingWeekAlerts() {
        // Fetch upcoming and filter to next 7 days
        var rows = dbManager.listUpcomingDateAlerts(limit: 200)
        rows.sort { $0.upcomingDate < $1.upcomingDate }
        let inDf = DateFormatter(); inDf.locale = Locale(identifier: "en_US_POSIX"); inDf.timeZone = TimeZone(secondsFromGMT: 0); inDf.dateFormat = "yyyy-MM-dd"
        guard let today = inDf.date(from: inDf.string(from: Date())),
              let week = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return }
        let nextWeek = rows.filter { inDf.date(from: $0.upcomingDate).map { $0 <= week } ?? false }
        if !nextWeek.isEmpty {
            upcomingWeek = nextWeek.map { (id: $0.alertId, name: $0.alertName, date: $0.upcomingDate) }

            let shouldShowPopup: Bool
            if !incomingDeadlinesPopupShownThisLaunch {
                incomingDeadlinesPopupShownThisLaunch = true
                shouldShowPopup = true
            } else {
                shouldShowPopup = showIncomingDeadlinesEveryVisit
            }

            if shouldShowPopup {
                showUpcomingWeekPopup = true
            }
        }
    }
}
