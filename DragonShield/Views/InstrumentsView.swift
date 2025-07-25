import SwiftUI

struct InstrumentsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    struct Instrument: Identifiable, Hashable {
        let id: Int
        let name: String
        let type: String
        let currency: String
        let symbol: String?
        let valor: String?
        let isin: String?
    }

    enum Column: String, CaseIterable, Identifiable {
        case name, type, currency, symbol, valor, isin
        var id: String { rawValue }
        var title: String {
            switch self {
            case .name: return "Name"
            case .type: return "Type"
            case .currency: return "Currency"
            case .symbol: return "Symbol"
            case .valor: return "Valor"
            case .isin: return "ISIN"
            }
        }
    }

    @State private var instruments: [Instrument] = []
    @State private var selection = Set<Instrument.ID>()
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\Instrument.name)]
    @State private var showAddSheet = false
    @State private var editInstrument: Instrument? = nil

    @State private var activeFilter: Column? = nil
    @State private var filters: [Column: Set<String>] = [:]

    var filteredInstruments: [Instrument] {
        var result = instruments
        if !searchText.isEmpty {
            result = result.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                (item.symbol?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.isin?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.valor?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        for (col, values) in filters {
            if values.isEmpty { continue }
            result = result.filter { item in
                switch col {
                case .name: return values.contains(item.name)
                case .type: return values.contains(item.type)
                case .currency: return values.contains(item.currency)
                case .symbol: return values.contains(item.symbol ?? "")
                case .valor: return values.contains(item.valor ?? "")
                case .isin: return values.contains(item.isin ?? "")
                }
            }
        }
        return result
    }

    var sortedInstruments: [Instrument] {
        filteredInstruments.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            searchField
            addButtonBar
            if isFiltered {
                Text("Showing \(filteredInstruments.count) of \(instruments.count) instruments.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            tableView
        }
        .padding(24)
        .background(Theme.surface)
        .cornerRadius(8)
        .onAppear(perform: loadInstruments)
        .sheet(isPresented: $showAddSheet) {
            AddInstrumentView()
                .environmentObject(dbManager)
        }
        .sheet(item: $editInstrument) { item in
            InstrumentEditView(instrumentId: item.id)
                .environmentObject(dbManager)
        }
    }

    private var header: some View {
        HStack {
            Text("Instruments")
                .font(.system(size: 32, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: 16) {
                statCard(title: "Total", value: "\(instruments.count)", icon: "number.circle.fill", color: .blue)
                statCard(title: "Types", value: "\(Set(instruments.map { $0.type }).count)", icon: "folder.circle.fill", color: .purple)
                statCard(title: "Currencies", value: "\(Set(instruments.map { $0.currency }).count)", icon: "dollarsign.circle.fill", color: .green)
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Search instruments...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityLabel("Search instruments")
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
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private var addButtonBar: some View {
        HStack {
            Button { showAddSheet = true } label: {
                Label("Add New Instrument", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Add New Instrument")
            Spacer()
        }
    }

    private var tableView: some View {
        Table(sortedInstruments, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(label: headerView(for: .name), value: \Instrument.name) { item in
                Text(item.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            TableColumn(label: headerView(for: .type)) { item in
                Text(item.type)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            TableColumn(label: headerView(for: .currency)) { item in
                Text(item.currency)
                    .frame(width: 70, alignment: .center)
            }
            TableColumn(label: headerView(for: .symbol)) { item in
                Text(item.symbol ?? "--")
                    .frame(width: 80, alignment: .leading)
            }
            TableColumn(label: headerView(for: .valor)) { item in
                Text(item.valor ?? "--")
                    .frame(width: 80, alignment: .trailing)
            }
            TableColumn(label: headerView(for: .isin)) { item in
                Text(item.isin ?? "--")
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .onTapGesture(count: 2) {
            if let id = selection.first, let item = instruments.first(where: { $0.id == id }) {
                editInstrument = item
            }
        }
    }

    private func headerView(for column: Column) -> some View {
        HStack(spacing: 4) {
            Text(column.title)
            Button {
                activeFilter = column
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Filter \(column.title)")
            .popover(isPresented: Binding(get: { activeFilter == column }, set: { if !$0 { activeFilter = nil } })) {
                filterPopover(for: column)
            }
        }
    }

    private func filterPopover(for column: Column) -> some View {
        let values: [String] = instruments.map { instrument in
            switch column {
            case .name: return instrument.name
            case .type: return instrument.type
            case .currency: return instrument.currency
            case .symbol: return instrument.symbol ?? ""
            case .valor: return instrument.valor ?? ""
            case .isin: return instrument.isin ?? ""
            }
        }
        let unique = Array(Set(values)).sorted()
        let selectionBinding = Binding(get: {
            filters[column, default: []]
        }, set: { newSet in
            filters[column] = newSet
        })
        return VStack(alignment: .leading) {
            ForEach(unique, id: \.self) { value in
                Toggle(isOn: Binding(get: {
                    selectionBinding.wrappedValue.contains(value)
                }, set: { newVal in
                    var set = selectionBinding.wrappedValue
                    if newVal { set.insert(value) } else { set.remove(value) }
                    selectionBinding.wrappedValue = set
                })) {
                    Text(value.isEmpty ? "-" : value)
                }
            }
        }
        .padding()
        .frame(width: 200)
    }

    private var isFiltered: Bool {
        !searchText.isEmpty || filters.contains { !$0.value.isEmpty }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
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
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1))
        )
        .shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
    }

    private func loadInstruments() {
        let assetData = dbManager.fetchAssets()
        let typeLookup = Dictionary(uniqueKeysWithValues: dbManager.fetchAssetTypes().map { ($0.id, $0.name) })
        instruments = assetData.map { item in
            Instrument(
                id: item.id,
                name: item.name,
                type: typeLookup[item.subClassId] ?? "Unknown",
                currency: item.currency,
                symbol: item.tickerSymbol,
                valor: item.valorNr,
                isin: item.isin
            )
        }
    }
}

struct InstrumentsView_Previews: PreviewProvider {
    static var previews: some View {
        InstrumentsView()
            .environmentObject(DatabaseManager())
    }
}
