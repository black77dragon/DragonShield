import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Version 2.0
// MARK: - History
// - 1.x -> 2.0: Adopted modern table UX with column controls, filters, and inline actions.

fileprivate struct TableFontConfig {
    let primarySize: CGFloat
    let secondarySize: CGFloat
    let headerSize: CGFloat
    let badgeSize: CGFloat
}

private enum TransactionTableColumn: String, CaseIterable, Codable {
    case tradeId
    case date
    case type
    case instrument
    case quantity
    case instrumentDelta
    case price
    case tradeValue
    case cashDelta
    case currency
    case custodyAccount
    case cashAccount
    case fees
    case commission

    var title: String {
        switch self {
        case .tradeId: return "#"
        case .date: return "Date"
        case .type: return "Type"
        case .instrument: return "Instrument"
        case .quantity: return "Qty"
        case .instrumentDelta: return "Instr Δ"
        case .price: return "Price"
        case .tradeValue: return "Value"
        case .cashDelta: return "Cash Δ"
        case .currency: return "Cur"
        case .custodyAccount: return "Custody"
        case .cashAccount: return "Cash"
        case .fees: return "Fees (CHF)"
        case .commission: return "Comm (CHF)"
        }
    }

    var menuTitle: String {
        switch self {
        case .tradeId: return "Trade ID"
        case .instrumentDelta: return "Instrument Delta"
        case .tradeValue: return "Trade Value"
        case .cashDelta: return "Cash Delta"
        case .custodyAccount: return "Custody Account"
        case .cashAccount: return "Cash Account"
        case .fees: return "Fees"
        case .commission: return "Commission"
        default:
            let base = title
            return base.isEmpty ? rawValue.capitalized : base
        }
    }
}

struct TradesHistoryView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var trades: [DatabaseManager.TradeWithLegs] = []
    @State private var selectedTrade: DatabaseManager.TradeWithLegs? = nil
    @State private var showForm = false
    @State private var showReverseConfirm = false
    @State private var showDeleteConfirm = false
    @State private var editTradeId: Int? = nil

    @State private var searchText: String = ""
    @State private var typeFilters: Set<String> = []
    @State private var cashAccountFilters: Set<String> = []
    @State private var custodyAccountFilters: Set<String> = []

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    enum SortColumn: String, CaseIterable {
        case tradeId
        case date
        case type
        case instrument
        case quantity
        case instrumentDelta
        case price
        case tradeValue
        case cashDelta
        case currency
        case custodyAccount
        case cashAccount
        case fees
        case commission
    }

    @State private var sortColumn: SortColumn = .date
    @State private var sortAscending: Bool = false

    @State private var columnFractions: [TransactionTableColumn: CGFloat]
    @State private var resolvedColumnWidths: [TransactionTableColumn: CGFloat]
    @State private var visibleColumns: Set<TransactionTableColumn>
    @State private var selectedFontSize: TableFontSize
    @State private var didRestoreColumnFractions = false
    @State private var availableTableWidth: CGFloat = 0
    @State private var dragContext: ColumnDragContext? = nil

    private struct ColumnDragContext {
        let primary: TransactionTableColumn
        let neighbor: TransactionTableColumn
        let primaryBaseWidth: CGFloat
        let neighborBaseWidth: CGFloat
    }

    enum TableFontSize: String, CaseIterable {
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
        var badgeSize: CGFloat { baseSize - 2 }
        var headerSize: CGFloat { baseSize - 1 }
    }

    private static let visibleColumnsKey = "TradesHistoryView.visibleColumns.v1"
    private static let columnFractionsKey = "TradesHistoryView.columnFractions.v1"
    private static let fontSizeKey = "TradesHistoryView.tableFontSize.v1"
    private static let headerBackground = Color(red: 230.0/255.0, green: 242.0/255.0, blue: 1.0)

    fileprivate static let columnHandleWidth: CGFloat = 10
    fileprivate static let columnHandleHitSlop: CGFloat = 8
    fileprivate static let columnTextInset: CGFloat = 12

    private static let columnOrder: [TransactionTableColumn] = [
        .tradeId, .date, .type, .instrument, .quantity, .instrumentDelta,
        .price, .tradeValue, .cashDelta, .currency, .custodyAccount,
        .cashAccount, .fees, .commission
    ]

    private static let defaultVisibleColumns: Set<TransactionTableColumn> = [
        .date, .type, .instrument, .quantity, .price, .tradeValue,
        .cashDelta, .currency, .custodyAccount, .cashAccount
    ]

    private static let requiredColumns: Set<TransactionTableColumn> = [.date, .instrument]

    private static let defaultColumnWidths: [TransactionTableColumn: CGFloat] = [
        .tradeId: 70,
        .date: 120,
        .type: 110,
        .instrument: 280,
        .quantity: 110,
        .instrumentDelta: 120,
        .price: 120,
        .tradeValue: 140,
        .cashDelta: 160,
        .currency: 80,
        .custodyAccount: 200,
        .cashAccount: 200,
        .fees: 120,
        .commission: 120
    ]

    private static let minimumColumnWidths: [TransactionTableColumn: CGFloat] = [
        .tradeId: 60,
        .date: 100,
        .type: 90,
        .instrument: 220,
        .quantity: 90,
        .instrumentDelta: 100,
        .price: 100,
        .tradeValue: 120,
        .cashDelta: 130,
        .currency: 70,
        .custodyAccount: 160,
        .cashAccount: 160,
        .fees: 100,
        .commission: 100
    ]

    private static let initialColumnFractions: [TransactionTableColumn: CGFloat] = {
        let total = defaultColumnWidths.values.reduce(0, +)
        guard total > 0 else {
            let fallback = 1.0 / CGFloat(TransactionTableColumn.allCases.count)
            return TransactionTableColumn.allCases.reduce(into: [:]) { result, column in
                result[column] = fallback
            }
        }
        return TransactionTableColumn.allCases.reduce(into: [:]) { result, column in
            let width = defaultColumnWidths[column] ?? 0
            result[column] = max(0.0001, width / total)
        }
    }()

#if os(macOS)
    fileprivate static let columnResizeCursor: NSCursor = {
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

    init() {
        let defaults = TradesHistoryView.initialColumnFractions
        _columnFractions = State(initialValue: defaults)
        _resolvedColumnWidths = State(initialValue: TradesHistoryView.defaultColumnWidths)

        if let storedVisible = UserDefaults.standard.array(forKey: TradesHistoryView.visibleColumnsKey) as? [String] {
            let set = Set(storedVisible.compactMap(TransactionTableColumn.init(rawValue:)))
            _visibleColumns = State(initialValue: set.isEmpty ? TradesHistoryView.defaultVisibleColumns : set)
        } else {
            _visibleColumns = State(initialValue: TradesHistoryView.defaultVisibleColumns)
        }

        if let storedFont = UserDefaults.standard.string(forKey: TradesHistoryView.fontSizeKey),
           let font = TableFontSize(rawValue: storedFont) {
            _selectedFontSize = State(initialValue: font)
        } else {
            _selectedFontSize = State(initialValue: .medium)
        }
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

            VStack(spacing: 0) {
                modernHeader
                infoBanner
                searchAndFilters
                transactionsContent
                modernActionBar
            }
        }
        .onAppear {
            dbManager.ensureTradeSchema()
            restoreColumnFractionsIfNeeded()
            reload()
            animateEntrance()
            recalcColumnWidths()
        }
        .onChange(of: selectedFontSize) {
            persistFontSize()
        }
        .sheet(isPresented: $showForm) {
            TradeFormView(
                onSaved: {
                    reload()
                    showForm = false
                },
                onCancel: {
                    showForm = false
                },
                editTradeId: editTradeId
            )
            .environmentObject(dbManager)
        }
        .alert("Reverse Trade", isPresented: $showReverseConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reverse", role: .destructive) {
                reverseSelectedTrade()
            }
        } message: {
            if let trade = selectedTrade {
                Text("Create a reversing trade for #\(trade.tradeId)?")
            }
        }
        .alert("Delete Trade", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedTrade()
            }
        } message: {
            if let trade = selectedTrade {
                Text("Permanently delete trade #\(trade.tradeId)?")
            }
        }
    }

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 32))
                        .foregroundColor(.green)

                    Text("Transactions")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("Buy/Sell trades with cash and instrument legs")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 16) {
                modernStatCard(
                    title: "Total",
                    value: "\(trades.count)",
                    icon: "number.circle",
                    color: .green
                )
                modernStatCard(
                    title: "Buys",
                    value: "\(trades.filter { $0.typeCode.uppercased() == "BUY" }.count)",
                    icon: "arrow.up.circle",
                    color: .blue
                )
                modernStatCard(
                    title: "Sells",
                    value: "\(trades.filter { $0.typeCode.uppercased() == "SELL" }.count)",
                    icon: "arrow.down.circle",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }

    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            Text("Transactions are NOT updating the custody and cash accounts. They are maintained manually. Currently the purpose of the transaction journal is to calculate the P&L of transactions only.")
                .font(.callout)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var searchAndFilters: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search instrument/account/currency, #id…", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
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

            if showSearchSummary {
                HStack {
                    Text("Found \(sortedTrades.count) of \(trades.count) trades")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }

                if hasActiveFilters {
                    HStack(spacing: 8) {
                        ForEach(Array(typeFilters).sorted(), id: \.self) { value in
                            filterChip(text: value) { typeFilters.remove(value) }
                        }
                        ForEach(Array(cashAccountFilters).sorted(), id: \.self) { value in
                            filterChip(text: value) { cashAccountFilters.remove(value) }
                        }
                        ForEach(Array(custodyAccountFilters).sorted(), id: \.self) { value in
                            filterChip(text: value) { custodyAccountFilters.remove(value) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .offset(y: contentOffset)
    }

    private var transactionsContent: some View {
        VStack(spacing: 12) {
            tableControls

            if sortedTrades.isEmpty {
                emptyStateView
                    .offset(y: contentOffset)
            } else {
                transactionsTable
                    .offset(y: contentOffset)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var tableControls: some View {
        HStack(spacing: 12) {
            columnsMenu
            fontSizePicker
            Spacer()
            if needsResetButton {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 4)
        .font(.system(size: 12))
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(TradesHistoryView.columnOrder, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.menuTitle, systemImage: isVisible ? "checkmark" : "")
                }
                .disabled(isVisible && (visibleColumns.count == 1 || TradesHistoryView.requiredColumns.contains(column)))
            }
            Divider()
            Button("Reset Columns", action: resetColumns)
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

    private var transactionsTable: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            let targetWidth = max(availableWidth, totalMinimumWidth())

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    modernTableHeader
                    transactionsTableRows
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
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
                .fill(TradesHistoryView.headerBackground)
                .overlay(Rectangle().stroke(Color.blue.opacity(0.15), lineWidth: 1))
        )
        .frame(width: max(availableTableWidth, totalMinimumWidth()), alignment: .leading)
    }

    private func headerCell(for column: TransactionTableColumn) -> some View {
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
                    Button {
                        if isActiveSort {
                            sortAscending.toggle()
                        } else {
                            sortColumn = sortOption
                            sortAscending = sortOption == .date ? false : true
                        }
                    } label: {
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
                        if !binding.wrappedValue.isEmpty {
                            Divider()
                            Button("Clear \(column.menuTitle)") {
                                binding.wrappedValue.removeAll()
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(binding.wrappedValue.isEmpty ? .gray : .accentColor)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                }
            }
            .padding(.leading, TradesHistoryView.columnTextInset + (leadingTarget == nil ? 0 : TradesHistoryView.columnHandleWidth))
            .padding(.trailing, isLast ? TradesHistoryView.columnHandleWidth + 8 : 8)
        }
    }

    private var transactionsTableRows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(sortedTrades.enumerated()), id: \.element.tradeId) { index, trade in
                    ModernTradeRowView(
                        trade: trade,
                        columns: activeColumns,
                        fontConfig: fontConfig,
                        widthFor: { width(for: $0) },
                        isSelected: selectedTrade?.tradeId == trade.tradeId,
                        isLast: index == sortedTrades.count - 1,
                        onTap: {
                            selectedTrade = trade
                        },
                        onEdit: {
                            editTradeId = trade.tradeId
                            showForm = true
                        },
                        formatNumber: formatNumber
                    )
                }
            }
        }
        .frame(width: max(availableTableWidth, totalMinimumWidth()), alignment: .leading)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                let isEmptyState = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasActiveFilters
                Image(systemName: isEmptyState ? "doc.text.magnifyingglass" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 8) {
                    Text(isEmptyState ? "No transactions yet" : "No matching trades")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)

                    Text(isEmptyState ? "Start by adding your first trade." : "Try adjusting your search or filters.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                if isEmptyState {
                    Button {
                        editTradeId = nil
                        showForm = true
                    } label: {
                        Label("Add Trade", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                    .foregroundColor(.black)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 16) {
                Button {
                    editTradeId = nil
                    showForm = true
                } label: {
                    Label("Add Trade", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)

                Button {
                    if let trade = selectedTrade {
                        editTradeId = trade.tradeId
                        showForm = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(selectedTrade == nil)

                Button {
                    showReverseConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.left")
                        Text("Reverse")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(selectedTrade == nil)

                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(selectedTrade == nil)

                Spacer()

                if let trade = selectedTrade {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Selected #\(trade.tradeId) • \(DateFormatter.iso8601DateOnly.string(from: trade.date))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .opacity(buttonsOpacity)
        }
    }

    private var fontConfig: TableFontConfig {
        TableFontConfig(
            primarySize: selectedFontSize.baseSize,
            secondarySize: selectedFontSize.secondarySize,
            headerSize: selectedFontSize.headerSize,
            badgeSize: selectedFontSize.badgeSize
        )
    }

    private var activeColumns: [TransactionTableColumn] {
        TradesHistoryView.columnOrder.filter { visibleColumns.contains($0) }
    }

    private var hasActiveFilters: Bool {
        !typeFilters.isEmpty || !cashAccountFilters.isEmpty || !custodyAccountFilters.isEmpty
    }

    private var showSearchSummary: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasActiveFilters
    }

    private var filteredTrades: [DatabaseManager.TradeWithLegs] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasQuery = !query.isEmpty

        return trades.filter { trade in
            let typeLabel = displayType(for: trade.typeCode)
            let cashName = normalized(trade.cashAccountName)
            let custodyName = normalized(trade.custodyAccountName)

            if !typeFilters.isEmpty && !typeFilters.contains(typeLabel) { return false }
            if !cashAccountFilters.isEmpty && !cashAccountFilters.contains(cashName) { return false }
            if !custodyAccountFilters.isEmpty && !custodyAccountFilters.contains(custodyName) { return false }

            guard hasQuery else { return true }

            let haystacks: [String] = [
                typeLabel.lowercased(),
                trade.instrumentName.lowercased(),
                cashName.lowercased(),
                custodyName.lowercased(),
                trade.currency.lowercased(),
                "#\(trade.tradeId)".lowercased(),
                formatNumber(trade.quantity, decimals: 4).lowercased(),
                formatNumber(trade.price, decimals: 4).lowercased(),
                formatNumber(trade.cashDelta, decimals: 2).lowercased()
            ]

            return haystacks.contains { $0.contains(query) }
        }
    }

    private var sortedTrades: [DatabaseManager.TradeWithLegs] {
        let rows = filteredTrades
        if sortAscending {
            return rows.sorted { ascendingSort(lhs: $0, rhs: $1) }
        } else {
            return rows.sorted { descendingSort(lhs: $0, rhs: $1) }
        }
    }

    private var needsResetButton: Bool {
        visibleColumns != TradesHistoryView.defaultVisibleColumns ||
        selectedFontSize != .medium ||
        hasCustomColumnFractions
    }

    private var hasCustomColumnFractions: Bool {
        let defaults = TradesHistoryView.initialColumnFractions
        for column in TradesHistoryView.columnOrder where visibleColumns.contains(column) {
            let current = columnFractions[column] ?? 0
            let baseline = defaults[column] ?? 0
            if abs(current - baseline) > 0.001 {
                return true
            }
        }
        return false
    }

    private func reload() {
        let currentSelectionId = selectedTrade?.tradeId
        trades = dbManager.fetchTradesWithLegs(limit: 500)
        if let id = currentSelectionId {
            selectedTrade = trades.first(where: { $0.tradeId == id })
        } else {
            selectedTrade = nil
        }
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6)) {
            headerOpacity = 1.0
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
            contentOffset = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            buttonsOpacity = 1.0
        }
    }

    private func resetTablePreferences() {
        visibleColumns = TradesHistoryView.defaultVisibleColumns
        selectedFontSize = .medium
        columnFractions = defaultFractions()
        persistVisibleColumns()
        persistFontSize()
        persistColumnFractions()
        recalcColumnWidths()
    }

    private func toggleColumn(_ column: TransactionTableColumn) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1, !TradesHistoryView.requiredColumns.contains(column) else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        persistVisibleColumns()
        columnFractions = normalizedFractions()
        persistColumnFractions()
        recalcColumnWidths()
    }

    private func resetColumns() {
        visibleColumns = TradesHistoryView.defaultVisibleColumns
        columnFractions = defaultFractions()
        persistVisibleColumns()
        persistColumnFractions()
        recalcColumnWidths()
    }

    private func formatNumber(_ value: Double, decimals: Int) -> String {
        guard value.isFinite else { return "—" }
        return String(format: "%0.*f", decimals, value)
    }

    private func displayType(for code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Other" : trimmed.capitalized
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func filterBinding(for column: TransactionTableColumn) -> Binding<Set<String>>? {
        switch column {
        case .type: return $typeFilters
        case .cashAccount: return $cashAccountFilters
        case .custodyAccount: return $custodyAccountFilters
        default: return nil
        }
    }

    private func filterValues(for column: TransactionTableColumn) -> [String] {
        switch column {
        case .type:
            return Array(Set(trades.map { displayType(for: $0.typeCode) })).sorted()
        case .cashAccount:
            return Array(Set(trades.map { normalized($0.cashAccountName) }.filter { !$0.isEmpty })).sorted()
        case .custodyAccount:
            return Array(Set(trades.map { normalized($0.custodyAccountName) }.filter { !$0.isEmpty })).sorted()
        default:
            return []
        }
    }

    private func sortOption(for column: TransactionTableColumn) -> SortColumn? {
        switch column {
        case .tradeId: return .tradeId
        case .date: return .date
        case .type: return .type
        case .instrument: return .instrument
        case .quantity: return .quantity
        case .instrumentDelta: return .instrumentDelta
        case .price: return .price
        case .tradeValue: return .tradeValue
        case .cashDelta: return .cashDelta
        case .currency: return .currency
        case .custodyAccount: return .custodyAccount
        case .cashAccount: return .cashAccount
        case .fees: return .fees
        case .commission: return .commission
        }
    }

    private func minimumWidth(for column: TransactionTableColumn) -> CGFloat {
        TradesHistoryView.minimumColumnWidths[column] ?? 60
    }

    private func width(for column: TransactionTableColumn) -> CGFloat {
        guard visibleColumns.contains(column) else { return 0 }
        return resolvedColumnWidths[column] ?? TradesHistoryView.defaultColumnWidths[column] ?? minimumWidth(for: column)
    }

    private func totalMinimumWidth() -> CGFloat {
        activeColumns.reduce(0) { $0 + minimumWidth(for: $1) }
    }

    private func updateAvailableWidth(_ width: CGFloat) {
        let targetWidth = max(width, totalMinimumWidth())
        guard targetWidth.isFinite, targetWidth > 0 else { return }

        if !didRestoreColumnFractions {
            restoreColumnFractionsIfNeeded()
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
        var resolved: [TransactionTableColumn: CGFloat] = [:]

        while !remainingColumns.isEmpty {
            var clampedColumns: [TransactionTableColumn] = []
            for column in remainingColumns {
                let fraction = fractions[column] ?? 0
                guard fraction > 0 else { continue }
                let proposed = remainingFraction > 0 ? remainingWidth * fraction / remainingFraction : 0
                let minWidth = minimumWidth(for: column)
                if proposed < minWidth {
                    resolved[column] = minWidth
                    remainingWidth -= minWidth
                    remainingFraction -= fraction
                    clampedColumns.append(column)
                }
            }
            if clampedColumns.isEmpty {
                for column in remainingColumns {
                    let fraction = fractions[column] ?? 0
                    guard fraction > 0 else { continue }
                    let proposed = remainingFraction > 0 ? remainingWidth * fraction / remainingFraction : 0
                    resolved[column] = max(minimumWidth(for: column), proposed)
                }
                break
            } else {
                remainingColumns.removeAll(where: { clampedColumns.contains($0) })
            }
        }

        resolvedColumnWidths = resolved
    }

    private func normalizedFractions(_ input: [TransactionTableColumn: CGFloat]? = nil) -> [TransactionTableColumn: CGFloat] {
        let source = input ?? columnFractions
        let active = activeColumns
        var result: [TransactionTableColumn: CGFloat] = [:]
        guard !active.isEmpty else {
            TradesHistoryView.columnOrder.forEach { result[$0] = 0 }
            return result
        }
        let total = active.reduce(0) { $0 + max(0, source[$1] ?? 0) }
        if total <= 0 {
            let share = 1.0 / CGFloat(active.count)
            TradesHistoryView.columnOrder.forEach { column in
                result[column] = active.contains(column) ? share : 0
            }
            return result
        }
        TradesHistoryView.columnOrder.forEach { column in
            if active.contains(column) {
                result[column] = max(0.0001, source[column] ?? 0) / total
            } else {
                result[column] = 0
            }
        }
        return result
    }

    private func defaultFractions() -> [TransactionTableColumn: CGFloat] {
        normalizedFractions(TradesHistoryView.initialColumnFractions)
    }

    private func persistColumnFractions() {
        let payload = columnFractions.reduce(into: [String: Double]()) { result, entry in
            guard entry.value.isFinite else { return }
            result[entry.key.rawValue] = Double(entry.value)
        }
        UserDefaults.standard.set(payload, forKey: TradesHistoryView.columnFractionsKey)
    }

    private func persistVisibleColumns() {
        let values = visibleColumns.map { $0.rawValue }
        UserDefaults.standard.set(values, forKey: TradesHistoryView.visibleColumnsKey)
    }

    private func persistFontSize() {
        UserDefaults.standard.set(selectedFontSize.rawValue, forKey: TradesHistoryView.fontSizeKey)
    }

    private func restoreColumnFractionsIfNeeded() {
        guard !didRestoreColumnFractions else { return }
        didRestoreColumnFractions = true
        if let stored = UserDefaults.standard.dictionary(forKey: TradesHistoryView.columnFractionsKey) as? [String: Double] {
            let typed = typedFractions(from: stored)
            if !typed.isEmpty {
                columnFractions = normalizedFractions(typed)
                return
            }
        }
        columnFractions = defaultFractions()
    }

    private func typedFractions(from stored: [String: Double]) -> [TransactionTableColumn: CGFloat] {
        stored.reduce(into: [:]) { result, entry in
            if let column = TransactionTableColumn(rawValue: entry.key), entry.value.isFinite {
                result[column] = CGFloat(entry.value)
            }
        }
    }

    private func recalcColumnWidths() {
        let target = max(availableTableWidth, totalMinimumWidth())
        adjustResolvedWidths(for: target)
    }

    private func leadingHandleTarget(for column: TransactionTableColumn) -> TransactionTableColumn? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        if index == 0 {
            return column
        }
        return columns[index - 1]
    }

    private func isLastActiveColumn(_ column: TransactionTableColumn) -> Bool {
        activeColumns.last == column
    }

    private func resizeHandle(for column: TransactionTableColumn) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: TradesHistoryView.columnHandleWidth + TradesHistoryView.columnHandleHitSlop * 2,
                   height: 28)
            .offset(x: -TradesHistoryView.columnHandleHitSlop)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
#if os(macOS)
                        TradesHistoryView.columnResizeCursor.set()
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
#if os(macOS)
            .onHover { inside in
                if inside {
                    TradesHistoryView.columnResizeCursor.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
#endif
    }

    private func beginDrag(for column: TransactionTableColumn) {
        guard let neighbor = neighborColumn(for: column) else { return }
        let primaryWidth = resolvedColumnWidths[column] ?? (TradesHistoryView.defaultColumnWidths[column] ?? minimumWidth(for: column))
        let neighborWidth = resolvedColumnWidths[neighbor] ?? (TradesHistoryView.defaultColumnWidths[neighbor] ?? minimumWidth(for: neighbor))
        dragContext = ColumnDragContext(primary: column, neighbor: neighbor, primaryBaseWidth: primaryWidth, neighborBaseWidth: neighborWidth)
    }

    private func updateDrag(for column: TransactionTableColumn, translation: CGFloat) {
        guard let context = dragContext, context.primary == column else { return }
        let totalWidth = max(availableTableWidth, 1)
        let minPrimary = minimumWidth(for: context.primary)
        let minNeighbor = minimumWidth(for: context.neighbor)
        let combined = context.primaryBaseWidth + context.neighborBaseWidth

        var newPrimary = context.primaryBaseWidth + translation
        let maxPrimary = combined - minNeighbor
        newPrimary = min(max(newPrimary, minPrimary), maxPrimary)
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

    private func neighborColumn(for column: TransactionTableColumn) -> TransactionTableColumn? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        if index < columns.count - 1 {
            return columns[index + 1]
        }
        return nil
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

    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: selectedFontSize.badgeSize))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: selectedFontSize.baseSize, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func compareAscending(_ lhs: String, _ rhs: String) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result == .orderedSame {
            return lhs < rhs
        }
        return result == .orderedAscending
    }

    private func compareDescending(_ lhs: String, _ rhs: String) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result == .orderedSame {
            return lhs > rhs
        }
        return result == .orderedDescending
    }

    private func ascendingSort(lhs: DatabaseManager.TradeWithLegs, rhs: DatabaseManager.TradeWithLegs) -> Bool {
        switch sortColumn {
        case .tradeId:
            return lhs.tradeId < rhs.tradeId
        case .date:
            if lhs.date == rhs.date {
                return lhs.tradeId < rhs.tradeId
            }
            return lhs.date < rhs.date
        case .type:
            let l = displayType(for: lhs.typeCode)
            let r = displayType(for: rhs.typeCode)
            if l == r {
                return lhs.tradeId < rhs.tradeId
            }
            return compareAscending(l, r)
        case .instrument:
            if lhs.instrumentName == rhs.instrumentName {
                return lhs.tradeId < rhs.tradeId
            }
            return compareAscending(lhs.instrumentName, rhs.instrumentName)
        case .quantity:
            if lhs.quantity == rhs.quantity {
                return lhs.tradeId < rhs.tradeId
            }
            return lhs.quantity < rhs.quantity
        case .instrumentDelta:
            if lhs.instrumentDelta == rhs.instrumentDelta {
                return lhs.tradeId < rhs.tradeId
            }
            return lhs.instrumentDelta < rhs.instrumentDelta
        case .price:
            if lhs.price == rhs.price {
                return lhs.tradeId < rhs.tradeId
            }
            return lhs.price < rhs.price
        case .tradeValue:
            let lv = lhs.quantity * lhs.price
            let rv = rhs.quantity * rhs.price
            if lv == rv {
                return lhs.tradeId < rhs.tradeId
            }
            return lv < rv
        case .cashDelta:
            if lhs.cashDelta == rhs.cashDelta {
                return lhs.tradeId < rhs.tradeId
            }
            return lhs.cashDelta < rhs.cashDelta
        case .currency:
            if lhs.currency == rhs.currency {
                return lhs.tradeId < rhs.tradeId
            }
            return compareAscending(lhs.currency, rhs.currency)
        case .custodyAccount:
            let l = normalized(lhs.custodyAccountName)
            let r = normalized(rhs.custodyAccountName)
            if l == r {
                return lhs.tradeId < rhs.tradeId
            }
            return compareAscending(l, r)
        case .cashAccount:
            let l = normalized(lhs.cashAccountName)
            let r = normalized(rhs.cashAccountName)
            if l == r {
                return lhs.tradeId < rhs.tradeId
            }
            return compareAscending(l, r)
        case .fees:
            if lhs.feesChf == rhs.feesChf {
                return lhs.tradeId < rhs.tradeId
            }
            return lhs.feesChf < rhs.feesChf
        case .commission:
            if lhs.commissionChf == rhs.commissionChf {
                return lhs.tradeId < rhs.tradeId
            }
            return lhs.commissionChf < rhs.commissionChf
        }
    }

    private func descendingSort(lhs: DatabaseManager.TradeWithLegs, rhs: DatabaseManager.TradeWithLegs) -> Bool {
        switch sortColumn {
        case .tradeId:
            return lhs.tradeId > rhs.tradeId
        case .date:
            if lhs.date == rhs.date {
                return lhs.tradeId > rhs.tradeId
            }
            return lhs.date > rhs.date
        case .type:
            let l = displayType(for: lhs.typeCode)
            let r = displayType(for: rhs.typeCode)
            if l == r {
                return lhs.tradeId > rhs.tradeId
            }
            return compareDescending(l, r)
        case .instrument:
            if lhs.instrumentName == rhs.instrumentName {
                return lhs.tradeId > rhs.tradeId
            }
            return compareDescending(lhs.instrumentName, rhs.instrumentName)
        case .quantity:
            if lhs.quantity == rhs.quantity {
                return lhs.tradeId > rhs.tradeId
            }
            return lhs.quantity > rhs.quantity
        case .instrumentDelta:
            if lhs.instrumentDelta == rhs.instrumentDelta {
                return lhs.tradeId > rhs.tradeId
            }
            return lhs.instrumentDelta > rhs.instrumentDelta
        case .price:
            if lhs.price == rhs.price {
                return lhs.tradeId > rhs.tradeId
            }
            return lhs.price > rhs.price
        case .tradeValue:
            let lv = lhs.quantity * lhs.price
            let rv = rhs.quantity * rhs.price
            if lv == rv {
                return lhs.tradeId > rhs.tradeId
            }
            return lv > rv
        case .cashDelta:
            if lhs.cashDelta == rhs.cashDelta {
                return lhs.tradeId > rhs.tradeId
            }
            return lhs.cashDelta > rhs.cashDelta
        case .currency:
            if lhs.currency == rhs.currency {
                return lhs.tradeId > rhs.tradeId
            }
            return compareDescending(lhs.currency, rhs.currency)
        case .custodyAccount:
            let l = normalized(lhs.custodyAccountName)
            let r = normalized(rhs.custodyAccountName)
            if l == r {
                return lhs.tradeId > rhs.tradeId
            }
            return compareDescending(l, r)
        case .cashAccount:
            let l = normalized(lhs.cashAccountName)
            let r = normalized(rhs.cashAccountName)
            if l == r {
                return lhs.tradeId > rhs.tradeId
            }
            return compareDescending(l, r)
        case .fees:
            if lhs.feesChf == rhs.feesChf {
                return lhs.tradeId > rhs.tradeId
            }
            return lhs.feesChf > rhs.feesChf
        case .commission:
            if lhs.commissionChf == rhs.commissionChf {
                return lhs.tradeId > rhs.tradeId
            }
            return lhs.commissionChf > rhs.commissionChf
        }
    }

    private func reverseSelectedTrade() {
        guard let trade = selectedTrade else { return }
        _ = dbManager.rewindTrade(tradeId: trade.tradeId)
        reload()
    }

    private func deleteSelectedTrade() {
        guard let trade = selectedTrade else { return }
        if dbManager.deleteTrade(tradeId: trade.tradeId) {
            selectedTrade = nil
            reload()
        }
    }
}

fileprivate struct ModernTradeRowView: View {
    let trade: DatabaseManager.TradeWithLegs
    let columns: [TransactionTableColumn]
    let fontConfig: TableFontConfig
    let widthFor: (TransactionTableColumn) -> CGFloat
    let isSelected: Bool
    let isLast: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let formatNumber: (Double, Int) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.self) { column in
                columnView(for: column)
            }
        }
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(isSelected ? Color.green.opacity(0.1) : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? Color.green.opacity(0.25) : Color.clear, lineWidth: 1)
                )
        )
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) {
            onTap()
            onEdit()
        }
    }

    @ViewBuilder
    private func columnView(for column: TransactionTableColumn) -> some View {
        switch column {
        case .tradeId:
            Text("#\(trade.tradeId)")
                .foregroundColor(.secondary)
                .font(.system(size: fontConfig.secondarySize))
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.tradeId), alignment: .leading)
        case .date:
            Text(DateFormatter.iso8601DateOnly.string(from: trade.date))
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.date), alignment: .leading)
        case .type:
            Text(trade.typeCode.capitalized)
                .font(.system(size: fontConfig.primarySize, weight: .medium))
                .foregroundColor(.primary)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.type), alignment: .leading)
        case .instrument:
            Text(trade.instrumentName)
                .font(.system(size: fontConfig.primarySize, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.instrument), alignment: .leading)
        case .quantity:
            Text(formatNumber(trade.quantity, 4))
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.quantity), alignment: .trailing)
        case .instrumentDelta:
            let value = trade.instrumentDelta
            Text(formatNumber(value, 4))
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(value >= 0 ? .green : .red)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.instrumentDelta), alignment: .trailing)
        case .price:
            Text(formatNumber(trade.price, 4))
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.price), alignment: .trailing)
        case .tradeValue:
            Text(formatNumber(trade.quantity * trade.price, 2))
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.tradeValue), alignment: .trailing)
        case .cashDelta:
            let value = trade.cashDelta
            Text("\(formatNumber(value, 2)) \(trade.currency)")
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(value >= 0 ? .green : .red)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.cashDelta), alignment: .trailing)
        case .currency:
            Text(trade.currency)
                .font(.system(size: fontConfig.badgeSize, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12))
                .clipShape(Capsule())
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.currency), alignment: .leading)
        case .custodyAccount:
            let name = trade.custodyAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(name.isEmpty ? "—" : name)
                .font(.system(size: fontConfig.secondarySize))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.custodyAccount), alignment: .leading)
        case .cashAccount:
            let name = trade.cashAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(name.isEmpty ? "—" : name)
                .font(.system(size: fontConfig.secondarySize))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.cashAccount), alignment: .leading)
        case .fees:
            Text(formatNumber(trade.feesChf, 2))
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.fees), alignment: .trailing)
        case .commission:
            Text(formatNumber(trade.commissionChf, 2))
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.leading, TradesHistoryView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.commission), alignment: .trailing)
        }
    }
}
