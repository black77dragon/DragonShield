import SwiftUI
#if os(macOS)
    import AppKit
#endif

#if os(macOS)
    private enum PriceUpdatesColumnSpec: String, CaseIterable {
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
            case .auto: return 40
            case .currency: return 50
            case .latestPrice, .newPrice: return 80
            case .instrument: return 200
            case .actions: return 180
            case .newAsOf, .priceSource, .externalId: return 80
            default: return 100
            }
        }

        var idealWidth: CGFloat {
            switch self {
            case .instrument: return 260
            case .currency: return 70
            case .latestPrice: return 120
            case .asOf: return 120
            case .priceSource: return 120
            case .auto: return 60
            case .autoProvider: return 140
            case .externalId: return 120
            case .newPrice: return 120
            case .newAsOf: return 120
            case .manualSource: return 150
            case .actions: return 220
            }
        }

        var maxWidth: CGFloat {
            switch self {
            case .auto: return 60
            case .currency: return 80
            case .instrument: return 420
            case .actions: return 280
            case .externalId: return 150
            case .newAsOf: return 150
            case .newPrice: return 150
            case .priceSource: return 150
            default: return 260
            }
        }

        func clamped(_ width: CGFloat) -> CGFloat {
            max(minWidth, min(maxWidth, width))
        }

        static var defaultWidths: [String: CGFloat] {
            Dictionary(uniqueKeysWithValues: allCases.map { ($0.title, $0.idealWidth) })
        }

        static func spec(for title: String) -> PriceUpdatesColumnSpec? {
            allCases.first(where: { $0.title == title })
        }
    }

    private enum PriceUpdatesColumnWidthStorage {
        static func load() -> [String: CGFloat] {
            var resolved: [String: CGFloat] = [:]
            if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.priceUpdatesColWidths),
               let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
            {
                for (key, value) in decoded {
                    let width = CGFloat(value)
                    if let spec = PriceUpdatesColumnSpec.spec(for: key) {
                        resolved[key] = spec.clamped(width)
                    } else {
                        resolved[key] = max(60, width)
                    }
                }
            }
            // Always blend with defaults so missing keys still get reasonable sizes.
            PriceUpdatesColumnSpec.defaultWidths.forEach { resolved[$0.key] = resolved[$0.key] ?? $0.value }
            return resolved
        }

        static func persist(_ widths: [String: CGFloat]) {
            guard !widths.isEmpty else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.priceUpdatesColWidths)
                return
            }
            let payload = widths.mapValues { Double($0) }
            if let data = try? JSONEncoder().encode(payload) {
                UserDefaults.standard.set(data, forKey: UserDefaultsKeys.priceUpdatesColWidths)
            }
        }
    }
#endif

struct PriceUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = PriceUpdatesViewModel()
    @State private var sortOrder: [KeyPathComparator<PriceUpdatesViewModel.DisplayRow>] = [
        KeyPathComparator(\.instrumentSortKey),
    ]

    private let staleOptions: [Int] = [0, 7, 14, 30, 60, 90]
    private let providerOptions: [String] = ["coingecko", "finnhub", "yahoo", "mock"]

    private var sortedRows: [PriceUpdatesViewModel.DisplayRow] {
        guard !sortOrder.isEmpty else { return viewModel.rows }
        return viewModel.rows.sorted(using: sortOrder)
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
            case let .history(id):
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
                Text("Price Updates")
                    .font(.title2).bold()
                Text("Streamlined table to inspect and update instrument prices.")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Save Edited", action: { viewModel.saveEdited() })
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!viewModel.hasPendingEdits)
            Button("Save Column Width") {
                #if os(macOS)
                    if let tableView = PriceUpdatesTableHeaderStyler.findTableViewExternally() {
                        PriceUpdatesTableHeaderStyler.snapshotAndPersistExternal(tableView: tableView, coordinator: nil)
                    }
                #endif
            }
            Button("Load Column Width") {
                #if os(macOS)
                    if let tableView = PriceUpdatesTableHeaderStyler.findTableViewExternally() {
                        PriceUpdatesTableHeaderStyler.applyPersistedWidths(to: tableView)
                    }
                #endif
            }
            Button {
                viewModel.fetchLatestEnabled(for: viewModel.rows)
            } label: {
                VStack(spacing: 2) {
                    Text("Fetch Latest Prices")
                    Text("for selected Instruments")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(viewModel.rows.isEmpty)
            .tint(.green)
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
            Table(sortedRows, sortOrder: $sortOrder) {
                TableColumn(tableHeader("Instrument"), value: \PriceUpdatesViewModel.DisplayRow.instrumentSortKey) { row in
                    instrumentCell(row.instrument)
                }

                TableColumn(tableHeader("Curr"), value: \PriceUpdatesViewModel.DisplayRow.currencySortKey) { row in
                    Text(row.instrument.currency)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TableColumn(tableHeader("Latest Price"), value: \PriceUpdatesViewModel.DisplayRow.latestPriceSortKey) { row in
                    Text(viewModel.formatted(row.instrument.latestPrice))
                        .monospacedDigit()
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(row.state.autoEnabled ? Color.green.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Group {
                    TableColumn(tableHeader("As Of"), value: \PriceUpdatesViewModel.DisplayRow.asOfSortKey) { row in
                        Text(viewModel.formatAsOf(row.instrument.asOf, timeZoneId: dbManager.defaultTimeZone))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    TableColumn(tableHeader("Price Source"), value: \PriceUpdatesViewModel.DisplayRow.priceSourceSortKey) { row in
                        HStack(spacing: 4) {
                            Text(row.instrument.source ?? "")
                            if row.state.autoEnabled,
                               !row.state.lastStatus.isEmpty,
                               row.state.lastStatus.lowercased() != "ok"
                            {
                                Text("🚫").help("Last auto update failed: \(row.state.lastStatus)")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    TableColumn(tableHeader("Auto"), value: \PriceUpdatesViewModel.DisplayRow.autoSortKey) { row in
                        Toggle("", isOn: viewModel.bindingForAuto(row) {
                            viewModel.persistSourceIfComplete(row)
                        })
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    TableColumn(tableHeader("Auto Provider"), value: \PriceUpdatesViewModel.DisplayRow.autoProviderSortKey) { row in
                        Picker("", selection: viewModel.bindingForProvider(row) {
                            viewModel.persistSourceIfComplete(row)
                        }) {
                            Text("").tag("")
                            ForEach(providerOptions, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    TableColumn(tableHeader("External ID"), value: \PriceUpdatesViewModel.DisplayRow.externalIdSortKey) { row in
                        TextField("", text: viewModel.bindingForExternalId(row) {
                            viewModel.persistSourceIfComplete(row)
                        })
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Group {
                    TableColumn(tableHeader("New Price"), value: \PriceUpdatesViewModel.DisplayRow.newPriceSortKey) { row in
                        TextField("", text: viewModel.bindingForEditedPrice(row))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    TableColumn(tableHeader("New As Of"), value: \PriceUpdatesViewModel.DisplayRow.newAsOfSortKey) { row in
                        DatePicker("", selection: viewModel.bindingForEditedDate(row), displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    TableColumn(tableHeader("Manual Source"), value: \PriceUpdatesViewModel.DisplayRow.manualSourceSortKey) { row in
                        TextField("manual source", text: viewModel.bindingForEditedSource(row))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    TableColumn(tableHeader("Actions"), value: \PriceUpdatesViewModel.DisplayRow.actionsSortKey) { row in
                        HStack(spacing: 8) {
                            Button("Save") { viewModel.saveRow(row) }
                                .disabled(!viewModel.hasEdits(row.id))
                            Button("Revert") { viewModel.revertRow(row) }
                                .disabled(!viewModel.hasEdits(row.id))
                            Button("History") { viewModel.openHistory(row.id) }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .background(
                PriceUpdatesTableHeaderStyler()
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
                    selected: Set(viewModel.currencyFilters.map(PriceUpdatesViewModel.normalizeSource)),
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
                    let normalized = PriceUpdatesViewModel.normalizeSource(item)
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
    private struct PriceUpdatesTableHeaderStyler: NSViewRepresentable {
        private let headerColor = NSColor(calibratedRed: 233 / 255, green: 241 / 255, blue: 1.0, alpha: 1.0)
        weak static var lastTableView: NSTableView?

        final class Coordinator: NSObject {
            var columnWidths: [String: CGFloat] = PriceUpdatesColumnWidthStorage.load()
            weak var observedTableView: NSTableView?
            var applyingWidths = false
            var initialized = false

            deinit {
                if let tableView = observedTableView {
                    NotificationCenter.default.removeObserver(self, name: NSTableView.columnDidResizeNotification, object: tableView)
                }
            }

            @objc func columnDidResize(_ notification: Notification) {
                // Ignore resizes we trigger ourselves during apply.
                if applyingWidths {
                    return
                }

                guard let tableView = observedTableView,
                      notification.object as? NSTableView === tableView,
                      let column = notification.userInfo?["NSTableColumn"] as? NSTableColumn,
                      let index = tableView.tableColumns.firstIndex(of: column) else { return }

                guard let resolvedSpec = PriceUpdatesTableHeaderStyler.resolvedSpec(for: column, index: index) else { return }

                PriceUpdatesTableHeaderStyler.normalize(column: column, to: resolvedSpec)

                let clamped = resolvedSpec.clamped(column.width)
                if abs(column.width - clamped) > 0.5 {
                    column.width = clamped
                }
                columnWidths[resolvedSpec.title] = clamped
            }
        }

        func makeCoordinator() -> Coordinator { Coordinator() }
        func makeNSView(context _: Context) -> NSView { NSView() }

        func updateNSView(_ nsView: NSView, context: Context) {
            DispatchQueue.main.async {
                guard let tableView = findTableView(from: nsView) else { return }
                applyStyle(to: tableView)
                configureColumnSizingOnce(for: tableView, coordinator: context.coordinator)
            }
        }

        static func dismantleNSView(_: NSView, coordinator: Coordinator) {
            if let tableView = coordinator.observedTableView {
                NotificationCenter.default.removeObserver(coordinator, name: NSTableView.columnDidResizeNotification, object: tableView)
                coordinator.observedTableView = nil
            }
        }

        private func applyStyle(to tableView: NSTableView) {
            guard let headerView = tableView.headerView else { return }

            if let styledHeader = headerView as? PriceUpdatesHeaderView {
                if styledHeader.fillColor != headerColor {
                    styledHeader.fillColor = headerColor
                }
            } else {
                let replacement = PriceUpdatesHeaderView(frame: headerView.frame)
                replacement.fillColor = headerColor
                replacement.tableView = tableView
                replacement.autoresizingMask = headerView.autoresizingMask
                tableView.headerView = replacement
            }

            tableView.headerView?.needsDisplay = true
        }

        private func configureColumnSizingOnce(for tableView: NSTableView, coordinator: Coordinator) {
            guard !coordinator.initialized else { return }
            // Wait until all columns are present to avoid skipping identifier assignment.
            let expectedCount = PriceUpdatesColumnSpec.allCases.count
            guard tableView.tableColumns.count >= expectedCount else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.configureColumnSizingOnce(for: tableView, coordinator: coordinator)
                }
                return
            }

            coordinator.initialized = true
            coordinator.columnWidths = PriceUpdatesColumnWidthStorage.load()

            if coordinator.observedTableView !== tableView {
                if let previous = coordinator.observedTableView {
                    NotificationCenter.default.removeObserver(coordinator, name: NSTableView.columnDidResizeNotification, object: previous)
                }
                coordinator.observedTableView = tableView
                PriceUpdatesTableHeaderStyler.lastTableView = tableView
                NotificationCenter.default.addObserver(coordinator,
                                                       selector: #selector(Coordinator.columnDidResize(_:)),
                                                       name: NSTableView.columnDidResizeNotification,
                                                       object: tableView)
            }

            // Enforce fixed sizing and identifiers once, then apply persisted widths once.
            tableView.columnAutoresizingStyle = .noColumnAutoresizing
            normalizeColumns(in: tableView)

            var targetWidths = PriceUpdatesColumnSpec.defaultWidths
            coordinator.columnWidths.forEach { targetWidths[$0.key] = $0.value }

            coordinator.applyingWidths = true
            for (idx, column) in tableView.tableColumns.enumerated() {
                guard let spec = PriceUpdatesColumnSpec.spec(for: column.title)
                    ?? PriceUpdatesColumnSpec.spec(for: column.identifier.rawValue)
                    ?? PriceUpdatesColumnSpec.allCases[safe: idx] else { continue }
                let desired = spec.clamped(targetWidths[spec.title] ?? spec.idealWidth)
                column.minWidth = spec.minWidth
                column.maxWidth = spec.maxWidth
                column.width = desired
            }
            coordinator.applyingWidths = false
        }

        private func normalizeColumns(in tableView: NSTableView) {
            for (idx, column) in tableView.tableColumns.enumerated() {
                guard let spec = PriceUpdatesColumnSpec.spec(for: column.title)
                    ?? PriceUpdatesColumnSpec.spec(for: column.identifier.rawValue)
                    ?? PriceUpdatesColumnSpec.allCases[safe: idx] else { continue }
                let identifier = NSUserInterfaceItemIdentifier(spec.title)
                if column.identifier != identifier {
                    column.identifier = identifier
                }
                if column.title != spec.title {
                    column.title = spec.title
                }
            }
        }

        private static func resolvedSpec(for column: NSTableColumn, index: Int) -> PriceUpdatesColumnSpec? {
            if let titleSpec = PriceUpdatesColumnSpec.spec(for: column.title) {
                return titleSpec
            }
            if let idSpec = PriceUpdatesColumnSpec.spec(for: column.identifier.rawValue) {
                return idSpec
            }
            return PriceUpdatesColumnSpec.allCases[safe: index]
        }

        private static func normalize(column: NSTableColumn, to spec: PriceUpdatesColumnSpec) {
            let identifier = NSUserInterfaceItemIdentifier(spec.title)
            if column.identifier != identifier {
                column.identifier = identifier
            }
            if column.title != spec.title {
                column.title = spec.title
            }
        }

        private static func snapshotAndPersist(tableView: NSTableView, coordinator: Coordinator) {
            var snapshot: [String: CGFloat] = [:]
            for (idx, column) in tableView.tableColumns.enumerated() {
                guard let spec = resolvedSpec(for: column, index: idx) else { continue }
                let width = spec.clamped(column.width)
                snapshot[spec.title] = width
            }
            guard !snapshot.isEmpty else { return }
            if looksDefaultish(snapshot) { return }
            coordinator.columnWidths = snapshot
            PriceUpdatesColumnWidthStorage.persist(snapshot)
            let summary = snapshot
                .map { "\($0.key)=\(Int($0.value))" }
                .sorted()
                .joined(separator: ", ")
            LoggingService.shared.log("PriceUpdates widths saved: \(summary)", type: .info, logger: .ui)
        }

        #if os(macOS)
            fileprivate static func findTableViewExternally() -> NSTableView? {
                if let known = lastTableView {
                    return known
                }
                // Fallback: walk all windows and find the first NSTableView.
                for window in NSApp.windows {
                    if let table = deepFindTable(in: window.contentView) {
                        return table
                    }
                }
                return nil
            }

            private static func deepFindTable(in view: NSView?) -> NSTableView? {
                guard let view else { return nil }
                if let table = view as? NSTableView {
                    return table
                }
                for sub in view.subviews {
                    if let table = deepFindTable(in: sub) {
                        return table
                    }
                }
                return nil
            }

            fileprivate static func snapshotAndPersistExternal(tableView: NSTableView, coordinator: Coordinator?) {
                let dummy = coordinator ?? Coordinator()
                snapshotAndPersist(tableView: tableView, coordinator: dummy)
            }
        #endif

        fileprivate static func widthSummary(tableView: NSTableView) -> String {
            let parts = tableView.tableColumns.enumerated().compactMap { idx, col -> String? in
                guard let spec = resolvedSpec(for: col, index: idx) else { return nil }
                return "\(spec.title)=\(Int(col.width))"
            }
            return parts.sorted().joined(separator: ", ")
        }

        fileprivate static func widthMap(tableView: NSTableView) -> [String: CGFloat] {
            var result: [String: CGFloat] = [:]
            for (idx, col) in tableView.tableColumns.enumerated() {
                guard let spec = resolvedSpec(for: col, index: idx) else { continue }
                result[spec.title] = spec.clamped(col.width)
            }
            return result
        }

        fileprivate static func hasMeaningfulDelta(stored: [String: CGFloat], current: [String: CGFloat], tolerance: CGFloat = 1.0) -> Bool {
            for key in current.keys {
                let newWidth = current[key] ?? 0
                let oldWidth = stored[key] ?? 0
                if abs(newWidth - oldWidth) > tolerance {
                    return true
                }
            }
            return false
        }

        fileprivate static func looksDefaultish(_ map: [String: CGFloat]) -> Bool {
            // Heuristic: if primary columns are near their default/ideal values, treat as autosize noise.
            let defaults: [String: CGFloat] = [
                PriceUpdatesColumnSpec.instrument.title: PriceUpdatesColumnSpec.instrument.idealWidth,
                PriceUpdatesColumnSpec.currency.title: PriceUpdatesColumnSpec.currency.idealWidth,
                PriceUpdatesColumnSpec.latestPrice.title: PriceUpdatesColumnSpec.latestPrice.idealWidth,
            ]
            let tolerance: CGFloat = 2.0
            for (key, def) in defaults {
                guard let val = map[key] else { continue }
                if abs(val - def) > tolerance {
                    return false
                }
            }
            return true
        }

        #if os(macOS)
            fileprivate static func applyPersistedWidths(to tableView: NSTableView) {
                let stored = PriceUpdatesColumnWidthStorage.load()
                guard !stored.isEmpty else { return }
                for (idx, column) in tableView.tableColumns.enumerated() {
                    guard let spec = resolvedSpec(for: column, index: idx) else { continue }
                    let desired = spec.clamped(stored[spec.title] ?? spec.idealWidth)
                    column.width = desired
                    column.minWidth = spec.minWidth
                    column.maxWidth = spec.maxWidth
                }
            }
        #endif

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

    private final class PriceUpdatesHeaderView: NSTableHeaderView {
        var fillColor: NSColor = .controlBackgroundColor {
            didSet { needsDisplay = true }
        }

        override func draw(_ dirtyRect: NSRect) {
            fillColor.setFill()
            dirtyRect.fill()
            super.draw(dirtyRect)
        }
    }
#endif
