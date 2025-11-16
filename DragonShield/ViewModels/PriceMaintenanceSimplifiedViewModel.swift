import SwiftUI

final class PriceUpdatesViewModel: ObservableObject {
    enum ActiveSheet: Identifiable {
        case logs
        case history(Int)
        case report
        case symbolHelp

        var id: String {
            switch self {
            case .logs: return "logs"
            case let .history(id): return "history_\(id)"
            case .report: return "report"
            case .symbolHelp: return "symbol_help"
            }
        }
    }

    struct RowDraft {
        var autoEnabled: Bool
        var providerCode: String
        var externalId: String
        var lastStatus: String
        var editedPrice: String?
        var editedAsOf: Date?
        var editedSource: String?
    }

    struct DisplayRow: Identifiable {
        let instrument: DatabaseManager.InstrumentLatestPriceRow
        let source: InstrumentPriceSource?
        let state: RowDraft
        let defaultNewAsOf: Date

        var id: Int { instrument.id }

        var instrumentSortKey: String { instrument.name.lowercased() }
        var currencySortKey: String { instrument.currency.lowercased() }
        var latestPriceSortKey: Double { instrument.latestPrice ?? -Double.greatestFiniteMagnitude }
        var asOfSortKey: String { instrument.asOf ?? "" }
        var priceSourceSortKey: String { (instrument.source ?? "").lowercased() }
        var autoSortKey: Int { state.autoEnabled ? 1 : 0 }
        var autoProviderSortKey: String { state.providerCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        var externalIdSortKey: String { state.externalId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        var newPriceSortKey: Double { Double(state.editedPrice ?? "") ?? -Double.greatestFiniteMagnitude }
        var newAsOfSortKey: Date { state.editedAsOf ?? defaultNewAsOf }
        var manualSourceSortKey: String { manualSourceDisplay.lowercased() }
        var actionsSortKey: Int { instrument.id }

        var manualSourceDisplay: String {
            let base = instrument.source?.trimmingCharacters(in: .whitespacesAndNewlines)
            return state.editedSource ?? (base?.isEmpty == false ? base! : "manual")
        }
    }

    @Published var searchText: String = ""
    @Published var showMissingOnly = false
    @Published var staleDays: Int = 0

    @Published var currencyFilters: Set<String> = []
    @Published var priceSourceFilters: Set<String> = []
    @Published var providerFilters: Set<String> = []
    @Published var autoFilters: Set<String> = []
    @Published var manualSourceFilters: Set<String> = []

    @Published private(set) var availableCurrencies: [String] = []
    @Published private(set) var availablePriceSources: [String] = []
    @Published private(set) var availableProviders: [String] = []
    @Published private(set) var availableAutoStates: [String] = []
    @Published private(set) var availableManualSources: [String] = []

    @Published private(set) var rows: [DisplayRow] = []
    @Published private(set) var loading = false
    @Published private(set) var fetchResults: [PriceUpdateService.ResultItem] = []
    @Published private(set) var nameByIdSnapshot: [Int: String] = [:]
    @Published private(set) var providerByIdSnapshot: [Int: String] = [:]
    @Published var activeSheet: ActiveSheet?

    private var dbManager: DatabaseManager?
    private var searchDebounce: DispatchWorkItem?
    private let searchDebounceInterval: TimeInterval = 0.25
    private var rowStates: [Int: RowDraft] = [:]
    private lazy var isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    var normalizedPriceSourceFilters: Set<String> { Set(priceSourceFilters.map(Self.normalizeSource)) }
    var normalizedProviderFilters: Set<String> { Set(providerFilters.map(Self.normalizeSource)) }
    var normalizedAutoFilters: Set<String> { Set(autoFilters.map(Self.normalizeSource)) }
    var normalizedManualSourceFilters: Set<String> { Set(manualSourceFilters.map(Self.normalizeSource)) }

    var hasPendingEdits: Bool {
        rowStates.values.contains(where: { $0.editedPrice != nil || $0.editedAsOf != nil || $0.editedSource != nil })
    }

    func attach(dbManager: DatabaseManager) {
        self.dbManager = dbManager
        reload()
    }

    func scheduleSearch() {
        searchDebounce?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.reload()
        }
        searchDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + searchDebounceInterval, execute: task)
    }

    func toggleCurrencyFilter(_ currency: String) {
        if currencyFilters.contains(currency) {
            currencyFilters.remove(currency)
        } else {
            currencyFilters.insert(currency)
        }
    }

    func clearCurrencyFilters() { currencyFilters.removeAll() }

    func togglePriceSourceFilter(_ source: String) {
        let normalized = Self.normalizeSource(source)
        guard !normalized.isEmpty else { return }
        if let existing = priceSourceFilters.first(where: { Self.normalizeSource($0) == normalized }) {
            priceSourceFilters.remove(existing)
        } else {
            priceSourceFilters.insert(source.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func clearPriceSourceFilters() { priceSourceFilters.removeAll() }

    func toggleProviderFilter(_ provider: String) {
        let normalized = Self.normalizeSource(provider)
        guard !normalized.isEmpty else { return }
        if let existing = providerFilters.first(where: { Self.normalizeSource($0) == normalized }) {
            providerFilters.remove(existing)
        } else {
            providerFilters.insert(provider.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func clearProviderFilters() { providerFilters.removeAll() }

    func toggleAutoFilter(_ label: String) {
        let normalized = Self.normalizeSource(label)
        guard !normalized.isEmpty else { return }
        if let existing = autoFilters.first(where: { Self.normalizeSource($0) == normalized }) {
            autoFilters.remove(existing)
        } else {
            autoFilters.insert(label.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func clearAutoFilters() { autoFilters.removeAll() }

    func toggleManualSourceFilter(_ source: String) {
        let normalized = Self.normalizeSource(source)
        guard !normalized.isEmpty else { return }
        if let existing = manualSourceFilters.first(where: { Self.normalizeSource($0) == normalized }) {
            manualSourceFilters.remove(existing)
        } else {
            manualSourceFilters.insert(source.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func clearManualSourceFilters() { manualSourceFilters.removeAll() }

    func resetFilters() {
        searchDebounce?.cancel()
        searchText = ""
        currencyFilters.removeAll()
        priceSourceFilters.removeAll()
        providerFilters.removeAll()
        autoFilters.removeAll()
        manualSourceFilters.removeAll()
        showMissingOnly = false
        staleDays = 0
        reload()
    }

    func reload() {
        guard let dbManager else { return }
        loading = true
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currencyFilters = currencyFilters
        let sourceFilters = normalizedPriceSourceFilters
        let providerFilters = normalizedProviderFilters
        let autoFilters = normalizedAutoFilters
        let manualFilters = normalizedManualSourceFilters
        let showMissing = showMissingOnly
        let stale = staleDays
        let existingStates = rowStates

        DispatchQueue.global(qos: .userInitiated).async {
            let currencies = currencyFilters.isEmpty ? nil : Array(currencyFilters)
            let baseRows = dbManager.listInstrumentLatestPrices(
                search: search.isEmpty ? nil : search,
                currencies: currencies,
                missingOnly: showMissing,
                staleDays: stale
            )
            let ids = baseRows.map { $0.id }
            let sources = dbManager.getPriceSources(instrumentIds: ids)
            let defaultNewAsOf = Date()

            var updatedStates = existingStates
            var draftRows: [DisplayRow] = []

            for row in baseRows {
                let priceSource = sources[row.id]
                var state = updatedStates[row.id] ?? RowDraft(
                    autoEnabled: priceSource?.enabled ?? false,
                    providerCode: priceSource?.providerCode ?? "",
                    externalId: priceSource?.externalId ?? "",
                    lastStatus: priceSource?.lastStatus ?? "",
                    editedPrice: nil,
                    editedAsOf: nil,
                    editedSource: nil
                )
                if let latestStatus = priceSource?.lastStatus {
                    state.lastStatus = latestStatus
                }
                updatedStates[row.id] = state
                draftRows.append(DisplayRow(
                    instrument: row,
                    source: priceSource,
                    state: state,
                    defaultNewAsOf: state.editedAsOf ?? defaultNewAsOf
                ))
            }

            let priceSourcesList: [String] = {
                let normalizedPairs = draftRows.compactMap { row -> (String, String)? in
                    guard let src = row.instrument.source?.trimmingCharacters(in: .whitespacesAndNewlines), !src.isEmpty else {
                        return nil
                    }
                    return (Self.normalizeSource(src), src)
                }
                var unique: [String: String] = [:]
                for pair in normalizedPairs where unique[pair.0] == nil {
                    unique[pair.0] = pair.1
                }
                return unique.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }()

            let providersList: [String] = {
                let normalizedPairs = draftRows.compactMap { row -> (String, String)? in
                    let prov = row.state.providerCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !prov.isEmpty else { return nil }
                    return (Self.normalizeSource(prov), prov)
                }
                var unique: [String: String] = [:]
                for pair in normalizedPairs where unique[pair.0] == nil {
                    unique[pair.0] = pair.1
                }
                return unique.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }()

            let autoStatesList: [String] = {
                let states = draftRows.map { self.autoStateLabel(enabled: $0.state.autoEnabled) }
                return Array(Set(states)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }()

            let manualSourcesList: [String] = {
                let values = draftRows.compactMap { row -> String? in
                    let value = row.manualSourceDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : value
                }
                return Array(Set(values)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }()

            let filteredBySource: [DisplayRow] = {
                guard !sourceFilters.isEmpty else { return draftRows }
                return draftRows.filter { row in
                    guard let src = row.instrument.source else { return false }
                    return sourceFilters.contains(Self.normalizeSource(src))
                }
            }()

            let filteredByProvider: [DisplayRow] = {
                guard !providerFilters.isEmpty else { return filteredBySource }
                return filteredBySource.filter { row in
                    let prov = Self.normalizeSource(row.state.providerCode)
                    return providerFilters.contains(prov)
                }
            }()

            let filteredByAuto: [DisplayRow] = {
                guard !autoFilters.isEmpty else { return filteredByProvider }
                return filteredByProvider.filter { row in
                    let label = self.autoStateLabel(enabled: row.state.autoEnabled)
                    return autoFilters.contains(Self.normalizeSource(label))
                }
            }()

            let filteredByManual: [DisplayRow] = {
                guard !manualFilters.isEmpty else { return filteredByAuto }
                return filteredByAuto.filter { row in
                    let value = row.manualSourceDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
                    return manualFilters.contains(Self.normalizeSource(value))
                }
            }()

            let currenciesList = Array(Set(filteredByManual.map { $0.instrument.currency.uppercased() })).sorted()

            DispatchQueue.main.async {
                self.availableCurrencies = currenciesList
                self.availablePriceSources = priceSourcesList
                self.availableProviders = providersList
                self.availableAutoStates = autoStatesList
                self.availableManualSources = manualSourcesList
                self.rows = filteredByManual
                self.loading = false
                self.rowStates = updatedStates
            }
        }
    }

    func bindingForAuto(_ row: DisplayRow, onChange: @escaping () -> Void) -> Binding<Bool> {
        Binding(
            get: { self.rowStates[row.id]?.autoEnabled ?? row.state.autoEnabled },
            set: { value in
                self.updateState(row) { $0.autoEnabled = value }
                onChange()
            }
        )
    }

    func bindingForProvider(_ row: DisplayRow, onChange: @escaping () -> Void) -> Binding<String> {
        Binding(
            get: { self.rowStates[row.id]?.providerCode ?? row.state.providerCode },
            set: { value in
                self.updateState(row) { $0.providerCode = value }
                onChange()
            }
        )
    }

    func bindingForExternalId(_ row: DisplayRow, onChange: @escaping () -> Void) -> Binding<String> {
        Binding(
            get: { self.rowStates[row.id]?.externalId ?? row.state.externalId },
            set: { value in
                self.updateState(row) { $0.externalId = value }
                onChange()
            }
        )
    }

    func bindingForEditedPrice(_ row: DisplayRow) -> Binding<String> {
        Binding(
            get: { self.rowStates[row.id]?.editedPrice ?? row.state.editedPrice ?? "" },
            set: { value in self.updateState(row) { $0.editedPrice = value } }
        )
    }

    func bindingForEditedDate(_ row: DisplayRow) -> Binding<Date> {
        Binding(
            get: { self.rowStates[row.id]?.editedAsOf ?? row.state.editedAsOf ?? row.defaultNewAsOf },
            set: { value in self.updateState(row) { $0.editedAsOf = value } }
        )
    }

    func bindingForEditedSource(_ row: DisplayRow) -> Binding<String> {
        Binding(
            get: { self.rowStates[row.id]?.editedSource ?? row.state.editedSource ?? row.manualSourceDisplay },
            set: { value in self.updateState(row) { $0.editedSource = value } }
        )
    }

    func persistSourceIfComplete(_ row: DisplayRow) {
        guard let dbManager else { return }
        let state = rowStates[row.id] ?? RowDraft(
            autoEnabled: row.state.autoEnabled,
            providerCode: row.state.providerCode,
            externalId: row.state.externalId,
            lastStatus: row.state.lastStatus,
            editedPrice: row.state.editedPrice,
            editedAsOf: row.state.editedAsOf,
            editedSource: row.state.editedSource
        )
        let enabled = state.autoEnabled
        let provider = state.providerCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = state.externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !enabled {
            _ = dbManager.upsertPriceSource(instrumentId: row.id, providerCode: provider, externalId: ext, enabled: false, priority: 1)
            return
        }
        if !provider.isEmpty {
            _ = dbManager.upsertPriceSource(instrumentId: row.id, providerCode: provider, externalId: ext, enabled: true, priority: 1)
        }
    }

    func fetchLatestEnabled(for rows: [DisplayRow]) {
        guard let dbManager else { return }
        rows.forEach { persistSourceIfComplete($0) }
        let records: [PriceSourceRecord] = rows.compactMap { row in
            guard let state = rowStates[row.id], state.autoEnabled else { return nil }
            let provider = state.providerCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let ext = state.externalId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !provider.isEmpty, !ext.isEmpty else { return nil }
            return PriceSourceRecord(instrumentId: row.id, providerCode: provider, externalId: ext, expectedCurrency: row.instrument.currency)
        }
        guard !records.isEmpty else { return }
        Task {
            let service = PriceUpdateService(dbManager: dbManager)
            let results = await service.fetchAndUpsert(records)
            await MainActor.run {
                self.fetchResults = results
                self.nameByIdSnapshot = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.instrument.name) })
                self.providerByIdSnapshot = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, self.rowStates[$0.id]?.providerCode ?? "") })
                self.activeSheet = .report
            }
            await MainActor.run { self.reload() }
        }
    }

    func saveRow(_ row: DisplayRow) {
        guard let dbManager,
              let state = rowStates[row.id],
              let priceString = state.editedPrice,
              let price = Double(priceString) else { return }
        let asOfDate = state.editedAsOf ?? Date()
        let source = (state.editedSource ?? row.manualSourceDisplay).trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = isoFormatter.string(from: asOfDate)
        if dbManager.upsertPrice(
            instrumentId: row.id,
            price: price,
            currency: row.instrument.currency,
            asOf: iso,
            source: source.isEmpty ? "manual" : source
        ) {
            updateState(row) {
                $0.editedPrice = nil
                $0.editedAsOf = nil
                $0.editedSource = nil
            }
            reload()
        }
    }

    func saveEdited() {
        for row in rows where rowStates[row.id]?.editedPrice != nil || rowStates[row.id]?.editedAsOf != nil || rowStates[row.id]?.editedSource != nil {
            saveRow(row)
        }
    }

    func revertRow(_ row: DisplayRow) {
        updateState(row) {
            $0.editedPrice = nil
            $0.editedAsOf = nil
            $0.editedSource = nil
        }
    }

    func hasEdits(_ id: Int) -> Bool {
        guard let state = rowStates[id] else { return false }
        return state.editedPrice != nil || state.editedAsOf != nil || state.editedSource != nil
    }

    func openHistory(_ id: Int) {
        activeSheet = .history(id)
    }

    func formatted(_ value: Double?) -> String {
        guard let value else { return "—" }
        let formatter = Self.priceFormatter
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    func formatAsOf(_ raw: String?, timeZoneId: String) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        let tz = TimeZone(identifier: timeZoneId) ?? .current
        var parsed: Date? = isoFormatter.date(from: raw)
        if parsed == nil {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            parsed = fallback.date(from: raw)
        }
        if parsed == nil {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone(secondsFromGMT: 0)
            parsed = df.date(from: raw)
        }
        if let date = parsed {
            var calendar = Calendar.current
            calendar.timeZone = tz
            let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
            let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0 || (comps.second ?? 0) != 0
            let out = DateFormatter()
            out.timeZone = tz
            out.dateFormat = hasTime ? "dd.MM.yy HH:mm" : "dd.MM.yy"
            return out.string(from: date)
        }
        if raw.count == 10,
           raw[raw.index(raw.startIndex, offsetBy: 4)] == "-"
        {
            let parts = raw.split(separator: "-")
            if parts.count == 3 {
                let yy = parts[0].suffix(2)
                return "\(parts[2]).\(parts[1]).\(yy)"
            }
        }
        return raw
    }

    func staleLabel(_ days: Int) -> String {
        days == 0 ? "0" : "\(days)d"
    }

    static func normalizeSource(_ source: String) -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func autoStateLabel(enabled: Bool) -> String { enabled ? "Enabled" : "Disabled" }

    private func updateState(_ row: DisplayRow, mutate: (inout RowDraft) -> Void) {
        var state = rowStates[row.id] ?? RowDraft(
            autoEnabled: row.state.autoEnabled,
            providerCode: row.state.providerCode,
            externalId: row.state.externalId,
            lastStatus: row.state.lastStatus,
            editedPrice: row.state.editedPrice,
            editedAsOf: row.state.editedAsOf,
            editedSource: row.state.editedSource
        )
        mutate(&state)
        rowStates[row.id] = state
        objectWillChange.send()
    }

    deinit {
        searchDebounce?.cancel()
    }
}
