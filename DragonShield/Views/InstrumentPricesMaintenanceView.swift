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
    @State private var editedPrice: [Int: String] = [:]
    @State private var editedAsOf: [Int: Date] = [:]
    @State private var editedSource: [Int: String] = [:]
    @State private var loading = false

    private enum SortKey: String, CaseIterable { case instrument, currency, price, asOf, source }

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
        }
    }

    private var filtersBar: some View {
        HStack(spacing: 12) {
            TextField("Search instruments, ticker, ISIN, valor", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { reload() }
                .frame(minWidth: 320)
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
                .onChange(of: showMissingOnly) { _ in reload() }
            HStack(spacing: 8) {
                Text("Stale >")
                Slider(
                    value: Binding(
                        get: { Double(staleDays) },
                        set: { staleDays = Int($0); reload() }
                    ),
                    in: 0...365, step: 1
                )
                .frame(width: 160)
                Text("\(staleDays) day\(staleDays == 1 ? "" : "s")")
                    .frame(width: 70, alignment: .leading)
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

    private var table: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                headerRow
                ForEach(rows) { row in
                    rowView(row)
                    Divider()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Instrument").frame(maxWidth: .infinity, alignment: .leading)
            Text("Currency").frame(width: 70, alignment: .leading)
            Text("Latest Price").frame(width: 140, alignment: .trailing)
            Text("As Of").frame(width: 160, alignment: .leading)
            Text("Source").frame(width: 100, alignment: .leading)
            Text("New Price").frame(width: 160, alignment: .trailing)
            Text("New As Of").frame(width: 160, alignment: .leading)
            Text("New Source").frame(width: 120, alignment: .leading)
            Text("Actions").frame(width: 120, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func rowView(_ r: DatabaseManager.InstrumentLatestPriceRow) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.name).fontWeight(.semibold)
                HStack(spacing: 6) {
                    if let t = r.ticker, !t.isEmpty { Text(t).font(.caption).foregroundColor(.secondary) }
                    if let i = r.isin, !i.isEmpty { Text(i).font(.caption).foregroundColor(.secondary) }
                    if let v = r.valorNr, !v.isEmpty { Text(v).font(.caption).foregroundColor(.secondary) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(r.currency).frame(width: 70, alignment: .leading)
            Text(formatted(r.latestPrice)).frame(width: 140, alignment: .trailing).monospacedDigit()
            Text(r.asOf ?? "—").frame(width: 160, alignment: .leading)
            Text(r.source ?? "").frame(width: 100, alignment: .leading)
            TextField("", text: Binding(
                get: { editedPrice[r.id] ?? "" },
                set: { editedPrice[r.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
            DatePicker("", selection: Binding(
                get: { editedAsOf[r.id] ?? Date() },
                set: { editedAsOf[r.id] = $0 }
            ), displayedComponents: .date)
            .labelsHidden()
            .frame(width: 160, alignment: .leading)
            TextField("source", text: Binding(
                get: { editedSource[r.id] ?? "manual" },
                set: { editedSource[r.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
            HStack(spacing: 8) {
                Button("Save") { saveRow(r) }.disabled(!hasEdits(r.id))
                Button("Revert") { revertRow(r.id) }.disabled(!hasEdits(r.id))
            }
            .frame(width: 120, alignment: .trailing)
        }
        .font(.system(size: 12))
        .padding(.vertical, 2)
    }

    private func formatted(_ v: Double?) -> String {
        guard let v else { return "—" }
        return Self.priceFormatter.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    private func distinctCurrencies() -> [String] {
        let set = Set(rows.map { $0.currency.uppercased() })
        return Array(set).sorted()
    }

    private func reload() {
        loading = true
        DispatchQueue.global().async {
            let currencies = currencyFilters.isEmpty ? nil : Array(currencyFilters)
            let data = dbManager.listInstrumentLatestPrices(
                search: searchText.isEmpty ? nil : searchText,
                currencies: currencies,
                missingOnly: showMissingOnly,
                staleDays: staleDays
            )
            DispatchQueue.main.async {
                self.rows = data
                self.applySort()
                self.loading = false
            }
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
