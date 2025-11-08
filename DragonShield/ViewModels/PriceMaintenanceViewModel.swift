import SwiftUI

final class PriceMaintenanceViewModel: ObservableObject {
    enum ActiveSheet: Identifiable {
        case logs
        case history(Int)
        case report
        case symbolHelp

        var id: String {
            switch self {
            case .logs: return "logs"
            case .history(let id): return "history_\(id)"
            case .report: return "report"
            case .symbolHelp: return "symbol_help"
            }
        }
    }

    @Published var searchText: String = ""
    @Published private(set) var currencyFilters: Set<String> = []
    @Published private(set) var availableCurrencies: [String] = []
    @Published var showMissingOnly = false
    @Published var staleDays: Int = 0
    @Published private(set) var rows: [DatabaseManager.InstrumentLatestPriceRow] = []
    @Published private(set) var loading = false
    @Published private(set) var editedPrice: [Int: String] = [:]
    @Published private(set) var editedAsOf: [Int: Date] = [:]
    @Published private(set) var editedSource: [Int: String] = [:]
    @Published private(set) var autoEnabled: [Int: Bool] = [:]
    @Published private(set) var providerCode: [Int: String] = [:]
    @Published private(set) var externalId: [Int: String] = [:]
    @Published private(set) var lastStatus: [Int: String] = [:]
    @Published private(set) var fetchResults: [PriceUpdateService.ResultItem] = []
    @Published private(set) var nameByIdSnapshot: [Int: String] = [:]
    @Published private(set) var providerByIdSnapshot: [Int: String] = [:]
    @Published var activeSheet: ActiveSheet?

    private var dbManager: DatabaseManager?
    private var searchDebounce: DispatchWorkItem?
    private let searchDebounceInterval: TimeInterval = 0.35

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

    var hasPendingEdits: Bool {
        !editedPrice.isEmpty || !editedAsOf.isEmpty || !editedSource.isEmpty
    }

    var currencyMenuLabel: String {
        currencyFilters.isEmpty ? "Currencies" : "\(currencyFilters.count) Currencies"
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

    func resetFilters() {
        searchDebounce?.cancel()
        searchText = ""
        currencyFilters.removeAll()
        showMissingOnly = false
        staleDays = 0
        reload()
    }

    func reload() {
        guard let dbManager else { return }
        loading = true
        let search = searchText
        let filters = currencyFilters
        let showMissing = showMissingOnly
        let stale = staleDays
        let manualSources = editedSource
        DispatchQueue.global(qos: .userInitiated).async {
            let currencies = filters.isEmpty ? nil : Array(filters)
            let data = dbManager.listInstrumentLatestPrices(
                search: nil,
                currencies: currencies,
                missingOnly: showMissing,
                staleDays: stale
            )
            var sourceState: [Int: (prov: String, ext: String, enabled: Bool, status: String)] = [:]
            for row in data {
                if let cfg = dbManager.getPriceSource(instrumentId: row.id) {
                    sourceState[row.id] = (cfg.providerCode, cfg.externalId, cfg.enabled, cfg.lastStatus ?? "")
                }
            }
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let filtered: [DatabaseManager.InstrumentLatestPriceRow] = {
                guard !query.isEmpty else { return data }
                return data.filter { row in
                    if row.name.lowercased().contains(query) { return true }
                    if let ticker = row.ticker?.lowercased(), ticker.contains(query) { return true }
                    if let isin = row.isin?.lowercased(), isin.contains(query) { return true }
                    if let valor = row.valorNr?.lowercased(), valor.contains(query) { return true }
                    if let source = row.source?.lowercased(), source.contains(query) { return true }
                    if let provider = sourceState[row.id]?.prov.lowercased(), provider.contains(query) { return true }
                    if let ext = sourceState[row.id]?.ext.lowercased(), ext.contains(query) { return true }
                    if let manual = (manualSources[row.id] ?? "manual").lowercased() as String?, manual.contains(query) { return true }
                    return false
                }
            }()
            let currenciesList = Array(Set(filtered.map { $0.currency.uppercased() })).sorted()
            DispatchQueue.main.async {
                self.availableCurrencies = currenciesList
                self.rows = filtered
                self.loading = false
                self.primeSourceCaches(with: sourceState)
            }
        }
    }

    private func primeSourceCaches(with state: [Int: (prov: String, ext: String, enabled: Bool, status: String)]) {
        for row in rows {
            if let info = state[row.id] {
                providerCode[row.id] = info.prov
                externalId[row.id] = info.ext
                autoEnabled[row.id] = info.enabled
                lastStatus[row.id] = info.status
            } else {
                providerCode[row.id] = providerCode[row.id] ?? ""
                externalId[row.id] = externalId[row.id] ?? ""
                autoEnabled[row.id] = autoEnabled[row.id] ?? false
                lastStatus[row.id] = lastStatus[row.id] ?? ""
            }
        }
    }

    func bindingForAuto(row: DatabaseManager.InstrumentLatestPriceRow, onChange: @escaping () -> Void) -> Binding<Bool> {
        Binding(
            get: { self.autoEnabled[row.id] ?? false },
            set: { value in
                self.autoEnabled[row.id] = value
                onChange()
            }
        )
    }

    func bindingForProvider(row: DatabaseManager.InstrumentLatestPriceRow, onChange: @escaping () -> Void) -> Binding<String> {
        Binding(
            get: { self.providerCode[row.id] ?? "" },
            set: { value in
                self.providerCode[row.id] = value
                onChange()
            }
        )
    }

    func bindingForExternalId(row: DatabaseManager.InstrumentLatestPriceRow, onChange: @escaping () -> Void) -> Binding<String> {
        Binding(
            get: { self.externalId[row.id] ?? "" },
            set: { value in
                self.externalId[row.id] = value
                onChange()
            }
        )
    }

    func bindingForEditedPrice(_ id: Int) -> Binding<String> {
        Binding(
            get: { self.editedPrice[id] ?? "" },
            set: { self.editedPrice[id] = $0 }
        )
    }

    func bindingForEditedDate(_ id: Int) -> Binding<Date> {
        Binding(
            get: { self.editedAsOf[id] ?? Date() },
            set: { self.editedAsOf[id] = $0 }
        )
    }

    func bindingForEditedSource(_ id: Int) -> Binding<String> {
        Binding(
            get: { self.editedSource[id] ?? "manual" },
            set: { self.editedSource[id] = $0 }
        )
    }

    func persistSourceIfComplete(_ row: DatabaseManager.InstrumentLatestPriceRow) {
        guard let dbManager else { return }
        let enabled = autoEnabled[row.id] ?? false
        let provider = (providerCode[row.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = (externalId[row.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !enabled {
            _ = dbManager.upsertPriceSource(instrumentId: row.id, providerCode: provider, externalId: ext, enabled: false, priority: 1)
            return
        }
        if !provider.isEmpty {
            _ = dbManager.upsertPriceSource(instrumentId: row.id, providerCode: provider, externalId: ext, enabled: true, priority: 1)
        }
    }

    func fetchLatestEnabled() {
        guard let dbManager else { return }
        rows.forEach { persistSourceIfComplete($0) }
        let records: [PriceSourceRecord] = rows.compactMap { row in
            guard autoEnabled[row.id] == true,
                  let provider = providerCode[row.id], !provider.isEmpty,
                  let ext = externalId[row.id], !ext.isEmpty else { return nil }
            return PriceSourceRecord(instrumentId: row.id, providerCode: provider, externalId: ext, expectedCurrency: row.currency)
        }
        guard !records.isEmpty else { return }
        Task {
            let service = PriceUpdateService(dbManager: dbManager)
            let results = await service.fetchAndUpsert(records)
            await MainActor.run {
                self.fetchResults = results
                self.nameByIdSnapshot = Dictionary(uniqueKeysWithValues: self.rows.map { ($0.id, $0.name) })
                self.providerByIdSnapshot = Dictionary(uniqueKeysWithValues: self.rows.map { ($0.id, self.providerCode[$0.id] ?? "") })
                self.activeSheet = .report
            }
            await MainActor.run {
                self.reload()
            }
        }
    }

    func formatted(_ value: Double?) -> String {
        guard let value else { return "—" }
        return Self.priceFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
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
           raw[raw.index(raw.startIndex, offsetBy: 4)] == "-" {
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

    func hasEdits(_ id: Int) -> Bool {
        editedPrice[id] != nil || editedAsOf[id] != nil || editedSource[id] != nil
    }

    func revertRow(_ id: Int) {
        editedPrice[id] = nil
        editedAsOf[id] = nil
        editedSource[id] = nil
    }

    func saveRow(_ row: DatabaseManager.InstrumentLatestPriceRow) {
        guard let dbManager,
              let priceString = editedPrice[row.id],
              let price = Double(priceString) else { return }
        let asOfDate = editedAsOf[row.id] ?? Date()
        let source = (editedSource[row.id] ?? "manual").trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = isoFormatter.string(from: asOfDate)
        if dbManager.upsertPrice(
            instrumentId: row.id,
            price: price,
            currency: row.currency,
            asOf: iso,
            source: source.isEmpty ? "manual" : source
        ) {
            revertRow(row.id)
            reload()
        }
    }

    func saveEdited() {
        for row in rows where hasEdits(row.id) {
            saveRow(row)
        }
    }

    func openHistory(_ id: Int) {
        activeSheet = .history(id)
    }

    deinit {
        searchDebounce?.cancel()
    }
}
