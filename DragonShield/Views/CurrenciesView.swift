// DragonShield/Views/CurrenciesView.swift

// MARK: - Version 2.1

// MARK: - History

// - 2.0 -> 2.1: Adopted Design System styling for layout, table badges, and actions.
// - 1.4 -> 2.0: Adopted shared maintenance-table UX with column controls, font persistence, and API/Status filters.
// - 1.3 -> 1.4: Fixed EditCurrencyView to correctly use the environment's DatabaseManager instance.
// - 1.2 -> 1.3: Updated deprecated onChange modifiers to use new two-parameter syntax.
// - 1.1 -> 1.2: Applied dynamic row spacing and padding from DatabaseManager configuration.
// - 1.0 -> 1.1: Updated deprecated onChange modifiers to new syntax for macOS 14.0+.

import SwiftUI
#if os(macOS)
    import AppKit
#endif

private enum CurrencyTableColumn: String, CaseIterable, Codable, MaintenanceTableColumn {
    case code, name, symbol, api, status

    var title: String {
        switch self {
        case .code: return "Code"
        case .name: return "Name"
        case .symbol: return "Symbol"
        case .api: return "API"
        case .status: return "Status"
        }
    }

    var menuTitle: String {
        switch self {
        case .code: return "Currency Code"
        case .name: return "Name"
        case .symbol: return "Symbol"
        case .api: return "API Support"
        case .status: return "Status"
        }
    }
}

private enum CurrencySortColumn: String, CaseIterable {
    case code, name, symbol, api, status
}

private struct CurrencyRow: Identifiable, Equatable {
    var id: String { code }
    let code: String
    let name: String
    let symbol: String
    let isActive: Bool
    let apiSupported: Bool

    var apiLabel: String { apiSupported ? "Yes" : "No" }
    var statusLabel: String { isActive ? "Active" : "Inactive" }
}

struct CurrenciesView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    /// 0 = Currencies, 1 = FX Rates
    @AppStorage(UserDefaultsKeys.currenciesFxSegment) private var selectedSegment: Int = 0

    @State private var currencies: [CurrencyRow] = []
    @State private var selectedCurrency: CurrencyRow? = nil
    @State private var searchText = ""
    @State private var apiFilters: Set<String> = []
    @State private var statusFilters: Set<String> = []

    @State private var showAddCurrencySheet = false
    @State private var showEditCurrencySheet = false
    @State private var showingDeleteAlert = false
    @State private var currencyToDelete: CurrencyRow? = nil

    @State private var sortColumn: CurrencySortColumn = .code
    @State private var sortAscending: Bool = true

    @StateObject private var tableModel = ResizableTableViewModel<CurrencyTableColumn>(configuration: CurrenciesView.tableConfiguration)

    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    private static let columnOrder: [CurrencyTableColumn] = [.code, .name, .symbol, .api, .status]
    private static let defaultVisibleColumns: Set<CurrencyTableColumn> = Set(columnOrder)
    private static let visibleColumnsKey = "CurrenciesView.visibleColumns.v1"
    private static let headerBackground = DSColor.surfaceSecondary

    private static let defaultColumnWidths: [CurrencyTableColumn: CGFloat] = [
        .code: 110,
        .name: 280,
        .symbol: 120,
        .api: 110,
        .status: 130,
    ]

    private static let minimumColumnWidths: [CurrencyTableColumn: CGFloat] = [
        .code: 90,
        .name: 220,
        .symbol: 90,
        .api: 90,
        .status: 110,
    ]

    private static let columnHandleWidth: CGFloat = 10
    private static let columnHandleHitSlop: CGFloat = 8
    fileprivate static let columnTextInset: CGFloat = DSLayout.spaceS
    private static let tableConfiguration: MaintenanceTableConfiguration<CurrencyTableColumn> = {
        #if os(macOS)
            MaintenanceTableConfiguration(
                preferenceKind: .currencies,
                columnOrder: columnOrder,
                defaultVisibleColumns: defaultVisibleColumns,
                requiredColumns: [],
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
                        secondary: size.secondarySize,
                        header: size.headerSize,
                        badge: size.badgeSize
                    )
                },
                columnResizeCursor: nil
            )
        #else
            MaintenanceTableConfiguration(
                preferenceKind: .currencies,
                columnOrder: columnOrder,
                defaultVisibleColumns: defaultVisibleColumns,
                requiredColumns: [],
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
                        secondary: size.secondarySize,
                        header: size.headerSize,
                        badge: size.badgeSize
                    )
                }
            )
        #endif
    }()

    private var activeColumns: [CurrencyTableColumn] { tableModel.activeColumns }
    private var fontConfig: MaintenanceTableFontConfig { tableModel.fontConfig }
    private var visibleColumns: Set<CurrencyTableColumn> { tableModel.visibleColumns }
    private var selectedFontSize: MaintenanceTableFontSize { tableModel.selectedFontSize }
    private var fontSizeBinding: Binding<MaintenanceTableFontSize> {
        Binding(
            get: { tableModel.selectedFontSize },
            set: { tableModel.selectedFontSize = $0 }
        )
    }

    private var filteredCurrencies: [CurrencyRow] {
        var result = currencies

        if !searchText.isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                result = result.filter { currency in
                    currency.code.localizedCaseInsensitiveContains(query) ||
                        currency.name.localizedCaseInsensitiveContains(query) ||
                        currency.symbol.localizedCaseInsensitiveContains(query)
                }
            }
        }

        if !apiFilters.isEmpty {
            result = result.filter { apiFilters.contains($0.apiLabel) }
        }

        if !statusFilters.isEmpty {
            result = result.filter { statusFilters.contains($0.statusLabel) }
        }

        return result
    }

    private var sortedCurrencies: [CurrencyRow] {
        let data = filteredCurrencies
        guard data.count > 1 else { return data }

        let sorted = data.sorted { lhs, rhs in
            switch sortColumn {
            case .code:
                let lhsCode = lhs.code.uppercased()
                let rhsCode = rhs.code.uppercased()
                if lhsCode == rhsCode { return lhs.name < rhs.name }
                return lhsCode < rhsCode
            case .name:
                let cmp = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return lhs.code.uppercased() < rhs.code.uppercased()
            case .symbol:
                let lhsSymbol = lhs.symbol.uppercased()
                let rhsSymbol = rhs.symbol.uppercased()
                if lhsSymbol == rhsSymbol { return lhs.code.uppercased() < rhs.code.uppercased() }
                return lhsSymbol < rhsSymbol
            case .api:
                if lhs.apiSupported == rhs.apiSupported { return lhs.code.uppercased() < rhs.code.uppercased() }
                return lhs.apiSupported && !rhs.apiSupported
            case .status:
                if lhs.isActive == rhs.isActive { return lhs.code.uppercased() < rhs.code.uppercased() }
                return lhs.isActive && !rhs.isActive
            }
        }

        return sortAscending ? sorted : Array(sorted.reversed())
    }

    private var isFiltering: Bool {
        !searchText.isEmpty || !apiFilters.isEmpty || !statusFilters.isEmpty
    }

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            VStack(spacing: DSLayout.spaceM) {
                if selectedSegment == 0 {
                    currenciesSection
                } else {
                    fxSection
                }
            }
            .transition(.opacity)
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.vertical, DSLayout.spaceL)
        }
        .onAppear {
            tableModel.connect(to: dbManager)
            loadCurrencies()
            animateEntrance()
            ensureFiltersWithinVisibleColumns()
            ensureValidSortColumn()
        }
        .onChange(of: selectedSegment) { _, newValue in
            if newValue == 0 {
                loadCurrencies()
            }
        }
        .onChange(of: tableModel.visibleColumns) { _, _ in
            ensureFiltersWithinVisibleColumns()
            ensureValidSortColumn()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCurrencies"))) { _ in
            loadCurrencies()
        }
        .sheet(isPresented: $showAddCurrencySheet) {
            AddCurrencyView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditCurrencySheet) {
            if let currency = selectedCurrency {
                EditCurrencyView(currencyCode: currency.code).environmentObject(dbManager)
            }
        }
        .alert("Delete Currency", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let currency = currencyToDelete {
                    confirmDelete(currency)
                }
            }
        } message: {
            if let currency = currencyToDelete {
                Text("Are you sure you want to delete '\(currency.name) (\(currency.code))'?")
            }
        }
        .navigationTitle("Currency Maintenance")
        .animation(.easeInOut, value: selectedSegment)
    }

    private var modePicker: some View {
        Picker("Mode", selection: $selectedSegment) {
            Text("Currencies").tag(0)
            Text("FX Rates").tag(1)
        }
        .pickerStyle(.segmented)
        .font(.ds.caption)
        .frame(maxWidth: 320)
    }

    private var currenciesSection: some View {
        VStack(spacing: 0) {
            HStack {
                modePicker
                Spacer()
            }
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.bottom, DSLayout.spaceS)

            modernHeader
            searchAndStats
            currenciesContent
            modernActionBar
        }
    }

    private var fxSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            HStack {
                modePicker
                Spacer()
            }
            HStack {
                Button(action: { withAnimation { selectedSegment = 0 } }) {
                    Label("Back to Currencies", systemImage: "chevron.left")
                }
                .buttonStyle(DSButtonStyle(type: .secondary))
                Spacer()
            }
            ExchangeRatesView()
                .environmentObject(dbManager)
        }
    }

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                HStack(spacing: DSLayout.spaceM) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(DSColor.accentMain)
                    Text("Currencies")
                        .dsHeaderLarge()
                }
                Text("Manage supported currencies and exchange rates")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
            }
            Spacer()
            HStack(spacing: DSLayout.spaceM) {
                modernStatCard(title: "Total", value: "\(currencies.count)", icon: "number.circle.fill", color: DSColor.accentMain)
                modernStatCard(title: "Active", value: "\(currencies.filter { $0.isActive }.count)", icon: "checkmark.circle.fill", color: DSColor.accentSuccess)
                modernStatCard(title: "API", value: "\(currencies.filter { $0.apiSupported }.count)", icon: "wifi.circle.fill", color: DSColor.textSecondary)
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    private var searchAndStats: some View {
        VStack(spacing: DSLayout.spaceM) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DSColor.textSecondary)
                TextField("Search currencies...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.ds.body)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(DSColor.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, DSLayout.spaceM)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DSLayout.radiusM)
                    .fill(DSColor.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSLayout.radiusM)
                            .stroke(DSColor.border, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)

            if isFiltering {
                VStack(alignment: .leading, spacing: DSLayout.spaceS) {
                    Text("Found \(sortedCurrencies.count) of \(currencies.count) currencies")
                        .dsCaption()
                        .foregroundColor(DSColor.textSecondary)
                    HStack(spacing: DSLayout.spaceS) {
                        ForEach(Array(apiFilters), id: \.self) { value in
                            filterChip(text: "API: \(value)") { apiFilters.remove(value) }
                        }
                        ForEach(Array(statusFilters), id: \.self) { value in
                            filterChip(text: value) { statusFilters.remove(value) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .offset(y: contentOffset)
    }

    private var currenciesContent: some View {
        VStack(spacing: DSLayout.spaceM) {
            tableControls
            if sortedCurrencies.isEmpty {
                emptyStateView
                    .offset(y: contentOffset)
            } else {
                currenciesTable
                    .offset(y: contentOffset)
            }
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.top, DSLayout.spaceS)
    }

    private var tableControls: some View {
        HStack(spacing: DSLayout.spaceM) {
            columnsMenu
            fontSizePicker
            Spacer()
            if visibleColumns != CurrenciesView.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
                    .font(.ds.caption)
            }
        }
        .padding(.horizontal, 4)
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(CurrenciesView.columnOrder, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && visibleColumns.count == 1)
            }
            Divider()
            Button("Reset Columns", action: resetVisibleColumns)
        } label: {
            Label("Columns", systemImage: "slider.horizontal.3")
                .font(.ds.caption)
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

    private var emptyStateView: some View {
        VStack(spacing: DSLayout.spaceL) {
            Spacer()
            VStack(spacing: DSLayout.spaceM) {
                Image(systemName: searchText.isEmpty && apiFilters.isEmpty && statusFilters.isEmpty ? "dollarsign.circle" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColor.textTertiary, DSColor.textTertiary.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                VStack(spacing: DSLayout.spaceS) {
                    Text(searchText.isEmpty && apiFilters.isEmpty && statusFilters.isEmpty ? "No currencies yet" : "No results match your filters")
                        .dsHeaderMedium()
                        .foregroundColor(DSColor.textSecondary)
                    Text(searchText.isEmpty && apiFilters.isEmpty && statusFilters.isEmpty ? "Add your first currency to start managing FX." : "Try adjusting your search or filter selections.")
                        .dsBody()
                        .foregroundColor(DSColor.textTertiary)
                        .multilineTextAlignment(.center)
                }
                if searchText.isEmpty && apiFilters.isEmpty && statusFilters.isEmpty {
                    Button { showAddCurrencySheet = true } label: {
                        Label("Add Currency", systemImage: "plus")
                    }
                    .buttonStyle(DSButtonStyle(type: .primary))
                    .padding(.top, DSLayout.spaceS)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var currenciesTable: some View {
        MaintenanceTableView(
            model: tableModel,
            rows: sortedCurrencies,
            rowSpacing: DSLayout.tableRowSpacing,
            showHorizontalIndicators: false,
            rowContent: { currency, context in
                ModernCurrencyRowView(
                    currency: currency,
                    columns: context.columns,
                    fontConfig: context.fontConfig,
                    isSelected: selectedCurrency?.code == currency.code,
                    rowPadding: DSLayout.tableRowPadding,
                    widthFor: { context.widthForColumn($0) },
                    onTap: {
                        selectedCurrency = currency
                    },
                    onEdit: {
                        selectedCurrency = currency
                        showEditCurrencySheet = true
                    }
                )
            },
            headerContent: { column, fontConfig in
                currenciesHeaderContent(for: column, fontConfig: fontConfig)
            }
        )
    }

    private func currenciesHeaderContent(for column: CurrencyTableColumn, fontConfig: MaintenanceTableFontConfig) -> some View {
        let sortOption = sortOption(for: column)
        let isActiveSort = sortOption.map { $0 == sortColumn } ?? false
        let filterBinding = filterBinding(for: column)
        let filterOptions = filterValues(for: column)

        return HStack(spacing: 6) {
            if let sortOption {
                Button(action: {
                    if isActiveSort {
                        sortAscending.toggle()
                    } else {
                        sortColumn = sortOption
                        sortAscending = true
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(column.title)
                            .font(.system(size: fontConfig.header, weight: .semibold))
                            .foregroundColor(DSColor.textPrimary)
                        if isActiveSort {
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(DSColor.accentMain)
                                .rotationEffect(.degrees(sortAscending ? 0 : 180))
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(column.title)
                    .font(.system(size: fontConfig.header, weight: .semibold))
                    .foregroundColor(DSColor.textPrimary)
            }

            if let binding = filterBinding, !filterOptions.isEmpty {
                Menu {
                    ForEach(filterOptions, id: \.self) { value in
                        Button {
                            if binding.wrappedValue.contains(value) {
                                binding.wrappedValue.remove(value)
                            } else {
                                binding.wrappedValue.insert(value)
                            }
                        } label: {
                            Label(value, systemImage: binding.wrappedValue.contains(value) ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(binding.wrappedValue.isEmpty ? DSColor.textTertiary : DSColor.accentMain)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
        }
    }

    private func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        DSBadge(text: text, color: DSColor.accentMain)
            .overlay(
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(DSColor.textOnAccent)
                }
                .padding(.leading, 4),
                alignment: .trailing
            )
    }

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DSColor.border)
                .frame(height: 1)
            HStack(spacing: DSLayout.spaceM) {
                Button { showAddCurrencySheet = true } label: {
                    Label("Add Currency", systemImage: "plus")
                }
                .buttonStyle(DSButtonStyle(type: .primary))

                if selectedCurrency != nil {
                    Button {
                        showEditCurrencySheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(DSButtonStyle(type: .secondary))

                    Button {
                        if let currency = selectedCurrency {
                            currencyToDelete = currency
                            showingDeleteAlert = true
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(DSButtonStyle(type: .destructive))
                }

                Spacer()

                if let currency = selectedCurrency {
                    HStack(spacing: DSLayout.spaceS) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DSColor.accentSuccess)
                        Text("Selected: \(currency.code)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DSColor.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, DSLayout.spaceM)
                    .padding(.vertical, DSLayout.spaceS)
                    .background(DSColor.surfaceHighlight)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DSLayout.spaceL)
            .padding(.vertical, DSLayout.spaceM)
            .background(DSColor.surfaceSecondary)
        }
        .opacity(buttonsOpacity)
    }

    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack(spacing: DSLayout.spaceXS) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.ds.caption)
                    .foregroundColor(DSColor.textSecondary)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(DSColor.textPrimary)
        }
        .padding(.horizontal, DSLayout.spaceM)
        .padding(.vertical, DSLayout.spaceS)
        .background(
            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                .fill(DSColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusM)
                        .stroke(DSColor.border, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            headerOpacity = 1.0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            contentOffset = 0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            buttonsOpacity = 1.0
        }
    }

    private func loadCurrencies() {
        let fetched = dbManager.fetchCurrencies()
        currencies = fetched.map { item in
            CurrencyRow(
                code: item.code,
                name: item.name,
                symbol: item.symbol,
                isActive: item.isActive,
                apiSupported: item.apiSupported
            )
        }
        if let selected = selectedCurrency {
            selectedCurrency = currencies.first(where: { $0.code == selected.code })
        }
    }

    private func confirmDelete(_ currency: CurrencyRow) {
        let success = dbManager.deleteCurrency(code: currency.code)
        if success {
            loadCurrencies()
            selectedCurrency = nil
            currencyToDelete = nil
        }
    }

    private func sortOption(for column: CurrencyTableColumn) -> CurrencySortColumn? {
        switch column {
        case .code: return .code
        case .name: return .name
        case .symbol: return .symbol
        case .api: return .api
        case .status: return .status
        }
    }

    private func filterBinding(for column: CurrencyTableColumn) -> Binding<Set<String>>? {
        switch column {
        case .api:
            return $apiFilters
        case .status:
            return $statusFilters
        default:
            return nil
        }
    }

    private func filterValues(for column: CurrencyTableColumn) -> [String] {
        switch column {
        case .api:
            return Array(Set(currencies.map { $0.apiLabel })).sorted()
        case .status:
            return Array(Set(currencies.map { $0.statusLabel })).sorted()
        default:
            return []
        }
    }

    private func toggleColumn(_ column: CurrencyTableColumn) {
        tableModel.toggleColumn(column)
        ensureFiltersWithinVisibleColumns()
        ensureValidSortColumn()
    }

    private func resetVisibleColumns() {
        tableModel.resetVisibleColumns()
        ensureFiltersWithinVisibleColumns()
        ensureValidSortColumn()
    }

    private func resetTablePreferences() {
        tableModel.resetTablePreferences()
        ensureFiltersWithinVisibleColumns()
        ensureValidSortColumn()
    }

    private func ensureValidSortColumn() {
        let currentColumn: CurrencyTableColumn = {
            switch sortColumn {
            case .code: return .code
            case .name: return .name
            case .symbol: return .symbol
            case .api: return .api
            case .status: return .status
            }
        }()

        if !visibleColumns.contains(currentColumn) {
            if let fallback = activeColumns.compactMap(sortOption(for:)).first {
                sortColumn = fallback
            } else {
                sortColumn = .code
            }
        }
    }

    private func ensureFiltersWithinVisibleColumns() {
        if !visibleColumns.contains(.api) {
            apiFilters.removeAll()
        }
        if !visibleColumns.contains(.status) {
            statusFilters.removeAll()
        }
    }
}

private struct ModernCurrencyRowView: View {
    let currency: CurrencyRow
    let columns: [CurrencyTableColumn]
    let fontConfig: MaintenanceTableFontConfig
    let isSelected: Bool
    let rowPadding: CGFloat
    let widthFor: (CurrencyTableColumn) -> CGFloat
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                columnView(for: column)
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, max(4, rowPadding))
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
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) {
            onTap()
            onEdit()
        }
        .contextMenu {
            Button("Edit Currency", action: onEdit)
            Button("Select Currency", action: onTap)
            Divider()
            #if os(macOS)
                Button("Copy Code") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(currency.code, forType: .string)
                }
                Button("Copy Name") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(currency.name, forType: .string)
                }
            #endif
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func columnView(for column: CurrencyTableColumn) -> some View {
        switch column {
        case .code:
            Text(currency.code)
                .font(.system(size: fontConfig.primary, weight: .semibold, design: .monospaced))
                .foregroundColor(DSColor.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DSColor.surfaceHighlight)
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                .padding(.leading, CurrenciesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.code), alignment: .leading)
        case .name:
            Text(currency.name)
                .font(.system(size: fontConfig.primary, weight: .medium))
                .foregroundColor(DSColor.textPrimary)
                .padding(.leading, CurrenciesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.name), alignment: .leading)
        case .symbol:
            Text(currency.symbol)
                .font(.system(size: fontConfig.secondary, weight: .medium))
                .foregroundColor(DSColor.textSecondary)
                .padding(.leading, CurrenciesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.symbol), alignment: .leading)
        case .api:
            badge(text: currency.apiLabel, color: apiBadgeColor, fontSize: fontConfig.badge)
                .padding(.leading, CurrenciesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.api), alignment: .leading)
        case .status:
            badge(text: currency.statusLabel, color: statusBadgeColor, fontSize: fontConfig.badge)
                .padding(.leading, CurrenciesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.status), alignment: .leading)
        }
    }

    private var apiBadgeColor: Color {
        currency.apiSupported ? DSColor.accentMain : DSColor.textTertiary
    }

    private var statusBadgeColor: Color {
        currency.isActive ? DSColor.accentSuccess : DSColor.accentWarning
    }

    private func badge(text: String, color: Color, fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
    }
}

// MARK: - Add Currency View (Unchanged)

struct AddCurrencyView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var currencyCode = ""
    @State private var currencyName = ""
    @State private var currencySymbol = ""
    @State private var isActive = true
    @State private var apiSupported = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50

    var isValid: Bool {
        !currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !currencyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            isValidCurrencyCode
    }

    private var isValidCurrencyCode: Bool {
        let trimmed = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 3 && trimmed.allSatisfy { $0.isLetter }
    }

    private var completionPercentage: Double {
        var completed = 0.0; let total = 4.0
        if !currencyCode.isEmpty { completed += 1 }; if !currencyName.isEmpty { completed += 1 }; if !currencySymbol.isEmpty { completed += 1 }; completed += 1
        return completed / total
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 0.99), Color(red: 0.93, green: 0.95, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            AddCurrencyParticleBackground()
            VStack(spacing: 0) { addModernHeader; addProgressBar; addModernContent }
        }.frame(width: 600, height: 550).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            .scaleEffect(formScale).onAppear { animateAddEntrance() }
            .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.contains("✅") { animateAddExit() } } } message: { Text(alertMessage) }
    }

    private var addModernHeader: some View {
        HStack {
            Button { animateAddExit() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundColor(.gray).frame(width: 32, height: 32).background(Color.gray.opacity(0.1)).clipShape(Circle()).overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1)) }.buttonStyle(ScaleButtonStyle())
            Spacer()
            HStack(spacing: 12) { Image(systemName: "dollarsign.circle.badge.plus").font(.system(size: 24)).foregroundColor(.green); Text("Add Currency").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)) }
            Spacer()
            Button { saveCurrency() } label: { HStack(spacing: 8) { if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8) } else { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)) }; Text(isLoading ? "Saving..." : "Save").font(.system(size: 14, weight: .semibold)) }.foregroundColor(.white).frame(height: 32).padding(.horizontal, 16).background(Group { if isValid && !isLoading { Color.green } else { Color.gray.opacity(0.4) } }).clipShape(Capsule()).overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1)).shadow(color: isValid ? .green.opacity(0.3) : .clear, radius: 8, x: 0, y: 2) }.disabled(isLoading || !isValid).buttonStyle(ScaleButtonStyle())
        }.padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }

    private var addProgressBar: some View {
        VStack(spacing: 8) {
            HStack { Text("Completion").font(.caption).foregroundColor(.gray); Spacer(); Text("\(Int(completionPercentage * 100))%").font(.caption.weight(.semibold)).foregroundColor(.green) }
            GeometryReader { geometry in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(height: 6); RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing)).frame(width: geometry.size.width * completionPercentage, height: 6).animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage).shadow(color: .green.opacity(0.3), radius: 3, x: 0, y: 1) } }.frame(height: 6)
        }.padding(.horizontal, 24).padding(.bottom, 20)
    }

    private var addModernContent: some View {
        ScrollView { VStack(spacing: 24) { addCurrencyInfoSection; addStatusSection }.padding(.horizontal, 24).padding(.bottom, 100) }.offset(y: sectionsOffset)
    }

    private var addCurrencyInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Currency Information", icon: "dollarsign.circle.fill", color: .green)
            VStack(spacing: 16) { addModernTextField(title: "Currency Code", text: $currencyCode, placeholder: "e.g., JPY", icon: "number.circle.fill", isRequired: true, autoUppercase: true, validation: isValidCurrencyCode, errorMessage: "Currency code must be 3 letters (e.g., USD, EUR)"); addModernTextField(title: "Currency Name", text: $currencyName, placeholder: "e.g., Japanese Yen", icon: "textformat", isRequired: true); addModernTextField(title: "Currency Symbol", text: $currencySymbol, placeholder: "e.g., ¥", icon: "dollarsign", isRequired: true) }
        }.padding(24).background(addCurrencyGlassMorphismBackground).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.2), lineWidth: 1)).shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    private var addStatusSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Settings", icon: "gearshape.circle.fill", color: .blue)
            VStack(spacing: 16) { HStack(spacing: 16) { VStack(alignment: .leading, spacing: 8) { HStack { Image(systemName: "checkmark.circle").font(.system(size: 14)).foregroundColor(.gray); Text("Active Status").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }; Toggle("Active", isOn: $isActive).toggleStyle(SwitchToggleStyle(tint: .green)).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1) }.frame(maxWidth: .infinity); VStack(alignment: .leading, spacing: 8) { HStack { Image(systemName: "wifi.circle").font(.system(size: 14)).foregroundColor(.gray); Text("API Support").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }; Toggle("API Supported", isOn: $apiSupported).toggleStyle(SwitchToggleStyle(tint: .purple)).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1) }.frame(maxWidth: .infinity) } }
        }.padding(24).background(addCurrencyGlassMorphismBackground).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.2), lineWidth: 1)).shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    private var addCurrencyGlassMorphismBackground: some View {
        ZStack { RoundedRectangle(cornerRadius: 16).fill(.regularMaterial).background(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)); RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.green.opacity(0.05), .blue.opacity(0.03), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)) }
    }

    private func addSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) { Image(systemName: icon).font(.system(size: 20)).foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)); Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8)); Spacer() }
    }

    private func addModernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool, autoUppercase: Bool = false, validation: Bool = true, errorMessage: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).font(.system(size: 14)).foregroundColor(.gray); Text(title + (isRequired ? "*" : "")).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer(); if !text.wrappedValue.isEmpty && !validation { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundColor(.red) } }
            TextField(placeholder, text: text).font(.system(size: 16)).foregroundColor(.black).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(!text.wrappedValue.isEmpty && !validation ? .red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { _, newValue in if autoUppercase { let uppercased = newValue.uppercased(); if text.wrappedValue != uppercased { text.wrappedValue = uppercased } } }
            if !text.wrappedValue.isEmpty && !validation && !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4) }
        }
    }

    private func animateAddEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }; withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }; withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }

    private func animateAddExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50 }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }

    func saveCurrency() {
        guard isValid else { alertMessage = "Please fill in all required fields correctly"; showingAlert = true; return }; isLoading = true
        let success = dbManager.addCurrency(code: currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), name: currencyName.trimmingCharacters(in: .whitespacesAndNewlines), symbol: currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines), isActive: isActive, apiSupported: apiSupported)
        DispatchQueue.main.async { self.isLoading = false; if success { NotificationCenter.default.post(name: NSNotification.Name("RefreshCurrencies"), object: nil); DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.animateAddExit() } } else { self.alertMessage = "❌ Failed to add currency. Please try again."; self.showingAlert = true } }
    }
}

// MARK: - Edit Currency View (FIXED)

struct EditCurrencyView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager // Use the environment object

    let currencyCode: String

    @State private var currencyName = ""
    @State private var currencySymbol = ""
    @State private var isActive = true
    @State private var apiSupported = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    @State private var hasChanges = false

    @State private var originalName = ""
    @State private var originalSymbol = ""
    @State private var originalIsActive = true
    @State private var originalApiSupported = true

    init(currencyCode: String) {
        self.currencyCode = currencyCode
    }

    var isValid: Bool {
        !currencyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func detectChanges() {
        hasChanges = currencyName != originalName ||
            currencySymbol != originalSymbol ||
            isActive != originalIsActive ||
            apiSupported != originalApiSupported
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 0.99), Color(red: 0.91, green: 0.94, blue: 0.98)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            EditCurrencyParticleBackground()

            VStack(spacing: 0) {
                modernHeader
                changeIndicator
                progressBar
                modernContent
                modernFooter
            }
        }
        .frame(width: 700, height: 750)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadCurrencyData()
            animateEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") { showingAlert = false }
        } message: { Text(alertMessage) }
        .onChange(of: currencyName) { _, _ in detectChanges() }
        .onChange(of: currencySymbol) { _, _ in detectChanges() }
        .onChange(of: isActive) { _, _ in detectChanges() }
        .onChange(of: apiSupported) { _, _ in detectChanges() }
    }

    private var modernHeader: some View {
        HStack {
            Button {
                if hasChanges { showUnsavedChangesAlert() } else { animateExit() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.gray)
                    .frame(width: 32, height: 32).background(Color.gray.opacity(0.1)).clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }.buttonStyle(ScaleButtonStyle())
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "pencil.circle.fill").font(.system(size: 24))
                    .foregroundStyle(LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Edit Currency").font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
            }
            Spacer()
            Button { saveCurrency() } label: {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8) }
                    else { Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark").font(.system(size: 14, weight: .bold)) }
                    Text(isLoading ? "Saving..." : "Save Changes").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white).frame(height: 32).padding(.horizontal, 16)
                .background(Group { if isValid && hasChanges && !isLoading { Color.orange } else { Color.gray.opacity(0.4) } })
                .clipShape(Capsule()).overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                .shadow(color: isValid && hasChanges && !isLoading ? .orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            }
            .disabled(isLoading || !isValid || !hasChanges)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }

    private var changeIndicator: some View {
        HStack {
            if hasChanges {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill").font(.system(size: 8)).foregroundColor(.orange)
                    Text("Unsaved changes").font(.caption).foregroundColor(.orange)
                }
                .padding(.horizontal, 12).padding(.vertical, 4).background(Color.orange.opacity(0.1)).clipShape(Capsule())
                .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .transition(.opacity.combined(with: .scale))
            }
            Spacer()
        }.padding(.horizontal, 24).animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Completion").font(.caption).foregroundColor(.gray)
                Spacer()
                Text("\(Int(completionPercentage * 100))%").font(.caption.weight(.semibold)).foregroundColor(.orange)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.orange, .green], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                        .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }.frame(height: 6)
        }.padding(.horizontal, 24).padding(.bottom, 20)
    }

    private var modernContent: some View {
        ScrollView { VStack(spacing: 24) { requiredSection; optionalSection }.padding(.horizontal, 24).padding(.bottom, 100) }.offset(y: sectionsOffset)
    }

    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Currency Information", icon: "checkmark.shield.fill", color: .orange)
            VStack(spacing: 16) {
                modernTextField(title: "Currency Code", text: .constant(currencyCode), placeholder: currencyCode, icon: "number.circle.fill", isRequired: true, isReadOnly: true)
                modernTextField(title: "Currency Name", text: $currencyName, placeholder: "e.g., Danish Krone", icon: "textformat", isRequired: true)
                modernTextField(title: "Currency Symbol", text: $currencySymbol, placeholder: "e.g., DKK", icon: "dollarsign", isRequired: true)
            }
        }.modifier(ModernFormSection(color: .orange))
    }

    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Settings", icon: "gearshape.circle.fill", color: .red)
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "checkmark.circle").font(.system(size: 14)).foregroundColor(.gray); Text("Active Status").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }
                        Toggle("Active", isOn: $isActive).modifier(ModernToggleStyle(tint: .green))
                    }.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "wifi.circle").font(.system(size: 14)).foregroundColor(.gray); Text("API Support").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }
                        Toggle("API Supported", isOn: $apiSupported).modifier(ModernToggleStyle(tint: .purple))
                    }.frame(maxWidth: .infinity)
                }
            }
        }.modifier(ModernFormSection(color: .red))
    }

    private var modernFooter: some View { Spacer() }

    private var completionPercentage: Double {
        var completed = 0.0; let total = 4.0
        completed += 1; if !currencyName.isEmpty { completed += 1 }; if !currencySymbol.isEmpty { completed += 1 }; completed += 1
        return completed / total
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) { Image(systemName: icon).font(.system(size: 20)).foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)); Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8)); Spacer() }
    }

    private func modernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool, autoUppercase: Bool = false, validation: Bool = true, errorMessage: String = "", isReadOnly: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).font(.system(size: 14)).foregroundColor(.gray); Text(title + (isRequired ? "*" : "")).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer(); if isReadOnly { Text("(Read-only)").font(.caption).foregroundColor(.gray).italic() }; if !text.wrappedValue.isEmpty && !validation { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundColor(.red) } }
            if isReadOnly { Text(text.wrappedValue).font(.system(size: 16, weight: .medium)).foregroundColor(.primary).padding(.horizontal, 16).padding(.vertical, 12).background(Color.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1)) }
            else { TextField(placeholder, text: text).font(.system(size: 16)).foregroundColor(.black).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(!text.wrappedValue.isEmpty && !validation ? .red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase { let uppercased = newValue.uppercased(); if text.wrappedValue != uppercased { text.wrappedValue = uppercased } }
                }
            }
            if !text.wrappedValue.isEmpty && !validation && !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4) }
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }; withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }; withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }

    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50 }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }

    func loadCurrencyData() {
        if let details = dbManager.fetchCurrencyDetails(code: currencyCode) {
            currencyName = details.name
            currencySymbol = details.symbol
            isActive = details.isActive
            apiSupported = details.apiSupported

            originalName = details.name
            originalSymbol = details.symbol
            originalIsActive = details.isActive
            originalApiSupported = details.apiSupported
        } else {
            alertMessage = "❌ Error: Could not load details for \(currencyCode)."
            showingAlert = true
        }
    }

    private func showUnsavedChangesAlert() {
        let alert = NSAlert(); alert.messageText = "Unsaved Changes"; alert.informativeText = "You have unsaved changes. Are you sure you want to close without saving?"; alert.alertStyle = .warning; alert.addButton(withTitle: "Save & Close"); alert.addButton(withTitle: "Discard Changes"); alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        switch response { case .alertFirstButtonReturn: saveCurrency(); case .alertSecondButtonReturn: animateExit(); default: break }
    }

    func saveCurrency() {
        guard isValid else { alertMessage = "Please fill in all required fields correctly"; showingAlert = true; return }; isLoading = true
        let success = dbManager.updateCurrency(code: currencyCode, name: currencyName.trimmingCharacters(in: .whitespacesAndNewlines), symbol: currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines), isActive: isActive, apiSupported: apiSupported)
        DispatchQueue.main.async { self.isLoading = false; if success { self.originalName = self.currencyName; self.originalSymbol = self.currencySymbol; self.originalIsActive = self.isActive; self.originalApiSupported = self.apiSupported; self.detectChanges(); NotificationCenter.default.post(name: NSNotification.Name("RefreshCurrencies"), object: nil); DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.animateExit() } } else { self.alertMessage = "❌ Failed to update currency. Please try again."; self.showingAlert = true } }
    }
}

// MARK: - Particle Backgrounds (Unchanged)

struct AddCurrencyParticleBackground: View {
    @State private var particles: [AddCurrencyParticle] = []; var body: some View { ZStack { ForEach(particles.indices, id: \.self) { index in Circle().fill(Color.green.opacity(0.04)).frame(width: particles[index].size, height: particles[index].size).position(particles[index].position).opacity(particles[index].opacity) } }.onAppear { createParticles(); animateParticles() } }
    private func createParticles() { particles = (0 ..< 12).map { _ in AddCurrencyParticle(position: CGPoint(x: CGFloat.random(in: 0 ... 600), y: CGFloat.random(in: 0 ... 550)), size: CGFloat.random(in: 3 ... 9), opacity: Double.random(in: 0.1 ... 0.2)) } }
    private func animateParticles() { withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) { for index in particles.indices {
        particles[index].position.y -= 700; particles[index].opacity = Double.random(in: 0.05 ... 0.15)
    } } }
}

struct EditCurrencyParticleBackground: View {
    @State private var particles: [EditCurrencyParticle] = []; var body: some View { ZStack { ForEach(particles.indices, id: \.self) { index in Circle().fill(Color.orange.opacity(0.04)).frame(width: particles[index].size, height: particles[index].size).position(particles[index].position).opacity(particles[index].opacity) } }.onAppear { createParticles(); animateParticles() } }
    private func createParticles() { particles = (0 ..< 12).map { _ in EditCurrencyParticle(position: CGPoint(x: CGFloat.random(in: 0 ... 600), y: CGFloat.random(in: 0 ... 600)), size: CGFloat.random(in: 3 ... 9), opacity: Double.random(in: 0.1 ... 0.2)) } }
    private func animateParticles() { withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) { for index in particles.indices {
        particles[index].position.y -= 800; particles[index].opacity = Double.random(in: 0.05 ... 0.15)
    } } }
}

struct AddCurrencyParticle { var position: CGPoint; var size: CGFloat; var opacity: Double }
struct EditCurrencyParticle { var position: CGPoint; var size: CGFloat; var opacity: Double }

struct CurrencyParticleBackground: View {
    @State private var particles: [CurrencyParticle] = []; var body: some View { ZStack { ForEach(particles.indices, id: \.self) { index in Circle().fill(Color.green.opacity(0.03)).frame(width: particles[index].size, height: particles[index].size).position(particles[index].position).opacity(particles[index].opacity) } }.onAppear { createParticles(); animateParticles() } }
    private func createParticles() { particles = (0 ..< 15).map { _ in CurrencyParticle(position: CGPoint(x: CGFloat.random(in: 0 ... 1200), y: CGFloat.random(in: 0 ... 800)), size: CGFloat.random(in: 2 ... 8), opacity: Double.random(in: 0.1 ... 0.2)) } }
    private func animateParticles() { withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) { for index in particles.indices {
        particles[index].position.y -= 1000; particles[index].opacity = Double.random(in: 0.05 ... 0.15)
    } } }
}

struct CurrencyParticle { var position: CGPoint; var size: CGFloat; var opacity: Double }
