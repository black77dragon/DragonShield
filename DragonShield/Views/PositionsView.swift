import SwiftUI
#if os(macOS)
    import AppKit
#endif

private enum PositionTableColumn: String, CaseIterable, Codable, MaintenanceTableColumn {
    case instrument
    case account
    case institution
    case currency
    case quantity
    case purchaseValue
    case currentValue
    case valueOriginal
    case valueChf
    case reportDate
    case uploadedAt
    case assetClass
    case assetSubClass
    case sector
    case country
    case importSession
    case notes

    var title: String {
        switch self {
        case .instrument: return "Instrument"
        case .account: return "Account"
        case .institution: return "Institution"
        case .currency: return "Cur"
        case .quantity: return "Qty"
        case .purchaseValue: return "Purchase"
        case .currentValue: return "Latest"
        case .valueOriginal: return "Val (orig)"
        case .valueChf: return "Val (CHF)"
        case .reportDate: return "Report"
        case .uploadedAt: return "Uploaded"
        case .assetClass: return "Asset Class"
        case .assetSubClass: return "Sub-Class"
        case .sector: return "Sector"
        case .country: return "Country"
        case .importSession: return "Import"
        case .notes: return "Notes"
        }
    }

    var menuTitle: String {
        let base = title
        return base.isEmpty ? rawValue.capitalized : base
    }
}

private enum PositionSortColumn: String, CaseIterable {
    case instrument
    case account
    case institution
    case currency
    case quantity
    case purchaseValue
    case currentValue
    case valueOriginal
    case valueChf
    case reportDate
    case uploadedAt
    case assetClass
    case assetSubClass
    case sector
    case country
    case importSession
}

struct PositionsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var positions: [PositionReportData] = []
    @State private var selectedPositionId: Int? = nil
    @State private var searchText: String = ""
    @State private var currencyFilters: Set<String> = []
    @State private var institutionFilters: Set<String> = []
    @State private var assetClassFilters: Set<String> = []

    @State private var sortColumn: PositionSortColumn = .instrument
    @State private var sortAscending: Bool = true

    @State private var isRefreshing: Bool = false
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    @StateObject private var tableModel = ResizableTableViewModel<PositionTableColumn>(configuration: PositionsView.tableConfiguration)
    @StateObject private var metrics = PositionsViewModel()
    @State private var quantityDrafts: [Int: String] = [:]
    @State private var positionToEdit: PositionReportData? = nil
    @State private var showDeleteConfirmation = false
    @State private var showAddPositionSheet = false

    private static let columnOrder: [PositionTableColumn] = [
        .instrument, .account, .institution, .currency, .quantity,
        .purchaseValue, .currentValue, .valueOriginal, .valueChf,
        .reportDate, .uploadedAt, .assetClass, .assetSubClass,
        .sector, .country, .importSession, .notes,
    ]

    private static let defaultVisibleColumns: Set<PositionTableColumn> = [
        .instrument, .account, .institution, .currency, .quantity,
        .valueOriginal, .valueChf, .reportDate,
    ]

    private static let requiredColumns: Set<PositionTableColumn> = [.instrument]
    private static let visibleColumnsKey = "PositionsView.visibleColumns.v1"
    private static let headerBackground = Color(red: 230.0 / 255.0, green: 242.0 / 255.0, blue: 1.0)
    private static let columnHandleWidth: CGFloat = 10
    private static let columnHandleHitSlop: CGFloat = 8
    fileprivate static let columnTextInset: CGFloat = 12

    private static let defaultColumnWidths: [PositionTableColumn: CGFloat] = [
        .instrument: 260,
        .account: 220,
        .institution: 220,
        .currency: 80,
        .quantity: 120,
        .purchaseValue: 150,
        .currentValue: 150,
        .valueOriginal: 170,
        .valueChf: 170,
        .reportDate: 140,
        .uploadedAt: 160,
        .assetClass: 180,
        .assetSubClass: 180,
        .sector: 160,
        .country: 120,
        .importSession: 120,
        .notes: 90,
    ]

    private static let minimumColumnWidths: [PositionTableColumn: CGFloat] = [
        .instrument: 200,
        .account: 180,
        .institution: 180,
        .currency: 70,
        .quantity: 100,
        .purchaseValue: 130,
        .currentValue: 130,
        .valueOriginal: 150,
        .valueChf: 150,
        .reportDate: 120,
        .uploadedAt: 140,
        .assetClass: 150,
        .assetSubClass: 150,
        .sector: 140,
        .country: 100,
        .importSession: 110,
        .notes: 70,
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
            NSColor.systemBlue.setFill()
            barRect.fill()
            image.unlockFocus()
            return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
        }()
    #endif

    private static let tableConfiguration: MaintenanceTableConfiguration<PositionTableColumn> = {
        #if os(macOS)
            MaintenanceTableConfiguration(
                preferenceKind: .positions,
                columnOrder: columnOrder,
                defaultVisibleColumns: defaultVisibleColumns,
                requiredColumns: requiredColumns,
                defaultColumnWidths: defaultColumnWidths,
                minimumColumnWidths: minimumColumnWidths,
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: columnHandleWidth,
                columnHandleHitSlop: columnHandleHitSlop,
                columnTextInset: columnTextInset,
                headerBackground: headerBackground,
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
                preferenceKind: .positions,
                columnOrder: columnOrder,
                defaultVisibleColumns: defaultVisibleColumns,
                requiredColumns: requiredColumns,
                defaultColumnWidths: defaultColumnWidths,
                minimumColumnWidths: minimumColumnWidths,
                visibleColumnsDefaultsKey: visibleColumnsKey,
                columnHandleWidth: columnHandleWidth,
                columnHandleHitSlop: columnHandleHitSlop,
                columnTextInset: columnTextInset,
                headerBackground: headerBackground,
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

    private var visibleColumns: Set<PositionTableColumn> { tableModel.visibleColumns }
    private var selectedFontSize: MaintenanceTableFontSize { tableModel.selectedFontSize }
    private var fontConfig: MaintenanceTableFontConfig { tableModel.fontConfig }
    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        Binding(
            get: { tableModel.selectedFontSize },
            set: { tableModel.selectedFontSize = $0 }
        )
    }

    private var filteredPositions: [PositionReportData] {
        var result = metrics.filterPositions(
            positions,
            searchText: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedInstitutionNames: Array(institutionFilters),
            currencyFilters: currencyFilters
        )
        if !assetClassFilters.isEmpty {
            result = result.filter { position in
                if let assetClass = position.assetClass, !assetClass.isEmpty {
                    return assetClassFilters.contains(assetClass)
                }
                return false
            }
        }
        return result
    }

    private var sortedPositions: [PositionReportData] {
        let base = filteredPositions
        let sorted = base.sorted { lhs, rhs in
            switch sortColumn {
            case .instrument:
                return compare(lhs.instrumentName, rhs.instrumentName)
            case .account:
                return compare(lhs.accountName, rhs.accountName)
            case .institution:
                return compare(lhs.institutionName, rhs.institutionName)
            case .currency:
                return compare(lhs.instrumentCurrency, rhs.instrumentCurrency)
            case .quantity:
                return compare(lhs.quantity, rhs.quantity)
            case .purchaseValue:
                return compare(lhs.purchasePrice, rhs.purchasePrice)
            case .currentValue:
                return compare(lhs.currentPrice, rhs.currentPrice)
            case .valueOriginal:
                return compare(valueOriginal(of: lhs), valueOriginal(of: rhs))
            case .valueChf:
                return compare(valueChf(of: lhs), valueChf(of: rhs))
            case .reportDate:
                return compare(lhs.reportDate, rhs.reportDate)
            case .uploadedAt:
                return compare(lhs.uploadedAt, rhs.uploadedAt)
            case .assetClass:
                return compare(lhs.assetClass, rhs.assetClass)
            case .assetSubClass:
                return compare(lhs.assetSubClass, rhs.assetSubClass)
            case .sector:
                return compare(lhs.instrumentSector, rhs.instrumentSector)
            case .country:
                return compare(lhs.instrumentCountry, rhs.instrumentCountry)
            case .importSession:
                return compare(lhs.importSessionId, rhs.importSessionId)
            }
        }
        return sortAscending ? sorted : Array(sorted.reversed())
    }

    private var uniqueCurrencies: [String] {
        Array(Set(positions.map { $0.instrumentCurrency })).sorted()
    }

    private var uniqueInstitutions: [String] {
        Array(Set(positions.map { $0.institutionName })).sorted()
    }

    private var uniqueAssetClasses: [String] {
        Array(Set(positions.compactMap { $0.assetClass })).sorted()
    }

    private var filteredValueCHF: Double {
        filteredPositions.reduce(0) { partial, position in
            guard let entry = metrics.positionValueCHF[position.id], let value = entry else { return partial }
            return partial + value
        }
    }

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !currencyFilters.isEmpty ||
            !institutionFilters.isEmpty ||
            !assetClassFilters.isEmpty
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header
                searchAndFilters
                tableControls
                if sortedPositions.isEmpty {
                    emptyState
                        .offset(y: contentOffset)
                } else {
                    positionsTable
                        .offset(y: contentOffset)
                }
                footerActions
            }
            .padding(DSLayout.spaceL)
        }
        .onAppear {
            tableModel.connect(to: dbManager)
            loadPositions()
            animateEntrance()
        }
        .sheet(item: $positionToEdit) { item in
            PositionFormView(position: item) {
                loadPositions()
            }
            .environmentObject(dbManager)
        }
        .sheet(isPresented: $showAddPositionSheet) {
            PositionFormView(position: nil) {
                loadPositions()
            }
            .environmentObject(dbManager)
        }
        .alert("Delete Position", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                confirmDeleteSelected()
            }
        } message: {
            if let selectedId = selectedPositionId,
               let position = positions.first(where: { $0.id == selectedId })
            {
                Text("Are you sure you want to delete '\(position.instrumentName)' from account '\(position.accountName)'?")
            } else {
                Text("Select a position before deleting.")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                HStack(spacing: DSLayout.spaceM) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 32))
                        .foregroundColor(DSColor.accentMain)
                    Text("Positions")
                        .dsHeaderLarge()
                        .foregroundColor(DSColor.textPrimary)
                }
                Text("Holdings table with filters, resizing, and persistence")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: DSLayout.spaceS) {
                statBlock(title: "Positions", value: "\(positions.count)")
                statBlock(
                    title: "Filtered Value (CHF)",
                    value: Self.chfFormatter.string(from: NSNumber(value: filteredValueCHF)) ?? "–"
                )
            }
        }
        .opacity(headerOpacity)
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DSColor.textSecondary)
                TextField("Search positions…", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.ds.body)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DSColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSLayout.spaceM)
            .padding(.vertical, DSLayout.spaceS)
            .background(DSColor.surface)
            .cornerRadius(DSLayout.radiusM)
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusM)
                    .stroke(DSColor.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)

            HStack(spacing: 12) {
                filterMenu(
                    title: currencyFilters.isEmpty ? "Currency" : "Currency (\(currencyFilters.count))",
                    icon: "coloncurrencysign.circle",
                    options: uniqueCurrencies,
                    selection: $currencyFilters
                )
                filterMenu(
                    title: institutionFilters.isEmpty ? "Institution" : "Institution (\(institutionFilters.count))",
                    icon: "building.2",
                    options: uniqueInstitutions,
                    selection: $institutionFilters
                )
                filterMenu(
                    title: assetClassFilters.isEmpty ? "Asset Class" : "Asset Class (\(assetClassFilters.count))",
                    icon: "square.stack.3d.up",
                    options: uniqueAssetClasses,
                    selection: $assetClassFilters
                )
                if isFiltering {
                    Button("Clear Filters") {
                        currencyFilters.removeAll()
                        institutionFilters.removeAll()
                        assetClassFilters.removeAll()
                    }
                    .buttonStyle(.link)
                }
                Spacer()
            }

            if isFiltering {
                VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                    Text("Showing \(filteredPositions.count) of \(positions.count) positions")
                        .dsCaption()
                        .foregroundColor(DSColor.textSecondary)
                    filterChips
                }
            }
        }
    }

    private var tableControls: some View {
        HStack(spacing: 12) {
            columnsMenu
            fontSizePicker
            Spacer()
            if visibleColumns != Self.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View") {
                    tableModel.resetTablePreferences()
                }
                .buttonStyle(.link)
            }
        }
        .font(.system(size: 12))
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(Self.columnOrder, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    tableModel.toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (visibleColumns.count == 1 || Self.requiredColumns.contains(column)))
            }
            Divider()
            Button("Reset Columns") {
                tableModel.resetVisibleColumns()
            }
        } label: {
            Label("Columns", systemImage: "slider.horizontal.3")
        }
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

    private var positionsTable: some View {
        MaintenanceTableView(
            model: tableModel,
            rows: sortedPositions,
            rowSpacing: DSLayout.tableRowSpacing,
            showHorizontalIndicators: true,
            rowContent: { position, context in
                PositionsRowView(
                    position: position,
                    columns: context.columns,
                    fontConfig: context.fontConfig,
                    widthFor: { context.widthForColumn($0) },
                    isSelected: selectedPositionId == position.id,
                    onSelect: { selectedPositionId = position.id },
                    onDoubleTap: { openEditor(for: position) },
                    quantityBinding: quantityBinding(for: position),
                    onQuantityCommit: { commitQuantityEdit(for: position) },
                    originalValue: valueOriginal(of: position),
                    chfValue: valueChf(of: position),
                    currencySymbol: metrics.currencySymbols[position.instrumentCurrency.uppercased()] ?? position.instrumentCurrency,
                    chfFormatter: Self.chfFormatter,
                    currencyFormatter: Self.currencyFormatter
                )
            },
            headerContent: { column, fontConfig in
                positionsHeader(for: column, fontConfig: fontConfig)
            }
        )
    }

    private func positionsHeader(for column: PositionTableColumn, fontConfig: MaintenanceTableFontConfig) -> some View {
        let sortOption = sortOption(for: column)
        let isActiveSort = sortOption == sortColumn
        let headerWeight: Font.Weight = column == .valueChf ? .bold : .semibold
        return HStack(spacing: 6) {
            if let sortOption {
                Button {
                    if isActiveSort {
                        sortAscending.toggle()
                    } else {
                        sortColumn = sortOption
                        sortAscending = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(column.title)
                            .font(.system(size: fontConfig.header, weight: headerWeight))
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
                    .font(.system(size: fontConfig.header, weight: headerWeight))
                    .foregroundColor(DSColor.textPrimary)
            }
        }
    }

    private func sortOption(for column: PositionTableColumn) -> PositionSortColumn? {
        switch column {
        case .instrument: return .instrument
        case .account: return .account
        case .institution: return .institution
        case .currency: return .currency
        case .quantity: return .quantity
        case .purchaseValue: return .purchaseValue
        case .currentValue: return .currentValue
        case .valueOriginal: return .valueOriginal
        case .valueChf: return .valueChf
        case .reportDate: return .reportDate
        case .uploadedAt: return .uploadedAt
        case .assetClass: return .assetClass
        case .assetSubClass: return .assetSubClass
        case .sector: return .sector
        case .country: return .country
        case .importSession: return .importSession
        case .notes: return nil
        }
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(Array(currencyFilters), id: \.self) { value in
                filterChip(label: value) { currencyFilters.remove(value) }
            }
            ForEach(Array(institutionFilters), id: \.self) { value in
                filterChip(label: value) { institutionFilters.remove(value) }
            }
            ForEach(Array(assetClassFilters), id: \.self) { value in
                filterChip(label: value) { assetClassFilters.remove(value) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DSLayout.spaceL) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(DSColor.textTertiary)
            Text(isFiltering ? "No positions match your filters" : "No positions available")
                .dsHeaderSmall()
                .foregroundColor(DSColor.textSecondary)
            if isFiltering {
                Button("Clear Filters") {
                    searchText = ""
                    currencyFilters.removeAll()
                    institutionFilters.removeAll()
                    assetClassFilters.removeAll()
                }
                .buttonStyle(DSButtonStyle(type: .secondary))
            }
            Spacer()
        }
        .padding(.vertical, 32)
    }

    private var footerActions: some View {
        HStack(spacing: DSLayout.spaceM) {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
            Button(action: refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(DSButtonStyle(type: .secondary))
            .disabled(isRefreshing)

            Button {
                showAddPositionSheet = true
            } label: {
                Label("New Position", systemImage: "plus")
            }
            .buttonStyle(DSButtonStyle(type: .primary))

            Button {
                editSelectedPosition()
            } label: {
                Label("Edit Selected", systemImage: "square.and.pencil")
            }
            .buttonStyle(DSButtonStyle(type: .secondary))
            .disabled(selectedPositionId == nil)

            Button {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Selected", systemImage: "trash")
            }
            .buttonStyle(DSButtonStyle(type: .secondary)) // Using secondary for destructive action, could add a destructive style later
            .disabled(selectedPositionId == nil)

            Spacer()

            if let selected = selectedPositionId,
               let position = positions.first(where: { $0.id == selected })
            {
                Text("Selected: \(position.instrumentName) — \(position.accountName)")
                    .dsCaption()
                    .foregroundColor(DSColor.textSecondary)
            }
        }
    }

    private func loadPositions() {
        positions = dbManager.fetchPositionReports()
        resetQuantityDrafts()
        metrics.calculateValues(positions: positions, db: dbManager)
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let fresh = dbManager.fetchPositionReports()
        positions = fresh
        resetQuantityDrafts()
        metrics.calculateValues(positions: fresh, db: dbManager)
        isRefreshing = false
    }

    private func resetQuantityDrafts() {
        quantityDrafts = positions.reduce(into: [Int: String]()) { dict, position in
            dict[position.id] = canonicalQuantityString(for: position.quantity)
        }
    }

    private func quantityBinding(for position: PositionReportData) -> Binding<String> {
        let id = position.id
        return Binding(
            get: {
                quantityDrafts[id] ?? canonicalQuantityString(for: currentQuantity(for: id) ?? position.quantity)
            },
            set: { newValue in
                quantityDrafts[id] = newValue
            }
        )
    }

    private func commitQuantityEdit(for position: PositionReportData) {
        let id = position.id
        guard var draft = quantityDrafts[id] else { return }
        draft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.isEmpty {
            revertQuantityDraft(for: id)
            return
        }
        guard let parsed = parseQuantity(draft) else {
            revertQuantityDraft(for: id)
            return
        }
        applyQuantity(parsed, to: id)
    }

    private func applyQuantity(_ value: Double, to id: Int) {
        guard let index = positions.firstIndex(where: { $0.id == id }) else { return }
        let current = positions[index].quantity
        if abs(current - value) < 0.00001 {
            quantityDrafts[id] = canonicalQuantityString(for: current)
            return
        }
        if dbManager.updatePositionQuantity(id: id, quantity: value) {
            positions[index].quantity = value
            quantityDrafts[id] = canonicalQuantityString(for: value)
            metrics.calculateValues(positions: positions, db: dbManager)
        } else {
            revertQuantityDraft(for: id)
        }
    }

    private func revertQuantityDraft(for id: Int) {
        if let value = currentQuantity(for: id) {
            quantityDrafts[id] = canonicalQuantityString(for: value)
        } else {
            quantityDrafts[id] = nil
        }
    }

    private func currentQuantity(for id: Int) -> Double? {
        positions.first(where: { $0.id == id })?.quantity
    }

    private func parseQuantity(_ text: String) -> Double? {
        let sanitized = text
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "")
        if sanitized.isEmpty { return nil }
        if let direct = Double(sanitized.replacingOccurrences(of: ",", with: ".")) {
            return direct
        }
        return Self.quantityFormatter.number(from: sanitized)?.doubleValue
    }

    private func canonicalQuantityString(for value: Double) -> String {
        Self.quantityFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.4f", value)
    }

    private func editSelectedPosition() {
        guard let selectedId = selectedPositionId,
              let position = positions.first(where: { $0.id == selectedId }) else { return }
        positionToEdit = position
    }

    private func openEditor(for position: PositionReportData) {
        selectedPositionId = position.id
        positionToEdit = position
    }

    private func confirmDeleteSelected() {
        guard let selectedId = selectedPositionId else { return }
        showDeleteConfirmation = false
        let succeeded = dbManager.deletePositionReport(id: selectedId)
        if succeeded {
            positions.removeAll { $0.id == selectedId }
            quantityDrafts[selectedId] = nil
            selectedPositionId = nil
            resetQuantityDrafts()
            metrics.calculateValues(positions: positions, db: dbManager)
        }
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6)) { headerOpacity = 1 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) { contentOffset = 0 }
    }

    private func valueOriginal(of position: PositionReportData) -> Double? {
        metrics.positionValueOriginal[position.id]
    }

    private func valueChf(of position: PositionReportData) -> Double? {
        guard let entry = metrics.positionValueCHF[position.id], let value = entry else { return nil }
        return value
    }

    private func compare(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private func compare(_ lhs: String?, _ rhs: String?) -> Bool {
        switch (lhs?.isEmpty == false ? lhs : nil, rhs?.isEmpty == false ? rhs : nil) {
        case let (l?, r?):
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return l < r
            }
            return comparison == .orderedAscending
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return false
        }
    }

    private func compare(_ lhs: Double, _ rhs: Double) -> Bool {
        lhs < rhs
    }

    private func compare(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case let (l?, r?): return l < r
        case (_?, nil): return true
        case (nil, _?): return false
        default: return false
        }
    }

    private func compare(_ lhs: Int?, _ rhs: Int?) -> Bool {
        switch (lhs, rhs) {
        case let (l?, r?): return l < r
        case (_?, nil): return true
        case (nil, _?): return false
        default: return false
        }
    }

    private func compare(_ lhs: Date, _ rhs: Date) -> Bool {
        lhs < rhs
    }

    private func compare(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (l?, r?): return l < r
        case (_?, nil): return true
        case (nil, _?): return false
        default: return false
        }
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title.uppercased())
                .dsCaption()
                .foregroundColor(DSColor.textSecondary)
            Text(value)
                .dsHeaderSmall()
                .foregroundColor(DSColor.textPrimary)
        }
    }

    private func filterMenu(title: String, icon: String, options: [String], selection: Binding<Set<String>>) -> some View {
        Menu {
            if options.isEmpty {
                Text("No values available")
            } else {
                ForEach(options, id: \.self) { option in
                    Button {
                        if selection.wrappedValue.contains(option) {
                            selection.wrappedValue.remove(option)
                        } else {
                            selection.wrappedValue.insert(option)
                        }
                    } label: {
                        HStack {
                            Text(option)
                            if selection.wrappedValue.contains(option) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Label(title, systemImage: icon)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DSColor.surfaceSecondary)
                .clipShape(Capsule())
                .foregroundColor(DSColor.textPrimary)
        }
    }

    private func filterChip(label: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .dsCaption()
                .foregroundColor(DSColor.textPrimary)
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DSColor.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(DSColor.surfaceSecondary)
        .clipShape(Capsule())
    }

    private static let quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "'"
        return formatter
    }()

    fileprivate static let chfFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "'"
        return formatter
    }()
}

private struct PositionsRowView: View {
    let position: PositionReportData
    let columns: [PositionTableColumn]
    let fontConfig: MaintenanceTableFontConfig
    let widthFor: (PositionTableColumn) -> CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onDoubleTap: () -> Void
    let quantityBinding: Binding<String>
    let onQuantityCommit: () -> Void
    let originalValue: Double?
    let chfValue: Double?
    let currencySymbol: String
    let chfFormatter: NumberFormatter
    let currencyFormatter: NumberFormatter

    @State private var showNotes = false
    @FocusState private var quantityFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                columnView(column)
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, max(4, fontConfig.badge - 6))
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
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private func columnView(_ column: PositionTableColumn) -> some View {
        switch column {
        case .instrument:
            VStack(alignment: .leading, spacing: 2) {
                Text(position.instrumentName)
                    .font(.system(size: fontConfig.primary, weight: .medium))
                    .foregroundColor(DSColor.textPrimary)
                if let sector = position.instrumentSector, !sector.isEmpty {
                    Text(sector)
                        .font(.system(size: fontConfig.secondary))
                        .foregroundColor(DSColor.textSecondary)
                }
            }
            .padding(.leading, PositionsView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.instrument), alignment: .leading)
        case .account:
            VStack(alignment: .leading, spacing: 2) {
                Text(position.accountName)
                    .font(.system(size: fontConfig.secondary))
                    .foregroundColor(DSColor.textPrimary)
                Text(position.institutionName)
                    .font(.system(size: fontConfig.badge))
                    .foregroundColor(DSColor.textSecondary)
            }
            .padding(.leading, PositionsView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.account), alignment: .leading)
        case .institution:
            Text(position.institutionName)
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.institution), alignment: .leading)
        case .currency:
            Text(position.instrumentCurrency.uppercased())
                .font(.system(size: fontConfig.badge, weight: .semibold))
                .foregroundColor(DSColor.textOnAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(DSColor.accentMain)
                .clipShape(Capsule())
                .padding(.leading, PositionsView.columnTextInset)
                .frame(width: widthFor(.currency), alignment: .leading)
        case .quantity:
            TextField("", text: quantityBinding)
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.quantity), alignment: .trailing)
                .focused($quantityFocused)
                .onSubmit(onQuantityCommit)
                .onChange(of: quantityFocused) { _, focused in
                    if !focused {
                        onQuantityCommit()
                    }
                }
        case .purchaseValue:
            Text(monetaryText(position.purchasePrice))
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(position.purchasePrice == nil ? DSColor.textTertiary : DSColor.textPrimary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.purchaseValue), alignment: .trailing)
        case .currentValue:
            Text(monetaryText(position.currentPrice))
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(position.currentPrice == nil ? DSColor.textTertiary : DSColor.textPrimary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.currentValue), alignment: .trailing)
        case .valueOriginal:
            Text(formattedOriginalValue)
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(originalValue == nil ? DSColor.textTertiary : DSColor.textPrimary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.valueOriginal), alignment: .trailing)
        case .valueChf:
            Text(formattedChfValue)
                .font(.system(size: fontConfig.secondary, weight: .bold, design: .monospaced))
                .foregroundColor(chfValue == nil ? DSColor.textTertiary : DSColor.textPrimary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.valueChf), alignment: .trailing)
        case .reportDate:
            Text(dateText(position.reportDate))
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.reportDate), alignment: .leading)
        case .uploadedAt:
            Text(dateTimeText(position.uploadedAt))
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.uploadedAt), alignment: .leading)
        case .assetClass:
            Text(position.assetClass ?? "–")
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.assetClass), alignment: .leading)
        case .assetSubClass:
            Text(position.assetSubClass ?? "–")
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.assetSubClass), alignment: .leading)
        case .sector:
            Text(position.instrumentSector ?? "–")
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.sector), alignment: .leading)
        case .country:
            Text(position.instrumentCountry ?? "–")
                .font(.system(size: fontConfig.secondary))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.country), alignment: .leading)
        case .importSession:
            Text(position.importSessionId.map { "#\($0)" } ?? "—")
                .font(.system(size: fontConfig.secondary, design: .monospaced))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, PositionsView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.importSession), alignment: .trailing)
        case .notes:
            notesColumn
                .frame(width: widthFor(.notes), alignment: .center)
        }
    }

    private func monetaryText(_ value: Double?) -> String {
        guard let value else { return "—" }
        let formatted = currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(formatted) \(position.instrumentCurrency.uppercased())"
    }

    private var formattedOriginalValue: String {
        guard let originalValue else { return "—" }
        let formatted = currencyFormatter.string(from: NSNumber(value: originalValue)) ?? String(format: "%.2f", originalValue)
        return "\(formatted) \(currencySymbol)"
    }

    private var formattedChfValue: String {
        guard let chfValue else { return "—" }
        return chfFormatter.string(from: NSNumber(value: chfValue)) ?? String(format: "%.0f", chfValue)
    }

    private var notesColumn: some View {
        Group {
            if let notes = position.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                Button {
                    showNotes = true
                } label: {
                    Image(systemName: "note.text")
                        .foregroundColor(DSColor.accentMain)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showNotes) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .dsHeaderSmall()
                            .foregroundColor(DSColor.textPrimary)
                        Text(notes)
                            .dsBody()
                            .foregroundColor(DSColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(DSLayout.spaceM)
                    .frame(width: 260)
                    .background(DSColor.surface)
                }
            } else {
                Image(systemName: "note.text")
                    .foregroundColor(DSColor.textTertiary)
            }
        }
    }

    private func dateText(_ date: Date) -> String {
        DateFormatter.userFacingFormatter.string(from: date)
    }

    private func dateTimeText(_ date: Date) -> String {
        DateFormatter.userFacingDateTimeFormatter.string(from: date)
    }
}

private extension DateFormatter {
    static let userFacingFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let userFacingDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
