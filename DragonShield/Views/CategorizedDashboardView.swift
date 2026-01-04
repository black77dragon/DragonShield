import SwiftUI
import UniformTypeIdentifiers

private let categorizedLayoutKey = UserDefaultsKeys.categorizedDashboardMainLayout
private let categorizedWarningsKey = UserDefaultsKeys.categorizedDashboardWarningsLayout
private let categorizedLayoutVersionKey = UserDefaultsKeys.categorizedDashboardLayoutVersion
private let categorizedLayoutCurrentVersion = 1
private let categoryOverlayExclusions: Set<String> = [
    AllNotesTile.tileID,
    MissingPricesTile.tileID,
    AccountsNeedingUpdateTile.tileID,
    UpcomingAlertsTile.tileID,
    UnusedInstrumentsTile.tileID,
    UnthemedInstrumentsTile.tileID,
    ThemesOverviewTile.tileID,
    TopPositionsTile.tileID,
    TodoDashboardTile.tileID
]

struct CategorizedDashboardView: View {
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
        static let maxColumnWidth: CGFloat = 360
        static let sectionSpacing: CGFloat = 12
        static let headerPadding: CGFloat = 4
        static let pinnedColumnWidth: CGFloat = 320
    }

    @State private var mainColumns: [[String]] = Array(repeating: [], count: Layout.columnCount)
    @State private var warningTiles: [String] = []
    @State private var showingPicker = false
    @State private var draggedTile: DraggedTile?
    @State private var draggedWarning: String?
    @State private var showUpcomingWeekPopup = false
    @State private var startupChecked = false
    @State private var upcomingWeek: [(id: Int, name: String, date: String)] = []
    @State private var isUpdatingFx = false
    @State private var isUpdatingPrices = false
    @State private var dashboardAlert: DashboardActionAlert?
    @State private var refreshToken = UUID()
    @State private var selectedCategory: DashboardCategory = .all

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
                        categoryBar
                            .padding(.horizontal, Layout.horizontalPadding)
                            .padding(.top, Layout.sectionSpacing)

                        headerSection(width: columnWidth(for: geo.size.width))
                            .padding(.horizontal, Layout.horizontalPadding)

                        HStack(alignment: .top, spacing: Layout.columnSpacing) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: Layout.columnSpacing) {
                                    ForEach(filteredMainColumns.indices, id: \.self) { columnIndex in
                                        VStack(spacing: Layout.tileSpacing) {
                                            ForEach(filteredMainColumns[columnIndex], id: \.self) { id in
                                                dashboardTile(id: id, columnIndex: columnIndex)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .frame(width: columnWidth(for: geo.size.width), alignment: .top)
                                        .onDrop(
                                            of: [.text],
                                            delegate: CategorizedColumnDropDelegate(
                                                item: nil,
                                                columnIndex: columnIndex,
                                                columns: $mainColumns,
                                                dragged: $draggedTile
                                            ) {
                                                saveLayout()
                                            }
                                        )
                                    }
                                }
                                .padding(.trailing, Layout.columnSpacing)
                                .id(refreshToken)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            warningsColumn
                                .frame(width: Layout.pinnedColumnWidth, alignment: .top)
                        }
                        .padding(.horizontal, Layout.horizontalPadding)
                    }
                    .padding(.vertical, Layout.sectionSpacing)
                }
            }
            .onAppear(perform: loadLayout)
            .onAppear {
                if !startupChecked {
                    startupChecked = true
                    loadUpcomingWeekAlerts()
                }
            }
        }
        .navigationTitle("Dashboard (Categorized)")
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
            CategorizedDashboardStartupAlertsPopupView(items: upcomingWeek)
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sidebarCategories) { category in
                    CategoryChip(
                        category: category,
                        count: count(for: category),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var sidebarCategories: [DashboardCategory] {
        [.all, .overview, .allocation, .risk, .warningsAlerts, .general]
    }

    private func count(for category: DashboardCategory) -> Int {
        switch category {
        case .all:
            return allTileIDs.count
        case .warningsAlerts:
            return warningTiles.count
        default:
            return allTileIDs.filter { DashboardTileCategories.category(for: $0) == category }.count
        }
    }

    private var filteredMainColumns: [[String]] {
        switch selectedCategory {
        case .all:
            return mainColumns
        case .warningsAlerts:
            return Array(repeating: [], count: Layout.columnCount)
        default:
            return mainColumns.map { column in
                column.filter { DashboardTileCategories.category(for: $0) == selectedCategory }
            }
        }
    }

    private func headerSection(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: Layout.columnSpacing) {
            headerTile(id: TotalValueTile.tileID) {
                TotalValueTile()
            }
            .frame(width: width, alignment: .topLeading)
            headerTile(id: InstrumentDashboardTile.tileID) {
                InstrumentDashboardTile()
            }
            .frame(width: width, alignment: .topLeading)
            headerTile(id: CategorizedCurrentDateTile.tileID) {
                CategorizedCurrentDateTile()
            }
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

    private func headerTile<Content: View>(id: String, @ViewBuilder content: () -> Content) -> some View {
        let category = DashboardTileCategories.category(for: id)
        return content()
            .overlay(alignment: .topTrailing) {
                if !categoryOverlayExclusions.contains(id) {
                    DashboardCategoryPill(category: category)
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private func dashboardTile(id: String, columnIndex: Int) -> some View {
        if let tile = TileRegistry.view(for: id) {
            let category = DashboardTileCategories.category(for: id)
            tile
                .overlay(alignment: .topTrailing) {
                    if !categoryOverlayExclusions.contains(id) {
                        DashboardCategoryPill(category: category)
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                }
                .onDrag {
                    draggedTile = DraggedTile(id: id, column: columnIndex)
                    return NSItemProvider(object: id as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: CategorizedColumnDropDelegate(
                        item: id,
                        columnIndex: columnIndex,
                        columns: $mainColumns,
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

    private var warningsColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Warnings & Alerts")
                    .font(.headline)
                CategoryCountBadge(count: warningTiles.count, color: .red)
                Spacer()
                Image(systemName: "pin.fill")
                    .foregroundColor(.red)
                    .font(.subheadline.weight(.bold))
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 4)

            if warningTiles.isEmpty {
                Text("No warning tiles enabled")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: Layout.tileSpacing) {
                    ForEach(warningTiles, id: \.self) { id in
                        warningTile(id: id)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Layout.tileSpacing)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func warningTile(id: String) -> some View {
        if let tile = TileRegistry.view(for: id) {
            tile
                .onDrag {
                    draggedWarning = id
                    return NSItemProvider(object: id as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: WarningTileDropDelegate(
                        item: id,
                        tiles: $warningTiles,
                        dragged: $draggedWarning
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
        let available = totalWidth
            - Layout.pinnedColumnWidth
            - Layout.horizontalPadding * 2
            - Layout.columnSpacing * 2
        let raw = available / CGFloat(Layout.columnCount)
        let clamped = min(Layout.maxColumnWidth, max(Layout.minColumnWidth, raw))
        return clamped
    }

    private var tilePickerBinding: Binding<[String]> {
        Binding(
            get: { allTileIDs },
            set: { newValue in
                let validIDs = Set(TileRegistry.all.map { $0.id })
                var seen = Set<String>()
                let deduped = newValue.filter { validIDs.contains($0) && seen.insert($0).inserted }

                let warnings = deduped.filter { DashboardTileCategories.warningTileIDs.contains($0) }
                let nonWarnings = deduped.filter { !DashboardTileCategories.warningTileIDs.contains($0) }

                let currentOrder = mainColumns.flatMap { $0 }.filter { nonWarnings.contains($0) }
                let newItems = nonWarnings.filter { !currentOrder.contains($0) }
                let merged = currentOrder + newItems

                mainColumns = distribute(merged)
                warningTiles = warnings
                saveLayout()
            }
        )
    }

    private var allTileIDs: [String] {
        mainColumns.flatMap { $0 } + warningTiles
    }

    private func distribute(_ ids: [String]) -> [[String]] {
        var result = Array(repeating: [String](), count: Layout.columnCount)
        for (index, id) in ids.enumerated() {
            result[index % Layout.columnCount].append(id)
        }
        return result
    }

    private func loadLayout() {
        let defaults = UserDefaults.standard
        _ = defaults.integer(forKey: categorizedLayoutVersionKey)

        if let saved = defaults.array(forKey: categorizedLayoutKey) as? [[String]] {
            mainColumns = normalizeMainLayout(from: saved)
        } else {
            mainColumns = defaultMainLayout()
        }

        if let savedWarnings = defaults.array(forKey: categorizedWarningsKey) as? [String] {
            warningTiles = normalizeWarningsLayout(from: savedWarnings)
        } else {
            warningTiles = defaultWarningLayout()
        }

        defaults.set(categorizedLayoutCurrentVersion, forKey: categorizedLayoutVersionKey)
    }

    private func saveLayout() {
        let defaults = UserDefaults.standard
        defaults.set(mainColumns, forKey: categorizedLayoutKey)
        defaults.set(warningTiles, forKey: categorizedWarningsKey)
        defaults.set(categorizedLayoutCurrentVersion, forKey: categorizedLayoutVersionKey)
    }

    private func normalizeMainLayout(from saved: [[String]]) -> [[String]] {
        let validIDs = Set(TileRegistry.all.map { $0.id })
        let warningIDs = DashboardTileCategories.warningTileIDs
        var columns = saved.prefix(Layout.columnCount).map { column in
            column.filter { validIDs.contains($0) && !warningIDs.contains($0) }
        }

        while columns.count < Layout.columnCount {
            columns.append([])
        }

        var seen = Set<String>()
        for idx in columns.indices {
            columns[idx] = columns[idx].filter { seen.insert($0).inserted }
        }
        return columns
    }

    private func normalizeWarningsLayout(from saved: [String]) -> [String] {
        let warningIDs = DashboardTileCategories.warningTileIDs
        var seen = Set<String>()
        return saved.filter { warningIDs.contains($0) && seen.insert($0).inserted }
    }

    private func defaultMainLayout() -> [[String]] {
        let warnings = DashboardTileCategories.warningTileIDs
        let ids = TileRegistry.all.map { $0.id }.filter { !warnings.contains($0) }
        return distribute(ids)
    }

    private func defaultWarningLayout() -> [String] {
        let warnings = DashboardTileCategories.warningTileIDs
        return TileRegistry.all.map { $0.id }.filter { warnings.contains($0) }
    }

    private func refreshDashboard() {
        refreshToken = UUID()
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

private struct CategorizedColumnDropDelegate: DropDelegate {
    let item: String?
    let columnIndex: Int
    @Binding var columns: [[String]]
    @Binding var dragged: CategorizedDashboardView.DraggedTile?
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

    private func moveTile(dragged: CategorizedDashboardView.DraggedTile) {
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

        if dragged.column == columnIndex, sourceIndex < targetIndex {
            targetIndex = max(0, targetIndex - 1)
        }
        targetIndex = min(max(0, targetIndex), targetColumn.count)

        targetColumn.insert(tile, at: targetIndex)
        updated[columnIndex] = targetColumn

        withAnimation(.easeInOut(duration: 0.15)) {
            columns = updated
            self.dragged = CategorizedDashboardView.DraggedTile(id: dragged.id, column: columnIndex)
        }
    }
}

private struct WarningTileDropDelegate: DropDelegate {
    let item: String?
    @Binding var tiles: [String]
    @Binding var dragged: String?
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

    private func moveTile(dragged: String) {
        guard let sourceIndex = tiles.firstIndex(of: dragged) else { return }
        var updated = tiles
        let tile = updated.remove(at: sourceIndex)

        var targetIndex: Int
        if let item = item, let idx = updated.firstIndex(of: item) {
            targetIndex = idx
        } else {
            targetIndex = updated.count
        }

        if sourceIndex < targetIndex {
            targetIndex = max(0, targetIndex - 1)
        }
        targetIndex = min(max(0, targetIndex), updated.count)

        updated.insert(tile, at: targetIndex)
        withAnimation(.easeInOut(duration: 0.15)) {
            tiles = updated
            self.dragged = dragged
        }
    }
}

private struct CategoryChip: View {
    let category: DashboardCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                CategoryCountBadge(count: count, color: category.accentColor)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? category.pillBackground : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? category.accentColor.opacity(0.35) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryCountBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.16))
            )
            .foregroundColor(color)
    }
}

private struct CategorizedCurrentDateTile: View {
    static let tileID = "current_date"
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

private struct CategorizedDashboardStartupAlertsPopupView: View {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upcoming Deadlines")
                        .font(.headline)
                    Text("Next 7 days")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
            if items.isEmpty {
                Text("No upcoming deadlines.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(items, id: \.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.name)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(format(item.date))
                                        .foregroundColor(.secondary)
                                }
                                if let text = daysUntilText(item.date) {
                                    Text(text)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.08))
                            )
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
