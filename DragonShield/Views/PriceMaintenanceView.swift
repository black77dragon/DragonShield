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

struct PriceMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = PriceMaintenanceViewModel()
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
                Text("Price Maintenance")
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
            Spacer(minLength: 0)
            Button {
                viewModel.resetFilters()
            } label: {
                Label("Reset Filters", systemImage: "arrow.uturn.backward")
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
        Text("Price Maintenance is available on macOS only.")
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
