import SwiftUI

private struct PriceMaintenanceTableRow: Identifiable {
    typealias SourceRow = DatabaseManager.InstrumentLatestPriceRow
    private static let emptyNumericSortValue = -Double.greatestFiniteMagnitude

    let source: SourceRow
    let instrumentSortKey: String
    let currencySortKey: String
    let latestPriceSortKey: Double
    let asOfSortKey: String
    let priceSourceSortKey: String
    let autoSortKey: Int
    let autoProviderSortKey: String
    let externalIdSortKey: String
    let newPriceSortKey: Double
    let newAsOfSortKey: Date
    let manualSourceSortKey: String
    let actionsSortKey: Int

    var id: Int { source.id }

    init(
        source: SourceRow,
        autoEnabled: Bool,
        providerCode: String,
        externalId: String,
        editedPrice: String?,
        editedAsOf: Date?,
        editedSource: String?,
        defaultNewAsOf: Date
    ) {
        self.source = source
        instrumentSortKey = source.name.lowercased()
        currencySortKey = source.currency.lowercased()
        latestPriceSortKey = Self.numericSortValue(source.latestPrice)
        asOfSortKey = source.asOf ?? ""
        priceSourceSortKey = (source.source ?? "").lowercased()
        autoSortKey = autoEnabled ? 1 : 0
        autoProviderSortKey = Self.normalized(providerCode)
        externalIdSortKey = Self.normalized(externalId)
        newPriceSortKey = Self.numericSortValue(Self.double(from: editedPrice))
        newAsOfSortKey = editedAsOf ?? defaultNewAsOf
        manualSourceSortKey = Self.normalized((editedSource ?? "manual"))
        actionsSortKey = source.id
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func double(from value: String?) -> Double? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return Double(raw)
    }

    private static func numericSortValue(_ value: Double?) -> Double {
        guard let value else { return emptyNumericSortValue }
        return value
    }
}

struct TestPriceMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = TestPriceMaintenanceViewModel()
    @State private var sortOrder: [KeyPathComparator<PriceMaintenanceTableRow>] = [
        KeyPathComparator(\.instrumentSortKey)
    ]

    private let staleOptions: [Int] = [0, 7, 14, 30, 60, 90]
    private let providerOptions: [String] = ["coingecko", "finnhub", "yahoo", "mock"]
    private typealias Row = DatabaseManager.InstrumentLatestPriceRow
    private var tableRows: [PriceMaintenanceTableRow] {
        let defaultNewAsOf = Date()
        return viewModel.rows.map { row in
            PriceMaintenanceTableRow(
                source: row,
                autoEnabled: viewModel.autoEnabled[row.id] ?? false,
                providerCode: viewModel.providerCode[row.id] ?? "",
                externalId: viewModel.externalId[row.id] ?? "",
                editedPrice: viewModel.editedPrice[row.id],
                editedAsOf: viewModel.editedAsOf[row.id],
                editedSource: viewModel.editedSource[row.id],
                defaultNewAsOf: defaultNewAsOf
            )
        }
    }

    private var sortedTableRows: [PriceMaintenanceTableRow] {
        let rows = tableRows
        guard !sortOrder.isEmpty else { return rows }
        return rows.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            filtersBar
            Divider()
            if viewModel.loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                tableArea
            }
        }
        .padding(16)
        .onAppear {
            viewModel.attach(dbManager: dbManager)
        }
        .sheet(item: $viewModel.activeSheet) { item in
            switch item {
            case .logs:
                LogViewerView().environmentObject(dbManager)
            case .history(let id):
                PriceHistoryView(instrumentId: id).environmentObject(dbManager)
            case .report:
                FetchResultsReportView(
                    results: viewModel.fetchResults,
                    nameById: viewModel.nameByIdSnapshot,
                    providerById: viewModel.providerByIdSnapshot,
                    timeZoneId: dbManager.defaultTimeZone
                )
            case .symbolHelp:
                SymbolFormatHelpView()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Test Price Maintenance")
                    .font(.title2).bold()
                Text("Unified table to inspect and update instrument prices.")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Save Edited", action: { viewModel.saveEdited() })
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!viewModel.hasPendingEdits)
            Button("Fetch Latest (Enabled)") {
                viewModel.fetchLatestEnabled()
            }.disabled(viewModel.rows.isEmpty)
            Button("View Logs") { viewModel.activeSheet = .logs }
            Button("Symbol Formats") { viewModel.activeSheet = .symbolHelp }
        }
    }

    private var filtersBar: some View {
        HStack(spacing: 12) {
            TextField("Search instruments, ticker, ISIN, valor", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 320)
                .onSubmit { viewModel.reload() }
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.scheduleSearch()
                }
            Text("name, ticker, ISIN, valor, source, provider, external id, manual source")
                .font(.caption)
                .foregroundColor(.secondary)
            Menu {
                ForEach(viewModel.availableCurrencies, id: \.self) { cur in
                    Button {
                        viewModel.toggleCurrencyFilter(cur)
                        viewModel.reload()
                    } label: {
                        HStack {
                            Text(cur)
                            if viewModel.currencyFilters.contains(cur) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(viewModel.currencyMenuLabel, systemImage: "line.3.horizontal.decrease.circle")
            }
            .disabled(viewModel.availableCurrencies.isEmpty)
            Toggle("Missing only", isOn: $viewModel.showMissingOnly)
                .onChange(of: viewModel.showMissingOnly) { _, _ in viewModel.reload() }
            HStack(spacing: 8) {
                Text("Stale >")
                Picker("", selection: $viewModel.staleDays) {
                    ForEach(staleOptions, id: \.self) { d in
                        Text(viewModel.staleLabel(d)).tag(d)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.staleDays) { _, _ in viewModel.reload() }
            }
        }
    }

    @ViewBuilder
    private var tableArea: some View {
        #if os(macOS)
        Table(sortedTableRows, sortOrder: $sortOrder) {
            TableColumn("Instrument", value: \PriceMaintenanceTableRow.instrumentSortKey) { row in
                instrumentCell(row.source)
            }

            TableColumn("Currency", value: \PriceMaintenanceTableRow.currencySortKey) { row in
                Text(row.source.currency)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TableColumn("Latest Price", value: \PriceMaintenanceTableRow.latestPriceSortKey) { row in
                Text(viewModel.formatted(row.source.latestPrice))
                    .monospacedDigit()
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(viewModel.autoEnabled[row.source.id] ?? false ? Color.green.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Group {
                TableColumn("As Of", value: \PriceMaintenanceTableRow.asOfSortKey) { row in
                    Text(viewModel.formatAsOf(row.source.asOf, timeZoneId: dbManager.defaultTimeZone))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn("Price Source", value: \PriceMaintenanceTableRow.priceSourceSortKey) { row in
                    HStack(spacing: 4) {
                        Text(row.source.source ?? "")
                        if (viewModel.autoEnabled[row.source.id] ?? false),
                           let status = viewModel.lastStatus[row.source.id],
                           !status.isEmpty,
                           status.lowercased() != "ok" {
                            Text("🚫").help("Last auto update failed: \(status)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn("Auto", value: \PriceMaintenanceTableRow.autoSortKey) { row in
                    Toggle("", isOn: viewModel.bindingForAuto(row: row.source) {
                        viewModel.persistSourceIfComplete(row.source)
                    })
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                TableColumn("Auto Provider", value: \PriceMaintenanceTableRow.autoProviderSortKey) { row in
                    Picker("", selection: viewModel.bindingForProvider(row: row.source) {
                        viewModel.persistSourceIfComplete(row.source)
                    }) {
                        Text("").tag("")
                        ForEach(providerOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn("External ID", value: \PriceMaintenanceTableRow.externalIdSortKey) { row in
                    TextField("", text: viewModel.bindingForExternalId(row: row.source) {
                        viewModel.persistSourceIfComplete(row.source)
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Group {
                TableColumn("New Price", value: \PriceMaintenanceTableRow.newPriceSortKey) { row in
                    TextField("", text: viewModel.bindingForEditedPrice(row.source.id))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                TableColumn("New As Of", value: \PriceMaintenanceTableRow.newAsOfSortKey) { row in
                    DatePicker("", selection: viewModel.bindingForEditedDate(row.source.id), displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn("Manual Source", value: \PriceMaintenanceTableRow.manualSourceSortKey) { row in
                    TextField("manual source", text: viewModel.bindingForEditedSource(row.source.id))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn("Actions", value: \PriceMaintenanceTableRow.actionsSortKey) { row in
                    HStack(spacing: 8) {
                        Button("Save") { viewModel.saveRow(row.source) }
                            .disabled(!viewModel.hasEdits(row.source.id))
                        Button("Revert") { viewModel.revertRow(row.source.id) }
                            .disabled(!viewModel.hasEdits(row.source.id))
                        Button("History") { viewModel.openHistory(row.source.id) }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(minHeight: 420)
        #else
        Text("Test Price Maintenance is available on macOS only.")
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.secondary)
        #endif
    }

    @ViewBuilder
    private func instrumentCell(_ row: DatabaseManager.InstrumentLatestPriceRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(row.name)
                    .fontWeight(.semibold)
                    .foregroundColor(row.isDeleted ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(row.name)
                if row.isDeleted {
                    Text("Soft-deleted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }
                if row.latestPrice == nil {
                    missingPriceChip
                }
            }
            HStack(spacing: 6) {
                if let ticker = row.ticker, !ticker.isEmpty {
                    Text(ticker)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let isin = row.isin, !isin.isEmpty {
                    Text(isin)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let valor = row.valorNr, !valor.isEmpty {
                    Text(valor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var missingPriceChip: some View {
        Text("Missing price")
            .font(.caption.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.paleRed)
            .foregroundColor(.numberRed)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.numberRed.opacity(0.6), lineWidth: 1))
            .cornerRadius(8)
            .accessibilityLabel("Missing price")
    }
}

// MARK: - View Model

final class TestPriceMaintenanceViewModel: ObservableObject {
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
    @Published var currencyFilters: Set<String> = []
    @Published var availableCurrencies: [String] = []
    @Published var showMissingOnly = false
    @Published var staleDays: Int = 0
    @Published var rows: [DatabaseManager.InstrumentLatestPriceRow] = []
    @Published var loading = false
    @Published var editedPrice: [Int: String] = [:]
    @Published var editedAsOf: [Int: Date] = [:]
    @Published var editedSource: [Int: String] = [:]
    @Published var autoEnabled: [Int: Bool] = [:]
    @Published var providerCode: [Int: String] = [:]
    @Published var externalId: [Int: String] = [:]
    @Published var lastStatus: [Int: String] = [:]
    @Published var fetchResults: [PriceUpdateService.ResultItem] = []
    @Published var nameByIdSnapshot: [Int: String] = [:]
    @Published var providerByIdSnapshot: [Int: String] = [:]
    @Published var activeSheet: ActiveSheet?

    private var dbManager: DatabaseManager?
    private var searchDebounce: DispatchWorkItem?

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
    }

    func toggleCurrencyFilter(_ currency: String) {
        if currencyFilters.contains(currency) {
            currencyFilters.remove(currency)
        } else {
            currencyFilters.insert(currency)
        }
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
