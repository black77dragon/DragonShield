import SwiftUI
#if os(macOS)
    import AppKit
#endif

struct PortfolioThemesAlignedView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    private enum Column: String, CaseIterable, MaintenanceTableColumn {
        case name, code, status, updatedAt, risk, totalValue, instruments, description

        var title: String {
            switch self {
            case .name: return "Portfolio"
            case .code: return "Code"
            case .status: return "Status"
            case .updatedAt: return "Updated"
            case .risk: return "Risk Score"
            case .totalValue: return "Counted Val (CHF)"
            case .instruments: return "# Instr"
            case .description: return "Description"
            }
        }

        var alignment: Alignment {
            switch self {
            case .risk, .totalValue, .instruments:
                return .trailing
            default:
                return .leading
            }
        }
    }

    private enum SortColumn {
        case name, code, status, updatedAt, risk, totalValue, instruments
    }

    private static let visibleColumnsKey = "PortfolioThemesAlignedView.visibleColumns.v1"
    private static let columnOrder: [Column] = Column.allCases
    private static let defaultVisibleColumns: Set<Column> = Set(Column.allCases)
    private static let requiredColumns: Set<Column> = [.name]

    private static let defaultColumnWidths: [Column: CGFloat] = [
        .name: 280,
        .code: 120,
        .status: 150,
        .updatedAt: 140,
        .risk: 140,
        .totalValue: 160,
        .instruments: 120,
        .description: 280
    ]

    private static let minimumColumnWidths: [Column: CGFloat] = [
        .name: 200,
        .code: 80,
        .status: 90,
        .updatedAt: 100,
        .risk: 90,
        .totalValue: 110,
        .instruments: 80,
        .description: 150
    ]

    #if os(macOS)
        private static let columnResizeCursor: NSCursor = {
            let size = NSSize(width: 8, height: 24)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: size).fill()
            let barWidth: CGFloat = 2
            let barRect = NSRect(x: (size.width - barWidth) / 2, y: 0, width: barWidth, height: size.height)
            NSColor(DSColor.accentMain).setFill()
            barRect.fill()
            image.unlockFocus()
            return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
        }()
    #endif

    private static let tableConfiguration: MaintenanceTableConfiguration<Column> = {
        #if os(macOS)
            MaintenanceTableConfiguration(
                preferenceKind: .portfolioThemes,
                columnOrder: columnOrder,
                defaultVisibleColumns: defaultVisibleColumns,
                requiredColumns: requiredColumns,
                defaultColumnWidths: defaultColumnWidths,
                minimumColumnWidths: minimumColumnWidths,
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: 10,
                columnHandleHitSlop: 8,
                columnTextInset: 0,
                headerBackground: DSColor.surfaceSecondary,
                headerTrailingPadding: 0,
                headerVerticalPadding: 0,
                fontConfigBuilder: { size in
                    MaintenanceTableFontConfig(
                        primary: size.baseSize,
                        secondary: max(11, size.secondarySize),
                        header: size.headerSize,
                        badge: max(10, size.badgeSize)
                    )
                },
                columnResizeCursor: columnResizeCursor
            )
        #else
            MaintenanceTableConfiguration(
                preferenceKind: .portfolioThemes,
                columnOrder: columnOrder,
                defaultVisibleColumns: defaultVisibleColumns,
                requiredColumns: requiredColumns,
                defaultColumnWidths: defaultColumnWidths,
                minimumColumnWidths: minimumColumnWidths,
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: 10,
                columnHandleHitSlop: 8,
                columnTextInset: 0,
                headerBackground: DSColor.surfaceSecondary,
                headerTrailingPadding: 0,
                headerVerticalPadding: 0,
                fontConfigBuilder: { size in
                    MaintenanceTableFontConfig(
                        primary: size.baseSize,
                        secondary: max(11, size.secondarySize),
                        header: size.headerSize,
                        badge: max(10, size.badgeSize)
                    )
                }
            )
        #endif
    }()

    @State private var themes: [PortfolioTheme] = []
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var selectedTheme: PortfolioTheme?
    @State private var themeToOpen: PortfolioTheme?
    @State private var searchText = ""
    @State private var sortColumn: SortColumn = .updatedAt
    @State private var sortAscending = false
    @State private var showingAddSheet = false
    @State private var valuationTask: Task<Void, Never>? = nil
    @StateObject private var tableModel = ResizableTableViewModel<Column>(configuration: PortfolioThemesAlignedView.tableConfiguration)
    @State private var showingMinWidthSheet = false
    @State private var minWidthInputs: [Column: Double] = [:]

    private let currencyFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.maximumFractionDigits = 0
        nf.minimumFractionDigits = 0
        return nf
    }()

    private var filteredThemes: [PortfolioTheme] {
        guard !searchText.isEmpty else { return themes }
        return themes.filter { theme in
            let text = searchText.lowercased()
            if theme.name.lowercased().contains(text) { return true }
            if theme.code.lowercased().contains(text) { return true }
            if theme.description?.lowercased().contains(text) == true { return true }
            return false
        }
    }

    private var sortedThemes: [PortfolioTheme] {
        filteredThemes.sorted { lhs, rhs in
            switch sortColumn {
            case .name:
                return sortAscending ? lhs.name < rhs.name : lhs.name > rhs.name
            case .code:
                return sortAscending ? lhs.code < rhs.code : lhs.code > rhs.code
            case .status:
                let lStatus = statusName(for: lhs.statusId)
                let rStatus = statusName(for: rhs.statusId)
                return sortAscending ? lStatus < rStatus : lStatus > rStatus
            case .updatedAt:
                let lDate = parsedDate(lhs.updatedAt)
                let rDate = parsedDate(rhs.updatedAt)
                return sortAscending ? lDate < rDate : lDate > rDate
            case .risk:
                let l = lhs.riskScore ?? -1
                let r = rhs.riskScore ?? -1
                return sortAscending ? l < r : l > r
            case .totalValue:
                let l = lhs.totalValueBase ?? -1
                let r = rhs.totalValueBase ?? -1
                return sortAscending ? l < r : l > r
            case .instruments:
                return sortAscending ? lhs.instrumentCount < rhs.instrumentCount : lhs.instrumentCount > rhs.instrumentCount
            }
        }
    }

    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        Binding(
            get: { tableModel.selectedFontSize },
            set: { tableModel.selectedFontSize = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            searchBar
            tableControls
            tableCard
        }
        .background(DSColor.background.ignoresSafeArea())
        .onAppear {
            tableModel.connect(to: dbManager)
            tableModel.recalcColumnWidths(shouldPersist: false)
            DispatchQueue.main.async {
                loadData()
            }
        }
        .onDisappear {
            valuationTask?.cancel()
            valuationTask = nil
        }
        .sheet(isPresented: $showingAddSheet, onDismiss: loadData) {
            AddPortfolioThemeView(isPresented: $showingAddSheet, onSave: {})
                .environmentObject(dbManager)
        }
        .sheet(isPresented: $showingMinWidthSheet) {
            minWidthSheet
        }
        .sheet(item: $themeToOpen, onDismiss: loadData) { theme in
            PortfolioThemeWorkspaceView(themeId: theme.id, origin: "portfolio_aligned")
                .environmentObject(dbManager)
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Portfolios")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Modern table layout with synced headers and rows.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Portfolio", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColor.accentMain)

                if let theme = selectedTheme {
                    Button {
                        themeToOpen = theme
                    } label: {
                        Label("Open", systemImage: "arrow.turn.down.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceM)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search portfolios...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DSLayout.spaceM)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusM)
                        .stroke(DSColor.border, lineWidth: 1)
                )
        )
        .padding(.horizontal, DSLayout.spaceL)
    }

    private var tableControls: some View {
        HStack(spacing: DSLayout.spaceM) {
            fontSizePicker
            Spacer()
            Button {
                tableModel.resetTablePreferences()
            } label: {
                Label("Reset Layout", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            Button {
                prepareMinWidthInputs()
                showingMinWidthSheet = true
            } label: {
                Label("Set Minimum Widths", systemImage: "text.alignleft")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.top, DSLayout.spaceS)
    }

    private var fontSizePicker: some View {
        Picker("Font Size", selection: fontSizeBinding) {
            ForEach(MaintenanceTableFontSize.allCases, id: \.self) { size in
                Text(size.label).tag(size)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .labelsHidden()
    }

    private var tableCard: some View {
        DSCard(padding: 0) {
            MaintenanceTableView(
                model: tableModel,
                rows: sortedThemes,
                rowSpacing: 0,
                showHorizontalIndicators: true,
                rowContent: { theme, context in
                    themeRow(theme, context: context)
                },
                headerContent: { column, fontConfig in
                    headerCell(for: column, fontConfig: fontConfig)
                }
            )
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.top, DSLayout.spaceM)
        .padding(.bottom, DSLayout.spaceL)
    }

    private func headerCell(for column: Column, fontConfig: MaintenanceTableFontConfig) -> some View {
        let activeSort = sortColumn(for: column) == sortColumn
        return Button {
            toggleSort(column)
        } label: {
            HStack(spacing: 6) {
                Text(column.title)
                    .font(.system(size: fontConfig.header, weight: .semibold))
                    .foregroundColor(.primary)
                if activeSort {
                    Image(systemName: "chevron.compact.\(sortAscending ? "up" : "down")")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 0)
            .padding(.horizontal, 0)
        }
        .buttonStyle(.plain)
    }

    private func themeRow(_ theme: PortfolioTheme, context: MaintenanceTableRowContext<Column>) -> some View {
        HStack(spacing: 0) {
            ForEach(context.columns, id: \.self) { column in
                rowCell(theme, column: column, fontConfig: context.fontConfig)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .frame(width: context.widthForColumn(column), alignment: column.alignment)
            }
        }
        .padding(.horizontal, DSLayout.spaceM)
        .padding(.vertical, 4)
        .background(selectedTheme?.id == theme.id ? DSColor.surfaceHighlight : Color.clear)
        .overlay(
            Rectangle()
                .fill(DSColor.border)
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTheme = theme
        }
        .onTapGesture(count: 2) {
            selectedTheme = theme
            themeToOpen = theme
        }
    }

    private var minWidthSheet: some View {
        let sheetWidth = max(preferredSheetWidth(), 760)
        let sheetHeight = max(preferredSheetHeight(), 560)

        return VStack(spacing: 0) {
            HStack {
                Text("Minimum column widths")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Column.allCases, id: \.self) { column in
                        let binding = Binding<Double>(
                            get: { minWidthInputs[column] ?? Double(tableModel.minimumWidth(for: column)) },
                            set: { minWidthInputs[column] = $0 }
                        )

                        HStack(spacing: 16) {
                            Text(column.title)
                                .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)

                            Stepper(value: binding, in: 60 ... 400, step: 5) {
                                Text("\(Int(binding.wrappedValue)) pt")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 220, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .padding(.top, 8)

            HStack {
                Button("Reset to Defaults") {
                    tableModel.resetMinimumWidths()
                    prepareMinWidthInputs()
                }
                Spacer()
                Button("Cancel") { showingMinWidthSheet = false }
                Button("Save") {
                    let payload = minWidthInputs.reduce(into: [Column: CGFloat]()) { result, entry in
                        result[entry.key] = CGFloat(entry.value)
                    }
                    tableModel.updateMinimumWidths(payload)
                    showingMinWidthSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: sheetWidth, height: sheetHeight)
    }

    private func prepareMinWidthInputs() {
        var values: [Column: Double] = [:]
        for column in Column.allCases {
            values[column] = Double(tableModel.minimumWidth(for: column))
        }
        minWidthInputs = values
    }

    private func preferredSheetWidth() -> CGFloat {
        #if os(macOS)
            let font = NSFont.systemFont(ofSize: 15, weight: .regular)
        #else
            let font = UIFont.systemFont(ofSize: 15, weight: .regular)
        #endif
        let labelWidth = Column.allCases
            .map { titleWidth($0.title, font: font) }
            .max() ?? 0
        let controlWidth: CGFloat = 200
        let padding: CGFloat = 24 * 2
        let spacing: CGFloat = 16
        let buffer: CGFloat = 80
        return max(680, labelWidth + controlWidth + padding + spacing + buffer)
    }

    private func preferredSheetHeight() -> CGFloat {
        let rowHeight: CGFloat = 38
        let headerHeight: CGFloat = 60
        let footerHeight: CGFloat = 64
        let rowsHeight = CGFloat(Column.allCases.count) * rowHeight
        return max(560, headerHeight + rowsHeight + footerHeight)
    }

    private func titleWidth(_ text: String, font: Any) -> CGFloat {
        #if os(macOS)
            guard let font = font as? NSFont else { return 0 }
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            return (text as NSString).size(withAttributes: attributes).width
        #else
            guard let font = font as? UIFont else { return 0 }
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            return (text as NSString).size(withAttributes: attributes).width
        #endif
    }

    @ViewBuilder
    private func rowCell(_ theme: PortfolioTheme, column: Column, fontConfig: MaintenanceTableFontConfig) -> some View {
        switch column {
        case .name:
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.name)
                    .font(.system(size: fontConfig.primary, weight: .medium))
                if let desc = theme.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: fontConfig.secondary))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        case .code:
            Text(theme.code)
                .font(.system(size: fontConfig.secondary, weight: .semibold))
                .foregroundColor(.secondary)
        case .status:
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(for: theme.statusId))
                    .frame(width: 8, height: 8)
                Text(statusName(for: theme.statusId))
                    .font(.system(size: fontConfig.primary, weight: .medium))
                    .foregroundColor(.primary)
            }
        case .updatedAt:
            Text(formattedDate(theme.updatedAt))
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(updatedColor(for: theme.updatedAt))
        case .risk:
            let scoreText = riskText(theme.riskScore, category: theme.riskCategory)
            if let score = theme.riskScore {
                HStack(spacing: 6) {
                    Text(scoreText)
                        .font(.system(size: fontConfig.primary, weight: .semibold))
                        .foregroundColor(riskColor(for: score))
                    if let category = theme.riskCategory, !category.isEmpty {
                        DSBadge(text: category, color: riskColor(for: score))
                    }
                }
            } else {
                Text(scoreText)
                    .font(.system(size: fontConfig.primary, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        case .totalValue:
            Text(formattedValue(theme.totalValueBase))
                .font(.system(size: fontConfig.primary, weight: .medium))
                .foregroundColor(.primary)
        case .instruments:
            Text("\(theme.instrumentCount)")
                .font(.system(size: fontConfig.primary, weight: .medium))
                .foregroundColor(.primary)
        case .description:
            Text(theme.description ?? "—")
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private func formattedValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        currencyFormatter.currencyCode = "CHF"
        currencyFormatter.currencySymbol = ""
        currencyFormatter.maximumFractionDigits = 0
        currencyFormatter.minimumFractionDigits = 0
        let raw = currencyFormatter.string(from: NSNumber(value: value)) ?? "—"
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func riskText(_ score: Double?, category: String?) -> String {
        guard let score else { return "—" }
        let rounded = (score * 10).rounded() / 10
        return String(format: "%.1f", rounded)
    }

    private func updatedColor(for iso: String) -> Color {
        switch updatedDateCategory(iso) {
        case .red:
            return DSColor.accentError
        case .amber:
            return DSColor.accentWarning
        case .green:
            return DSColor.accentSuccess
        case nil:
            return DSColor.textSecondary
        }
    }

    private func updatedDateCategory(_ iso: String) -> UpdatedDateCategory? {
        guard
            let date = ISO8601DateParser.parse(iso),
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date())
        else { return nil }

        if date < twoMonthsAgo { return .red }
        if date < oneMonthAgo { return .amber }
        return .green
    }

    private func formattedDate(_ iso: String) -> String {
        let date = parsedDate(iso)
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func parsedDate(_ iso: String) -> Date {
        if let d = ISO8601DateParser.parse(iso) { return d }
        if let d = DateFormatter.iso8601DateTime.date(from: iso) { return d }
        if let d = ISO8601DateFormatter().date(from: iso) { return d }
        return .distantPast
    }

    private func statusColor(for statusId: Int) -> Color {
        if let status = statuses.first(where: { $0.id == statusId }), !status.colorHex.isEmpty {
            return Color(hex: status.colorHex)
        }
        return DSColor.textSecondary
    }

    private func riskColor(for score: Double) -> Color {
        if score <= 2.5 { return DSColor.accentSuccess }
        if score <= 4.0 { return Color.blue }
        if score <= 5.5 { return DSColor.accentWarning }
        return DSColor.accentError
    }

    private enum UpdatedDateCategory {
        case green, amber, red
    }

    private func toggleSort(_ column: Column) {
        let sort = sortColumn(for: column)
        if sortColumn == sort {
            sortAscending.toggle()
        } else {
            sortColumn = sort
            sortAscending = sort == .updatedAt ? false : true
        }
    }

    private func sortColumn(for column: Column) -> SortColumn {
        switch column {
        case .name: return .name
        case .code: return .code
        case .status: return .status
        case .updatedAt: return .updatedAt
        case .risk: return .risk
        case .totalValue: return .totalValue
        case .instruments: return .instruments
        case .description: return .name
        }
    }

    private func loadData() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
        themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: true)
        if let selected = selectedTheme, !themes.contains(where: { $0.id == selected.id }) {
            selectedTheme = nil
        }
        loadValuations()
    }

    private func statusName(for id: Int) -> String {
        statuses.first(where: { $0.id == id })?.name ?? "Unknown"
    }

    private func loadValuations() {
        valuationTask?.cancel()
        let ids = themes.map { $0.id }
        guard !ids.isEmpty else { return }
        valuationTask = Task {
            let fxService = FXConversionService(dbManager: dbManager)
            let valuationService = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
            let riskService = PortfolioRiskScoringService(dbManager: dbManager, fxService: fxService)
            for id in ids {
                if Task.isCancelled { break }
                let snapshot = valuationService.snapshot(themeId: id)
                let risk = riskService.score(themeId: id, valuation: snapshot)
                await MainActor.run {
                    if let index = themes.firstIndex(where: { $0.id == id }) {
                        themes[index].totalValueBase = snapshot.includedTotalValueBase
                        themes[index].riskScore = risk.portfolioScore
                        themes[index].riskCategory = risk.category.rawValue
                    }
                }
            }
        }
    }
}
