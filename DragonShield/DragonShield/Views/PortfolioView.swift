import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#endif

fileprivate struct TableFontConfig {
    let nameSize: CGFloat
    let secondarySize: CGFloat
    let headerSize: CGFloat
    let badgeSize: CGFloat
}

private enum InstrumentTableColumn: String, CaseIterable, Codable {
    case name, type, currency, symbol, valor, isin, notes

    var title: String {
        switch self {
        case .name: return "Name"
        case .type: return "Type"
        case .currency: return "$£"
        case .symbol: return "Ticker"
        case .valor: return "Valor"
        case .isin: return "ISIN"
        case .notes: return ""
        }
    }
}

// MARK: - Main Portfolio View
struct PortfolioView: View {
    @EnvironmentObject var assetManager: AssetManager
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var showAddInstrumentSheet = false
    @State private var showEditInstrumentSheet = false
    @State private var selectedAsset: DragonAsset? = nil
    @State private var showingDeleteAlert = false
    @State private var assetToDelete: DragonAsset? = nil
    @State private var searchText = ""
    // Filtering & Sorting
    @State private var typeFilters: Set<String> = []
    @State private var currencyFilters: Set<String> = []
    @State private var sortColumn: SortColumn = .name
    @State private var sortAscending: Bool = true
    @State private var showUnusedReport = false
    @State private var columnFractions: [InstrumentTableColumn: CGFloat]
    @State private var resolvedColumnWidths: [InstrumentTableColumn: CGFloat]
    @State private var visibleColumns: Set<InstrumentTableColumn>
    @State private var selectedFontSize: TableFontSize
    @State private var didRestoreColumnFractions = false
    @State private var availableTableWidth: CGFloat = 0
    @State private var dragContext: ColumnDragContext? = nil
    @State private var hasHydratedPreferences = false
    @State private var isHydratingPreferences = false
    private static let legacyColumnFractionsKey = "PortfolioView.instrumentColumnFractions.v2"
    private static let visibleColumnsKey = "PortfolioView.visibleColumns.v1"
    private static let legacyFontSizeKey = "PortfolioView.tableFontSize.v1"
    private let headerBackground = Color(red: 230.0/255.0, green: 242.0/255.0, blue: 1.0)

    init() {
        let defaults = PortfolioView.initialColumnFractions
        _columnFractions = State(initialValue: defaults)
        _resolvedColumnWidths = State(initialValue: PortfolioView.defaultColumnWidths)
        let storedVisible = UserDefaults.standard.array(forKey: PortfolioView.visibleColumnsKey) as? [String]
        if let storedVisible {
            let set = Set(storedVisible.compactMap(InstrumentTableColumn.init(rawValue:)))
            _visibleColumns = State(initialValue: set.isEmpty ? PortfolioView.defaultVisibleColumns : set)
        } else {
            _visibleColumns = State(initialValue: PortfolioView.defaultVisibleColumns)
        }
        _selectedFontSize = State(initialValue: .medium)
    }

    enum SortColumn {
        case name, type, currency, symbol, valor, isin
    }

    private static let columnOrder: [InstrumentTableColumn] = [.name, .type, .currency, .symbol, .valor, .isin, .notes]
    private static let defaultVisibleColumns: Set<InstrumentTableColumn> = Set(columnOrder)

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

        var secondarySize: CGFloat { baseSize - 1 }
        var badgeSize: CGFloat { baseSize - 2 }
        var headerSize: CGFloat { baseSize - 1 }
    }

    // Animation states
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0
    
    // Filtered assets based on search and column filters
    var filteredAssets: [DragonAsset] {
        var result = assetManager.assets
        if !searchText.isEmpty {
            result = result.filter { asset in
                asset.name.localizedCaseInsensitiveContains(searchText) ||
                asset.type.localizedCaseInsensitiveContains(searchText) ||
                asset.currency.localizedCaseInsensitiveContains(searchText) ||
                asset.tickerSymbol?.localizedCaseInsensitiveContains(searchText) == true ||
                asset.isin?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        if !typeFilters.isEmpty {
            result = result.filter { typeFilters.contains($0.type) }
        }
        if !currencyFilters.isEmpty {
            result = result.filter { currencyFilters.contains($0.currency) }
        }
        return result
    }

    private var activeColumns: [InstrumentTableColumn] {
        let set = visibleColumns.intersection(PortfolioView.columnOrder)
        let ordered = PortfolioView.columnOrder.filter { set.contains($0) }
        return ordered.isEmpty ? [.name] : ordered
    }

    private var fontConfig: TableFontConfig {
        TableFontConfig(
            nameSize: selectedFontSize.baseSize,
            secondarySize: max(11, selectedFontSize.secondarySize),
            headerSize: selectedFontSize.headerSize,
            badgeSize: max(10, selectedFontSize.badgeSize)
        )
    }

    // Sorted assets based on selected column
    var sortedAssets: [DragonAsset] {
        filteredAssets.sorted { a, b in
            switch sortColumn {
            case .name:
                return sortAscending ? a.name < b.name : a.name > b.name
            case .type:
                return sortAscending ? a.type < b.type : a.type > b.type
            case .currency:
                return sortAscending ? a.currency < b.currency : a.currency > b.currency
            case .symbol:
                return sortAscending ? (a.tickerSymbol ?? "") < (b.tickerSymbol ?? "") : (a.tickerSymbol ?? "") > (b.tickerSymbol ?? "")
            case .valor:
                return sortAscending ? (a.valorNr ?? "") < (b.valorNr ?? "") : (a.valorNr ?? "") > (b.valorNr ?? "")
            case .isin:
                return sortAscending ? (a.isin ?? "") < (b.isin ?? "") : (a.isin ?? "") > (b.isin ?? "")
            }
        }
    }

    private struct ColumnDragContext {
        let primary: InstrumentTableColumn
        let neighbor: InstrumentTableColumn
        let primaryBaseWidth: CGFloat
        let neighborBaseWidth: CGFloat
    }

    private struct TableWidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    private static let defaultColumnWidths: [InstrumentTableColumn: CGFloat] = [
        .name: 280,
        .type: 140,
        .currency: 90,
        .symbol: 120,
        .valor: 110,
        .isin: 160,
        .notes: 40
    ]

    private static let minimumColumnWidths: [InstrumentTableColumn: CGFloat] = [
        .name: 200,
        .type: 110,
        .currency: 80,
        .symbol: 90,
        .valor: 90,
        .isin: 140,
        .notes: 40
    ]

    private static let initialColumnFractions: [InstrumentTableColumn: CGFloat] = {
        let total = defaultColumnWidths.values.reduce(0, +)
        guard total > 0 else {
            let fallback = 1.0 / CGFloat(InstrumentTableColumn.allCases.count)
            return InstrumentTableColumn.allCases.reduce(into: [:]) { $0[$1] = fallback }
        }
        return InstrumentTableColumn.allCases.reduce(into: [:]) { result, column in
            let width = defaultColumnWidths[column] ?? 0
            result[column] = max(0.0001, width / total)
        }
    }()

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

    fileprivate static let columnHandleWidth: CGFloat = 10
    fileprivate static let columnTextInset: CGFloat = 12
    private static let columnHandleHitSlop: CGFloat = 8

    private func minimumWidth(for column: InstrumentTableColumn) -> CGFloat {
        Self.minimumColumnWidths[column] ?? 60
    }

    private func width(for column: InstrumentTableColumn) -> CGFloat {
        guard visibleColumns.contains(column) else { return 0 }
        return resolvedColumnWidths[column] ?? Self.defaultColumnWidths[column] ?? minimumWidth(for: column)
    }

    private func totalMinimumWidth() -> CGFloat {
        activeColumns.reduce(0) { $0 + minimumWidth(for: $1) }
    }

    private func persistColumnFractions() {
        guard !isHydratingPreferences else {
            print("ℹ️ [instruments] Skipping persistColumnFractions during hydration")
            return
        }
        isHydratingPreferences = true
        let payload = columnFractions.reduce(into: [String: Double]()) { result, entry in
            guard entry.value.isFinite else { return }
            result[entry.key.rawValue] = Double(entry.value)
        }
        print("💾 [instruments] Persisting column fractions: \(payload)")
        dbManager.setTableColumnFractions(payload, for: .instruments)
        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    private func restoreColumnFractions() {
        if restoreFromStoredColumnFractions(dbManager.tableColumnFractions(for: .instruments)) {
            print("📥 [instruments] Applied stored column fractions from configuration table")
            return
        }

        if let legacy = dbManager.legacyTableColumnFractions(for: .instruments) {
            let typed = typedFractions(from: legacy)
            guard !typed.isEmpty else {
                dbManager.clearLegacyTableColumnFractions(for: .instruments)
                return
            }
            columnFractions = normalizedFractions(typed)
            dbManager.setTableColumnFractions(legacy, for: .instruments)
            dbManager.clearLegacyTableColumnFractions(for: .instruments)
            print("♻️ [instruments] Migrated legacy column fractions to configuration table")
            return
        }

        columnFractions = defaultFractions()
        print("ℹ️ [instruments] Using default column fractions")
    }

    @discardableResult
    private func restoreFromStoredColumnFractions(_ stored: [String: Double]) -> Bool {
        let restored = typedFractions(from: stored)
        guard !restored.isEmpty else {
            print("⚠️ [instruments] Stored column fractions empty or invalid")
            return false
        }
        columnFractions = normalizedFractions(restored)
        print("🎯 [instruments] Restored column fractions: \(restored)")
        return true
    }

    private func typedFractions(from raw: [String: Double]) -> [InstrumentTableColumn: CGFloat] {
        raw.reduce(into: [InstrumentTableColumn: CGFloat]()) { result, entry in
            guard let column = InstrumentTableColumn(rawValue: entry.key), entry.value.isFinite else { return }
            let fraction = max(0, entry.value)
            if fraction > 0 { result[column] = CGFloat(fraction) }
        }
    }

    private func hydratePreferencesIfNeeded() {
        guard !hasHydratedPreferences else { return }
        hasHydratedPreferences = true
        isHydratingPreferences = true

        migrateLegacyFontIfNeeded()

        let storedFont = dbManager.tableFontSize(for: .instruments)
        if let storedSize = TableFontSize(rawValue: storedFont) {
            print("📥 [instruments] Applying stored font size: \(storedSize.rawValue)")
            selectedFontSize = storedSize
        }

        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    private func migrateLegacyFontIfNeeded() {
        guard let legacy = dbManager.legacyTableFontSize(for: .instruments) else { return }
        if dbManager.tableFontSize(for: .instruments) != legacy {
            print("♻️ [instruments] Migrating legacy font size \(legacy) to configuration table")
            dbManager.setTableFontSize(legacy, for: .instruments)
        }
        dbManager.clearLegacyTableFontSize(for: .instruments)
    }

    private func defaultFractions() -> [InstrumentTableColumn: CGFloat] {
        normalizedFractions(PortfolioView.initialColumnFractions)
    }

    private func normalizedFractions(_ input: [InstrumentTableColumn: CGFloat]? = nil) -> [InstrumentTableColumn: CGFloat] {
        let source = input ?? columnFractions
        let active = activeColumns
        var result: [InstrumentTableColumn: CGFloat] = [:]
        guard !active.isEmpty else {
            for column in PortfolioView.columnOrder { result[column] = 0 }
            return result
        }
        let total = active.reduce(0) { $0 + max(0, source[$1] ?? 0) }
        if total <= 0 {
            let share = 1.0 / CGFloat(active.count)
            for column in PortfolioView.columnOrder {
                result[column] = active.contains(column) ? share : 0
            }
            return result
        }
        for column in PortfolioView.columnOrder {
            if active.contains(column) {
                result[column] = max(0.0001, source[column] ?? 0) / total
            } else {
                result[column] = 0
            }
        }
        return result
    }

    private func instrumentColumn(for sortColumn: SortColumn) -> InstrumentTableColumn {
        switch sortColumn {
        case .name: return .name
        case .type: return .type
        case .currency: return .currency
        case .symbol: return .symbol
        case .valor: return .valor
        case .isin: return .isin
        }
    }

    private func sortOption(for column: InstrumentTableColumn) -> SortColumn? {
        switch column {
        case .name: return .name
        case .type: return .type
        case .currency: return .currency
        case .symbol: return .symbol
        case .valor: return .valor
        case .isin: return .isin
        case .notes: return nil
        }
    }

    private func filterBinding(for column: InstrumentTableColumn) -> Binding<Set<String>>? {
        switch column {
        case .type:
            return $typeFilters
        case .currency:
            return $currencyFilters
        default:
            return nil
        }
    }

    private func filterValues(for column: InstrumentTableColumn) -> [String] {
        switch column {
        case .type:
            return Array(Set(assetManager.assets.map { $0.type })).sorted()
        case .currency:
            return Array(Set(assetManager.assets.map { $0.currency })).sorted()
        default:
            return []
        }
    }

    private func isLastActiveColumn(_ column: InstrumentTableColumn) -> Bool {
        activeColumns.last == column
    }

    private func leadingHandleTarget(for column: InstrumentTableColumn) -> InstrumentTableColumn? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        if index == 0 {
            return column
        }
        return columns[index - 1]
    }

    private func resizeHandle(for column: InstrumentTableColumn) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: Self.columnHandleWidth + Self.columnHandleHitSlop * 2,
                   height: 28)
            .offset(x: -Self.columnHandleHitSlop)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
#if os(macOS)
                        PortfolioView.columnResizeCursor.set()
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
                    PortfolioView.columnResizeCursor.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
#endif
    }

    private func updateAvailableWidth(_ width: CGFloat) {
        let targetWidth = max(width, totalMinimumWidth())
        guard targetWidth.isFinite, targetWidth > 0 else { return }
        print("📏 [instruments] updateAvailableWidth(width=\(width), target=\(targetWidth))")

        if !didRestoreColumnFractions {
            restoreColumnFractions()
            didRestoreColumnFractions = true
        }

        if abs(availableTableWidth - targetWidth) < 0.5 { return }

        availableTableWidth = targetWidth
        print("📏 [instruments] Stored availableTableWidth=\(availableTableWidth)")
        adjustResolvedWidths(for: targetWidth)
        persistColumnFractions()
    }

    private func adjustResolvedWidths(for availableWidth: CGFloat) {
        guard availableWidth > 0 else { return }
        let fractions = normalizedFractions()
        var remainingColumns = activeColumns
        var remainingWidth = availableWidth
        var remainingFraction = remainingColumns.reduce(0) { $0 + (fractions[$1] ?? 0) }
        var resolved: [InstrumentTableColumn: CGFloat] = [:]

        while !remainingColumns.isEmpty {
            var clampedColumns: [InstrumentTableColumn] = []
            for column in remainingColumns {
                let fraction = fractions[column] ?? 0
                guard fraction > 0 else { continue }
                let proposed = remainingFraction > 0 ? remainingWidth * fraction / remainingFraction : 0
                let minWidth = minimumWidth(for: column)
                if proposed < minWidth - 0.5 {
                    resolved[column] = minWidth
                    remainingWidth = max(0, remainingWidth - minWidth)
                    remainingFraction -= fraction
                    clampedColumns.append(column)
                }
            }
            if clampedColumns.isEmpty { break }
            remainingColumns.removeAll { clampedColumns.contains($0) }
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
        for column in PortfolioView.columnOrder {
            if !visibleColumns.contains(column) {
                resolved[column] = 0
            } else if resolved[column] == nil {
                resolved[column] = minimumWidth(for: column)
            }
        }
        resolvedColumnWidths = resolved
        print("📐 [instruments] Resolved column widths: \(resolvedColumnWidths)")

        var updatedFractions: [InstrumentTableColumn: CGFloat] = [:]
        let safeWidth = max(availableWidth, 1)
        for column in PortfolioView.columnOrder {
            let widthValue = resolved[column] ?? 0
            updatedFractions[column] = max(0.0001, widthValue / safeWidth)
        }
        columnFractions = normalizedFractions(updatedFractions)
    }

    private func persistVisibleColumns() {
        let ordered = PortfolioView.columnOrder.filter { visibleColumns.contains($0) }
        UserDefaults.standard.set(ordered.map { $0.rawValue }, forKey: PortfolioView.visibleColumnsKey)
    }

    private func persistFontSize() {
        guard !isHydratingPreferences else {
            print("ℹ️ [instruments] Skipping persistFontSize during hydration")
            return
        }
        isHydratingPreferences = true
        print("💾 [instruments] Persisting font size: \(selectedFontSize.rawValue)")
        dbManager.setTableFontSize(selectedFontSize.rawValue, for: .instruments)
        DispatchQueue.main.async { isHydratingPreferences = false }
    }

    private func ensureValidSortColumn() {
        let currentColumn = instrumentColumn(for: sortColumn)
        if !visibleColumns.contains(currentColumn) {
            if let fallbackSort = activeColumns.compactMap(sortOption(for:)).first {
                sortColumn = fallbackSort
            } else {
                sortColumn = .name
            }
        }
    }

    private func toggleColumn(_ column: InstrumentTableColumn) {
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
        visibleColumns = PortfolioView.defaultVisibleColumns
        persistVisibleColumns()
        ensureValidSortColumn()
        recalcColumnWidths()
    }

    private func resetTablePreferences() {
        visibleColumns = PortfolioView.defaultVisibleColumns
        selectedFontSize = .medium
        persistVisibleColumns()
        persistFontSize()
        ensureValidSortColumn()
        recalcColumnWidths()
    }

    private func recalcColumnWidths() {
        let width = max(availableTableWidth, totalMinimumWidth())
        guard availableTableWidth > 0 else {
            print("ℹ️ [instruments] Skipping recalcColumnWidths — available width not ready")
            return
        }
        print("🔧 [instruments] Recalculating column layout with availableWidth=\(availableTableWidth)")
        adjustResolvedWidths(for: width)
        persistColumnFractions()
    }

    private func balanceResolvedWidths(_ resolved: inout [InstrumentTableColumn: CGFloat], targetWidth: CGFloat) {
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
                var columnsAtMinimum: [InstrumentTableColumn] = []
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

    private func beginDrag(for column: InstrumentTableColumn) {
        guard let neighbor = neighborColumn(for: column) else { return }
        let primaryWidth = resolvedColumnWidths[column] ?? (Self.defaultColumnWidths[column] ?? minimumWidth(for: column))
        let neighborWidth = resolvedColumnWidths[neighbor] ?? (Self.defaultColumnWidths[neighbor] ?? minimumWidth(for: neighbor))
        dragContext = ColumnDragContext(primary: column, neighbor: neighbor, primaryBaseWidth: primaryWidth, neighborBaseWidth: neighborWidth)
    }

    private func updateDrag(for column: InstrumentTableColumn, translation: CGFloat) {
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

    private func neighborColumn(for column: InstrumentTableColumn) -> InstrumentTableColumn? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        if index < columns.count - 1 {
            return columns[index + 1]
        } else if index > 0 {
            return columns[index - 1]
        }
        return nil
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
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
            
            // Subtle animated background elements
            InstrumentParticleBackground()
            
            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                instrumentsContent
                modernActionBar
            }
        }
        .onAppear {
            hydratePreferencesIfNeeded()
            assetManager.loadAssets()
            animateEntrance()
            if !didRestoreColumnFractions {
                restoreColumnFractions()
                didRestoreColumnFractions = true
                recalcColumnWidths()
            }
        }
        .onChange(of: selectedFontSize) { _, _ in
            persistFontSize()
        }
        .onReceive(dbManager.$instrumentsTableFontSize) { newValue in
            guard !isHydratingPreferences, let size = TableFontSize(rawValue: newValue), size != selectedFontSize else { return }
            isHydratingPreferences = true
            print("📥 [instruments] Received font size update from configuration: \(newValue)")
            selectedFontSize = size
            DispatchQueue.main.async { isHydratingPreferences = false }
        }
        .onReceive(dbManager.$instrumentsTableColumnFractions) { newValue in
            guard !isHydratingPreferences else { return }
            isHydratingPreferences = true
            print("📥 [instruments] Received column fractions from configuration: \(newValue)")
            let restored = restoreFromStoredColumnFractions(newValue)
            if restored {
                didRestoreColumnFractions = true
                recalcColumnWidths()
            }
            DispatchQueue.main.async { isHydratingPreferences = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshPortfolio"))) { _ in
            assetManager.loadAssets()
        }
        .sheet(isPresented: $showAddInstrumentSheet) {
            AddInstrumentView()
                .onDisappear {
                    assetManager.loadAssets()
                }
        }
        .sheet(isPresented: $showEditInstrumentSheet) {
            if let asset = selectedAsset {
                InstrumentEditView(instrumentId: asset.id)
                    .onDisappear {
                        assetManager.loadAssets()
                        selectedAsset = nil
                    }
            }
        }
        .sheet(isPresented: $showUnusedReport) {
            UnusedInstrumentsReportView {
                showUnusedReport = false
            }
        }

        .alert("Delete Instrument", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let asset = assetToDelete {
                    confirmDelete(asset)
                }
            }
        } message: {
            if let asset = assetToDelete {
                Text("Are you sure you want to delete '\(asset.name)'?\n\nThis action cannot be undone.")
            }
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    Text("Instruments")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                Text("Manage your financial instruments")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Quick stats
            HStack(spacing: 16) {
                modernStatCard(
                    title: "Total",
                    value: "\(assetManager.assets.count)",
                    icon: "number.circle.fill",
                    color: .blue
                )
                
                modernStatCard(
                    title: "Types",
                    value: "\(Set(assetManager.assets.map(\.type)).count)",
                    icon: "folder.circle.fill",
                    color: .purple
                )
                
                modernStatCard(
                    title: "Currencies",
                    value: "\(Set(assetManager.assets.map(\.currency)).count)",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Search and Stats
    private var searchAndStats: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search instruments...", text: $searchText)
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
            
            // Results indicator
            if !searchText.isEmpty || !typeFilters.isEmpty || !currencyFilters.isEmpty {
                HStack {
                    Text("Found \(sortedAssets.count) of \(assetManager.assets.count) instruments")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                if !typeFilters.isEmpty || !currencyFilters.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(typeFilters), id: \.self) { val in
                            filterChip(text: val) { typeFilters.remove(val) }
                        }
                        ForEach(Array(currencyFilters), id: \.self) { val in
                            filterChip(text: val) { currencyFilters.remove(val) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Instruments Content
    private var instrumentsContent: some View {
        VStack(spacing: 12) {
            tableControls
            if sortedAssets.isEmpty {
                emptyStateView
            } else {
                instrumentsTable
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
            if visibleColumns != PortfolioView.defaultVisibleColumns || selectedFontSize != .medium {
                Button("Reset View", action: resetTablePreferences)
                    .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 4)
        .font(.system(size: 12))
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(PortfolioView.columnOrder, id: \.self) { column in
                let isVisible = visibleColumns.contains(column)
                Button {
                    toggleColumn(column)
                } label: {
                    Label(column.title, systemImage: isVisible ? "checkmark" : "")
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
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "briefcase" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No instruments yet" : "No matching instruments")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text(searchText.isEmpty ?
                         "Start building your portfolio by adding your first instrument" :
                         "Try adjusting your search terms")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                if searchText.isEmpty {
                    Button { showAddInstrumentSheet = true } label: {
                        Label("Add Instrument", systemImage: "plus")
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
    
    // MARK: - Instruments Table
    private var instrumentsTable: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            let targetWidth = max(availableWidth, totalMinimumWidth())

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    modernTableHeader
                    instrumentsTableRows
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

    private var instrumentsTableRows: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedAssets) { asset in
                    ModernAssetRowView(
                        asset: asset,
                        columns: activeColumns,
                        fontConfig: fontConfig,
                        isSelected: selectedAsset?.id == asset.id,
                        onTap: {
                            selectedAsset = asset
                        },
                        onEdit: {
                            selectedAsset = asset
                            showEditInstrumentSheet = true
                        },
                        widthFor: { width(for: $0) }
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
    
    // MARK: - Modern Table Header
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
                .fill(headerBackground)
                .overlay(Rectangle().stroke(Color.blue.opacity(0.15), lineWidth: 1))
        )
        .frame(width: max(availableTableWidth, totalMinimumWidth()), alignment: .leading)
    }

    private func headerCell(for column: InstrumentTableColumn) -> some View {
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

                if column == .notes {
                    Image(systemName: "note.text")
                        .font(.system(size: fontConfig.headerSize, weight: .semibold))
                        .foregroundColor(.black)
                        .help("Notes")
                }
            }
            .padding(.leading, Self.columnTextInset + (leadingTarget == nil ? 0 : Self.columnHandleWidth))
            .padding(.trailing, isLast ? Self.columnHandleWidth + 8 : 8)
        }
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
    
    // MARK: - Modern Action Bar
    private var modernActionBar: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 16) {
                // Primary action
                Button { showAddInstrumentSheet = true } label: {
                    Label("Add Instrument", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)

                Button {
                    showUnusedReport = true
                } label: {
                    Label("Unused Instruments", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .accessibilityLabel("Open unused instruments report")

                // Secondary actions
                if selectedAsset != nil {
                    Button {
                        showEditInstrumentSheet = true
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
                    
                    Button {
                        if let asset = selectedAsset {
                            assetToDelete = asset
                            showingDeleteAlert = true
                        }
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
                }
                
                Spacer()
                
                // Selection indicator
                if let asset = selectedAsset {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Selected: \(asset.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
        .opacity(buttonsOpacity)
    }
    
    // MARK: - Helper Views
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
    
    // MARK: - Animations
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
    
    // MARK: - Functions
    func confirmDelete(_ asset: DragonAsset) {
        let dbManager = DatabaseManager()
        let success = dbManager.deleteInstrument(id: asset.id)

        if success {
            assetManager.loadAssets()
            selectedAsset = nil
            assetToDelete = nil
        }
    }
}

// MARK: - Modern Asset Row
fileprivate struct ModernAssetRowView: View {
    let asset: DragonAsset
    fileprivate let columns: [InstrumentTableColumn]
    fileprivate let fontConfig: TableFontConfig
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    fileprivate let widthFor: (InstrumentTableColumn) -> CGFloat

    fileprivate init(
        asset: DragonAsset,
        columns: [InstrumentTableColumn],
        fontConfig: TableFontConfig,
        isSelected: Bool,
        onTap: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        widthFor: @escaping (InstrumentTableColumn) -> CGFloat
    ) {
        self.asset = asset
        self.columns = columns
        self.fontConfig = fontConfig
        self.isSelected = isSelected
        self.onTap = onTap
        self.onEdit = onEdit
        self.widthFor = widthFor
    }

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
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) { onEdit() }
        .contextMenu {
            Button("Edit Instrument", action: onEdit)
            Button("Select Instrument", action: onTap)
            Divider()
#if os(macOS)
            Button("Copy Name") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(asset.name, forType: .string)
            }
            if let isin = asset.isin {
                Button("Copy ISIN") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(isin, forType: .string)
                }
            }
#endif
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func columnView(for column: InstrumentTableColumn) -> some View {
        switch column {
        case .name:
            HStack(spacing: 6) {
                Text(asset.name)
                    .font(.system(size: fontConfig.nameSize, weight: .medium))
                    .foregroundColor(asset.isDeleted ? .secondary : .primary)
                if asset.isDeleted {
                    Text("Soft-deleted")
                        .font(.system(size: max(10, fontConfig.secondarySize - 1), weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                        .help("This instrument is soft-deleted. Double-click to open and restore.")
                }
            }
            .padding(.leading, PortfolioView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.name), alignment: .leading)
            .onTapGesture(count: 2) {
                onTap()
                onEdit()
            }
        case .type:
            Text(asset.type)
                .font(.system(size: fontConfig.secondarySize))
                .foregroundColor(.secondary)
                .padding(.leading, PortfolioView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.type), alignment: .leading)
        case .currency:
            HStack {
                Text(asset.currency)
                    .font(.system(size: fontConfig.badgeSize, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.leading, PortfolioView.columnTextInset)
            .padding(.trailing, 8)
            .frame(width: widthFor(.currency), alignment: .leading)
        case .symbol:
            Text(asset.tickerSymbol ?? "--")
                .font(.system(size: fontConfig.secondarySize, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.leading, PortfolioView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.symbol), alignment: .leading)
        case .valor:
            Text(asset.valorNr ?? "--")
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.leading, PortfolioView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.valor), alignment: .leading)
        case .isin:
            Text(asset.isin ?? "--")
                .font(.system(size: fontConfig.secondarySize, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.leading, PortfolioView.columnTextInset)
                .padding(.trailing, 8)
                .frame(width: widthFor(.isin), alignment: .leading)
        case .notes:
            NotesIconView(instrumentId: asset.id, instrumentName: asset.name, instrumentCode: asset.tickerSymbol ?? "")
                .frame(width: widthFor(.notes), alignment: .center)
        }
    }
}

struct NotesIconView: View {
    let instrumentId: Int
    let instrumentName: String
    let instrumentCode: String

    @State private var updatesCount: Int?
    @State private var mentionsCount: Int?
    @State private var showModal = false
    @State private var initialTab: InstrumentNotesView.Tab = .updates

    private static var cache: [Int: (Int, Int)] = [:]

    var body: some View {
        Button(action: openDefault) {
            Image(systemName: "note.text")
                .font(.system(size: 14))
                .foregroundColor(hasNotes ? .accentColor : .gray)
                .opacity(hasNotes ? 1 : 0.3)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Open notes for \(instrumentName)")
        .help(tooltip)
        .contextMenu {
            Button("Open General Notes") { openGeneral() }
            Button("Open Updates") { openUpdates() }
            Button("Open Mentions") { openMentions() }
        }
        .sheet(isPresented: $showModal) {
            InstrumentNotesView(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName, initialTab: initialTab, initialThemeId: nil, onClose: {
                showModal = false
                NotesIconView.invalidateCache(instrumentId: instrumentId)
                loadCounts()
            })
                .environmentObject(DatabaseManager())
        }
        .onAppear { loadCounts() }
    }

    private var hasNotes: Bool {
        (updatesCount ?? 0) > 0 || (mentionsCount ?? 0) > 0
    }

    private var tooltip: String {
        if let u = updatesCount, let m = mentionsCount {
            return (u == 0 && m == 0) ? "Open notes (no notes yet)" : "Updates: \(u) • Mentions: \(m)"
        } else {
            return "Open notes"
        }
    }

    private func openDefault() {
        let last = UserDefaults.standard.string(forKey: "instrumentNotesLastTab")
        switch last {
        case "general": initialTab = .general
        case "mentions": initialTab = .mentions
        default: initialTab = .updates
        }
        showModal = true
    }

    private func openGeneral() {
        initialTab = .general
        showModal = true
    }

    private func openUpdates() {
        initialTab = .updates
        showModal = true
    }

    private func openMentions() {
        initialTab = .mentions
        showModal = true
    }

    private func loadCounts() {
        if let cached = NotesIconView.cache[instrumentId] {
            updatesCount = cached.0
            mentionsCount = cached.1
            return
        }
        DispatchQueue.global().async {
            let db = DatabaseManager()
            let summary = db.instrumentNotesSummary(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName)
            DispatchQueue.main.async {
                updatesCount = summary.updates
                mentionsCount = summary.mentions
                NotesIconView.cache[instrumentId] = (summary.updates, summary.mentions)
            }
        }
    }

    static func invalidateCache(instrumentId: Int) {
        cache.removeValue(forKey: instrumentId)
    }
}

// MARK: - Background Particles
struct InstrumentParticleBackground: View {
    @State private var particles: [InstrumentParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.blue.opacity(0.03))
                    .frame(width: particles[index].size, height: particles[index].size)
                    .position(particles[index].position)
                    .opacity(particles[index].opacity)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<20).map { _ in
            InstrumentParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1200),
                    y: CGFloat.random(in: 0...800)
                ),
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.1...0.2)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 35).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 1000
                particles[index].opacity = Double.random(in: 0.05...0.15)
            }
        }
    }
}

struct InstrumentParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

// Note: ScaleButtonStyle is defined in AddInstrumentView.swift

// MARK: - Preview
struct PortfolioView_Previews: PreviewProvider {
    static var previews: some View {
        PortfolioView()
            .environmentObject(AssetManager())
    }
}
