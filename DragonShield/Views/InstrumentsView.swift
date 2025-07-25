// DragonShield/Views/InstrumentsView.swift
// MARK: - Version 1.0 (2025-07-25)
// MARK: - History
// - Initial creation: Modern instruments table with search, sort and filters.

import SwiftUI

struct InstrumentsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    struct InstrumentRow: Identifiable, Hashable {
        var id: Int
        var name: String
        var type: String
        var currency: String
        var symbol: String?
        var valor: String?
        var isin: String?
    }

    @State private var instruments: [InstrumentRow] = []
    @State private var selectedRows = Set<Int>()
    @State private var searchText = ""

    @State private var sortOrder = [KeyPathComparator(\InstrumentRow.name)]

    @State private var filterName: Set<String> = []
    @State private var filterType: Set<String> = []
    @State private var filterCurrency: Set<String> = []
    @State private var filterSymbol: Set<String> = []
    @State private var filterValor: Set<String> = []
    @State private var filterIsin: Set<String> = []

    @State private var instrumentToEdit: InstrumentRow? = nil

    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    private var filteredInstruments: [InstrumentRow] {
        var result = instruments
        if !searchText.isEmpty {
            result = result.filter { inst in
                inst.name.localizedCaseInsensitiveContains(searchText) ||
                (inst.symbol?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (inst.isin?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (inst.valor?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        if !filterName.isEmpty { result = result.filter { filterName.contains($0.name) } }
        if !filterType.isEmpty { result = result.filter { filterType.contains($0.type) } }
        if !filterCurrency.isEmpty { result = result.filter { filterCurrency.contains($0.currency) } }
        if !filterSymbol.isEmpty { result = result.filter { filterSymbol.contains($0.symbol ?? "") } }
        if !filterValor.isEmpty { result = result.filter { filterValor.contains($0.valor ?? "") } }
        if !filterIsin.isEmpty { result = result.filter { filterIsin.contains($0.isin ?? "") } }
        return result
    }

    private var filtersActive: Bool {
        !filterName.isEmpty || !filterType.isEmpty || !filterCurrency.isEmpty ||
        !filterSymbol.isEmpty || !filterValor.isEmpty || !filterIsin.isEmpty ||
        !searchText.isEmpty
    }

    private var types: [String] { Array(Set(instruments.map { $0.type })).sorted() }
    private var currencies: [String] { Array(Set(instruments.map { $0.currency })).sorted() }
    private var names: [String] { Array(Set(instruments.map { $0.name })).sorted() }
    private var symbols: [String] { Array(Set(instruments.compactMap { $0.symbol })).sorted() }
    private var valors: [String] { Array(Set(instruments.compactMap { $0.valor })).sorted() }
    private var isins: [String] { Array(Set(instruments.compactMap { $0.isin })).sorted() }

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

            VStack(spacing: 0) {
                modernHeader
                searchBar
                instrumentsTable
            }
        }
        .onAppear {
            loadData()
            animateEntrance()
        }
        .sheet(item: $instrumentToEdit) { item in
            InstrumentEditView(instrumentId: item.id)
                .environmentObject(dbManager)
                .onDisappear { loadData() }
        }
    }

    // MARK: - Header
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Instruments")
                        .font(.system(size: 32, weight: .semibold))
                }
            }
            Spacer()
            HStack(spacing: 16) {
                modernStatCard(title: "Total", value: "\(instruments.count)", icon: "number.circle.fill", color: .blue)
                modernStatCard(title: "Types", value: "\(types.count)", icon: "folder.circle.fill", color: .purple)
                modernStatCard(title: "Currencies", value: "\(currencies.count)", icon: "dollarsign.circle.fill", color: .green)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
        .offset(y: contentOffset)
        .overlay(
            VStack(alignment: .trailing) {
                if filtersActive {
                    Text("Showing \(filteredInstruments.count) of \(instruments.count) instruments")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.trailing, 24)
            .padding(.top, 52), alignment: .topTrailing
        )
    }

    // MARK: - Search & Add
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search instruments...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)

            Button {
                instrumentToEdit = InstrumentRow(id: 0, name: "", type: "", currency: "", symbol: nil, valor: nil, isin: nil)
            } label: {
                Label("Add New Instrument", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .opacity(buttonsOpacity)
    }

    // MARK: - Table
    private var instrumentsTable: some View {
        Table(filteredInstruments, selection: $selectedRows, sortOrder: $sortOrder) {
            TableColumn(headerView(title: "Name", filters: $filterName, values: names)) { inst in
                Text(inst.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) { instrumentToEdit = inst }
            }
            .width(min: 150, ideal: 200)
            TableColumn(headerView(title: "Type", filters: $filterType, values: types), value: \InstrumentRow.type)
                .width(min: 100, ideal: 140)
            TableColumn(headerView(title: "Currency", filters: $filterCurrency, values: currencies)) { inst in
                Text(inst.currency)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(min: 70, ideal: 80)
            TableColumn(headerView(title: "Symbol", filters: $filterSymbol, values: symbols)) { inst in
                Text(inst.symbol ?? "-")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .width(min: 80, ideal: 100)
            TableColumn(headerView(title: "Valor", filters: $filterValor, values: valors)) { inst in
                Text(inst.valor ?? "-")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 90, ideal: 100)
            TableColumn(headerView(title: "ISIN", filters: $filterIsin, values: isins)) { inst in
                Text(inst.isin ?? "-")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .width(min: 140, ideal: 160)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .offset(y: contentOffset)
    }

    private func headerView(title: String, filters: Binding<Set<String>>, values: [String]) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Menu {
                ForEach(values, id: \..self) { val in
                    Button {
                        if filters.wrappedValue.contains(val) {
                            filters.wrappedValue.remove(val)
                        } else {
                            filters.wrappedValue.insert(val)
                        }
                    } label: {
                        HStack {
                            Text(val)
                            if filters.wrappedValue.contains(val) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                if !filters.wrappedValue.isEmpty {
                    Divider()
                    Button("Clear Filters") { filters.wrappedValue.removeAll() }
                }
            } label: {
                Image(systemName: filters.wrappedValue.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
            .menuStyle(BorderlessButtonMenuStyle())
        }
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
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
    }

    private func loadData() {
        let types = dbManager.fetchAssetTypes()
        let lookup = Dictionary(uniqueKeysWithValues: types.map { ($0.id, $0.name) })
        let rows = dbManager.fetchAssets().map { item in
            InstrumentRow(
                id: item.id,
                name: item.name,
                type: lookup[item.subClassId] ?? "Unknown",
                currency: item.currency,
                symbol: item.tickerSymbol,
                valor: item.valorNr,
                isin: item.isin
            )
        }
        instruments = rows
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { contentOffset = 0 }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) { buttonsOpacity = 1.0 }
    }
}

struct InstrumentsView_Previews: PreviewProvider {
    static var previews: some View {
        InstrumentsView()
            .environmentObject(DatabaseManager())
    }
}
