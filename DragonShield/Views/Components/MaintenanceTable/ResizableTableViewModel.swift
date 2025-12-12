import Combine
import SwiftUI

final class ResizableTableViewModel<Column: MaintenanceTableColumn>: ObservableObject {
    @Published private(set) var visibleColumns: Set<Column>
    @Published var selectedFontSize: MaintenanceTableFontSize {
        didSet {
            guard selectedFontSize != oldValue else { return }
            persistFontSize()
        }
    }

    @Published private(set) var columnFractions: [Column: CGFloat]
    @Published private(set) var resolvedColumnWidths: [Column: CGFloat]
    @Published var availableTableWidth: CGFloat = 0
    @Published private(set) var minimumWidthOverrides: [Column: CGFloat] = [:]

    let configuration: MaintenanceTableConfiguration<Column>

    private var cancellables: Set<AnyCancellable> = []
    private weak var dbManager: DatabaseManager?
    private var isHydratingPreferences = false
    private var hasHydratedPreferences = false
    private var dragContext: ColumnDragContext?
    private var hasAppliedHydratedLayout = false
    private let minimumWidthsDefaultsKey: String?

    private struct ColumnDragContext {
        let primary: Column
        let neighbor: Column
        let primaryBaseWidth: CGFloat
        let neighborBaseWidth: CGFloat
    }

    init(configuration: MaintenanceTableConfiguration<Column>) {
        self.configuration = configuration
        var initialVisible = ResizableTableViewModel.initialVisibleColumns(configuration)
        ResizableTableViewModel.enforceRequiredColumns(configuration, on: &initialVisible)
        visibleColumns = initialVisible
        selectedFontSize = .medium
        columnFractions = ResizableTableViewModel.initialFractions(configuration)
        resolvedColumnWidths = configuration.defaultColumnWidths
        minimumWidthsDefaultsKey = configuration.minimumWidthsDefaultsKey ?? (configuration.visibleColumnsDefaultsKey + ".minWidths")
        minimumWidthOverrides = ResizableTableViewModel.loadMinimumWidthOverrides(configuration: configuration, defaultsKey: minimumWidthsDefaultsKey)
    }

    func connect(to manager: DatabaseManager) {
        if dbManager === manager { return }
        dbManager = manager
        cancellables.removeAll()
        hasAppliedHydratedLayout = false
        debugLog("Connecting to manager; hasHydrated=\(hasHydratedPreferences)")
        observe(manager: manager)
        hydratePreferencesIfNeeded()
    }

    var fontConfig: MaintenanceTableFontConfig {
        configuration.fontConfigBuilder(selectedFontSize)
    }

    var activeColumns: [Column] {
        let order = configuration.columnOrder
        let filtered = order.filter { visibleColumns.contains($0) }
        if filtered.isEmpty, let first = order.first {
            return [first]
        }
        return filtered
    }

    func width(for column: Column) -> CGFloat {
        guard visibleColumns.contains(column) else { return 0 }
        if let width = resolvedColumnWidths[column], width > 0 {
            return width
        }
        if let fallback = configuration.defaultColumnWidths[column] {
            return fallback
        }
        return minimumWidth(for: column)
    }

    func minimumWidth(for column: Column) -> CGFloat {
        if let override = minimumWidthOverrides[column], override > 0 {
            return override
        }
        return configuration.minimumColumnWidths[column] ?? 80
    }

    var totalMinimumWidth: CGFloat {
        activeColumns.reduce(0) { $0 + minimumWidth(for: $1) }
    }

    func leadingHandleTarget(for column: Column) -> Column? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        if index == 0 {
            return column
        }
        return columns[index - 1]
    }

    func isLastActiveColumn(_ column: Column) -> Bool {
        activeColumns.last == column
    }

    func beginDrag(for column: Column) {
        if let context = dragContext, context.primary == column { return }
        guard let neighbor = neighborColumn(for: column) else { return }
        let primaryWidth = width(for: column)
        let neighborWidth = width(for: neighbor)
        dragContext = ColumnDragContext(primary: column, neighbor: neighbor, primaryBaseWidth: primaryWidth, neighborBaseWidth: neighborWidth)
    }

    func updateDrag(for column: Column, translation: CGFloat) {
        guard let context = dragContext, context.primary == column else { return }
        let totalWidth = max(availableTableWidth, totalMinimumWidth)
        guard totalWidth > 0 else { return }

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

    func finalizeDrag() {
        dragContext = nil
        debugLog("Finalize drag → persisting fractions")
        persistColumnFractions(force: true)
    }

    func toggleColumn(_ column: Column) {
        var updated = visibleColumns
        if updated.contains(column) {
            if updated.count == 1 { return }
            if configuration.requiredColumns.contains(column) { return }
            updated.remove(column)
        } else {
            updated.insert(column)
        }
        setVisibleColumns(updated)
    }

    func setVisibleColumns(_ columns: Set<Column>) {
        visibleColumns = normalizedVisibleColumns(columns)
        persistVisibleColumns()
        ensureValidSelectionAfterVisibilityChange()
        recalcColumnWidths()
    }

    func resetVisibleColumns() {
        var defaults = configuration.defaultVisibleColumns
        ResizableTableViewModel.enforceRequiredColumns(configuration, on: &defaults)
        visibleColumns = defaults
        persistVisibleColumns()
        ensureValidSelectionAfterVisibilityChange()
        recalcColumnWidths()
    }

    func resetTablePreferences() {
        var defaults = configuration.defaultVisibleColumns
        ResizableTableViewModel.enforceRequiredColumns(configuration, on: &defaults)
        visibleColumns = defaults
        selectedFontSize = .medium
        columnFractions = defaultFractions()
        minimumWidthOverrides = [:]
        recalcColumnWidths()
        persistVisibleColumns()
        persistFontSize()
        persistColumnFractions()
        persistMinimumWidths()
    }

    func updateAvailableWidth(_ width: CGFloat) {
        let targetWidth = max(width, totalMinimumWidth)
        if abs(availableTableWidth - targetWidth) < 0.5 { return }
        availableTableWidth = targetWidth
        adjustResolvedWidths(for: targetWidth)
        if hasHydratedPreferences, !hasAppliedHydratedLayout {
            hasAppliedHydratedLayout = true
            debugLog("updateAvailableWidth target=\(String(format: "%.1f", Double(targetWidth))) → applied hydrated layout (no persist)")
            return
        }

        if canPersistFractions {
            debugLog("updateAvailableWidth target=\(String(format: "%.1f", Double(targetWidth))) → persist")
            persistColumnFractions()
        } else {
            debugLog("updateAvailableWidth target=\(String(format: "%.1f", Double(targetWidth))) → skip (not ready)")
        }
    }

    func recalcColumnWidths(shouldPersist: Bool = true) {
        let width = max(availableTableWidth, totalMinimumWidth)
        guard width > 0 else { return }
        adjustResolvedWidths(for: width)
        if shouldPersist {
            if canPersistFractions {
                debugLog("recalcColumnWidths width=\(String(format: "%.1f", Double(width))) → persist")
                persistColumnFractions()
            } else {
                debugLog("recalcColumnWidths width=\(String(format: "%.1f", Double(width))) → skip (not ready)")
            }
        }
    }

    // MARK: - Private helpers

    private static func initialVisibleColumns(_ configuration: MaintenanceTableConfiguration<Column>) -> Set<Column> {
        let defaults = UserDefaults.standard
        if let stored = defaults.array(forKey: configuration.visibleColumnsDefaultsKey) as? [String] {
            let mapped = stored.compactMap(Column.init(rawValue:))
            if !mapped.isEmpty {
                return Set(mapped)
            }
        }
        return configuration.defaultVisibleColumns
    }

    private static func initialFractions(_ configuration: MaintenanceTableConfiguration<Column>) -> [Column: CGFloat] {
        let defaults = configuration.defaultColumnWidths
        let total = defaults.values.reduce(0, +)
        guard total > 0 else {
            let share = 1.0 / CGFloat(configuration.columnOrder.count)
            return configuration.columnOrder.reduce(into: [:]) { dict, column in
                dict[column] = share
            }
        }
        return configuration.columnOrder.reduce(into: [:]) { dict, column in
            let width = defaults[column] ?? 0
            dict[column] = max(0.0001, width / total)
        }
    }

    private static func enforceRequiredColumns(_ configuration: MaintenanceTableConfiguration<Column>, on set: inout Set<Column>) {
        set.formUnion(configuration.requiredColumns)
    }

    private func normalizedVisibleColumns(_ input: Set<Column>) -> Set<Column> {
        var updated = input
        ResizableTableViewModel.enforceRequiredColumns(configuration, on: &updated)
        if updated.isEmpty, let first = configuration.columnOrder.first {
            updated.insert(first)
        }
        return updated
    }

    private func neighborColumn(for column: Column) -> Column? {
        let columns = activeColumns
        guard let index = columns.firstIndex(of: column) else { return nil }
        if index < columns.count - 1 {
            return columns[index + 1]
        }
        if index > 0 {
            return columns[index - 1]
        }
        return nil
    }

    private func hydratePreferencesIfNeeded() {
        guard !hasHydratedPreferences, let manager = dbManager else { return }
        debugLog("Hydrating preferences…")
        hasHydratedPreferences = true
        isHydratingPreferences = true

        migrateLegacyFontIfNeeded(manager)
        if let stored = MaintenanceTableFontSize(rawValue: manager.tableFontSize(for: configuration.preferenceKind)) {
            selectedFontSize = stored
        }

        restoreColumnFractions(using: manager)

        isHydratingPreferences = false

        if availableTableWidth > 0 {
            hasAppliedHydratedLayout = true
            debugLog("Hydration width already known (\(String(format: "%.1f", Double(availableTableWidth)))) → recalc immediately")
            recalcColumnWidths(shouldPersist: false)
        } else {
            hasAppliedHydratedLayout = false
            debugLog("Hydration deferred recalc until layout provides width")
        }
        debugLog("Hydration finished; activeFractionCount=\(columnFractions.filter { $0.value > 0 }.count)")
    }

    private func migrateLegacyFontIfNeeded(_ manager: DatabaseManager) {
        guard let legacy = manager.legacyTableFontSize(for: configuration.preferenceKind) else { return }
        if manager.tableFontSize(for: configuration.preferenceKind) != legacy {
            manager.setTableFontSize(legacy, for: configuration.preferenceKind)
        }
        manager.clearLegacyTableFontSize(for: configuration.preferenceKind)
    }

    private func restoreColumnFractions(using manager: DatabaseManager) {
        let live = manager.tableColumnFractions(for: configuration.preferenceKind)
        if applyFractions(live) {
            debugLog("Applied live fractions from manager: \(describeFractions(live))")
            return
        }

        if let legacy = manager.legacyTableColumnFractions(for: configuration.preferenceKind) {
            debugLog("Live fractions empty; attempting legacy fractions")
            if applyFractions(legacy) {
                debugLog("Applied legacy fractions: \(describeFractions(legacy))")
                manager.setTableColumnFractions(legacy, for: configuration.preferenceKind)
            }
            manager.clearLegacyTableColumnFractions(for: configuration.preferenceKind)
            return
        }

        columnFractions = defaultFractions()
        let defaults = columnFractions.reduce(into: [String: Double]()) { $0[$1.key.rawValue] = Double($1.value) }
        debugLog("Falling back to default fractions: \(describeFractions(defaults))")
    }

    private func applyFractions(_ raw: [String: Double]) -> Bool {
        let typed = typedFractions(from: raw)
        guard !typed.isEmpty else {
            debugLog("Incoming fractions empty → skip apply")
            return false
        }
        columnFractions = normalizedFractions(typed)
        debugLog("Normalized fractions: \(describeFractions(raw))")
        return true
    }

    private func typedFractions(from raw: [String: Double]) -> [Column: CGFloat] {
        raw.reduce(into: [Column: CGFloat]()) { result, entry in
            guard let column = Column(rawValue: entry.key), entry.value.isFinite else { return }
            let fraction = max(0, entry.value)
            if fraction > 0 {
                result[column] = CGFloat(fraction)
            }
        }
    }

    private func defaultFractions() -> [Column: CGFloat] {
        ResizableTableViewModel.initialFractions(configuration)
    }

    private func normalizedFractions(_ input: [Column: CGFloat]? = nil) -> [Column: CGFloat] {
        let source = input ?? columnFractions
        var result: [Column: CGFloat] = [:]
        let activeSet = Set(activeColumns)
        let total = activeColumns.reduce(0) { $0 + max(0, source[$1] ?? 0) }

        if total <= 0 {
            let share = activeColumns.isEmpty ? 0 : 1.0 / CGFloat(activeColumns.count)
            for column in configuration.columnOrder {
                result[column] = activeSet.contains(column) ? share : 0
            }
            return result
        }

        for column in configuration.columnOrder {
            if activeSet.contains(column) {
                result[column] = max(0.0001, source[column] ?? 0) / total
            } else {
                result[column] = 0
            }
        }
        return result
    }

    private func adjustResolvedWidths(for width: CGFloat) {
        guard width > 0 else { return }
        let fractions = normalizedFractions()
        var resolved: [Column: CGFloat] = [:]
        for column in configuration.columnOrder {
            guard visibleColumns.contains(column) else {
                resolved[column] = 0
                continue
            }
            let fraction = fractions[column] ?? 0
            let proposed = fraction * width
            let minWidth = minimumWidth(for: column)
            resolved[column] = max(minWidth, proposed)
        }

        balanceResolvedWidths(&resolved, targetWidth: width)
        resolvedColumnWidths = resolved
        columnFractions = normalizedFractions(resolved)
    }

    private func balanceResolvedWidths(_ resolved: inout [Column: CGFloat], targetWidth: CGFloat) {
        let columns = activeColumns
        guard !columns.isEmpty else { return }
        let currentTotal = columns.reduce(0) { $0 + (resolved[$1] ?? 0) }
        let difference = targetWidth - currentTotal
        guard abs(difference) > 0.5 else { return }

        if difference > 0 {
            let share = difference / CGFloat(columns.count)
            for column in columns {
                resolved[column, default: minimumWidth(for: column)] += share
            }
        } else {
            var remainingDifference = difference
            var adjustable = columns

            while remainingDifference < -0.5, !adjustable.isEmpty {
                let share = remainingDifference / CGFloat(adjustable.count)
                var columnsAtMinimum: [Column] = []
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

    private func ensureValidSelectionAfterVisibilityChange() {
        // Intentionally left empty for now; hook for future view-specific validation.
    }

    private func persistVisibleColumns() {
        let ordered = configuration.columnOrder.filter { visibleColumns.contains($0) }
        UserDefaults.standard.set(ordered.map(\.rawValue), forKey: configuration.visibleColumnsDefaultsKey)
    }

    private func persistFontSize() {
        guard !isHydratingPreferences, let manager = dbManager else { return }
        isHydratingPreferences = true
        manager.setTableFontSize(selectedFontSize.rawValue, for: configuration.preferenceKind)
        DispatchQueue.main.async { [weak self] in
            self?.isHydratingPreferences = false
        }
    }

    private func persistColumnFractions(force: Bool = false) {
        guard let manager = dbManager else {
            debugLog("Skipping persistColumnFractions (no manager)")
            return
        }
        if !force, !canPersistFractions {
            debugLog("Skipping persistColumnFractions (not ready and force=false)")
            return
        }
        guard !isHydratingPreferences else {
            debugLog("Skipping persistColumnFractions (currently hydrating)")
            return
        }
        let payload = columnFractions.reduce(into: [String: Double]()) { result, entry in
            guard entry.value.isFinite else { return }
            result[entry.key.rawValue] = Double(entry.value)
        }
        debugLog("Persisting fractions: \(describeFractions(payload))")
        isHydratingPreferences = true
        manager.setTableColumnFractions(payload, for: configuration.preferenceKind)
        DispatchQueue.main.async { [weak self] in
            self?.isHydratingPreferences = false
        }
    }

    func updateMinimumWidths(_ overrides: [Column: CGFloat]) {
        minimumWidthOverrides = overrides.filter { $0.value.isFinite && $0.value > 0 }
        persistMinimumWidths()
        recalcColumnWidths()
    }

    func resetMinimumWidths() {
        minimumWidthOverrides = [:]
        persistMinimumWidths()
        recalcColumnWidths()
    }

    private static func loadMinimumWidthOverrides(configuration: MaintenanceTableConfiguration<Column>, defaultsKey: String?) -> [Column: CGFloat] {
        guard let key = defaultsKey else { return [:] }
        let defaults = UserDefaults.standard
        guard let raw = defaults.dictionary(forKey: key) else { return [:] }
        return raw.reduce(into: [Column: CGFloat]()) { result, entry in
            guard let column = Column(rawValue: entry.key) else { return }
            if let number = entry.value as? NSNumber {
                let value = CGFloat(number.doubleValue)
                if value.isFinite, value > 0 { result[column] = value }
            }
        }
    }

    private func persistMinimumWidths() {
        guard let key = minimumWidthsDefaultsKey else { return }
        let payload = minimumWidthOverrides.reduce(into: [String: Double]()) { result, entry in
            result[entry.key.rawValue] = Double(entry.value)
        }
        UserDefaults.standard.set(payload, forKey: key)
    }

    private func observe(manager: DatabaseManager) {
        fontPublisher(for: manager)
            .receive(on: RunLoop.main)
            .sink { [weak self] raw in
                guard let self else { return }
                guard !self.isHydratingPreferences else { return }
                guard let size = MaintenanceTableFontSize(rawValue: raw) else { return }
                self.selectedFontSize = size
            }
            .store(in: &cancellables)

        fractionsPublisher(for: manager)
            .receive(on: RunLoop.main)
            .sink { [weak self] raw in
                guard let self else { return }
                guard !self.isHydratingPreferences else {
                    self.debugLog("Ignoring fractions update while hydrating")
                    return
                }
                if self.applyFractions(raw) {
                    self.debugLog("Applying fractions update from manager")
                    self.recalcColumnWidths(shouldPersist: false)
                }
            }
            .store(in: &cancellables)
    }

    private func fontPublisher(for manager: DatabaseManager) -> AnyPublisher<String, Never> {
        switch configuration.preferenceKind {
        case .institutions: return manager.$institutionsTableFontSize.eraseToAnyPublisher()
        case .instruments: return manager.$instrumentsTableFontSize.eraseToAnyPublisher()
        case .assetSubClasses: return manager.$assetSubClassesTableFontSize.eraseToAnyPublisher()
        case .assetClasses: return manager.$assetClassesTableFontSize.eraseToAnyPublisher()
        case .currencies: return manager.$currenciesTableFontSize.eraseToAnyPublisher()
        case .accounts: return manager.$accountsTableFontSize.eraseToAnyPublisher()
        case .positions: return manager.$positionsTableFontSize.eraseToAnyPublisher()
        case .portfolioThemes: return manager.$portfolioThemesTableFontSize.eraseToAnyPublisher()
        case .transactionTypes: return manager.$transactionTypesTableFontSize.eraseToAnyPublisher()
        case .accountTypes: return manager.$accountTypesTableFontSize.eraseToAnyPublisher()
        }
    }

    private func fractionsPublisher(for manager: DatabaseManager) -> AnyPublisher<[String: Double], Never> {
        switch configuration.preferenceKind {
        case .institutions: return manager.$institutionsTableColumnFractions.eraseToAnyPublisher()
        case .instruments: return manager.$instrumentsTableColumnFractions.eraseToAnyPublisher()
        case .assetSubClasses: return manager.$assetSubClassesTableColumnFractions.eraseToAnyPublisher()
        case .assetClasses: return manager.$assetClassesTableColumnFractions.eraseToAnyPublisher()
        case .currencies: return manager.$currenciesTableColumnFractions.eraseToAnyPublisher()
        case .accounts: return manager.$accountsTableColumnFractions.eraseToAnyPublisher()
        case .positions: return manager.$positionsTableColumnFractions.eraseToAnyPublisher()
        case .portfolioThemes: return manager.$portfolioThemesTableColumnFractions.eraseToAnyPublisher()
        case .transactionTypes: return manager.$transactionTypesTableColumnFractions.eraseToAnyPublisher()
        case .accountTypes: return manager.$accountTypesTableColumnFractions.eraseToAnyPublisher()
        }
    }

    private func describeFractions(_ input: [String: Double]) -> String {
        guard !input.isEmpty else { return "<empty>" }
        let sorted = input.sorted { $0.key < $1.key }
        let parts = sorted.map { "\($0.key)=\(String(format: "%.4f", $0.value))" }
        return parts.joined(separator: ", ")
    }

    private var canPersistFractions: Bool {
        (!hasHydratedPreferences || hasAppliedHydratedLayout) && !isHydratingPreferences
    }

    #if DEBUG
        private func debugLog(_ message: String) {
            print("🧭 [table:\(configuration.preferenceKind.logLabel)] \(message)")
        }
    #else
        private func debugLog(_: String) {}
    #endif
}
