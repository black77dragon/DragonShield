// DragonShield/Views/CurrenciesView.swift
// MARK: - Version 2.0
// MARK: - History
// - 1.4 -> 2.0: Adopted shared maintenance-table UX with column controls, font persistence, and API/Status filters.
// - 1.3 -> 1.4: Fixed EditCurrencyView to correctly use the environment's DatabaseManager instance.
// - 1.2 -> 1.3: Updated deprecated onChange modifiers to use new two-parameter syntax.
// - 1.1 -> 1.2: Applied dynamic row spacing and padding from DatabaseManager configuration.
// - 1.0 -> 1.1: Updated deprecated onChange modifiers to new syntax for macOS 14.0+.

import SwiftUI
#if os(macOS)
import AppKit
#endif

fileprivate struct TableFontConfig {
    let primarySize: CGFloat
    let secondarySize: CGFloat
    let headerSize: CGFloat
    let badgeSize: CGFloat
}

private enum CurrencyTableColumn: String, CaseIterable, Codable {
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
        switch self {
        case .xSmall: return 12
        case .small: return 13.5
        case .medium: return 15
        case .large: return 16.5
        case .xLarge: return 18
        }
    }

    var secondarySize: CGFloat { baseSize - 1 }
    var badgeSize: CGFloat { max(baseSize - 2, 10) }
    var headerSize: CGFloat { baseSize - 1 }
}

private struct ColumnDragContext {
    let primary: CurrencyTableColumn
    let neighbor: CurrencyTableColumn
    let primaryBaseWidth: CGFloat
    let neighborBaseWidth: CGFloat
}

fileprivate struct CurrencyRow: Identifiable, Equatable {
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

    @State private var columnFractions: [CurrencyTableColumn: CGFloat]
    @State private var resolvedColumnWidths: [CurrencyTableColumn: CGFloat]
    @State private var visibleColumns: Set<CurrencyTableColumn>
    @State private var selectedFontSize: TableFontSize
    @State private var didRestoreColumnFractions = false
    @State private var availableTableWidth: CGFloat = 0
    @State private var dragContext: ColumnDragContext? = nil
    @State private var hasHydratedPreferences = false
    @State private var isHydratingPreferences = false

    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    private static let columnOrder: [CurrencyTableColumn] = [.code, .name, .symbol, .api, .status]
    private static let defaultVisibleColumns: Set<CurrencyTableColumn> = Set(columnOrder)
    private static let visibleColumnsKey = "CurrenciesView.visibleColumns.v1"
    private static let headerBackground = Color(red: 230.0/255.0, green: 242.0/255.0, blue: 1.0)

    private static let defaultColumnWidths: [CurrencyTableColumn: CGFloat] = [
        .code: 110,
        .name: 280,
        .symbol: 120,
        .api: 110,
        .status: 130
    ]

    private static let minimumColumnWidths: [CurrencyTableColumn: CGFloat] = [
        .code: 90,
        .name: 220,
        .symbol: 90,
        .api: 90,
        .status: 110
    ]

    private static let initialColumnFractions: [CurrencyTableColumn: CGFloat] = {
        let total = defaultColumnWidths.values.reduce(0, +)
        guard total > 0 else {
            let share = 1.0 / CGFloat(CurrencyTableColumn.allCases.count)
            return Dictionary(uniqueKeysWithValues: CurrencyTableColumn.allCases.map { ($0, share) })
        }
        return Dictionary(uniqueKeysWithValues: CurrencyTableColumn.allCases.map { column in
            let width = defaultColumnWidths[column] ?? 0
            return (column, max(0.0001, width / total))
        })
    }()

    private static let columnHandleWidth: CGFloat = 10
    private static let columnHandleHitSlop: CGFloat = 8
    fileprivate static let columnTextInset: CGFloat = 12

    init() {
        let defaults = CurrenciesView.initialColumnFractions
        _columnFractions = State(initialValue: defaults)
        _resolvedColumnWidths = State(initialValue: CurrenciesView.defaultColumnWidths)
        if let storedVisible = UserDefaults.standard.array(forKey: CurrenciesView.visibleColumnsKey) as? [String] {
            let restored = Set(storedVisible.compactMap(CurrencyTableColumn.init(rawValue:)))
            _visibleColumns = State(initialValue: restored.isEmpty ? CurrenciesView.defaultVisibleColumns : restored)
        } else {
            _visibleColumns = State(initialValue: CurrenciesView.defaultVisibleColumns)
        }
        _selectedFontSize = State(initialValue: .medium)
    }

    private var activeColumns: [CurrencyTableColumn] {
        CurrenciesView.columnOrder.filter { visibleColumns.contains($0) }
    }

    private var fontConfig: TableFontConfig {
        TableFontConfig(
            primarySize: selectedFontSize.baseSize,
            secondarySize: selectedFontSize.secondarySize,
            headerSize: selectedFontSize.headerSize,
            badgeSize: selectedFontSize.badgeSize
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.93, green: 0.95, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            CurrencyParticleBackground()

            VStack(spacing: 16) {
                modePicker
                Group {
                    if selectedSegment == 0 {
                        currenciesSection
                    } else {
                        fxSection
                    }
                }
                .transition(.opacity)
            }
            .padding(24)
        }
        .onAppear {
            hydratePreferencesIfNeeded()
            loadCurrencies()
            animateEntrance()
            if !didRestoreColumnFractions {
                restoreColumnFractions()
                didRestoreColumnFractions = true
                recalcColumnWidths()
            }
        }
        .onChange(of: selectedSegment) { _, newValue in
            if newValue == 0 {
                loadCurrencies()
            }
        }
        .onChange(of: selectedFontSize) { _, _ in
            persistFontSize()
        }
        .onReceive(dbManager.$currenciesTableFontSize) { newValue in
            guard !isHydratingPreferences, let size = TableFontSize(rawValue: newValue), size != selectedFontSize else { return }
            isHydratingPreferences = true
            selectedFontSize = size
            DispatchQueue.main.async { isHydratingPreferences = false }
        }
        .onReceive(dbManager.$currenciesTableColumnFractions) { newValue in
            guard !isHydratingPreferences else { return }
            isHydratingPreferences = true
            if restoreFromStoredColumnFractions(newValue) {
                didRestoreColumnFractions = true
                recalcColumnWidths()
            }
            DispatchQueue.main.async { isHydratingPreferences = false }
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
            Button("Cancel", role: .cancel) { }
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
        .pickerStyle(SegmentedPickerStyle())
        .font(.system(size: 13, weight: .semibold))
    }

    private var currenciesSection: some View {
        VStack(spacing: 0) {
            modernHeader
            searchAndStats
            currenciesContent
            modernActionBar
        }
    }

    private var fxSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: { withAnimation { selectedSegment = 0 } }) {
                    Label("Back to Currencies", systemImage: "chevron.left")
                }
                .buttonStyle(SecondaryButtonStyle())
                Spacer()
            }
            ExchangeRatesView()
                .environmentObject(dbManager)
        }
    }

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("Currencies")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                Text("Manage supported currencies and exchange rates")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 16) {
                modernStatCard(title: "Total", value: "\(currencies.count)", icon: "number.circle.fill", color: .green)
                modernStatCard(title: "Active", value: "\(currencies.filter { $0.isActive }.count)", icon: "checkmark.circle.fill", color: .blue)
                modernStatCard(title: "API", value: "\(currencies.filter { $0.apiSupported }.count)", icon: "wifi.circle.fill", color: .purple)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }

    private var searchAndStats: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search currencies...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)

            if !searchText.isEmpty || !apiFilters.isEmpty || !statusFilters.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Found \(sortedCurrencies.count) of \(currencies.count) currencies")
                        .font(.caption)
                        .foregroundColor(.gray)
                    HStack(spacing: 8) {
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
        .padding(.horizontal, 24)
        .offset(y: contentOffset)
    }

    private var currenciesContent: some View {
        VStack(spacing: 12) {
            tableControls
            if sortedCurrencies.isEmpty {
                emptyStateView
            } else {
                currenciesTable
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .offset(y: contentOffset)
    }

    private var tableControls: some View {
        HStack(spacing: 12) {
            columnsMenu
            fontSizePicker
            Spacer()
            if visibleColumns != CurrenciesView.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 4)
        .font(.system(size: 12))
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
        }
    }

    private var fontSizePicker: some View {
        Picker("Font Size", selection: $selectedFontSize) {
            ForEach(TableFontSize.allCases, id: \.self) { size in
                Text(size.label).tag(size)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .labelsHidden()
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty && apiFilters.isEmpty && statusFilters.isEmpty ? "dollarsign.circle" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                VStack(spacing: 8) {
                    Text(searchText.isEmpty && apiFilters.isEmpty && statusFilters.isEmpty ? "No currencies yet" : "No results match your filters")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    Text(searchText.isEmpty && apiFilters.isEmpty && statusFilters.isEmpty ? "Add your first currency to start managing FX." : "Try adjusting your search or filter selections.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                if searchText.isEmpty && apiFilters.isEmpty && statusFilters.isEmpty {
                    Button { showAddCurrencySheet = true } label: {
                        Label("Add Currency", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                    .foregroundColor(.black)
                    .padding(.top, 8)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var currenciesTable: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            let targetWidth = max(availableWidth, totalMinimumWidth())

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    modernTableHeader
                    currenciesTableRows
                }
                .frame(width: targetWidth, alignment: .leading)
            }
            .frame(width: availableWidth, alignment: .leading)
            .onAppear {
                updateAvailableWidth(targetWidth)
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                updateAvailableWidth(max(newWidth, totalMinimumWidth()))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0)
    }

    private var currenciesTableRows: some View {
        ScrollView {
            LazyVStack(spacing: CGFloat(dbManager.tableRowSpacing)) {
                ForEach(sortedCurrencies) { currency in
                    ModernCurrencyRowView(
                        currency: currency,
                        columns: activeColumns,
                        fontConfig: fontConfig,
                        isSelected: selectedCurrency?.code == currency.code,
                        rowPadding: CGFloat(dbManager.tableRowPadding),
                        widthFor: { width(for: $0) },
                        onTap: {
                            selectedCurrency = currency
                        },
                        onEdit: {
                            selectedCurrency = currency
                            showEditCurrencySheet = true
                        }
                    )
                }
            }
        }
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .frame(width: max(availableTableWidth, totalMinimumWidth()), alignment: .leading)
    }

    private var modernTableHeader: some View {
        HStack(spacing: 0) {
            ForEach(activeColumns, id: \.self) { column in
                headerCell(for: column)
                    .frame(width: width(for: column), alignment: .leading)
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, 2)
        .background(
            Rectangle()
                .fill(CurrenciesView.headerBackground)
                .overlay(Rectangle().stroke(Color.blue.opacity(0.15), lineWidth: 1))
        )
        .frame(width: max(availableTableWidth, totalMinimumWidth()), alignment: .leading)
    }

    private func headerCell(for column: CurrencyTableColumn) -> some View {
        let leadingTarget = leadingHandleTarget(for: column)
        let isLast = isLastActiveColumn(column)
        let sortOption = sortOption(for: column)
        let isActiveSort = sortOption.map { $0 == sortColumn } ?? false
        let filterBinding = filterBinding(for: column)
        let filterOptions = filterValues(for: column)

        return ZStack(alignment: .leading) {
            if let target = leadingTarget {
                resizeHandle(for: target)
            }
            if isLast {
                resizeHandle(for: column)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 6) {
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
                                .font(.system(size: fontConfig.headerSize, weight: .semibold))
                                .foregroundColor(.black)
                            Text(sortAscending ? "▲" : "▼")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isActiveSort ? .accentColor : .clear)
                                .accessibilityHidden(!isActiveSort)
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
                            .foregroundColor(binding.wrappedValue.isEmpty ? .gray : .accentColor)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                }
            }
            .padding(.leading, CurrenciesView.columnTextInset + (leadingTarget == nil ? 0 : CurrenciesView.columnHandleWidth))
            .padding(.trailing, isLast ? CurrenciesView.columnHandleWidth + 8 : 8)
        }
    }

    private func resizeHandle(for column: CurrencyTableColumn) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: CurrenciesView.columnHandleWidth + CurrenciesView.columnHandleHitSlop * 2,
                   height: 28)
            .offset(x: -CurrenciesView.columnHandleHitSlop)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
#if os(macOS)
                        NSCursor.resizeLeftRight.set()
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
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
#endif
    }

    private func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            HStack(spacing: 16) {
                Button { showAddCurrencySheet = true } label: {
                    Label("Add Currency", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)

                if selectedCurrency != nil {
                    Button {
                        showEditCurrencySheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        if let currency = selectedCurrency {
                            currencyToDelete = currency
                            showingDeleteAlert = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Spacer()

                if let currency = selectedCurrency {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Selected: \(currency.code)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
        .opacity(buttonsOpacity)
    }

    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
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

    private func isLastActiveColumn(_ column: CurrencyTableColumn) -> Bool {
        activeColumns.last == column
    }

    private func leadingHandleTarget(for column: CurrencyTableColumn) -> CurrencyTableColumn? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        return index == 0 ? column : columns[index - 1]
    }

    private func neighborColumn(for column: CurrencyTableColumn) -> CurrencyTableColumn? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        if index < columns.count - 1 {
            return columns[index + 1]
        } else if index > 0 {
            return columns[index - 1]
        }
        return nil
    }

    private func width(for column: CurrencyTableColumn) -> CGFloat {
        guard visibleColumns.contains(column) else { return 0 }
        return resolvedColumnWidths[column] ?? CurrenciesView.defaultColumnWidths[column] ?? minimumWidth(for: column)
    }

    private func minimumWidth(for column: CurrencyTableColumn) -> CGFloat {
        CurrenciesView.minimumColumnWidths[column] ?? 80
    }

    private func totalMinimumWidth() -> CGFloat {
        activeColumns.reduce(0) { $0 + minimumWidth(for: $1) }
    }

    private func updateAvailableWidth(_ width: CGFloat) {
        let targetWidth = max(width, totalMinimumWidth())
        guard targetWidth.isFinite, targetWidth > 0 else { return }

        if !didRestoreColumnFractions {
            restoreColumnFractions()
            didRestoreColumnFractions = true
        }

        if abs(availableTableWidth - targetWidth) < 0.5 { return }
        availableTableWidth = targetWidth
        adjustResolvedWidths(for: targetWidth)
        persistColumnFractions()
    }

    private func adjustResolvedWidths(for availableWidth: CGFloat) {
        guard availableWidth > 0 else { return }
        let fractions = normalizedFractions()
        var remainingColumns = activeColumns
        var remainingWidth = availableWidth
        var remainingFraction = remainingColumns.reduce(0) { $0 + (fractions[$1] ?? 0) }
        var resolved: [CurrencyTableColumn: CGFloat] = [:]

        while !remainingColumns.isEmpty {
            var clamped: [CurrencyTableColumn] = []
            for column in remainingColumns {
                let fraction = fractions[column] ?? 0
                guard fraction > 0 else { continue }
                let proposed = remainingFraction > 0 ? remainingWidth * fraction / remainingFraction : 0
                let minWidth = minimumWidth(for: column)
                if proposed < minWidth - 0.5 {
                    resolved[column] = minWidth
                    remainingWidth = max(0, remainingWidth - minWidth)
                    remainingFraction -= fraction
                    clamped.append(column)
                }
            }
            if clamped.isEmpty { break }
            remainingColumns.removeAll { clamped.contains($0) }
            if remainingFraction <= 0 { break }
        }

        if !remainingColumns.isEmpty {
            if remainingFraction > 0 {
                for column in remainingColumns {
                    let fraction = fractions[column] ?? 0
                    let share = remainingWidth * fraction / remainingFraction
                    let minWidth = minimumWidth(for: column)
                    resolved[column] = max(minWidth, share)
                }
            } else {
                let share = remainingColumns.isEmpty ? 0 : remainingWidth / CGFloat(remainingColumns.count)
                for column in remainingColumns {
                    resolved[column] = max(minimumWidth(for: column), share)
                }
                }
        }

        balanceResolvedWidths(&resolved, targetWidth: availableWidth)

        for column in CurrenciesView.columnOrder {
            if !visibleColumns.contains(column) {
                resolved[column] = 0
            } else if resolved[column] == nil {
                resolved[column] = minimumWidth(for: column)
            }
        }

        resolvedColumnWidths = resolved

        var updatedFractions: [CurrencyTableColumn: CGFloat] = [:]
        let safeWidth = max(availableWidth, 1)
        for column in CurrenciesView.columnOrder {
            let widthValue = resolved[column] ?? 0
            updatedFractions[column] = max(0.0001, widthValue / safeWidth)
        }
        columnFractions = normalizedFractions(updatedFractions)
    }

    private func balanceResolvedWidths(_ resolved: inout [CurrencyTableColumn: CGFloat], targetWidth: CGFloat) {
        let currentTotal = resolved.values.reduce(0, +)
        let difference = targetWidth - currentTotal
        guard abs(difference) > 0.5 else { return }

        if difference > 0 {
            if let column = activeColumns.first {
                resolved[column, default: minimumWidth(for: column)] += difference
            }
        } else {
            var remainingDifference = difference
            var adjustable = activeColumns.filter {
                let current = resolved[$0] ?? minimumWidth(for: $0)
                return current - minimumWidth(for: $0) > 0.5
            }

            while remainingDifference < -0.5, !adjustable.isEmpty {
                let share = remainingDifference / CGFloat(adjustable.count)
                var columnsAtMinimum: [CurrencyTableColumn] = []
                for column in adjustable {
                    let minWidth = minimumWidth(for: column)
                    let current = resolved[column] ?? minWidth
                    let adjusted = max(minWidth, current + share)
                    resolved[column] = adjusted
                    remainingDifference -= (adjusted - current)
                    if adjusted - minWidth < 0.5 {
                        columnsAtMinimum.append(column)
                    }
                    if remainingDifference >= -0.5 { break }
                }
                adjustable.removeAll { columnsAtMinimum.contains($0) }
                if adjustable.isEmpty { break }
            }
        }
    }

    private func normalizedFractions(_ input: [CurrencyTableColumn: CGFloat]? = nil) -> [CurrencyTableColumn: CGFloat] {
        let source = input ?? columnFractions
        let active = activeColumns
        var result: [CurrencyTableColumn: CGFloat] = [:]
        guard !active.isEmpty else {
            for column in CurrenciesView.columnOrder { result[column] = 0 }
            return result
        }
        let total = active.reduce(0) { $0 + max(0, source[$1] ?? 0) }
        if total <= 0 {
            let share = 1.0 / CGFloat(active.count)
            for column in CurrenciesView.columnOrder {
                result[column] = active.contains(column) ? share : 0
            }
            return result
        }
        for column in CurrenciesView.columnOrder {
            if active.contains(column) {
                result[column] = max(0.0001, source[column] ?? 0) / total
            } else {
                result[column] = 0
            }
        }
        return result
    }

    private func beginDrag(for column: CurrencyTableColumn) {
        guard let neighbor = neighborColumn(for: column) else { return }
        let primaryWidth = resolvedColumnWidths[column] ?? (CurrenciesView.defaultColumnWidths[column] ?? minimumWidth(for: column))
        let neighborWidth = resolvedColumnWidths[neighbor] ?? (CurrenciesView.defaultColumnWidths[neighbor] ?? minimumWidth(for: neighbor))
        dragContext = ColumnDragContext(primary: column, neighbor: neighbor, primaryBaseWidth: primaryWidth, neighborBaseWidth: neighborWidth)
    }

    private func updateDrag(for column: CurrencyTableColumn, translation: CGFloat) {
        guard let context = dragContext, context.primary == column else { return }
        let totalWidth = max(availableTableWidth, 1)
        let minPrimary = minimumWidth(for: context.primary)
        let minNeighbor = minimumWidth(for: context.neighbor)
        let combined = context.primaryBaseWidth + context.neighborBaseWidth

        var newPrimary = context.primaryBaseWidth + translation
        let maximumPrimary = combined - minNeighbor
        newPrimary = min(max(newPrimary, minPrimary), maximumPrimary)
        let newNeighbor = combined - newPrimary

        var updatedFractions = columnFractions
        updatedFractions[context.primary] = max(0.0001, newPrimary / totalWidth)
        updatedFractions[context.neighbor] = max(0.0001, newNeighbor / totalWidth)
        columnFractions = normalizedFractions(updatedFractions)
        adjustResolvedWidths(for: totalWidth)
    }

    private func finalizeDrag() {
        dragContext = nil
        persistColumnFractions()
    }

    private func toggleColumn(_ column: CurrencyTableColumn) {
        var newSet = visibleColumns
        if newSet.contains(column) {
            guard newSet.count > 1 else { return }
            newSet.remove(column)
        } else {
            newSet.insert(column)
        }
        visibleColumns = newSet
        persistVisibleColumns()
        ensureValidSortColumn()
        recalcColumnWidths()
    }

    private func resetVisibleColumns() {
        visibleColumns = CurrenciesView.defaultVisibleColumns
        persistVisibleColumns()
        ensureValidSortColumn()
        recalcColumnWidths()
    }

    private func resetTablePreferences() {
        visibleColumns = CurrenciesView.defaultVisibleColumns
        selectedFontSize = .medium
        persistVisibleColumns()
        persistFontSize()
        ensureValidSortColumn()
        recalcColumnWidths()
    }

    private func persistVisibleColumns() {
        let ordered = CurrenciesView.columnOrder.filter { visibleColumns.contains($0) }
        UserDefaults.standard.set(ordered.map { $0.rawValue }, forKey: CurrenciesView.visibleColumnsKey)
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

    private func recalcColumnWidths() {
        let width = max(availableTableWidth, totalMinimumWidth())
        guard availableTableWidth > 0 else { return }
        adjustResolvedWidths(for: width)
        persistColumnFractions()
    }

    private func hydratePreferencesIfNeeded() {
        guard !hasHydratedPreferences else { return }
        hasHydratedPreferences = true
        isHydratingPreferences = true

        migrateLegacyFontIfNeeded()

        if let stored = TableFontSize(rawValue: dbManager.tableFontSize(for: .currencies)) {
            selectedFontSize = stored
        }

        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    private func migrateLegacyFontIfNeeded() {
        guard let legacy = dbManager.legacyTableFontSize(for: .currencies) else { return }
        if dbManager.tableFontSize(for: .currencies) != legacy {
            dbManager.setTableFontSize(legacy, for: .currencies)
        }
        dbManager.clearLegacyTableFontSize(for: .currencies)
    }

    private func persistFontSize() {
        guard !isHydratingPreferences else { return }
        isHydratingPreferences = true
        dbManager.setTableFontSize(selectedFontSize.rawValue, for: .currencies)
        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    private func persistColumnFractions() {
        guard !isHydratingPreferences else { return }
        isHydratingPreferences = true
        let payload = columnFractions.reduce(into: [String: Double]()) { result, entry in
            guard entry.value.isFinite else { return }
            result[entry.key.rawValue] = Double(entry.value)
        }
        dbManager.setTableColumnFractions(payload, for: .currencies)
        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    private func restoreColumnFractions() {
        if restoreFromStoredColumnFractions(dbManager.tableColumnFractions(for: .currencies)) {
            return
        }

        if let legacy = dbManager.legacyTableColumnFractions(for: .currencies) {
            let typed = typedFractions(from: legacy)
            if typed.isEmpty {
                dbManager.clearLegacyTableColumnFractions(for: .currencies)
            } else {
                columnFractions = normalizedFractions(typed)
                dbManager.setTableColumnFractions(legacy, for: .currencies)
                dbManager.clearLegacyTableColumnFractions(for: .currencies)
            }
            return
        }

        columnFractions = normalizedFractions(CurrenciesView.initialColumnFractions)
    }

    @discardableResult
    private func restoreFromStoredColumnFractions(_ stored: [String: Double]) -> Bool {
        let restored = typedFractions(from: stored)
        guard !restored.isEmpty else { return false }
        columnFractions = normalizedFractions(restored)
        return true
    }

    private func typedFractions(from raw: [String: Double]) -> [CurrencyTableColumn: CGFloat] {
        raw.reduce(into: [CurrencyTableColumn: CGFloat]()) { result, entry in
            guard let column = CurrencyTableColumn(rawValue: entry.key), entry.value.isFinite else { return }
            let fraction = max(0, entry.value)
            if fraction > 0 { result[column] = CGFloat(fraction) }
        }
    }
}

fileprivate struct ModernCurrencyRowView: View {
    let currency: CurrencyRow
    let columns: [CurrencyTableColumn]
    let fontConfig: TableFontConfig
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
                .fill(isSelected ? Color.green.opacity(0.1) : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.05))
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
                .font(.system(size: fontConfig.primarySize, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.leading, CurrenciesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.code), alignment: .leading)
        case .name:
            Text(currency.name)
                .font(.system(size: fontConfig.primarySize, weight: .medium))
                .foregroundColor(.primary)
                .padding(.leading, CurrenciesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.name), alignment: .leading)
        case .symbol:
            Text(currency.symbol)
                .font(.system(size: fontConfig.secondarySize, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.leading, CurrenciesView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.symbol), alignment: .leading)
        case .api:
            HStack(spacing: 6) {
                Circle()
                    .fill(currency.apiSupported ? Color.purple : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(currency.apiLabel)
                    .font(.system(size: fontConfig.badgeSize, weight: .semibold))
                    .foregroundColor(currency.apiSupported ? .purple : .gray)
            }
            .padding(.leading, CurrenciesView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.api), alignment: .leading)
        case .status:
            HStack(spacing: 6) {
                Circle()
                    .fill(currency.isActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(currency.statusLabel)
                    .font(.system(size: fontConfig.badgeSize, weight: .semibold))
                    .foregroundColor(currency.isActive ? .green : .orange)
            }
            .padding(.leading, CurrenciesView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.status), alignment: .leading)
        }
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
            LinearGradient( colors: [Color(red: 0.98, green: 0.99, blue: 1.0),Color(red: 0.95, green: 0.97, blue: 0.99),Color(red: 0.93, green: 0.95, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            AddCurrencyParticleBackground()
            VStack(spacing: 0) { addModernHeader; addProgressBar; addModernContent; }
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
        ScrollView { VStack(spacing: 24) { addCurrencyInfoSection; addStatusSection; }.padding(.horizontal, 24).padding(.bottom, 100) }.offset(y: sectionsOffset)
    }
    private var addCurrencyInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Currency Information", icon: "dollarsign.circle.fill", color: .green)
            VStack(spacing: 16) { addModernTextField(title: "Currency Code",text: $currencyCode,placeholder: "e.g., JPY",icon: "number.circle.fill",isRequired: true,autoUppercase: true,validation: isValidCurrencyCode,errorMessage: "Currency code must be 3 letters (e.g., USD, EUR)"); addModernTextField(title: "Currency Name",text: $currencyName,placeholder: "e.g., Japanese Yen",icon: "textformat",isRequired: true); addModernTextField(title: "Currency Symbol",text: $currencySymbol,placeholder: "e.g., ¥",icon: "dollarsign",isRequired: true) }
        }.padding(24).background(addCurrencyGlassMorphismBackground).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.2), lineWidth: 1)).shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    private var addStatusSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Settings", icon: "gearshape.circle.fill", color: .blue)
            VStack(spacing: 16) { HStack(spacing: 16) { VStack(alignment: .leading, spacing: 8) { HStack { Image(systemName: "checkmark.circle").font(.system(size: 14)).foregroundColor(.gray); Text("Active Status").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }; Toggle("Active", isOn: $isActive).toggleStyle(SwitchToggleStyle(tint: .green)).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1) }.frame(maxWidth: .infinity); VStack(alignment: .leading, spacing: 8) { HStack { Image(systemName: "wifi.circle").font(.system(size: 14)).foregroundColor(.gray); Text("API Support").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }; Toggle("API Supported", isOn: $apiSupported).toggleStyle(SwitchToggleStyle(tint: .purple)).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1) }.frame(maxWidth: .infinity) } }
        }.padding(24).background(addCurrencyGlassMorphismBackground).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.2), lineWidth: 1)).shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    private var addCurrencyGlassMorphismBackground: some View {
        ZStack { RoundedRectangle(cornerRadius: 16).fill(.regularMaterial).background(LinearGradient(colors: [.white.opacity(0.8),.white.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)); RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.green.opacity(0.05),.blue.opacity(0.03),.clear], startPoint: .topLeading, endPoint: .bottomTrailing)) }
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
        ScrollView { VStack(spacing: 24) { requiredSection; optionalSection; }.padding(.horizontal, 24).padding(.bottom, 100) }.offset(y: sectionsOffset)
    }
    
    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Currency Information", icon: "checkmark.shield.fill", color: .orange)
            VStack(spacing: 16) {
                modernTextField(title: "Currency Code",text: .constant(currencyCode),placeholder: currencyCode,icon: "number.circle.fill",isRequired: true,isReadOnly: true)
                modernTextField(title: "Currency Name",text: $currencyName,placeholder: "e.g., Danish Krone",icon: "textformat",isRequired: true)
                modernTextField(title: "Currency Symbol",text: $currencySymbol,placeholder: "e.g., DKK",icon: "dollarsign",isRequired: true)
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
        let alert = NSAlert();alert.messageText = "Unsaved Changes";alert.informativeText = "You have unsaved changes. Are you sure you want to close without saving?";alert.alertStyle = .warning;alert.addButton(withTitle: "Save & Close");alert.addButton(withTitle: "Discard Changes");alert.addButton(withTitle: "Cancel");
        let response = alert.runModal();
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
    private func createParticles() { particles = (0..<12).map { _ in AddCurrencyParticle(position: CGPoint(x: CGFloat.random(in: 0...600), y: CGFloat.random(in: 0...550)), size: CGFloat.random(in: 3...9), opacity: Double.random(in: 0.1...0.2)) } }
    private func animateParticles() { withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) { for index in particles.indices { particles[index].position.y -= 700; particles[index].opacity = Double.random(in: 0.05...0.15) } } }
}
struct EditCurrencyParticleBackground: View {
    @State private var particles: [EditCurrencyParticle] = []; var body: some View { ZStack { ForEach(particles.indices, id: \.self) { index in Circle().fill(Color.orange.opacity(0.04)).frame(width: particles[index].size, height: particles[index].size).position(particles[index].position).opacity(particles[index].opacity) } }.onAppear { createParticles(); animateParticles() } }
    private func createParticles() { particles = (0..<12).map { _ in EditCurrencyParticle(position: CGPoint(x: CGFloat.random(in: 0...600), y: CGFloat.random(in: 0...600)), size: CGFloat.random(in: 3...9), opacity: Double.random(in: 0.1...0.2)) } }
    private func animateParticles() { withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) { for index in particles.indices { particles[index].position.y -= 800; particles[index].opacity = Double.random(in: 0.05...0.15) } } }
}
struct AddCurrencyParticle { var position: CGPoint; var size: CGFloat; var opacity: Double }
struct EditCurrencyParticle { var position: CGPoint; var size: CGFloat; var opacity: Double }

struct CurrencyParticleBackground: View {
    @State private var particles: [CurrencyParticle] = []; var body: some View { ZStack { ForEach(particles.indices, id: \.self) { index in Circle().fill(Color.green.opacity(0.03)).frame(width: particles[index].size, height: particles[index].size).position(particles[index].position).opacity(particles[index].opacity) } }.onAppear { createParticles(); animateParticles() } }
    private func createParticles() { particles = (0..<15).map { _ in CurrencyParticle(position: CGPoint(x: CGFloat.random(in: 0...1200), y: CGFloat.random(in: 0...800)), size: CGFloat.random(in: 2...8), opacity: Double.random(in: 0.1...0.2)) } }
    private func animateParticles() { withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) { for index in particles.indices { particles[index].position.y -= 1000; particles[index].opacity = Double.random(in: 0.05...0.15) } } }
}
struct CurrencyParticle { var position: CGPoint; var size: CGFloat; var opacity: Double }
