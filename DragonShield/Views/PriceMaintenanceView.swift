import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
private enum PriceMaintenanceColumnSpec: String, CaseIterable {
    case instrument = "Instrument"
    case currency = "Curr"
    case latestPrice = "Latest Price"
    case asOf = "As Of"
    case priceSource = "Price Source"
    case auto = "Auto"
    case autoProvider = "Auto Provider"
    case externalId = "External ID"
    case newPrice = "New Price"
    case newAsOf = "New As Of"
    case manualSource = "Manual Source"
    case actions = "Actions"

    var title: String { rawValue }
    var minWidth: CGFloat {
        switch self {
        case .auto: return 60
        case .currency: return 70
        case .latestPrice, .newPrice: return 110
        case .instrument: return 200
        case .actions: return 180
        default: return 120
        }
    }
    var idealWidth: CGFloat {
        switch self {
        case .instrument: return 260
        case .currency: return 80
        case .latestPrice: return 140
        case .asOf: return 150
        case .priceSource: return 150
        case .auto: return 70
        case .autoProvider: return 160
        case .externalId: return 180
        case .newPrice: return 140
        case .newAsOf: return 150
        case .manualSource: return 170
        case .actions: return 220
        }
    }
    var maxWidth: CGFloat {
        switch self {
        case .auto: return 100
        case .currency: return 110
        case .instrument: return 420
        case .actions: return 280
        default: return 260
        }
    }

    func clamped(_ width: CGFloat) -> CGFloat {
        max(minWidth, min(maxWidth, width))
    }

    static var defaultWidths: [String: CGFloat] {
        Dictionary(uniqueKeysWithValues: PriceMaintenanceColumnSpec.allCases.map { ($0.title, $0.idealWidth) })
    }

    static func spec(for title: String) -> PriceMaintenanceColumnSpec? {
        Self.allCases.first(where: { $0.title == title })
    }
}

private enum PriceMaintenanceColumnWidthStorage {
    static func load() -> [String: CGFloat] {
        var resolved: [String: CGFloat] = [:]

        // Prefer JSON payload.
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.pricesMaintenanceColWidths),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            for (key, value) in decoded {
                let width = CGFloat(value)
                if let spec = PriceMaintenanceColumnSpec.spec(for: key) {
                    resolved[key] = spec.clamped(width)
                } else {
                    resolved[key] = max(60, width)
                }
            }
        } else if let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.pricesMaintenanceColWidths) {
            // Fallback for any legacy CSV format: "Instrument:280,Curr:90,..."
            for part in raw.split(separator: ",") {
                let kv = part.split(separator: ":")
                guard kv.count == 2, let width = Double(kv[1]) else { continue }
                let key = String(kv[0])
                if let spec = PriceMaintenanceColumnSpec.spec(for: key) {
                    resolved[key] = spec.clamped(CGFloat(width))
                } else {
                    resolved[key] = max(60, CGFloat(width))
                }
            }
        }

        return resolved
    }

    static func persist(_ widths: [String: CGFloat]) {
        guard !widths.isEmpty else {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.pricesMaintenanceColWidths)
            return
        }
        let payload = widths.mapValues { Double($0) }
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.pricesMaintenanceColWidths)
        }
    }
}
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
            columnFiltersBar
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
            PriceMaintenanceTableHeaderStyler()
        )
        .frame(minHeight: 420)
        #else
        Text("Price Maintenance is available on macOS only.")
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.secondary)
        #endif
    }

    private var columnFiltersBar: some View {
        #if os(macOS)
        HStack(spacing: 10) {
            filterMenu(
                title: "Price Source",
                items: viewModel.availablePriceSources,
                selected: viewModel.normalizedPriceSourceFilters,
                emptyLabel: "No price sources",
                onToggle: { viewModel.togglePriceSourceFilter($0); viewModel.reload() },
                onClear: { viewModel.clearPriceSourceFilters(); viewModel.reload() }
            )
            filterMenu(
                title: "Curr",
                items: viewModel.availableCurrencies,
                selected: Set(viewModel.currencyFilters.map(PriceMaintenanceViewModel.normalizeSource)),
                emptyLabel: "No currencies",
                onToggle: { viewModel.toggleCurrencyFilter($0); viewModel.reload() },
                onClear: { viewModel.clearCurrencyFilters(); viewModel.reload() }
            )
            filterMenu(
                title: "Auto Provider",
                items: viewModel.availableProviders,
                selected: viewModel.normalizedProviderFilters,
                emptyLabel: "No providers",
                onToggle: { viewModel.toggleProviderFilter($0); viewModel.reload() },
                onClear: { viewModel.clearProviderFilters(); viewModel.reload() }
            )
            filterMenu(
                title: "Auto",
                items: viewModel.availableAutoStates,
                selected: viewModel.normalizedAutoFilters,
                emptyLabel: "No auto states",
                onToggle: { viewModel.toggleAutoFilter($0); viewModel.reload() },
                onClear: { viewModel.clearAutoFilters(); viewModel.reload() }
            )
            filterMenu(
                title: "Manual Source",
                items: viewModel.availableManualSources,
                selected: viewModel.normalizedManualSourceFilters,
                emptyLabel: "No manual sources",
                onToggle: { viewModel.toggleManualSourceFilter($0); viewModel.reload() },
                onClear: { viewModel.clearManualSourceFilters(); viewModel.reload() }
            )
            Spacer()
        }
        .font(.system(size: 12, weight: .semibold))
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private func filterMenu(
        title: String,
        items: [String],
        selected: Set<String>,
        emptyLabel: String,
        onToggle: @escaping (String) -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        let labelText = selected.isEmpty ? title : "\(title) (\(selected.count))"
        Menu {
            if items.isEmpty {
                Text(emptyLabel).foregroundColor(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    let normalized = PriceMaintenanceViewModel.normalizeSource(item)
                    Button {
                        onToggle(item)
                    } label: {
                        HStack {
                            Text(item)
                            if selected.contains(normalized) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                if !selected.isEmpty {
                    Divider()
                    Button("Clear \(title) Filter", action: onClear)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(labelText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(selected.isEmpty ? 0.08 : 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .disabled(items.isEmpty && selected.isEmpty)
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

    final class Coordinator: NSObject {
        var columnWidths: [String: CGFloat] = PriceMaintenanceColumnWidthStorage.load()
        weak var observedTableView: NSTableView?

        deinit {
            if let tableView = observedTableView {
                NotificationCenter.default.removeObserver(self, name: NSTableView.columnDidResizeNotification, object: tableView)
            }
        }

        @objc func columnDidResize(_ notification: Notification) {
            guard let tableView = observedTableView,
                  notification.object as? NSTableView === tableView,
                  let column = notification.userInfo?["NSTableColumn"] as? NSTableColumn,
                  let spec = PriceMaintenanceColumnSpec.spec(for: column.title) else { return }

            let clamped = spec.clamped(column.width)
            if abs(column.width - clamped) > 0.5 {
                column.width = clamped
            }
            columnWidths[spec.title] = clamped
            PriceMaintenanceColumnWidthStorage.persist(columnWidths)
        }
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
            configureColumnSizing(for: tableView, coordinator: context.coordinator)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let tableView = coordinator.observedTableView {
            NotificationCenter.default.removeObserver(coordinator, name: NSTableView.columnDidResizeNotification, object: tableView)
            coordinator.observedTableView = nil
        }
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

    private func configureColumnSizing(for tableView: NSTableView, coordinator: Coordinator) {
        coordinator.columnWidths = PriceMaintenanceColumnWidthStorage.load()
        if coordinator.observedTableView !== tableView {
            if let previous = coordinator.observedTableView {
                NotificationCenter.default.removeObserver(coordinator, name: NSTableView.columnDidResizeNotification, object: previous)
            }
            coordinator.observedTableView = tableView
            NotificationCenter.default.addObserver(coordinator,
                                                   selector: #selector(Coordinator.columnDidResize(_:)),
                                                   name: NSTableView.columnDidResizeNotification,
                                                   object: tableView)
        }

        var targetWidths = PriceMaintenanceColumnSpec.defaultWidths
        coordinator.columnWidths.forEach { targetWidths[$0.key] = $0.value }

        // Keep manual sizing and rely on scroll view for extra width.
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        for column in tableView.tableColumns {
            guard let spec = PriceMaintenanceColumnSpec.spec(for: column.title) else { continue }
            let desired = spec.clamped(targetWidths[spec.title] ?? spec.idealWidth)
            column.minWidth = spec.minWidth
            column.maxWidth = spec.maxWidth
            if abs(column.width - desired) > 0.5 {
                column.width = desired
            }
        }
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

private final class PriceMaintenanceHeaderView: NSTableHeaderView {
    var fillColor: NSColor = NSColor.controlBackgroundColor {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }
}
#endif
