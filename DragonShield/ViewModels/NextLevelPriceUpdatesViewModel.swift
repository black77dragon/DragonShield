import SwiftUI
import Combine

final class NextLevelPriceUpdatesViewModel: ObservableObject {
    enum ActiveSheet: Identifiable {
        case logs
        case report
        case symbolHelp

        var id: String {
            switch self {
            case .logs: return "logs"
            case .report: return "report"
            case .symbolHelp: return "symbol_help"
            }
        }
    }

    enum UpdateMode: String {
        case auto = "Auto"
        case manual = "Manual"
    }

    struct RowDraft {
        var autoEnabled: Bool
        var providerCode: String
        var externalId: String
        var lastStatus: String
        var lastCheckedAt: String?
        var editedPrice: String?
        var editedAsOf: Date?
        var editedSource: String?
    }

    struct DisplayRow: Identifiable {
        let instrument: InstrumentLatestPriceRow
        let source: InstrumentPriceSource?
        let state: RowDraft
        let defaultNewAsOf: Date
        let asOfDate: Date?
        let lastCheckedAtDate: Date?

        var id: Int { instrument.id }

        var instrumentSortKey: String { instrument.name.lowercased() }
        var currentPriceSortKey: Double { instrument.latestPrice ?? -Double.greatestFiniteMagnitude }
        var asOfSortKey: Date { asOfDate ?? Date.distantPast }
        var updateModeSortKey: Int { state.autoEnabled ? 1 : 0 }
        var lastUpdateSortKey: Date {
            state.autoEnabled ? (lastCheckedAtDate ?? Date.distantPast) : (asOfDate ?? Date.distantPast)
        }
    }

    @Published var searchText: String = ""
    @Published var currencyFilters: Set<String> = []
    @Published var priceSourceFilters: Set<String> = []
    @Published var updateModeFilters: Set<String> = []

    @Published private(set) var availableCurrencies: [String] = []
    @Published private(set) var availablePriceSources: [String] = []
    @Published private(set) var availableUpdateModes: [String] = []
    @Published private(set) var rows: [DisplayRow] = []
    @Published private(set) var loading = false
    @Published private(set) var providerOptions: [String] = NextLevelPriceUpdatesViewModel.defaultProviderCodes
    @Published private(set) var fetchResults: [PriceUpdateService.ResultItem] = []
    @Published private(set) var nameByIdSnapshot: [Int: String] = [:]
    @Published private(set) var providerByIdSnapshot: [Int: String] = [:]
    @Published var activeSheet: ActiveSheet?

    private var dbManager: DatabaseManager?
    private var searchDebounce: DispatchWorkItem?
    private let searchDebounceInterval: TimeInterval = 0.25
    private var rowStates: [Int: RowDraft] = [:]

    static let defaultProviderCodes = ["coingecko", "finnhub", "yahoo", "mock"]
    static let staleThresholdDays = 30

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

    private static var lastSortOrder: [KeyPathComparator<DisplayRow>] = [
        KeyPathComparator(\.instrumentSortKey),
    ]

    static var initialSortOrder: [KeyPathComparator<DisplayRow>] { lastSortOrder }

    var normalizedPriceSourceFilters: Set<String> { Set(priceSourceFilters.map(Self.normalizeFilterValue)) }
    var normalizedUpdateModeFilters: Set<String> { Set(updateModeFilters.map(Self.normalizeFilterValue)) }

    static func updateSortOrder(_ order: [KeyPathComparator<DisplayRow>]) {
        lastSortOrder = order
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

    func reload() {
        guard let dbManager else { return }
        loading = true
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let currencyFilterSnapshot = currencyFilters
        let priceSourceFilterSnapshot = normalizedPriceSourceFilters
        let updateModeFilterSnapshot = normalizedUpdateModeFilters
        let existingStates = rowStates

        DispatchQueue.global(qos: .userInitiated).async {
            let baseRows = dbManager.listInstrumentLatestPrices()
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
                    lastCheckedAt: priceSource?.lastCheckedAt,
                    editedPrice: nil,
                    editedAsOf: nil,
                    editedSource: nil
                )
                if let latestStatus = priceSource?.lastStatus {
                    state.lastStatus = latestStatus
                }
                if let lastChecked = priceSource?.lastCheckedAt {
                    state.lastCheckedAt = lastChecked
                }
                updatedStates[row.id] = state
                let asOfDate = self.parseDate(row.asOf)
                let lastCheckedDate = self.parseDate(state.lastCheckedAt)
                draftRows.append(DisplayRow(
                    instrument: row,
                    source: priceSource,
                    state: state,
                    defaultNewAsOf: state.editedAsOf ?? defaultNewAsOf,
                    asOfDate: asOfDate,
                    lastCheckedAtDate: lastCheckedDate
                ))
            }

            let searchRows: [DisplayRow] = {
                guard !search.isEmpty else { return draftRows }
                return draftRows.filter { self.matchesSearch(row: $0, query: search) }
            }()

            let priceSourcesList: [String] = {
                let normalizedPairs = searchRows.compactMap { row -> (String, String)? in
                    guard let src = row.instrument.source?.trimmingCharacters(in: .whitespacesAndNewlines), !src.isEmpty else {
                        return nil
                    }
                    return (Self.normalizeFilterValue(src), src)
                }
                var unique: [String: String] = [:]
                for pair in normalizedPairs where unique[pair.0] == nil {
                    unique[pair.0] = pair.1
                }
                return unique.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }()

            let updateModesList: [String] = {
                let values = searchRows.map { self.updateModeLabel(enabled: $0.state.autoEnabled) }
                return Array(Set(values)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }()

            let filteredBySource: [DisplayRow] = {
                guard !priceSourceFilterSnapshot.isEmpty else { return searchRows }
                return searchRows.filter { row in
                    guard let src = row.instrument.source else { return false }
                    return priceSourceFilterSnapshot.contains(Self.normalizeFilterValue(src))
                }
            }()

            let filteredByUpdateMode: [DisplayRow] = {
                guard !updateModeFilterSnapshot.isEmpty else { return filteredBySource }
                return filteredBySource.filter { row in
                    let label = self.updateModeLabel(enabled: row.state.autoEnabled)
                    return updateModeFilterSnapshot.contains(Self.normalizeFilterValue(label))
                }
            }()

            let filteredByCurrency: [DisplayRow] = {
                guard !currencyFilterSnapshot.isEmpty else { return filteredByUpdateMode }
                let normalized = Set(currencyFilterSnapshot.map { $0.uppercased() })
                return filteredByUpdateMode.filter { normalized.contains($0.instrument.currency.uppercased()) }
            }()

            let currenciesList = Array(Set(filteredByUpdateMode.map { $0.instrument.currency.uppercased() })).sorted()

            let providerSet = Set(Self.defaultProviderCodes)
                .union(searchRows.map { $0.state.providerCode.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            let providerOptions = providerSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            DispatchQueue.main.async {
                self.availableCurrencies = currenciesList
                self.availablePriceSources = priceSourcesList
                self.availableUpdateModes = updateModesList
                self.providerOptions = providerOptions
                self.rows = filteredByCurrency
                self.loading = false
                self.rowStates = updatedStates
            }
        }
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
        let normalized = Self.normalizeFilterValue(source)
        guard !normalized.isEmpty else { return }
        if let existing = priceSourceFilters.first(where: { Self.normalizeFilterValue($0) == normalized }) {
            priceSourceFilters.remove(existing)
        } else {
            priceSourceFilters.insert(source.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func clearPriceSourceFilters() { priceSourceFilters.removeAll() }

    func toggleUpdateModeFilter(_ label: String) {
        let normalized = Self.normalizeFilterValue(label)
        guard !normalized.isEmpty else { return }
        if let existing = updateModeFilters.first(where: { Self.normalizeFilterValue($0) == normalized }) {
            updateModeFilters.remove(existing)
        } else {
            updateModeFilters.insert(label.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func clearUpdateModeFilters() { updateModeFilters.removeAll() }

    func updateMode(for row: DisplayRow) -> UpdateMode {
        let autoEnabled = rowStates[row.id]?.autoEnabled ?? row.state.autoEnabled
        return autoEnabled ? .auto : .manual
    }

    func setUpdateMode(_ mode: UpdateMode, for row: DisplayRow) {
        updateState(row) { $0.autoEnabled = mode == .auto }
        persistAutoState(for: row)
        reload()
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
            get: { self.rowStates[row.id]?.editedSource ?? row.state.editedSource ?? self.manualSourceDisplay(for: row) },
            set: { value in self.updateState(row) { $0.editedSource = value } }
        )
    }

    func persistAutoState(for row: DisplayRow) {
        guard let dbManager else { return }
        let state = rowStates[row.id] ?? row.state
        let enabled = state.autoEnabled
        let provider = state.providerCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let externalId = state.externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !provider.isEmpty else { return }
        _ = dbManager.upsertPriceSource(
            instrumentId: row.id,
            providerCode: provider,
            externalId: externalId,
            enabled: enabled,
            priority: 1
        )
    }

    func fetchLatestSelected(for rows: [DisplayRow]) {
        guard let dbManager else { return }
        rows.forEach { persistAutoState(for: $0) }
        let records: [PriceSourceRecord] = rows.compactMap { row in
            guard updateMode(for: row) == .auto else { return nil }
            let state = rowStates[row.id] ?? row.state
            let provider = state.providerCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let externalId = state.externalId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !provider.isEmpty, !externalId.isEmpty else { return nil }
            return PriceSourceRecord(
                instrumentId: row.id,
                providerCode: provider,
                externalId: externalId,
                expectedCurrency: row.instrument.currency
            )
        }
        guard !records.isEmpty else { return }
        Task {
            let service = PriceUpdateService(dbManager: dbManager)
            let results = await service.fetchAndUpsert(records)
            await MainActor.run {
                self.fetchResults = results
                self.nameByIdSnapshot = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.instrument.name) })
                self.providerByIdSnapshot = Dictionary(
                    uniqueKeysWithValues: rows.map { ($0.id, self.rowStates[$0.id]?.providerCode ?? "") }
                )
                self.activeSheet = .report
            }
            await MainActor.run { self.reload() }
        }
    }

    func saveRow(_ row: DisplayRow) {
        guard let dbManager else { return }
        guard updateMode(for: row) == .manual else { return }
        guard let state = rowStates[row.id],
              let priceString = state.editedPrice,
              let price = Double(priceString) else { return }
        let asOfDate = state.editedAsOf ?? Date()
        let source = (state.editedSource ?? manualSourceDisplay(for: row))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        let iso = isoFormatter.string(from: asOfDate)
        if dbManager.upsertPrice(
            instrumentId: row.id,
            price: price,
            currency: row.instrument.currency,
            asOf: iso,
            source: source
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
        for row in rows where updateMode(for: row) == .manual && hasManualEdits(row.id) {
            if canSaveManual(row) {
                saveRow(row)
            }
        }
    }

    func revertRow(_ row: DisplayRow) {
        updateState(row) {
            $0.editedPrice = nil
            $0.editedAsOf = nil
            $0.editedSource = nil
        }
    }

    func hasManualEdits(_ id: Int) -> Bool {
        guard let state = rowStates[id] else { return false }
        return state.editedPrice != nil || state.editedAsOf != nil || state.editedSource != nil
    }

    func canSaveManual(_ row: DisplayRow) -> Bool {
        guard updateMode(for: row) == .manual else { return false }
        guard let state = rowStates[row.id] else { return false }
        guard let priceString = state.editedPrice?.trimmingCharacters(in: .whitespacesAndNewlines),
              !priceString.isEmpty,
              Double(priceString) != nil else { return false }
        let source = (state.editedSource ?? manualSourceDisplay(for: row))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !source.isEmpty
    }

    var hasPendingManualEdits: Bool {
        rows.contains { updateMode(for: $0) == .manual && hasManualEdits($0.id) }
    }

    func manualEditsCount() -> Int {
        rows.filter { updateMode(for: $0) == .manual && hasManualEdits($0.id) }.count
    }

    static func normalizeFilterValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func formattedPrice(_ value: Double?) -> String {
        guard let value else { return "-" }
        let formatter = Self.priceFormatter
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    func formatAsOf(_ raw: String?, timeZoneId: String) -> String {
        guard let raw, !raw.isEmpty else { return "-" }
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

    func formatTimestamp(_ raw: String?, timeZoneId: String) -> String {
        formatAsOf(raw, timeZoneId: timeZoneId)
    }

    func manualSourceDisplay(for row: DisplayRow) -> String {
        let edited = rowStates[row.id]?.editedSource ?? row.state.editedSource
        if let edited, !edited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return edited
        }
        let base = row.instrument.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if base.isEmpty { return "manual" }
        if Self.defaultProviderCodes.contains(base.lowercased()) { return "manual" }
        return base
    }

    func needsUpdate(_ row: DisplayRow) -> Bool {
        row.instrument.latestPrice == nil || isStale(row.asOfDate)
    }

    func staleDays(for row: DisplayRow) -> Int? {
        guard let date = row.asOfDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days
    }

    func autoStatusLabel(for row: DisplayRow) -> String {
        let state = rowStates[row.id] ?? row.state
        let provider = state.providerCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let externalId = state.externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider.isEmpty { return "Provider required" }
        if externalId.isEmpty { return "External ID required" }
        let status = state.lastStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        if status.isEmpty { return "Not checked" }
        if status.lowercased() == "ok" { return "OK" }
        return status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    func autoStatusColor(for row: DisplayRow) -> Color {
        let label = autoStatusLabel(for: row).lowercased()
        if label == "ok" { return .green }
        if label.contains("required") { return .orange }
        if label.contains("error") || label.contains("failed") || label.contains("mismatch") { return .red }
        return .orange
    }

    func autoLastCheckedLabel(for row: DisplayRow, timeZoneId: String) -> String {
        let state = rowStates[row.id] ?? row.state
        guard let lastChecked = state.lastCheckedAt, !lastChecked.isEmpty else { return "Never checked" }
        return "Last checked \(formatTimestamp(lastChecked, timeZoneId: timeZoneId))"
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = isoFormatter.date(from: raw) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        if let date = fallback.date(from: raw) { return date }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df.date(from: raw)
    }

    private func isStale(_ date: Date?) -> Bool {
        guard let date else { return false }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days > Self.staleThresholdDays
    }

    private func matchesSearch(row: DisplayRow, query: String) -> Bool {
        let baseFields: [String?] = [
            row.instrument.name,
            row.instrument.ticker,
            row.instrument.isin,
            row.instrument.valorNr,
            row.instrument.source,
            row.state.providerCode,
            row.state.externalId,
            row.instrument.className,
            row.instrument.subClassName,
        ]
        return baseFields.contains { field in
            field?.lowercased().contains(query) == true
        }
    }

    private func updateState(_ row: DisplayRow, mutate: (inout RowDraft) -> Void) {
        var state = rowStates[row.id] ?? row.state
        mutate(&state)
        rowStates[row.id] = state
        if let idx = rows.firstIndex(where: { $0.id == row.id }) {
            rows[idx] = DisplayRow(
                instrument: row.instrument,
                source: row.source,
                state: state,
                defaultNewAsOf: row.defaultNewAsOf,
                asOfDate: row.asOfDate,
                lastCheckedAtDate: row.lastCheckedAtDate
            )
        }
        objectWillChange.send()
    }

    deinit {
        searchDebounce?.cancel()
    }

    private func updateModeLabel(enabled: Bool) -> String {
        enabled ? "Auto" : "Manual"
    }
}
