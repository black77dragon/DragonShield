import SwiftUI
#if os(macOS)
    import AppKit
#endif

struct NewPortfoliosView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var preferences: AppPreferences

    fileprivate struct TableFontConfig {
        let nameSize: CGFloat
        let secondarySize: CGFloat
        let headerSize: CGFloat
        let badgeSize: CGFloat
    }

    fileprivate enum ThemeColumn: String, CaseIterable, Codable {
        case name
        case code
        case status
        case timeHorizon
        case updatedAt
        case risk
        case totalValue
        case instruments
        case description

        var title: String {
            switch self {
            case .name: return "Theme"
            case .code: return "Code"
            case .status: return "Status"
            case .timeHorizon: return "Time Horizon"
            case .updatedAt: return "Updated"
            case .risk: return "Risk"
            case .totalValue: return "Counted Value"
            case .instruments: return "# of instr"
            case .description: return "Description"
            }
        }

        var menuTitle: String {
            let title = self.title
            return title.isEmpty ? rawValue.capitalized : title
        }
    }

    private enum SortColumn: String, CaseIterable {
        case name
        case code
        case status
        case timeHorizon
        case updatedAt
        case risk
        case totalValue
        case instruments
    }

    private enum TableFontSize: String, CaseIterable {
        case xSmall, small, medium, large, xLarge

        var label: String {
            switch self {
            case .xSmall: return "XS"
            case .small: return "S"
            case .medium: return "M"
            case .large: return "L"
            case .xLarge: return "XL"
            }
        }

        var baseSize: CGFloat {
            let index: Int
            switch self {
            case .xSmall: index = 0
            case .small: index = 1
            case .medium: index = 2
            case .large: index = 3
            case .xLarge: index = 4
            }
            return TableFontMetrics.baseSize(for: index)
        }

        var secondarySize: CGFloat { max(11, baseSize - 1) }
        var badgeSize: CGFloat { max(10, baseSize - 2) }
        var headerSize: CGFloat { baseSize - 1 }
    }

    private struct ColumnDragContext {
        let primary: ThemeColumn
        let neighbor: ThemeColumn
        let primaryBaseWidth: CGFloat
        let neighborBaseWidth: CGFloat
    }

    fileprivate static let columnOrder: [ThemeColumn] = [.name, .code, .status, .timeHorizon, .updatedAt, .risk, .totalValue, .instruments, .description]
    fileprivate static let defaultVisibleColumns: Set<ThemeColumn> = [.name, .status, .timeHorizon, .updatedAt, .risk, .totalValue, .instruments, .description]
    fileprivate static let requiredColumns: Set<ThemeColumn> = [.name]
    fileprivate static let visibleColumnsKey = "NewPortfoliosView.visibleColumns.v1"

    fileprivate static let defaultColumnWidths: [ThemeColumn: CGFloat] = [
        .name: 280,
        .code: 120,
        .status: 160,
        .timeHorizon: 200,
        .updatedAt: 140,
        .risk: 140,
        .totalValue: 160,
        .instruments: 120,
        .description: 280,
    ]

    fileprivate static let minimumColumnWidths: [ThemeColumn: CGFloat] = [
        .name: 220,
        .code: 100,
        .status: 140,
        .timeHorizon: 170,
        .updatedAt: 120,
        .risk: 120,
        .totalValue: 140,
        .instruments: 100,
        .description: 200,
    ]

    fileprivate static let initialColumnFractions: [ThemeColumn: CGFloat] = {
        let columns = ThemeColumn.allCases
        guard !columns.isEmpty else { return [:] }
        let uniformFraction = max(0.0001, 1.0 / CGFloat(columns.count))
        return columns.reduce(into: [:]) { result, column in
            result[column] = uniformFraction
        }
    }()

    fileprivate static let columnHandleWidth: CGFloat = 10
    fileprivate static let columnHandleHitSlop: CGFloat = 8
    fileprivate static let columnTextInset: CGFloat = 12
    private let headerBackground = Color(red: 230.0 / 255.0, green: 242.0 / 255.0, blue: 1.0)

    @State private var themes: [PortfolioTheme] = []
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var timelines: [PortfolioTimelineRow] = []
    @State private var selectedTheme: PortfolioTheme? = nil
    @State private var searchText = ""
    @State private var showArchivedThemes = true
    @State private var showSoftDeletedThemes = false
    @State private var statusFilters: Set<String> = []
    @State private var valuationTask: Task<Void, Never>? = nil
    @State private var themeToOpen: PortfolioTheme? = nil
    @State private var showingAddSheet = false
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30


    @State private var columnFractions: [ThemeColumn: CGFloat]
    @State private var resolvedColumnWidths: [ThemeColumn: CGFloat]
    @State private var visibleColumns: Set<ThemeColumn>
    @State private var selectedFontSize: TableFontSize
    @State private var didRestoreColumnFractions = false
    @State private var availableTableWidth: CGFloat = 0
    @State private var dragContext: ColumnDragContext? = nil
    @State private var hasHydratedPreferences = false
    @State private var isHydratingPreferences = false
    @State private var sortColumn: SortColumn = .updatedAt
    @State private var sortAscending: Bool = false

    init() {
        let defaults = NewPortfoliosView.initialColumnFractions
        _columnFractions = State(initialValue: defaults)
        _resolvedColumnWidths = State(initialValue: NewPortfoliosView.defaultColumnWidths)

        if let stored = UserDefaults.standard.array(forKey: NewPortfoliosView.visibleColumnsKey) as? [String] {
            var decoded = Set(stored.compactMap(ThemeColumn.init(rawValue:)))
            decoded.insert(.risk) // ensure new risk column is visible by default
            decoded.insert(.timeHorizon)
            _visibleColumns = State(initialValue: decoded.isEmpty ? NewPortfoliosView.defaultVisibleColumns : decoded)
        } else {
            _visibleColumns = State(initialValue: NewPortfoliosView.defaultVisibleColumns)
        }

        _selectedFontSize = State(initialValue: .medium)
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                CustomToolbar(actions: [
                    ToolbarAction(icon: "plus", tooltip: "Create New Portfolio", action: { showingAddSheet = true }),
                    ToolbarAction(icon: "arrow.turn.down.right", tooltip: "Open Selected Portfolio", isDisabled: selectedTheme == nil, action: openSelected),
                    ToolbarAction(icon: "slider.horizontal.3", tooltip: "Columns", action: { /* handled by menu */ }),
                    ToolbarAction(icon: "eye", tooltip: "View Settings", action: { /* handled by menu */ })
                ])
                .opacity(headerOpacity)
                
                header
                    .padding(.horizontal, DSLayout.spaceL)
                    .padding(.top, DSLayout.spaceL)
                    .opacity(headerOpacity)
                searchAndToggles
                    .padding(.horizontal, DSLayout.spaceL)
                    .padding(.top, DSLayout.spaceM)
                    .opacity(headerOpacity)
                filterChips
                    .padding(.horizontal, DSLayout.spaceL)
                    .padding(.top, DSLayout.spaceS)
                    .opacity(headerOpacity)
                tableContent
                    .padding(.horizontal, DSLayout.spaceL)
                    .padding(.top, 12)
                    .padding(.bottom, DSLayout.spaceL)
                    .offset(y: contentOffset)
            }
        }

        .onAppear {
            animateEntrance()
            hydratePreferencesIfNeeded()
            restoreColumnFractionsIfNeeded()
            loadData()
        }
        .onDisappear {
            valuationTask?.cancel()
            valuationTask = nil
        }
        .sheet(isPresented: $showingAddSheet, onDismiss: loadData) {
            AddPortfolioThemeView(isPresented: $showingAddSheet, onSave: {})
                .environmentObject(dbManager)
        }
        .sheet(item: $themeToOpen, onDismiss: loadData) { theme in
            PortfolioThemeWorkspaceView(themeId: theme.id, origin: "new_portfolios")
                .environmentObject(dbManager)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DSLayout.spaceM) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Portfolios")
                    .dsHeaderLarge()
                Text("Modern table view for managing portfolio themes")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(filteredThemes.count)")
                    .dsStatLarge()
                    .foregroundColor(DSColor.accentMain)
                Text("Themes visible")
                    .dsCaption()
            }
        }
    }

    private var searchAndToggles: some View {
        HStack(spacing: DSLayout.spaceM) {
            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DSColor.textTertiary)
                TextField("Search by name or code", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.ds.body)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: DSLayout.radiusM)
                    .fill(DSColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusM)
                    .stroke(DSColor.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
            .frame(minWidth: 280)

            Divider().frame(height: 32)

            Toggle("Show archived", isOn: $showArchivedThemes)
                .toggleStyle(.switch)
                .onChange(of: showArchivedThemes) { _, _ in loadData() }
            Toggle("Show soft-deleted", isOn: $showSoftDeletedThemes)
                .toggleStyle(.switch)
                .onChange(of: showSoftDeletedThemes) { _, _ in loadData() }
            Spacer()
        }
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(Array(statusFilters), id: \.self) { status in
                filterChip(text: status) {
                    statusFilters.remove(status)
                }
            }
            Spacer()
        }
    }



    private var columnsMenu: some View {
        Menu {
            ForEach(NewPortfoliosView.columnOrder, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (visibleColumns.count == 1 || NewPortfoliosView.requiredColumns.contains(column)))
            }
            Divider()
            Button("Reset Columns", action: resetVisibleColumns)
        } label: {
            Label("Columns", systemImage: "slider.horizontal.3")
        }
    }



    private var tableContent: some View {
        Group {
            if sortedThemes.isEmpty {
                emptyState
            } else {
                tableView
            }
        }
    }

    private var tableView: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            let targetWidth = max(availableWidth, totalMinimumWidth())

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    modernTableHeader
                    tableRows
                }
                .frame(width: targetWidth, alignment: .leading)
            }
            .frame(width: availableWidth, alignment: .leading)
            .onAppear { updateAvailableWidth(targetWidth) }
            .onChange(of: proxy.size.width) { _, newValue in
                updateAvailableWidth(max(newValue, totalMinimumWidth()))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0)
    }

    private var tableRows: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                ForEach(sortedThemes, id: \.id) { theme in
                    PortfolioThemeRowView(
                        theme: theme,
                        status: status(for: theme.statusId),
                        timeline: theme.timelineId.flatMap { timelineById[$0] },
                        columns: activeColumns,
                        fontConfig: fontConfig,
                        baseCurrency: preferences.baseCurrency,
                        rowPadding: DSLayout.tableRowPadding,
                        isSelected: selectedTheme?.id == theme.id,
                        widthFor: { width(for: $0) },
                        onSelect: { selectedTheme = theme },
                        onOpen: { selectedTheme = theme; open(theme) }
                    )
                }
            }
        }
        .frame(width: max(availableTableWidth, totalMinimumWidth()), alignment: .leading)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var modernTableHeader: some View {
        HStack(spacing: 0) {
            ForEach(activeColumns, id: \.self) { column in
                headerCell(for: column)
                    .frame(width: width(for: column), alignment: alignment(for: column))
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(DSColor.surfaceSecondary)
                .overlay(Rectangle().stroke(DSColor.border, lineWidth: 1))
        )
        .frame(width: max(availableTableWidth, totalMinimumWidth()), alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "square.grid.2x2" : "doc.text.magnifyingglass")
                .font(.system(size: 72))
                .foregroundColor(.gray.opacity(0.4))
            Text(searchText.isEmpty ? "No themes yet" : "No matching themes")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            Text(searchText.isEmpty ? "Add a portfolio theme to get started." : "Try adjusting your filters or search term.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if searchText.isEmpty {
                Button(action: { showingAddSheet = true }) {
                    Label("Add new Portfolio", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }



    private func alignment(for column: ThemeColumn) -> Alignment {
        switch column {
        case .risk, .totalValue, .instruments:
            return .trailing
        default:
            return .leading
        }
    }

    private func headerCell(for column: ThemeColumn) -> some View {
        let leadingTarget = leadingHandleTarget(for: column)
        let isLast = isLastActiveColumn(column)
        let sortOption = sortOption(for: column)
        let isActiveSort = sortOption.map { $0 == sortColumn } ?? false
        let filterBinding = filterBinding(for: column)
        let filterOptions = filterValues(for: column)
        let alignment = alignment(for: column)
        let leadingOffset = leadingTarget == nil ? 0 : NewPortfoliosView.columnHandleWidth
        let trailingOffset = isLast ? NewPortfoliosView.columnHandleWidth + 8 : 8
        let leadingPadding: CGFloat
        let trailingPadding: CGFloat

        if alignment == .trailing {
            leadingPadding = leadingOffset
            trailingPadding = trailingOffset + NewPortfoliosView.columnTextInset
        } else {
            leadingPadding = NewPortfoliosView.columnTextInset + leadingOffset
            trailingPadding = trailingOffset
        }

        return ZStack(alignment: .leading) {
            if let target = leadingTarget {
                resizeHandle(for: target)
            }
            if isLast {
                resizeHandle(for: column)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            HStack(spacing: 6) {
                if let option = sortOption {
                    Button(action: {
                        if isActiveSort {
                            sortAscending.toggle()
                        } else {
                            sortColumn = option
                            sortAscending = option == .updatedAt ? false : true
                        }
                        applySort()
                    }) {
                        HStack(spacing: 4) {
                            Text(column.title)
                                .font(.system(size: fontConfig.headerSize, weight: .semibold))
                                .foregroundColor(.black)
                            if isActiveSort {
                                Image(systemName: "triangle.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.accentColor)
                                    .rotationEffect(.degrees(sortAscending ? 0 : 180))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(column.title)
                        .font(.system(size: fontConfig.headerSize, weight: .semibold))
                        .foregroundColor(.black)
                }

                if let binding = filterBinding, !filterOptions.isEmpty {
                    Menu {
                        ForEach(filterOptions, id: \.self) { option in
                            Button {
                                if binding.wrappedValue.contains(option) {
                                    binding.wrappedValue.remove(option)
                                } else {
                                    binding.wrappedValue.insert(option)
                                }
                                applySort()
                            } label: {
                                Label(option, systemImage: binding.wrappedValue.contains(option) ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(binding.wrappedValue.isEmpty ? .gray : .accentColor)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
        }
    }

    private func resizeHandle(for column: ThemeColumn) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: NewPortfoliosView.columnHandleWidth + NewPortfoliosView.columnHandleHitSlop * 2, height: 28)
            .offset(x: -NewPortfoliosView.columnHandleHitSlop)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        #if os(macOS)
                            NewPortfoliosView.columnResizeCursor.set()
                        #endif
                        guard availableTableWidth > 0 else { return }
                        if dragContext?.primary != column {
                            beginDrag(for: column)
                        }
                        updateDrag(for: column, translation: value.translation.width)
                    }
                    .onEnded { _ in
                        finalizeDrag()
                        #if os(macOS)
                            NSCursor.arrow.set()
                        #endif
                    }
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 2, height: 22)
            }
            .padding(.vertical, 2)
            .background(Color.clear)
        #if os(macOS)
            .onHover { inside in
                if inside {
                    NewPortfoliosView.columnResizeCursor.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
        #endif
    }

    #if os(macOS)
        private static let columnResizeCursor: NSCursor = {
            let size = NSSize(width: 8, height: 24)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: size).fill()
            let barWidth: CGFloat = 2
            let barRect = NSRect(x: (size.width - barWidth) / 2, y: 0, width: barWidth, height: size.height)
            NSColor.systemBlue.setFill()
            barRect.fill()
            image.unlockFocus()
            return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
        }()
    #endif

    private var activeColumns: [ThemeColumn] {
        let set = visibleColumns.intersection(NewPortfoliosView.columnOrder)
        let ordered = NewPortfoliosView.columnOrder.filter { set.contains($0) }
        return ordered.isEmpty ? [.name] : ordered
    }

    private var fontConfig: TableFontConfig {
        TableFontConfig(
            nameSize: selectedFontSize.baseSize,
            secondarySize: selectedFontSize.secondarySize,
            headerSize: selectedFontSize.headerSize,
            badgeSize: selectedFontSize.badgeSize
        )
    }

    private var timelineById: [Int: PortfolioTimelineRow] {
        Dictionary(uniqueKeysWithValues: timelines.map { ($0.id, $0) })
    }

    private var filteredThemes: [PortfolioTheme] {
        themes.filter { theme in
            if !showArchivedThemes {
                if theme.archivedAt != nil || status(for: theme.statusId)?.code == PortfolioThemeStatus.archivedCode { return false }
            }
            if !showSoftDeletedThemes, theme.softDelete { return false }
            if !statusFilters.isEmpty {
                let name = statusName(for: theme.statusId)
                if !statusFilters.contains(name) { return false }
            }
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }
            let needle = trimmed.lowercased()
            if theme.name.lowercased().contains(needle) { return true }
            if theme.code.lowercased().contains(needle) { return true }
            return theme.description?.lowercased().contains(needle) ?? false
        }
    }

    private var sortedThemes: [PortfolioTheme] {
        guard !filteredThemes.isEmpty else { return [] }
        return filteredThemes.sorted { lhs, rhs in
            switch sortColumn {
            case .name:
                let result = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                return sortAscending ? result != .orderedDescending : result == .orderedDescending
            case .code:
                let result = lhs.code.localizedCaseInsensitiveCompare(rhs.code)
                return sortAscending ? result != .orderedDescending : result == .orderedDescending
            case .status:
                let l = statusName(for: lhs.statusId)
                let r = statusName(for: rhs.statusId)
                let result = l.localizedCaseInsensitiveCompare(r)
                return sortAscending ? result != .orderedDescending : result == .orderedDescending
            case .timeHorizon:
                let l = timeHorizonLabel(for: lhs)
                let r = timeHorizonLabel(for: rhs)
                let result = l.localizedCaseInsensitiveCompare(r)
                return sortAscending ? result != .orderedDescending : result == .orderedDescending
            case .updatedAt:
                let l = lhs.updatedAt
                let r = rhs.updatedAt
                if sortAscending { return l < r } else { return l > r }
            case .risk:
                let ls = lhs.riskScore ?? Double.nan
                let rs = rhs.riskScore ?? Double.nan
                if ls.isNaN, rs.isNaN { return false }
                if ls.isNaN { return !sortAscending }
                if rs.isNaN { return sortAscending }
                return sortAscending ? ls < rs : ls > rs
            case .totalValue:
                let lv = lhs.totalValueBase ?? Double.nan
                let rv = rhs.totalValueBase ?? Double.nan
                if lv.isNaN, rv.isNaN { return false }
                if lv.isNaN { return !sortAscending }
                if rv.isNaN { return sortAscending }
                return sortAscending ? lv < rv : lv > rv
            case .instruments:
                return sortAscending ? lhs.instrumentCount < rhs.instrumentCount : lhs.instrumentCount > rhs.instrumentCount
            }
        }
    }

    private func sortOption(for column: ThemeColumn) -> SortColumn? {
        switch column {
        case .name: return .name
        case .code: return .code
        case .status: return .status
        case .timeHorizon: return .timeHorizon
        case .updatedAt: return .updatedAt
        case .risk: return .risk
        case .totalValue: return .totalValue
        case .instruments: return .instruments
        case .description: return nil
        }
    }

    private func filterBinding(for column: ThemeColumn) -> Binding<Set<String>>? {
        switch column {
        case .status: return $statusFilters
        default: return nil
        }
    }

    private func filterValues(for column: ThemeColumn) -> [String] {
        switch column {
        case .status:
            let names = themes.map { statusName(for: $0.statusId) }.filter { !$0.isEmpty }
            return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        default:
            return []
        }
    }

    private func status(for id: Int) -> PortfolioThemeStatus? {
        statuses.first { $0.id == id }
    }

    private func statusName(for id: Int) -> String {
        status(for: id)?.name ?? ""
    }

    private func timeHorizonLabel(for theme: PortfolioTheme) -> String {
        guard let id = theme.timelineId, let row = timelineById[id] else { return "—" }
        return "\(row.description) (\(row.timeIndication))"
    }

    private func width(for column: ThemeColumn) -> CGFloat {
        resolvedColumnWidths[column] ?? (NewPortfoliosView.defaultColumnWidths[column] ?? 120)
    }

    private func totalMinimumWidth() -> CGFloat {
        activeColumns.reduce(0) { $0 + (NewPortfoliosView.minimumColumnWidths[$1] ?? 80) }
    }

    private func updateAvailableWidth(_ width: CGFloat) {
        guard width != availableTableWidth else { return }
        availableTableWidth = width
        recalcColumnWidths()
    }

    private func recalcColumnWidths() {
        let totalFraction = columnFractions.reduce(0) { $0 + $1.value }
        guard totalFraction > 0 else { return }
        var widths: [ThemeColumn: CGFloat] = [:]
        for column in ThemeColumn.allCases {
            let fraction = columnFractions[column] ?? 0
            let raw = availableTableWidth * fraction / totalFraction
            let minWidth = NewPortfoliosView.minimumColumnWidths[column] ?? 80
            widths[column] = max(minWidth, raw)
        }
        resolvedColumnWidths = widths
    }

    private func beginDrag(for column: ThemeColumn) {
        guard let neighbor = trailingNeighbor(of: column) else { return }
        let primaryWidth = width(for: column)
        let neighborWidth = width(for: neighbor)
        dragContext = ColumnDragContext(primary: column, neighbor: neighbor, primaryBaseWidth: primaryWidth, neighborBaseWidth: neighborWidth)
    }

    private func updateDrag(for column: ThemeColumn, translation: CGFloat) {
        guard let context = dragContext else { return }
        let minWidth = NewPortfoliosView.minimumColumnWidths[column] ?? 80
        let neighborMin = NewPortfoliosView.minimumColumnWidths[context.neighbor] ?? 80
        let proposedPrimary = max(minWidth, context.primaryBaseWidth + translation)
        let proposedNeighbor = max(neighborMin, context.neighborBaseWidth - translation)
        let combined = proposedPrimary + proposedNeighbor
        guard combined > 0, availableTableWidth > 0 else { return }

        var fractions = columnFractions
        fractions[column] = max(0.0001, proposedPrimary / availableTableWidth)
        fractions[context.neighbor] = max(0.0001, proposedNeighbor / availableTableWidth)
        columnFractions = normalizedFractions(fractions)
        recalcColumnWidths()
    }

    private func finalizeDrag() {
        dragContext = nil
        persistColumnFractions()
    }

    private func trailingNeighbor(of column: ThemeColumn) -> ThemeColumn? {
        guard let index = activeColumns.firstIndex(of: column), index < activeColumns.count - 1 else { return nil }
        return activeColumns[index + 1]
    }

    private func leadingHandleTarget(for column: ThemeColumn) -> ThemeColumn? {
        guard let index = activeColumns.firstIndex(of: column), index > 0 else { return nil }
        return activeColumns[index - 1]
    }

    private func isLastActiveColumn(_ column: ThemeColumn) -> Bool {
        guard let index = activeColumns.firstIndex(of: column) else { return false }
        return index == activeColumns.count - 1
    }

    private func normalizedFractions(_ fractions: [ThemeColumn: CGFloat]) -> [ThemeColumn: CGFloat] {
        let sum = fractions.values.reduce(0, +)
        guard sum > 0 else { return fractions }
        return fractions.mapValues { max(0.0001, $0 / sum) }
    }

    private func toggleColumn(_ column: ThemeColumn) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1, !NewPortfoliosView.requiredColumns.contains(column) else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        persistVisibleColumns()
        recalcColumnWidths()
    }

    private func resetVisibleColumns() {
        visibleColumns = NewPortfoliosView.defaultVisibleColumns
        columnFractions = NewPortfoliosView.initialColumnFractions
        recalcColumnWidths()
        persistVisibleColumns()
        persistColumnFractions()
    }

    private func resetTablePreferences() {
        visibleColumns = NewPortfoliosView.defaultVisibleColumns
        selectedFontSize = .medium
        columnFractions = NewPortfoliosView.initialColumnFractions
        recalcColumnWidths()
        persistVisibleColumns()
        persistFontSize()
        persistColumnFractions()
    }

    private func persistVisibleColumns() {
        let ordered = NewPortfoliosView.columnOrder.filter { visibleColumns.contains($0) }
        UserDefaults.standard.set(ordered.map { $0.rawValue }, forKey: NewPortfoliosView.visibleColumnsKey)
    }

    private func persistFontSize() {
        guard !isHydratingPreferences else { return }
        isHydratingPreferences = true
        dbManager.setTableFontSize(selectedFontSize.rawValue, for: .portfolioThemes)
        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    private func persistColumnFractions() {
        guard !isHydratingPreferences else { return }
        isHydratingPreferences = true
        let payload = columnFractions.reduce(into: [String: Double]()) { result, entry in
            result[entry.key.rawValue] = entry.value.isFinite ? Double(entry.value) : 0
        }
        dbManager.setTableColumnFractions(payload, for: .portfolioThemes)
        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    private func hydratePreferencesIfNeeded() {
        guard !hasHydratedPreferences else { return }
        hasHydratedPreferences = true
        isHydratingPreferences = true

        let storedFont = preferences.tableFontSize(for: .portfolioThemes)
        if let stored = TableFontSize(rawValue: storedFont) {
            selectedFontSize = stored
        }

        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    private func restoreColumnFractionsIfNeeded() {
        guard !didRestoreColumnFractions else { return }
        didRestoreColumnFractions = true
        let stored = preferences.tableColumnFractions(for: .portfolioThemes)
        guard !stored.isEmpty else {
            recalcColumnWidths()
            return
        }
        var typed: [ThemeColumn: CGFloat] = [:]
        for (key, value) in stored {
            guard let column = ThemeColumn(rawValue: key), value.isFinite else { continue }
            typed[column] = CGFloat(max(0, value))
        }
        if !typed.isEmpty {
            columnFractions = normalizedFractions(typed)
            recalcColumnWidths()
        }
    }

    private func loadData() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
        timelines = dbManager.listPortfolioTimelines(includeInactive: true)
        themes = dbManager.fetchPortfolioThemes(includeArchived: showArchivedThemes, includeSoftDeleted: showSoftDeletedThemes)
        if let selected = selectedTheme, !themes.contains(where: { $0.id == selected.id }) {
            selectedTheme = nil
        }
        applySort()
        loadValuations()
    }

    private func applySort() {}

    private func loadValuations() {
        valuationTask?.cancel()
        let snapshotIds = themes.map { $0.id }
        guard !snapshotIds.isEmpty else { return }
        valuationTask = Task {
            let fxService = FXConversionService(dbManager: dbManager)
            let service = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
            let riskService = PortfolioRiskScoringService(dbManager: dbManager, fxService: fxService)
            for id in snapshotIds {
                if Task.isCancelled { break }
                let snapshot = service.snapshot(themeId: id)
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

    private func openSelected() {
        guard let theme = selectedTheme else {
            #if os(macOS)
                NSSound.beep()
            #endif
            return
        }
        open(theme)
    }

    private func open(_ theme: PortfolioTheme) {
        themeToOpen = theme
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6)) {
            headerOpacity = 1
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)) {
            contentOffset = 0
        }
    }

    private func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct PortfolioThemeRowView: View {
    let theme: PortfolioTheme
    let status: PortfolioThemeStatus?
    let timeline: PortfolioTimelineRow?
    let columns: [NewPortfoliosView.ThemeColumn]
    let fontConfig: NewPortfoliosView.TableFontConfig
    let baseCurrency: String
    let rowPadding: CGFloat
    let isSelected: Bool
    let widthFor: (NewPortfoliosView.ThemeColumn) -> CGFloat
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        let verticalPadding = max(4, rowPadding)

        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                columnView(for: column)
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, verticalPadding)
        .background(
            Rectangle()
                .fill(isSelected ? DSColor.surfaceHighlight : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? DSColor.accentMain.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .overlay(
            Rectangle()
                .fill(DSColor.border)
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) {
            onSelect()
            onOpen()
        }
        .contextMenu {
            Button("Open Theme", action: onOpen)
            Button("Select Theme", action: onSelect)
            #if os(macOS)
                Divider()
                Button("Copy Name") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(theme.name, forType: .string)
                }
                Button("Copy Code") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(theme.code, forType: .string)
                }
            #endif
        }
    }

    @ViewBuilder
    private func columnView(for column: NewPortfoliosView.ThemeColumn) -> some View {
        switch column {
        case .name:
            HStack(spacing: 6) {
                Text(theme.name)
                    .dsBody()
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let archivedAt = theme.archivedAt, !archivedAt.isEmpty {
                    DSBadge(text: "Archived", color: DSColor.accentWarning)
                }
                if theme.softDelete {
                    DSBadge(text: "Soft Deleted", color: DSColor.accentError)
                }
            }
            .padding(.leading, NewPortfoliosView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.name), alignment: .leading)
        case .code:
            Text(theme.code)
                .dsMonoSmall()
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, NewPortfoliosView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.code), alignment: .leading)
        case .status:
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(status?.name ?? "—")
                    .dsBodySmall()
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, NewPortfoliosView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.status), alignment: .leading)
        case .timeHorizon:
            VStack(alignment: .leading, spacing: 2) {
                Text(timeHorizonLabel)
                    .dsBodySmall()
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let endDateText = endDateLabel {
                    Text(endDateText)
                        .font(.system(size: fontConfig.secondarySize))
                        .foregroundColor(endDateStatusColor)
                }
            }
            .padding(.leading, NewPortfoliosView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.timeHorizon), alignment: .leading)
        case .updatedAt:
            updatedAtText()
        case .risk:
            if let score = theme.riskScore {
                HStack(spacing: 6) {
                    Text(score, format: .number.precision(.fractionLength(1)))
                        .dsMono()
                        .foregroundColor(riskColor(for: score))
                    if let cat = theme.riskCategory {
                        DSBadge(text: cat, color: riskColor(for: score))
                    }
                }
                .padding(.trailing, 8)
                .frame(width: widthFor(.risk), alignment: .trailing)
            } else {
                HStack(spacing: 4) {
                    Text("—")
                        .dsBodySmall()
                    ProgressView().controlSize(.small)
                }
                .padding(.trailing, 8)
                .frame(width: widthFor(.risk), alignment: .trailing)
            }
        case .totalValue:
            if let value = theme.totalValueBase, let formatted = formattedTotalValue(value) {
                Text(formatted)
                    .dsMono()
                    .padding(.trailing, 8)
                    .frame(width: widthFor(.totalValue), alignment: .trailing)
            } else {
                HStack(spacing: 4) {
                    Text("—")
                        .dsBodySmall()
                    ProgressView().controlSize(.small)
                }
                .padding(.trailing, 8)
                .frame(width: widthFor(.totalValue), alignment: .trailing)
            }
        case .instruments:
            Text("\(theme.instrumentCount)")
                .dsBody()
                .padding(.trailing, 8)
                .frame(width: widthFor(.instruments), alignment: .trailing)
        case .description:
            Text(theme.description ?? "—")
                .dsBodySmall()
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .truncationMode(.tail)
                .padding(.leading, NewPortfoliosView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.description), alignment: .leading)
        }
    }

    private var statusColor: Color {
        if let status, !status.colorHex.isEmpty {
            return Color(hex: status.colorHex)
        }
        if theme.archivedAt != nil {
            return DSColor.accentWarning
        }
        return DSColor.textSecondary
    }

    private var timeHorizonLabel: String {
        guard let timeline else { return "—" }
        return "\(timeline.description) (\(timeline.timeIndication))"
    }

    private var endDateLabel: String? {
        guard let raw = theme.timeHorizonEndDate, !raw.isEmpty else { return nil }
        let formatted = DateFormatting.dateOnly(raw)
        if formatted == "—" { return "End \(raw)" }
        return "End \(formatted)"
    }

    private var endDateStatusColor: Color {
        guard let raw = theme.timeHorizonEndDate, let date = ISO8601DateParser.parse(raw) else {
            return DSColor.textSecondary
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: endDay).day ?? 0
        if days < 0 { return DSColor.accentError }
        if days <= 30 { return DSColor.accentWarning }
        return DSColor.textSecondary
    }

    private func riskColor(for score: Double) -> Color {
        if score <= 2.5 { return DSColor.accentSuccess }
        if score <= 4.0 { return Color.blue }
        if score <= 5.5 { return DSColor.accentWarning }
        return DSColor.accentError
    }

    private func updatedAtText() -> some View {
        let category = updatedDateCategory(theme.updatedAt)
        return Text(DateFormatting.dateOnly(theme.updatedAt))
            .dsBodySmall()
            .foregroundColor(updatedDateColor(for: category))
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, NewPortfoliosView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.updatedAt), alignment: .leading)
    }

    private func formattedTotalValue(_ value: Double) -> String? {
        PortfolioThemeRowView.totalValueFormatter.string(from: NSNumber(value: value))
    }

    private func updatedDateCategory(_ isoString: String) -> UpdatedDateCategory? {
        guard
            let date = ISO8601DateParser.parse(isoString),
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date())
        else {
            return nil
        }

        if date < twoMonthsAgo { return .red }
        if date < oneMonthAgo { return .amber }
        return .green
    }

    private func updatedDateColor(for category: UpdatedDateCategory?) -> Color {
        switch category {
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

    private enum UpdatedDateCategory {
        case green, amber, red
    }

    private static let totalValueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "'"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

#if DEBUG
    #Preview {
        NewPortfoliosView()
            .environmentObject(DatabaseManager())
            .frame(minWidth: 1200, minHeight: 720)
    }
#endif
