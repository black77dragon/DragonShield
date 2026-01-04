import SwiftUI
import UniformTypeIdentifiers

private let newLayoutKey = UserDefaultsKeys.newDashboardColumnsLayout
private let newLayoutVersionKey = UserDefaultsKeys.newDashboardLayoutVersion
private let newLayoutCurrentVersion = 2

struct DashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var preferences: AppPreferences
    @AppStorage(UserDefaultsKeys.dashboardShowIncomingDeadlinesEveryVisit) private var showIncomingDeadlinesEveryVisit: Bool = true
    @AppStorage(UserDefaultsKeys.dashboardIncomingPopupShownThisLaunch) private var incomingDeadlinesPopupShownThisLaunch: Bool = false

    private enum Layout {
        static let columnCount = 3
        static let columnSpacing: CGFloat = 12
        static let tileSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 12
        static let minColumnWidth: CGFloat = 260
        static let maxColumnWidth: CGFloat = 380
        static let sectionSpacing: CGFloat = 12
        static let headerPadding: CGFloat = 4
    }

    @State private var tileColumns: [[String]] = Array(repeating: [], count: Layout.columnCount)
    @State private var showingPicker = false
    @State private var draggedTile: DraggedTile?
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

    struct DraggedTile: Equatable {
        let id: String
        var column: Int
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                CustomToolbar(actions: [
                    ToolbarAction(icon: "arrow.triangle.2.circlepath", tooltip: "FX Update", isDisabled: isUpdatingFx, action: triggerFxUpdate),
                    ToolbarAction(icon: "chart.line.uptrend.xyaxis", tooltip: "Price Update", isDisabled: isUpdatingPrices, action: triggerPriceUpdate),
                    ToolbarAction(icon: "square.dashed.inset.filled", tooltip: "Customize Dashboard", action: { showingPicker = true })
                ])
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                        headerSection(width: columnWidth(for: geo.size.width))
                            .padding(.horizontal, Layout.horizontalPadding)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: Layout.columnSpacing) {
                                ForEach(tileColumns.indices, id: \.self) { columnIndex in
                                    VStack(spacing: Layout.tileSpacing) {
                                        ForEach(tileColumns[columnIndex], id: \.self) { id in
                                            dashboardTile(id: id, columnIndex: columnIndex)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(width: columnWidth(for: geo.size.width), alignment: .top)
                                    .onDrop(
                                        of: [.text],
                                        delegate: ColumnTileDropDelegate(
                                            item: nil,
                                            columnIndex: columnIndex,
                                            columns: $tileColumns,
                                            dragged: $draggedTile
                                        ) {
                                            saveLayout()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, Layout.horizontalPadding)
                            .id(refreshToken)
                        }
                    }
                    .padding(.vertical, Layout.sectionSpacing)
                }
            .onAppear(perform: loadLayout)
            .onAppear {
                if !startupChecked {
                    startupChecked = true
                    loadUpcomingWeekAlerts()
                }
            }
        }
        }
        .navigationTitle("Dashboard")
        .alert(item: $dashboardAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingPicker) {
            TilePickerView(tileIDs: tilePickerBinding)
                .onDisappear { saveLayout() }
        }
        .sheet(isPresented: $showUpcomingWeekPopup) {
            NewDashboardStartupAlertsPopupView(items: upcomingWeek)
        }
    }

    private func headerSection(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: Layout.columnSpacing) {
            TotalValueTile()
                .frame(width: width, alignment: .topLeading)
            InstrumentDashboardTile()
                .frame(width: width, alignment: .topLeading)
            CurrentDateTile()
                .frame(width: width, alignment: .topLeading)
        }
        .padding(Layout.headerPadding)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.tileBorder, lineWidth: 1)
        )
        .shadow(color: Theme.tileShadow, radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private func dashboardTile(id: String, columnIndex: Int) -> some View {
        if let tile = TileRegistry.view(for: id) {
            tile
                .onDrag {
                    draggedTile = DraggedTile(id: id, column: columnIndex)
                    return NSItemProvider(object: id as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: ColumnTileDropDelegate(
                        item: id,
                        columnIndex: columnIndex,
                        columns: $tileColumns,
                        dragged: $draggedTile
                    ) {
                        saveLayout()
                    }
                )
                .accessibilityLabel(TileRegistry.info(for: id).name)
        } else {
            EmptyView()
        }
    }

    private func columnWidth(for totalWidth: CGFloat) -> CGFloat {
        let available = totalWidth - Layout.horizontalPadding * 2 - Layout.columnSpacing * CGFloat(Layout.columnCount - 1)
        let raw = available / CGFloat(Layout.columnCount)
        let clamped = min(Layout.maxColumnWidth, max(Layout.minColumnWidth, raw))
        return clamped
    }

    private var tilePickerBinding: Binding<[String]> {
        Binding(
            get: { tileColumns.flatMap { $0 } },
            set: { newValue in
                let current = Set(tileColumns.flatMap { $0 })
                let next = Set(newValue)
                let removed = current.subtracting(next)
                let added = newValue.filter { !current.contains($0) }

                var updated = tileColumns.map { column in
                    column.filter { !removed.contains($0) }
                }
                for id in added {
                    let target = updated.enumerated().min { $0.element.count < $1.element.count }?.offset ?? 0
                    updated[target].append(id)
                }
                tileColumns = normalizedLayout(from: updated)
            }
        )
    }

    private func refreshDashboard() {
        refreshToken = UUID()
    }

    private func loadLayout() {
        let defaults = UserDefaults.standard
        let previousVersion = defaults.integer(forKey: newLayoutVersionKey)

        if let saved = defaults.array(forKey: newLayoutKey) as? [[String]] {
            var layout = normalizedLayout(from: saved)
            let migrated = migrateLayout(from: layout, previousVersion: previousVersion)
            if migrated != layout {
                layout = migrated
                defaults.set(layout, forKey: newLayoutKey)
            }
            tileColumns = layout
        } else {
            var layout = defaultLayout()
            layout = migrateLayout(from: layout, previousVersion: previousVersion)
            tileColumns = layout
            defaults.set(layout, forKey: newLayoutKey)
        }

        defaults.set(newLayoutCurrentVersion, forKey: newLayoutVersionKey)
    }

    private func normalizedLayout(from saved: [[String]]) -> [[String]] {
        let validIDs = Set(TileRegistry.all.map { $0.id })
        var columns = saved.prefix(Layout.columnCount).map { column in
            column.filter { validIDs.contains($0) }
        }

        while columns.count < Layout.columnCount {
            columns.append([])
        }

        var seen = Set<String>()
        for idx in columns.indices {
            columns[idx] = columns[idx].filter { id in
                if seen.contains(id) { return false }
                seen.insert(id)
                return true
            }
        }

        return columns
    }

    private func defaultLayout() -> [[String]] {
        distribute(TileRegistry.all.map { $0.id })
    }

    private func distribute(_ ids: [String]) -> [[String]] {
        var result = Array(repeating: [String](), count: Layout.columnCount)
        for (index, id) in ids.enumerated() {
            result[index % Layout.columnCount].append(id)
        }
        return result
    }

    private func migrateLayout(from layout: [[String]], previousVersion: Int) -> [[String]] {
        guard previousVersion < newLayoutCurrentVersion else { return layout }
        var flattened = layout.flatMap { $0 }

        if !flattened.contains(CryptoTop5Tile.tileID) {
            flattened.insert(CryptoTop5Tile.tileID, at: 0)
        }
        if !flattened.contains(InstitutionsAUMTile.tileID) {
            flattened.append(InstitutionsAUMTile.tileID)
        }
        if previousVersion < 2 {
            let riskTiles = [
                RiskScoreTile.tileID,
                RiskSRIDonutTile.tileID,
                RiskLiquidityDonutTile.tileID,
                RiskOverridesTile.tileID
            ]
            if let idx = flattened.firstIndex(of: RiskBucketsTile.tileID) {
                var insertIndex = idx
                for id in riskTiles where !flattened.contains(id) {
                    flattened.insert(id, at: min(insertIndex, flattened.count))
                    insertIndex += 1
                }
            } else {
                for id in riskTiles where !flattened.contains(id) {
                    flattened.append(id)
                }
            }
        }

        return distribute(flattened)
    }

    private func saveLayout() {
        let defaults = UserDefaults.standard
        defaults.set(tileColumns, forKey: newLayoutKey)
        defaults.set(newLayoutCurrentVersion, forKey: newLayoutVersionKey)
    }

    private func triggerFxUpdate() {
        if isUpdatingFx { return }
        Task {
            await MainActor.run { isUpdatingFx = true }
            let base = await MainActor.run { preferences.baseCurrency }
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
                NotificationCenter.default.post(name: .dashboardPriceUpdateCompleted, object: nil)
            }
        }
    }

    private func loadUpcomingWeekAlerts() {
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

private struct ColumnTileDropDelegate: DropDelegate {
    let item: String?
    let columnIndex: Int
    @Binding var columns: [[String]]
    @Binding var dragged: DashboardView.DraggedTile?
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        guard let dragged = dragged else { return }
        moveTile(dragged: dragged)
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        dragged = nil
        onDrop()
        return true
    }

    private func moveTile(dragged: DashboardView.DraggedTile) {
        guard columns.indices.contains(dragged.column),
              columns.indices.contains(columnIndex),
              let sourceIndex = columns[dragged.column].firstIndex(of: dragged.id) else { return }

        var updated = columns
        var sourceColumn = updated[dragged.column]
        let tile = sourceColumn.remove(at: sourceIndex)
        updated[dragged.column] = sourceColumn

        var targetColumn = updated[columnIndex]
        var targetIndex: Int
        if let item = item, let idx = targetColumn.firstIndex(of: item) {
            targetIndex = idx
        } else {
            targetIndex = targetColumn.count
        }

        // When moving within the same column, removal shifts indices left.
        if dragged.column == columnIndex, sourceIndex < targetIndex {
            targetIndex = max(0, targetIndex - 1)
        }
        targetIndex = min(max(0, targetIndex), targetColumn.count)

        targetColumn.insert(tile, at: targetIndex)
        updated[columnIndex] = targetColumn

        withAnimation(.easeInOut(duration: 0.15)) {
            columns = updated
            self.dragged = DashboardView.DraggedTile(id: dragged.id, column: columnIndex)
        }
    }
}

private struct CurrentDateTile: View {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "dd. MMM yy"
        return f
    }()

    private let now = Date()

    var body: some View {
        DashboardCard(title: "Today", minHeight: DashboardTileLayout.heroTileHeight) {
            Text(Self.formatter.string(from: now))
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NewDashboardStartupAlertsPopupView: View {
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
