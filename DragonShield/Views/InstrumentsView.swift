import SwiftUI

struct InstrumentsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    struct InstrumentData: Identifiable, Hashable {
        var id: Int
        var name: String
        var type: String
        var currency: String
        var symbol: String?
        var valor: String?
        var isin: String?
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

    @State private var instruments: [InstrumentData] = []
    @State private var selectedRows = Set<InstrumentData.ID>()
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\InstrumentData.name)]
    @State private var filterSelections: [Column: Set<String>] = [:]
    @State private var activeFilter: Column?

    @State private var showAddSheet = false
    @State private var instrumentToEdit: InstrumentData? = nil

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

            VStack(spacing: 12) {
                header
                searchBar
                if isFiltering {
                    filteredSummary
                }
                instrumentsTable
                Spacer()
            }
            .padding()
        }
        .onAppear(perform: loadData)
        .sheet(isPresented: $showAddSheet) {
            AddInstrumentView()
                .environmentObject(dbManager)
        }
        .sheet(item: $instrumentToEdit) { item in
            InstrumentEditView(instrumentId: item.id)
                .environmentObject(dbManager)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Instruments")
                    .font(.system(size: 32, weight: .semibold))
                HStack(spacing: 16) {
                    statCard(title: "Total", value: "\(instruments.count)", color: .blue)
                    statCard(title: "Types", value: "\(Set(instruments.map(\.type)).count)", color: .purple)
                    statCard(title: "Currencies", value: "\(Set(instruments.map(\.currency)).count)", color: .green)
                }
            }
            Spacer()
            Button { showAddSheet = true } label: {
                Label("Add New Instrument", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Add New Instrument")
        }
    }

    private var searchBar: some View {
        TextField("Search instruments...", text: $searchText)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .accessibilityLabel("Search instruments")
    }

    private var filteredSummary: some View {
        HStack {
            Text("Showing \(filteredInstruments.count) of \(instruments.count) instruments")
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
    }

    private var instrumentsTable: some View {
        Table(sortedInstruments, selection: $selectedRows, sortOrder: $sortOrder) {
            TableColumn(columnHeader(for: .name), sortUsing: KeyPathComparator(\InstrumentData.name)) { inst in
                Text(inst.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .width(min: 160)

            TableColumn(columnHeader(for: .type), sortUsing: KeyPathComparator(\InstrumentData.type)) { inst in
                Text(inst.type)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .width(min: 120)

            TableColumn(columnHeader(for: .currency), sortUsing: KeyPathComparator(\InstrumentData.currency)) { inst in
                Text(inst.currency)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .width(min: 60)

            TableColumn(columnHeader(for: .symbol), sortUsing: KeyPathComparator(\InstrumentData.symbol)) { inst in
                Text(inst.symbol ?? "--")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .width(min: 80)

            TableColumn(columnHeader(for: .valor), sortUsing: KeyPathComparator(\InstrumentData.valor)) { inst in
                Text(inst.valor ?? "--")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80)

            TableColumn(columnHeader(for: .isin), sortUsing: KeyPathComparator(\InstrumentData.isin)) { inst in
                Text(inst.isin ?? "--")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .width(min: 140)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .onTapGesture(count: 2) {
            if let id = selectedRows.first, let inst = instruments.first(where: { $0.id == id }) {
                instrumentToEdit = inst
            }
        }
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private func columnHeader(for column: Column) -> some View {
        HStack(spacing: 4) {
            Text(column.title)
            filterButton(for: column)
        }
    }

    private func filterButton(for column: Column) -> some View {
        Button {
            activeFilter = column
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(.blue)
                .padding(.trailing, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(item: Binding<Column?>(
            get: { activeFilter == column ? column : nil },
            set: { val in if val == nil { activeFilter = nil } }
        )) { _ in
            filterPopover(for: column)
        }
        .accessibilityLabel("Filter \(column.title)")
    }

    private func filterPopover(for column: Column) -> some View {
        let values = uniqueValues(for: column)
        let selections = filterSelections[column] ?? []
        return VStack(alignment: .leading) {
            ForEach(values, id: \.self) { value in
                Toggle(value.isEmpty ? "(Empty)" : value, isOn: Binding(
                    get: { selections.contains(value) },
                    set: { val in
                        if val {
                            filterSelections[column, default: []].insert(value)
                        } else {
                            filterSelections[column]?.remove(value)
                        }
                    }
                ))
            }
            Button("Clear") { filterSelections[column] = [] }
                .padding(.top, 4)
        }
        .padding()
        .frame(width: 200)
    }

    private var isFiltering: Bool {
        !searchText.isEmpty || filterSelections.values.contains { !$0.isEmpty }
    }

    private var filteredInstruments: [InstrumentData] {
        var result = instruments
        if !searchText.isEmpty {
            let text = searchText.lowercased()
            result = result.filter { instr in
                instr.name.lowercased().contains(text) ||
                (instr.symbol?.lowercased().contains(text) ?? false) ||
                (instr.isin?.lowercased().contains(text) ?? false) ||
                (instr.valor?.lowercased().contains(text) ?? false)
            }
        }
        for column in Column.allCases {
            if let selected = filterSelections[column], !selected.isEmpty {
                result = result.filter { selected.contains(value(for: column, item: $0)) }
            }
        }
        return result
    }

    private var sortedInstruments: [InstrumentData] {
        filteredInstruments.sorted(using: sortOrder)
    }

    private func uniqueValues(for column: Column) -> [String] {
        let vals = instruments.map { value(for: column, item: $0) }
        return Array(Set(vals)).sorted()
    }

    private func value(for column: Column, item: InstrumentData) -> String {
        switch column {
        case .name: return item.name
        case .type: return item.type
        case .currency: return item.currency
        case .symbol: return item.symbol ?? ""
        case .valor: return item.valor ?? ""
        case .isin: return item.isin ?? ""
        }
    }

    private func loadData() {
        let assets = dbManager.fetchAssets()
        let types = dbManager.fetchAssetTypes()
        let typeLookup = Dictionary(uniqueKeysWithValues: types.map { ($0.id, $0.name) })
        instruments = assets.map { a in
            InstrumentData(
                id: a.id,
                name: a.name,
                type: typeLookup[a.subClassId] ?? "",
                currency: a.currency,
                symbol: a.tickerSymbol,
                valor: a.valorNr,
                isin: a.isin
            )
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.8)))
    }
}

struct InstrumentsView_Previews: PreviewProvider {
    static var previews: some View {
        InstrumentsView().environmentObject(DatabaseManager())
    }
}
