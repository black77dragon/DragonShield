import SwiftUI
#if os(macOS)
import AppKit
#endif

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

    private func tableHeader(_ titleKey: LocalizedStringKey) -> Text {
        Text(titleKey).font(.system(size: 13, weight: .semibold))
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
            Button {
                viewModel.fetchLatestEnabled()
            } label: {
                VStack(spacing: 2) {
                    Text("Fetch Latest Prices")
                    Text("for selected Instruments")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(viewModel.rows.isEmpty)
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
            TableColumn(tableHeader("Instrument"), value: \PriceMaintenanceTableRow.instrumentSortKey) { row in
                instrumentCell(row.source)
            }

            TableColumn(tableHeader("Curr"), value: \PriceMaintenanceTableRow.currencySortKey) { row in
                Text(row.source.currency)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TableColumn(tableHeader("Latest Price"), value: \PriceMaintenanceTableRow.latestPriceSortKey) { row in
                Text(viewModel.formatted(row.source.latestPrice))
                    .monospacedDigit()
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(viewModel.autoEnabled[row.source.id] ?? false ? Color.green.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Group {
                TableColumn(tableHeader("As Of"), value: \PriceMaintenanceTableRow.asOfSortKey) { row in
                    Text(viewModel.formatAsOf(row.source.asOf, timeZoneId: dbManager.defaultTimeZone))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn(tableHeader("Price Source"), value: \PriceMaintenanceTableRow.priceSourceSortKey) { row in
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

                TableColumn(tableHeader("Auto"), value: \PriceMaintenanceTableRow.autoSortKey) { row in
                    Toggle("", isOn: viewModel.bindingForAuto(row: row.source) {
                        viewModel.persistSourceIfComplete(row.source)
                    })
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                TableColumn(tableHeader("Auto Provider"), value: \PriceMaintenanceTableRow.autoProviderSortKey) { row in
                    Picker("", selection: viewModel.bindingForProvider(row: row.source) {
                        viewModel.persistSourceIfComplete(row.source)
                    }) {
                        Text("").tag("")
                        ForEach(providerOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn(tableHeader("External ID"), value: \PriceMaintenanceTableRow.externalIdSortKey) { row in
                    TextField("", text: viewModel.bindingForExternalId(row: row.source) {
                        viewModel.persistSourceIfComplete(row.source)
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Group {
                TableColumn(tableHeader("New Price"), value: \PriceMaintenanceTableRow.newPriceSortKey) { row in
                    TextField("", text: viewModel.bindingForEditedPrice(row.source.id))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                TableColumn(tableHeader("New As Of"), value: \PriceMaintenanceTableRow.newAsOfSortKey) { row in
                    DatePicker("", selection: viewModel.bindingForEditedDate(row.source.id), displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn(tableHeader("Manual Source"), value: \PriceMaintenanceTableRow.manualSourceSortKey) { row in
                    TextField("manual source", text: viewModel.bindingForEditedSource(row.source.id))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn(tableHeader("Actions"), value: \PriceMaintenanceTableRow.actionsSortKey) { row in
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
        .background(
            PriceMaintenanceTableHeaderStyler(
                priceSources: viewModel.availablePriceSources,
                selectedPriceSources: viewModel.normalizedPriceSourceFilters,
                currencies: viewModel.availableCurrencies,
                selectedCurrencies: Set(viewModel.currencyFilters.map(PriceMaintenanceViewModel.normalizeSource)),
                providers: viewModel.availableProviders,
                selectedProviders: viewModel.normalizedProviderFilters,
                autoStates: viewModel.availableAutoStates,
                selectedAutoStates: viewModel.normalizedAutoFilters,
                manualSources: viewModel.availableManualSources,
                selectedManualSources: viewModel.normalizedManualSourceFilters,
                onTogglePriceSource: { source in
                    viewModel.togglePriceSourceFilter(source)
                    viewModel.reload()
                },
                onClearPriceSources: {
                    viewModel.clearPriceSourceFilters()
                    viewModel.reload()
                },
                onToggleCurrency: { currency in
                    viewModel.toggleCurrencyFilter(currency)
                    viewModel.reload()
                },
                onClearCurrencies: {
                    viewModel.clearCurrencyFilters()
                    viewModel.reload()
                },
                onToggleProvider: { provider in
                    viewModel.toggleProviderFilter(provider)
                    viewModel.reload()
                },
                onClearProviders: {
                    viewModel.clearProviderFilters()
                    viewModel.reload()
                },
                onToggleAuto: { state in
                    viewModel.toggleAutoFilter(state)
                    viewModel.reload()
                },
                onClearAuto: {
                    viewModel.clearAutoFilters()
                    viewModel.reload()
                },
                onToggleManualSource: { source in
                    viewModel.toggleManualSourceFilter(source)
                    viewModel.reload()
                },
                onClearManualSources: {
                    viewModel.clearManualSourceFilters()
                    viewModel.reload()
                }
            )
        )
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

#if os(macOS)
private struct PriceMaintenanceTableHeaderStyler: NSViewRepresentable {
    private let headerColor = NSColor(calibratedRed: 233 / 255, green: 241 / 255, blue: 1.0, alpha: 1.0)
    let priceSources: [String]
    let selectedPriceSources: Set<String>
    let currencies: [String]
    let selectedCurrencies: Set<String>
    let providers: [String]
    let selectedProviders: Set<String>
    let autoStates: [String]
    let selectedAutoStates: Set<String>
    let manualSources: [String]
    let selectedManualSources: Set<String>
    let onTogglePriceSource: (String) -> Void
    let onClearPriceSources: () -> Void
    let onToggleCurrency: (String) -> Void
    let onClearCurrencies: () -> Void
    let onToggleProvider: (String) -> Void
    let onClearProviders: () -> Void
    let onToggleAuto: (String) -> Void
    let onClearAuto: () -> Void
    let onToggleManualSource: (String) -> Void
    let onClearManualSources: () -> Void

    final class Coordinator {
        var priceSourceHost: NSHostingView<HeaderFilterButton>?
        var currencyHost: NSHostingView<HeaderFilterButton>?
        var providerHost: NSHostingView<HeaderFilterButton>?
        var autoHost: NSHostingView<HeaderFilterButton>?
        var manualHost: NSHostingView<HeaderFilterButton>?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let tableView = findTableView(from: nsView) else { return }
            applyStyle(to: tableView)
            installPriceSourceFilter(in: tableView, context: context)
            installCurrencyFilter(in: tableView, context: context)
            installProviderFilter(in: tableView, context: context)
            installAutoFilter(in: tableView, context: context)
            installManualSourceFilter(in: tableView, context: context)
        }
    }

    private func installPriceSourceFilter(in tableView: NSTableView, context: Context) {
        guard let headerView = tableView.headerView else { return }
        context.coordinator.priceSourceHost = installFilter(
            columnTitle: "Price Source",
            availableItems: priceSources,
            selectedItems: selectedPriceSources,
            headerView: headerView,
            tableView: tableView,
            existingHost: context.coordinator.priceSourceHost,
            tooltip: "Filter Price Source",
            clearTitle: "Clear Price Source Filter",
            emptyMessage: "No price sources available",
            toggle: onTogglePriceSource,
            clear: onClearPriceSources
        )
    }

    private func installCurrencyFilter(in tableView: NSTableView, context: Context) {
        guard let headerView = tableView.headerView else { return }
        context.coordinator.currencyHost = installFilter(
            columnTitle: "Curr",
            availableItems: currencies,
            selectedItems: selectedCurrencies,
            headerView: headerView,
            tableView: tableView,
            existingHost: context.coordinator.currencyHost,
            tooltip: "Filter Currency",
            clearTitle: "Clear Currency Filter",
            emptyMessage: "No currencies available",
            toggle: onToggleCurrency,
            clear: onClearCurrencies
        )
    }

    private func installProviderFilter(in tableView: NSTableView, context: Context) {
        guard let headerView = tableView.headerView else { return }
        context.coordinator.providerHost = installFilter(
            columnTitle: "Auto Provider",
            availableItems: providers,
            selectedItems: selectedProviders,
            headerView: headerView,
            tableView: tableView,
            existingHost: context.coordinator.providerHost,
            tooltip: "Filter Auto Provider",
            clearTitle: "Clear Auto Provider Filter",
            emptyMessage: "No providers available",
            toggle: onToggleProvider,
            clear: onClearProviders
        )
    }

    private func installAutoFilter(in tableView: NSTableView, context: Context) {
        guard let headerView = tableView.headerView else { return }
        context.coordinator.autoHost = installFilter(
            columnTitle: "Auto",
            availableItems: autoStates,
            selectedItems: selectedAutoStates,
            headerView: headerView,
            tableView: tableView,
            existingHost: context.coordinator.autoHost,
            tooltip: "Filter Auto",
            clearTitle: "Clear Auto Filter",
            emptyMessage: "No auto states",
            toggle: onToggleAuto,
            clear: onClearAuto
        )
    }

    private func installManualSourceFilter(in tableView: NSTableView, context: Context) {
        guard let headerView = tableView.headerView else { return }
        context.coordinator.manualHost = installFilter(
            columnTitle: "Manual Source",
            availableItems: manualSources,
            selectedItems: selectedManualSources,
            headerView: headerView,
            tableView: tableView,
            existingHost: context.coordinator.manualHost,
            tooltip: "Filter Manual Source",
            clearTitle: "Clear Manual Source Filter",
            emptyMessage: "No manual sources",
            toggle: onToggleManualSource,
            clear: onClearManualSources
        )
    }

    private func installFilter(
        columnTitle: String,
        availableItems: [String],
        selectedItems: Set<String>,
        headerView: NSTableHeaderView,
        tableView: NSTableView,
        existingHost: NSHostingView<HeaderFilterButton>?,
        tooltip: String,
        clearTitle: String,
        emptyMessage: String,
        toggle: @escaping (String) -> Void,
        clear: @escaping () -> Void
    ) -> NSHostingView<HeaderFilterButton>? {
        guard let columnIndex = tableView.tableColumns.firstIndex(where: { $0.title == columnTitle }) else { return existingHost }

        let headerRect = headerView.headerRect(ofColumn: columnIndex)
        let buttonWidth: CGFloat = 34
        let resolvedWidth = max(min(buttonWidth, headerRect.width - 8), 24)
        let buttonFrame = NSRect(
            x: headerRect.maxX - resolvedWidth - 6,
            y: headerRect.minY + 2,
            width: resolvedWidth,
            height: max(headerRect.height - 4, 20)
        )

        let host: NSHostingView<HeaderFilterButton> = {
            if let existing = existingHost {
                existing.autoresizingMask = [.minXMargin]
                return existing
            }
            let view = NSHostingView(rootView: HeaderFilterButton(
                availableItems: availableItems,
                selectedNormalizedItems: selectedItems,
                toggleItem: toggle,
                clearItems: clear,
                emptyMessage: emptyMessage,
                clearTitle: clearTitle,
                helpText: tooltip
            ))
            view.autoresizingMask = [.minXMargin]
            return view
        }()

        host.rootView = HeaderFilterButton(
            availableItems: availableItems,
            selectedNormalizedItems: selectedItems,
            toggleItem: toggle,
            clearItems: clear,
            emptyMessage: emptyMessage,
            clearTitle: clearTitle,
            helpText: tooltip
        )

        if host.superview !== headerView {
            host.removeFromSuperview()
            headerView.addSubview(host)
        }

        host.frame = buttonFrame
        host.toolTip = tooltip
        return host
    }

    private func applyStyle(to tableView: NSTableView) {
        guard let headerView = tableView.headerView else { return }

        if let styledHeader = headerView as? PriceMaintenanceHeaderView {
            if styledHeader.fillColor != headerColor {
                styledHeader.fillColor = headerColor
            }
        } else {
            let replacement = PriceMaintenanceHeaderView(frame: headerView.frame)
            replacement.fillColor = headerColor
            replacement.tableView = tableView
            replacement.autoresizingMask = headerView.autoresizingMask
            tableView.headerView = replacement
        }

        tableView.headerView?.needsDisplay = true
    }

    private func findTableView(from view: NSView) -> NSTableView? {
        var visited = Set<ObjectIdentifier>()
        return findTableView(from: view, visited: &visited)
    }

    private func findTableView(from view: NSView, visited: inout Set<ObjectIdentifier>) -> NSTableView? {
        let identifier = ObjectIdentifier(view)
        guard !visited.contains(identifier) else { return nil }
        visited.insert(identifier)

        if let table = view as? NSTableView {
            return table
        }

        for subview in view.subviews {
            if let table = findTableView(from: subview, visited: &visited) {
                return table
            }
        }

        if let superview = view.superview {
            return findTableView(from: superview, visited: &visited)
        }

        return nil
    }
}

private struct HeaderFilterButton: View {
    let availableItems: [String]
    let selectedNormalizedItems: Set<String>
    let toggleItem: (String) -> Void
    let clearItems: () -> Void
    let emptyMessage: String
    let clearTitle: String
    let helpText: String

    var body: some View {
        Menu {
            if availableItems.isEmpty {
                if selectedNormalizedItems.isEmpty {
                    Text(emptyMessage).foregroundColor(.secondary)
                } else {
                    Button(clearTitle, action: clearItems)
                }
            } else {
                ForEach(availableItems, id: \.self) { item in
                    let normalized = PriceMaintenanceViewModel.normalizeSource(item)
                    Button {
                        toggleItem(item)
                    } label: {
                        HStack {
                            Text(item)
                            if selectedNormalizedItems.contains(normalized) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                if !selectedNormalizedItems.isEmpty {
                    Divider()
                    Button(clearTitle, action: clearItems)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedNormalizedItems.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                if !selectedNormalizedItems.isEmpty {
                    Text("\(selectedNormalizedItems.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(selectedNormalizedItems.isEmpty ? Color.clear : Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .disabled(availableItems.isEmpty && selectedNormalizedItems.isEmpty)
        .help(helpText)
    }
}

private final class PriceMaintenanceHeaderView: NSTableHeaderView {
    var fillColor: NSColor = NSColor.controlBackgroundColor {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}
#endif
