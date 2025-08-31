import SwiftUI

struct InstrumentPricesMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var searchText: String = ""
    @State private var currencyFilters: Set<String> = []
    @State private var showMissingOnly = false
    @State private var staleDays: Int = 0
    @State private var sortKey: SortKey = .instrument
    @State private var sortAscending: Bool = true

    @State private var rows: [DatabaseManager.InstrumentLatestPriceRow] = []
    // Column widths (resizable like Workspace Holdings)
    @State private var colWidths: [Column: CGFloat] = [:]
    @State private var editedPrice: [Int: String] = [:]
    @State private var editedAsOf: [Int: Date] = [:]
    @State private var editedSource: [Int: String] = [:]
    // Auto-price configuration state
    @State private var autoEnabled: [Int: Bool] = [:]
    @State private var providerCode: [Int: String] = [:]
    @State private var externalId: [Int: String] = [:]
    @State private var lastStatus: [Int: String] = [:]
    private let providerOptions: [String] = ["coingecko", "finnhub", "yahoo", "alphavantage", "mock"]
    @State private var loading = false
    // Debounce for live search typing
    @State private var searchDebounce: DispatchWorkItem? = nil
    private enum ActiveSheet: Identifiable { case logs, history(Int), report, symbolHelp; var id: String { switch self { case .logs: return "logs"; case .history(let i): return "history_\(i)"; case .report: return "report"; case .symbolHelp: return "symbol_help" } } }
    @State private var activeSheet: ActiveSheet? = nil
    // Report sheet state
    @State private var fetchResults: [PriceUpdateService.ResultItem] = []
    @State private var nameByIdSnapshot: [Int: String] = [:]
    @State private var providerByIdSnapshot: [Int: String] = [:]
    // Removed HistoryItem in favor of unified ActiveSheet

    private enum SortKey: String, CaseIterable {
        case instrument, currency, price, asOf, source
        case auto        // Auto toggle state
        case autoProvider // Provider code used for auto fetch
        case manualSource // Text in the Manual Source field
    }

    private enum Column: String, CaseIterable, Hashable, Identifiable {
        case instrument, currency, latestPrice, asOf, source, auto, provider, externalId, newPrice, newAsOf, newSource, actions
        var id: String { rawValue }
    }
    private let staleOptions: [Int] = [0, 7, 14, 30, 60, 90]

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            filtersBar
            Divider()
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                table
            }
        }
        .padding(16)
        .onAppear(perform: reload)
        .onAppear(perform: restoreWidths)
        // Present structured report and other sheets
        .sheet(item: $activeSheet) { item in
            switch item {
            case .logs:
                LogViewerView().environmentObject(dbManager)
            case .history(let id):
                PriceHistoryView(instrumentId: id)
                    .environmentObject(dbManager)
            case .report:
                FetchResultsReportView(
                    results: fetchResults,
                    nameById: nameByIdSnapshot,
                    providerById: providerByIdSnapshot,
                    timeZoneId: dbManager.defaultTimeZone
                )
            case .symbolHelp:
                SymbolFormatHelpView()
            }
        }
    }

    // Helper: small blue arrow next to active sort header (like Workspace holdings)
    private func sortArrow(for key: SortKey) -> some View {
        Group {
            if sortKey == key {
                Text(sortAscending ? "▲" : "▼").foregroundColor(.blue)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Instrument Prices Maintenance").font(.title2).bold()
                Text("View, filter, and update latest prices across instruments.").foregroundColor(.secondary)
            }
            Spacer()
            Button("Save Edited", action: saveEdited)
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(editedPrice.isEmpty && editedAsOf.isEmpty && editedSource.isEmpty)
            Button("Fetch Latest (Enabled)") { fetchLatestEnabled() }
                .disabled(rows.isEmpty)
            Button("View Logs") { activeSheet = .logs }
            Button("Symbol Formats") { activeSheet = .symbolHelp }
        }
    }

    private var filtersBar: some View {
        HStack(spacing: 12) {
            TextField("Search instruments, ticker, ISIN, valor", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { reload() }
                .onChange(of: searchText) { _, _ in
                    // Debounce to avoid requerying on every keystroke
                    searchDebounce?.cancel()
                    let task = DispatchWorkItem { reload() }
                    searchDebounce = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
                }
                .frame(minWidth: 320)
            Text("name, ticker, ISIN, valor, source, provider, external id, manual source")
                .font(.caption)
                .foregroundColor(.secondary)
            Menu {
                ForEach(distinctCurrencies(), id: \.self) { cur in
                    Button {
                        if currencyFilters.contains(cur) { currencyFilters.remove(cur) } else { currencyFilters.insert(cur) }
                        reload()
                    } label: {
                        HStack { Text(cur); if currencyFilters.contains(cur) { Image(systemName: "checkmark") } }
                    }
                }
            } label: {
                Label(currencyFilters.isEmpty ? "Currencies" : "\(currencyFilters.count) Currencies", systemImage: "line.3.horizontal.decrease.circle")
            }
            Toggle("Missing only", isOn: $showMissingOnly)
                .onChange(of: showMissingOnly) { _, _ in reload() }
            HStack(spacing: 8) {
                Text("Stale >")
                Picker("", selection: $staleDays) {
                    ForEach(staleOptions, id: \.self) { d in
                        Text(staleLabel(d)).tag(d)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: staleDays) { _, _ in reload() }
            }
            Spacer()
            Picker("Sort", selection: $sortKey) {
                ForEach(SortKey.allCases, id: \.self) { key in Text(key.rawValue.capitalized).tag(key) }
            }
            .frame(width: 160)
            Button(action: { sortAscending.toggle(); applySort() }) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
            }
        }
    }

    #if os(macOS)
    @ViewBuilder
    private var table: some View {
        // Custom table like Workspace Holdings — precise alignment and truncation
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    headerCell("Instrument", key: .instrument, width: width(for: .instrument), alignment: .leading)
                    resizeHandle(for: .instrument)
                    headerCell("Currency", key: .currency, width: width(for: .currency), alignment: .leading)
                    resizeHandle(for: .currency)
                    headerCell("Latest Price", key: .price, width: width(for: .latestPrice), alignment: .trailing)
                    resizeHandle(for: .latestPrice)
                    headerCell("As Of", key: .asOf, width: width(for: .asOf), alignment: .leading)
                    resizeHandle(for: .asOf)
                    headerCell("Price Source", key: .source, width: width(for: .source), alignment: .leading)
                    resizeHandle(for: .source)
                    headerCell("Auto", key: .auto, width: width(for: .auto), alignment: .center)
                    resizeHandle(for: .auto)
                    headerCell("Auto Provider", key: .autoProvider, width: width(for: .provider), alignment: .leading)
                    resizeHandle(for: .provider)
                    Text("External ID").frame(width: width(for: .externalId), alignment: .leading)
                    resizeHandle(for: .externalId)
                    Text("New Price").frame(width: width(for: .newPrice), alignment: .trailing)
                    resizeHandle(for: .newPrice)
                    Text("New As Of").frame(width: width(for: .newAsOf), alignment: .leading)
                    resizeHandle(for: .newAsOf)
                    headerCell("Manual Source", key: .manualSource, width: width(for: .newSource), alignment: .leading)
                    resizeHandle(for: .newSource)
                    Text("Actions").frame(width: width(for: .actions), alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

                // Rows
                LazyVStack(spacing: 1) {
                    ForEach(rows) { r in
                        HStack(alignment: .center, spacing: 8) {
                            // Instrument cell
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(r.name)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .help(r.name)
                                    if r.latestPrice == nil { missingPriceChip }
                                }
                                HStack(spacing: 6) {
                                    if let t = r.ticker, !t.isEmpty { Text(t).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle) }
                                    if let i = r.isin, !i.isEmpty { Text(i).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle) }
                                    if let v = r.valorNr, !v.isEmpty { Text(v).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle) }
                                }
                            }
                            .frame(width: width(for: .instrument), alignment: .leading)
                            resizeSpacer(for: .instrument)

                            Text(r.currency).frame(width: width(for: .currency), alignment: .leading)
                            resizeSpacer(for: .currency)
                            Text(formatted(r.latestPrice))
                                .frame(width: width(for: .latestPrice), alignment: .trailing)
                                .monospacedDigit()
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background((autoEnabled[r.id] ?? false) ? Color.green.opacity(0.12) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            resizeSpacer(for: .latestPrice)
                            Text(formatAsOf(r.asOf)).frame(width: width(for: .asOf), alignment: .leading)
                            resizeSpacer(for: .asOf)
                            HStack(spacing: 4) {
                                Text(r.source ?? "")
                                if (autoEnabled[r.id] ?? false), let st = lastStatus[r.id], !st.isEmpty, st.lowercased() != "ok" { Text("🚫").help("Last auto update failed: \(st)") }
                            }.frame(width: width(for: .source), alignment: .leading)
                            resizeSpacer(for: .source)
                            Toggle("", isOn: Binding(get: { autoEnabled[r.id] ?? false }, set: { autoEnabled[r.id] = $0; persistSourceIfComplete(r) }))
                                .labelsHidden()
                                .frame(width: width(for: .auto), alignment: .center)
                            resizeSpacer(for: .auto)
                            Picker("", selection: Binding(get: { providerCode[r.id] ?? "" }, set: { providerCode[r.id] = $0; persistSourceIfComplete(r) })) {
                                Text("").tag("")
                                ForEach(providerOptions, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: width(for: .provider), alignment: .leading)
                            resizeSpacer(for: .provider)
                            TextField("", text: Binding(get: { externalId[r.id] ?? "" }, set: { externalId[r.id] = $0; persistSourceIfComplete(r) }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: width(for: .externalId), alignment: .leading)
                            resizeSpacer(for: .externalId)
                            TextField("", text: Binding(get: { editedPrice[r.id] ?? "" }, set: { editedPrice[r.id] = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: width(for: .newPrice), alignment: .trailing)
                            resizeSpacer(for: .newPrice)
                            DatePicker("", selection: Binding(get: { editedAsOf[r.id] ?? Date() }, set: { editedAsOf[r.id] = $0 }), displayedComponents: .date)
                                .labelsHidden()
                                .frame(width: width(for: .newAsOf), alignment: .leading)
                            resizeSpacer(for: .newAsOf)
                            TextField("manual source", text: Binding(get: { editedSource[r.id] ?? "manual" }, set: { editedSource[r.id] = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: width(for: .newSource), alignment: .leading)
                            resizeSpacer(for: .newSource)
                            HStack(spacing: 8) {
                                Button("Save") { saveRow(r) }.disabled(!hasEdits(r.id))
                                Button("Revert") { revertRow(r.id) }.disabled(!hasEdits(r.id))
                                Button("History") { openHistory(r.id) }
                            }
                            .frame(width: width(for: .actions), alignment: .trailing)
                        }
                        .font(.system(size: 12))
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.vertical, 4)
            .frame(minWidth: Self.tableMinWidth, maxWidth: .infinity, alignment: .topLeading)
        }
    }
    #else
    private var table: some View {
        // Horizontal + vertical scroll. Force content to anchor to the top-left so rows never appear centered.
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.bottom, 4)
                ForEach(rows) { row in
                    rowView(row)
                    Divider()
                }
            }
            .padding(.vertical, 4)
            .frame(minWidth: Self.tableMinWidth, maxWidth: .infinity, alignment: .topLeading)
        }
    }
    #endif

    private var headerRow: some View {
        HStack {
            headerCell("Instrument", key: .instrument, width: Self.colInstrument, alignment: .leading)
            headerCell("Currency", key: .currency, width: Self.colCurrency, alignment: .leading)
            headerCell("Latest Price", key: .price, width: Self.colLatestPrice, alignment: .trailing)
            headerCell("As Of", key: .asOf, width: Self.colAsOf, alignment: .leading)
            headerCell("Price Source", key: .source, width: Self.colSource, alignment: .leading)
            headerCell("Auto", key: .auto, width: Self.colAuto, alignment: .center)
            headerCell("Auto Provider", key: .autoProvider, width: Self.colProvider, alignment: .leading)
            Text("External ID").frame(width: Self.colExternalId, alignment: .leading)
            Text("New Price").frame(width: Self.colNewPrice, alignment: .trailing)
            Text("New As Of").frame(width: Self.colNewAsOf, alignment: .leading)
            headerCell("Manual Source", key: .manualSource, width: Self.colNewSource, alignment: .leading)
            Text("Actions").frame(width: Self.colActions, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func headerCell(_ title: String, key: SortKey, width: CGFloat, alignment: Alignment) -> some View {
        let isActive = sortKey == key
        return Button(action: { toggleSort(key) }) {
            HStack(spacing: 4) {
                Text(title)
                    .fontWeight(isActive ? .bold : .regular)
                if isActive { Text(sortAscending ? "▲" : "▼").foregroundColor(.blue) }
            }
            .frame(width: width, alignment: alignment)
        }
        .buttonStyle(.plain)
    }

    private func toggleSort(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
        applySort()
    }

    private func rowView(_ r: DatabaseManager.InstrumentLatestPriceRow) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(r.name).fontWeight(.semibold)
                    if r.latestPrice == nil { missingPriceChip }
                }
                HStack(spacing: 6) {
                    if let t = r.ticker, !t.isEmpty { Text(t).font(.caption).foregroundColor(.secondary) }
                    if let i = r.isin, !i.isEmpty { Text(i).font(.caption).foregroundColor(.secondary) }
                    if let v = r.valorNr, !v.isEmpty { Text(v).font(.caption).foregroundColor(.secondary) }
                }
            }
            .frame(width: Self.colInstrument, alignment: .leading)
            .layoutPriority(1)
            Text(r.currency).frame(width: Self.colCurrency, alignment: .leading)
            Text(formatted(r.latestPrice))
                .frame(width: Self.colLatestPrice, alignment: .trailing)
                .monospacedDigit()
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background((autoEnabled[r.id] ?? false) ? Color.green.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(formatAsOf(r.asOf))
                .frame(width: Self.colAsOf, alignment: .leading)
            HStack(spacing: 4) {
                Text(r.source ?? "")
                if (autoEnabled[r.id] ?? false), let st = lastStatus[r.id], !st.isEmpty, st.lowercased() != "ok" {
                    Text("🚫")
                        .help("Last auto update failed: \(st)")
                }
            }
            .frame(width: Self.colSource, alignment: .leading)
            Toggle("", isOn: Binding(get: { autoEnabled[r.id] ?? false }, set: { autoEnabled[r.id] = $0; persistSourceIfComplete(r) }))
                .labelsHidden()
                .frame(width: Self.colAuto, alignment: .center)
            Picker("", selection: Binding(get: { providerCode[r.id] ?? "" }, set: { providerCode[r.id] = $0; persistSourceIfComplete(r) })) {
                Text("").tag("")
                ForEach(providerOptions, id: \.self) { p in Text(p).tag(p) }
            }
            .labelsHidden()
            .frame(width: Self.colProvider, alignment: .leading)
            TextField("", text: Binding(get: { externalId[r.id] ?? "" }, set: { externalId[r.id] = $0; persistSourceIfComplete(r) }))
                .textFieldStyle(.roundedBorder)
                .frame(width: Self.colExternalId, alignment: .leading)
            TextField("", text: Binding(
                get: { editedPrice[r.id] ?? "" },
                set: { editedPrice[r.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: Self.colNewPrice)
            DatePicker("", selection: Binding(
                get: { editedAsOf[r.id] ?? Date() },
                set: { editedAsOf[r.id] = $0 }
            ), displayedComponents: .date)
            .labelsHidden()
            .frame(width: Self.colNewAsOf, alignment: .leading)
            TextField("manual source", text: Binding(
                get: { editedSource[r.id] ?? "manual" },
                set: { editedSource[r.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: Self.colNewSource)
            HStack(spacing: 8) {
                Button("Save") { saveRow(r) }.disabled(!hasEdits(r.id))
                Button("Revert") { revertRow(r.id) }.disabled(!hasEdits(r.id))
                Button("History") { openHistory(r.id) }
            }
            .frame(width: Self.colActions, alignment: .trailing)
        }
        .font(.system(size: 12))
        .padding(.vertical, 2)
    }

    // Column widths + min table width to align header and rows and enable horizontal scrolling on small screens
    private static let colInstrument: CGFloat = 280
    private static let colCurrency: CGFloat = 70
    private static let colLatestPrice: CGFloat = 140
    private static let colAsOf: CGFloat = 170
    private static let colSource: CGFloat = 110
    private static let colAuto: CGFloat = 50
    private static let colProvider: CGFloat = 140
    private static let colExternalId: CGFloat = 200
    private static let colNewPrice: CGFloat = 120
    private static let colNewAsOf: CGFloat = 170
    private static let colNewSource: CGFloat = 130
    private static let colActions: CGFloat = 160
    private static let tableMinWidth: CGFloat = colInstrument + colCurrency + colLatestPrice + colAsOf + colSource + colAuto + colProvider + colExternalId + colNewPrice + colNewAsOf + colNewSource + colActions + 24

    private func formatted(_ v: Double?) -> String {
        guard let v else { return "—" }
        return Self.priceFormatter.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    private func staleLabel(_ d: Int) -> String { d == 0 ? "0" : "\(d)d" }

    // MARK: - Status chips
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

    private func distinctCurrencies() -> [String] {
        let set = Set(rows.map { $0.currency.uppercased() })
        return Array(set).sorted()
    }

    // MARK: - Column widths (resizable)
    private func defaultWidth(for col: Column) -> CGFloat {
        switch col {
        case .instrument: return Self.colInstrument
        case .currency: return Self.colCurrency
        case .latestPrice: return Self.colLatestPrice
        case .asOf: return Self.colAsOf
        case .source: return Self.colSource
        case .auto: return Self.colAuto
        case .provider: return Self.colProvider
        case .externalId: return Self.colExternalId
        case .newPrice: return Self.colNewPrice
        case .newAsOf: return Self.colNewAsOf
        case .newSource: return Self.colNewSource
        case .actions: return Self.colActions
        }
    }
    private func width(for col: Column) -> CGFloat { colWidths[col] ?? defaultWidth(for: col) }
    private func resizeHandle(for col: Column) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.001))
            .frame(width: 6, height: 18)
            .overlay(Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 2))
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                var w = width(for: col) + value.translation.width
                w = max(40, min(600, w))
                colWidths[col] = w
            }.onEnded { _ in
                persistWidths()
            })
            .help("Drag to resize column")
    }
    private func resizeSpacer(for col: Column) -> some View {
        Rectangle().fill(Color.clear).frame(width: 6, height: 18)
    }
    private func restoreWidths() {
        guard let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.pricesMaintenanceColWidths) else { return }
        var map: [Column: CGFloat] = [:]
        for part in raw.split(separator: ",") {
            let kv = part.split(separator: ":")
            if kv.count == 2, let c = Column(rawValue: String(kv[0])), let w = Double(kv[1]) {
                map[c] = max(40, CGFloat(w))
            }
        }
        if !map.isEmpty { colWidths = map }
    }
    private func persistWidths() {
        let raw = Column.allCases.compactMap { col -> String? in
            if let w = colWidths[col] { return "\(col.rawValue):\(Int(w))" }
            return nil
        }.joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: UserDefaultsKeys.pricesMaintenanceColWidths)
    }

    private func reload() {
        loading = true
        DispatchQueue.global().async {
            let currencies = currencyFilters.isEmpty ? nil : Array(currencyFilters)
            // Fetch rows with DB-side structural filters only; do text search in-memory across extra fields too
            let data = dbManager.listInstrumentLatestPrices(
                search: nil,
                currencies: currencies,
                missingOnly: showMissingOnly,
                staleDays: staleDays
            )
            // Preload price source configuration for provider/externalId matching
            var src: [Int: (prov: String, ext: String, enabled: Bool, status: String)] = [:]
            for r in data {
                if let cfg = dbManager.getPriceSource(instrumentId: r.id) {
                    src[r.id] = (cfg.providerCode, cfg.externalId, cfg.enabled, cfg.lastStatus ?? "")
                }
            }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let filtered: [DatabaseManager.InstrumentLatestPriceRow] = {
                guard !q.isEmpty else { return data }
                return data.filter { r in
                    if r.name.lowercased().contains(q) { return true }
                    if let t = r.ticker?.lowercased(), t.contains(q) { return true }
                    if let i = r.isin?.lowercased(), i.contains(q) { return true }
                    if let v = r.valorNr?.lowercased(), v.contains(q) { return true }
                    if let s = r.source?.lowercased(), s.contains(q) { return true } // Price Source
                    if let p = src[r.id]?.prov.lowercased(), p.contains(q) { return true } // Auto Provider
                    if let e = src[r.id]?.ext.lowercased(), e.contains(q) { return true } // External ID
                    if let m = (editedSource[r.id] ?? "manual").lowercased() as String?, m.contains(q) { return true } // Manual Source (edited or default)
                    return false
                }
            }()
            DispatchQueue.main.async {
                self.rows = filtered
                self.applySort()
                self.loading = false
                self.preloadSources()
            }
        }
    }

    private func preloadSources() {
        // Prefill provider/externalId/auto from DB for visible rows
        for r in rows {
            if let cfg = dbManager.getPriceSource(instrumentId: r.id) {
                providerCode[r.id] = cfg.providerCode
                externalId[r.id] = cfg.externalId
                autoEnabled[r.id] = cfg.enabled
                if let st = cfg.lastStatus { lastStatus[r.id] = st } else { lastStatus[r.id] = "" }
            } else {
                providerCode[r.id] = providerCode[r.id] ?? ""
                externalId[r.id] = externalId[r.id] ?? ""
                autoEnabled[r.id] = autoEnabled[r.id] ?? false
                lastStatus[r.id] = lastStatus[r.id] ?? ""
            }
        }
    }

    private func persistSourceIfComplete(_ r: DatabaseManager.InstrumentLatestPriceRow) {
        let enabled = autoEnabled[r.id] ?? false
        let prov = providerCode[r.id] ?? ""
        let ext = externalId[r.id] ?? ""
        // Only persist when we have provider and external id (or when disabling)
        if (!prov.isEmpty && !ext.isEmpty) || !enabled {
            _ = dbManager.upsertPriceSource(instrumentId: r.id, providerCode: prov, externalId: ext, enabled: enabled, priority: 1)
        }
    }

    private func fetchLatestEnabled() {
        // Ensure current provider/externalId selections are persisted before fetching
        for r in rows { persistSourceIfComplete(r) }
        let records: [PriceSourceRecord] = rows.compactMap { r in
            if autoEnabled[r.id] == true,
               let prov = providerCode[r.id], !prov.isEmpty,
               let ext = externalId[r.id], !ext.isEmpty {
                return PriceSourceRecord(instrumentId: r.id, providerCode: prov, externalId: ext, expectedCurrency: r.currency)
            }
            return nil
        }
        guard !records.isEmpty else { return }
        Task {
            let service = PriceUpdateService(dbManager: dbManager)
            let results = await service.fetchAndUpsert(records)
            // Snapshot names and providers for the report
            self.fetchResults = results
            self.nameByIdSnapshot = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.name) })
            self.providerByIdSnapshot = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, providerCode[$0.id] ?? "") })
            self.activeSheet = .report
            reload()
        }
    }

    private func applySort() {
        rows.sort { a, b in
            switch sortKey {
            case .instrument: return sortAscending ? a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending : a.name.localizedCaseInsensitiveCompare(b.name) == .orderedDescending
            case .currency: return sortAscending ? a.currency < b.currency : a.currency > b.currency
            case .price:
                let lv = a.latestPrice ?? -Double.greatestFiniteMagnitude
                let rv = b.latestPrice ?? -Double.greatestFiniteMagnitude
                return sortAscending ? lv < rv : lv > rv
            case .asOf:
                let la = a.asOf ?? ""
                let rb = b.asOf ?? ""
                return sortAscending ? la < rb : la > rb
            case .source:
                let ls = a.source ?? ""
                let rs = b.source ?? ""
                return sortAscending ? ls < rs : ls > rs
            case .auto:
                let la = autoEnabled[a.id] ?? false
                let lb = autoEnabled[b.id] ?? false
                if sortAscending { return (la ? 1 : 0) < (lb ? 1 : 0) } else { return (la ? 1 : 0) > (lb ? 1 : 0) }
            case .autoProvider:
                let pa = providerCode[a.id] ?? ""
                let pb = providerCode[b.id] ?? ""
                return sortAscending ? pa < pb : pa > pb
            case .manualSource:
                let msa = editedSource[a.id] ?? "manual"
                let msb = editedSource[b.id] ?? "manual"
                return sortAscending ? msa < msb : msa > msb
            }
        }
    }

    private func hasEdits(_ id: Int) -> Bool { editedPrice[id] != nil || editedAsOf[id] != nil || editedSource[id] != nil }
    private func revertRow(_ id: Int) { editedPrice[id] = nil; editedAsOf[id] = nil; editedSource[id] = nil }

    private func saveRow(_ r: DatabaseManager.InstrumentLatestPriceRow) {
        guard let priceStr = editedPrice[r.id], let price = Double(priceStr) else { return }
        let asOfDate = editedAsOf[r.id] ?? Date()
        let source = (editedSource[r.id] ?? "manual").trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = iso8601Formatter().string(from: asOfDate)
        if dbManager.upsertPrice(instrumentId: r.id, price: price, currency: r.currency, asOf: iso, source: source.isEmpty ? "manual" : source) {
            revertRow(r.id)
            reload()
        }
    }

    private func saveEdited() {
        for r in rows {
            if hasEdits(r.id) { saveRow(r) }
        }
    }

    private func iso8601Formatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    private func openHistory(_ instrumentId: Int) { self.activeSheet = .history(instrumentId) }

    // MARK: - Date formatting for "As Of": show dd.MM.yy or dd.MM.yy HH:mm
    private func formatAsOf(_ s: String?) -> String {
        guard let s, !s.isEmpty else { return "—" }
        let tz = TimeZone(identifier: dbManager.defaultTimeZone) ?? .current
        // Try ISO with fractional seconds
        if let d = iso8601Formatter().date(from: s) ?? {
            // Try ISO without fractional seconds
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s)
        }() ?? {
            // Try date-only format yyyy-MM-dd
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone(secondsFromGMT: 0)
            return df.date(from: s)
        }() {
            let cal = Calendar.current
            let comps = cal.dateComponents(in: tz, from: d)
            let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0 || (comps.second ?? 0) != 0
            let out = DateFormatter()
            out.timeZone = tz
            out.dateFormat = hasTime ? "dd.MM.yy HH:mm" : "dd.MM.yy"
            return out.string(from: d)
        }
        // Fallback: best-effort transform if matches yyyy-MM-dd
        if s.count == 10, s[ s.index(s.startIndex, offsetBy: 4) ] == "-" { // naive check
            let parts = s.split(separator: "-")
            if parts.count == 3 {
                let yyyy = parts[0]; let mm = parts[1]; let dd = parts[2]
                let shortYY = yyyy.suffix(2)
                return "\(dd).\(mm).\(shortYY)"
            }
        }
        return s
    }
}

#if DEBUG
struct InstrumentPricesMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        InstrumentPricesMaintenanceView()
            .frame(width: 980, height: 520)
            .environmentObject(DatabaseManager())
    }
}
#endif
