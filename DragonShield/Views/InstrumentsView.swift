import SwiftUI

struct InstrumentsView: View {
    @EnvironmentObject var assetManager: AssetManager
    @State private var selectedRows = Set<UUID>()
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\DragonAsset.name)]

    @State private var nameFilter = Set<String>()

    @State private var typeFilter = Set<String>()
    @State private var currencyFilter = Set<String>()
    @State private var symbolFilter = Set<String>()
    @State private var valorFilter = Set<String>()
    @State private var isinFilter = Set<String>()

    @State private var showTypeFilter = false
    @State private var showCurrencyFilter = false
    @State private var showSymbolFilter = false
    @State private var showValorFilter = false
    @State private var showIsinFilter = false
    @State private var showNameFilter = false

    @State private var showAddSheet = false
    @State private var editInstrumentId: Int? = nil

    var filteredAssets: [DragonAsset] {
        var result = assetManager.assets
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { asset in
                asset.name.lowercased().contains(query) ||
                asset.tickerSymbol?.lowercased().contains(query) == true ||
                asset.isin?.lowercased().contains(query) == true ||
                asset.valorNr?.lowercased().contains(query) == true
            }
        }
        if !nameFilter.isEmpty { result = result.filter { nameFilter.contains($0.name) } }
        if !typeFilter.isEmpty { result = result.filter { typeFilter.contains($0.type) } }
        if !currencyFilter.isEmpty { result = result.filter { currencyFilter.contains($0.currency) } }
        if !symbolFilter.isEmpty {
            result = result.filter { symbolFilter.contains($0.tickerSymbol ?? "") }
        }
        if !valorFilter.isEmpty {
            result = result.filter { valorFilter.contains($0.valorNr ?? "") }
        }
        if !isinFilter.isEmpty {
            result = result.filter { isinFilter.contains($0.isin ?? "") }
        }
        return result
    }

    private var isFiltered: Bool {
        return !searchText.isEmpty || !nameFilter.isEmpty || !typeFilter.isEmpty || !currencyFilter.isEmpty || !symbolFilter.isEmpty || !valorFilter.isEmpty || !isinFilter.isEmpty
    }

    private var uniqueNames: [String] { Array(Set(assetManager.assets.map { $0.name })).sorted() }
    private var uniqueTypes: [String] { Array(Set(assetManager.assets.map { $0.type })).sorted() }
    private var uniqueCurrencies: [String] { Array(Set(assetManager.assets.map { $0.currency })).sorted() }
    private var uniqueSymbols: [String] { Array(Set(assetManager.assets.map { $0.tickerSymbol ?? "" })).sorted() }
    private var uniqueValors: [String] { Array(Set(assetManager.assets.map { $0.valorNr ?? "" })).sorted() }
    private var uniqueIsins: [String] { Array(Set(assetManager.assets.map { $0.isin ?? "" })).sorted() }

    var body: some View {
        VStack(spacing: 16) {
            header
            searchBar
            addButton
            if isFiltered {
                HStack {
                    Text("Showing \(filteredAssets.count) of \(assetManager.assets.count) instruments.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            tableView
        }
        .padding(.top, 20)
        .sheet(isPresented: $showAddSheet) {
            AddInstrumentView()
                .environmentObject(assetManager)
                .onDisappear { assetManager.loadAssets() }
        }
        .sheet(item: $editInstrumentId) { id in
            InstrumentEditView(instrumentId: id)
                .onDisappear { assetManager.loadAssets() }
        }
    }

    private var header: some View {
        HStack {
            Text("Instruments")
                .font(.system(size: 32, weight: .semibold))
            Spacer()
            HStack(spacing: 16) {
                modernStatCard(title: "Total", value: "\(assetManager.assets.count)", icon: "number.circle.fill", color: .blue)
                modernStatCard(title: "Types", value: "\(Set(assetManager.assets.map{ $0.type }).count)", icon: "folder.circle.fill", color: .purple)
                modernStatCard(title: "Currencies", value: "\(Set(assetManager.assets.map{ $0.currency }).count)", icon: "dollarsign.circle.fill", color: .green)
            }
        }
        .padding(.horizontal, 24)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search instruments...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityLabel("Search instruments")
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.fieldGray))
        .padding(.horizontal, 24)
    }

    private var addButton: some View {
        HStack {
            Button { showAddSheet = true } label: {
                Label("Add New Instrument", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var tableView: some View {
        Table(filteredAssets.sorted(using: sortOrder), selection: $selectedRows, sortOrder: $sortOrder) {
            TableColumn(columnHeader("Name", filter: $nameFilter, show: $showNameFilter, options: uniqueNames)) { asset in
                Text(asset.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) { openEdit(for: asset) }
            }
            TableColumn(columnHeader("Type", filter: $typeFilter, show: $showTypeFilter, options: uniqueTypes), value: \DragonAsset.type) { asset in
                Text(asset.type)
                    .onTapGesture(count: 2) { openEdit(for: asset) }
            }
            TableColumn(columnHeader("Currency", filter: $currencyFilter, show: $showCurrencyFilter, options: uniqueCurrencies), value: \DragonAsset.currency) { asset in
                Text(asset.currency)
                    .onTapGesture(count: 2) { openEdit(for: asset) }
            }
            TableColumn(columnHeader("Symbol", filter: $symbolFilter, show: $showSymbolFilter, options: uniqueSymbols)) { asset in
                Text(asset.tickerSymbol ?? "--")
                    .onTapGesture(count: 2) { openEdit(for: asset) }
            }
            TableColumn(columnHeader("Valor", filter: $valorFilter, show: $showValorFilter, options: uniqueValors)) { asset in
                Text(asset.valorNr ?? "--")
                    .frame(alignment: .trailing)
                    .onTapGesture(count: 2) { openEdit(for: asset) }
            }
            TableColumn(columnHeader("ISIN", filter: $isinFilter, show: $showIsinFilter, options: uniqueIsins)) { asset in
                Text(asset.isin ?? "--")
                    .onTapGesture(count: 2) { openEdit(for: asset) }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .padding(.horizontal, 24)
    }

    private func columnHeader(_ title: String, filter: Binding<Set<String>>, show: Binding<Bool>, options: [String]) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Button { show.wrappedValue.toggle() } label: {
                Image(systemName: filter.wrappedValue.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
            .buttonStyle(BorderlessButtonStyle())
            .accessibilityLabel("Filter \(title)")
            .popover(isPresented: show) {
                VStack(alignment: .leading) {
                    ForEach(options, id: \.self) { value in
                        Button {
                            if filter.wrappedValue.contains(value) {
                                filter.wrappedValue.remove(value)
                            } else {
                                filter.wrappedValue.insert(value)
                            }
                        } label: {
                            HStack {
                                Text(value.isEmpty ? "--" : value)
                                Spacer()
                                if filter.wrappedValue.contains(value) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }

    private func openEdit(for asset: DragonAsset) {
        if let id = getInstrumentId(for: asset) {
            editInstrumentId = id
        }
    }

    private func getInstrumentId(for asset: DragonAsset) -> Int? {
        let dbManager = DatabaseManager()
        let instruments = dbManager.fetchAssets()
        return instruments.first { $0.name == asset.name }?.id
    }

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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
    }
}

struct InstrumentsView_Previews: PreviewProvider {
    static var previews: some View {
        InstrumentsView()
            .environmentObject(AssetManager())
    }
}

