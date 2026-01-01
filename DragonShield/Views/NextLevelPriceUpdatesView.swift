import SwiftUI

struct NextLevelPriceUpdatesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var preferences: AppPreferences
    @StateObject private var viewModel = NextLevelPriceUpdatesViewModel()
    @State private var filter: UpdateFilter = .all
    @State private var sortOrder: [KeyPathComparator<NextLevelPriceUpdatesViewModel.DisplayRow>] =
        NextLevelPriceUpdatesViewModel.initialSortOrder

    private enum UpdateFilter: String, CaseIterable, Identifiable {
        case all
        case manual
        case auto
        case needsUpdate

        var id: String { rawValue }
    }

    private var baseRows: [NextLevelPriceUpdatesViewModel.DisplayRow] { viewModel.rows }

    private var manualCount: Int {
        baseRows.filter { viewModel.updateMode(for: $0) == .manual }.count
    }

    private var autoCount: Int {
        baseRows.filter { viewModel.updateMode(for: $0) == .auto }.count
    }

    private var needsUpdateCount: Int {
        baseRows.filter { viewModel.needsUpdate($0) }.count
    }

    private var filteredRows: [NextLevelPriceUpdatesViewModel.DisplayRow] {
        switch filter {
        case .all:
            return baseRows
        case .manual:
            return baseRows.filter { viewModel.updateMode(for: $0) == .manual }
        case .auto:
            return baseRows.filter { viewModel.updateMode(for: $0) == .auto }
        case .needsUpdate:
            return baseRows.filter { viewModel.needsUpdate($0) }
        }
    }

    private var sortedRows: [NextLevelPriceUpdatesViewModel.DisplayRow] {
        guard !sortOrder.isEmpty else { return filteredRows }
        return filteredRows.sorted(using: sortOrder)
    }

    private var visibleAutoRows: [NextLevelPriceUpdatesViewModel.DisplayRow] {
        filteredRows.filter { viewModel.updateMode(for: $0) == .auto }
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
        .onAppear { viewModel.attach(dbManager: dbManager) }
        .onChange(of: sortOrder) { _, newValue in
            NextLevelPriceUpdatesViewModel.updateSortOrder(newValue)
        }
        .sheet(item: $viewModel.activeSheet) { item in
            switch item {
            case .logs:
                LogViewerView().environmentObject(dbManager)
            case .report:
                FetchResultsReportView(
                    results: viewModel.fetchResults,
                    nameById: viewModel.nameByIdSnapshot,
                    providerById: viewModel.providerByIdSnapshot,
                    timeZoneId: preferences.defaultTimeZone
                )
            case .symbolHelp:
                SymbolFormatHelpView()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Price Update")
                    .font(.title2).bold()
                Text("Unified update modes and sources with fast, dense scanning.")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Save Manual Updates") { viewModel.saveEdited() }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!viewModel.hasPendingManualEdits)
                .help("Apply manual edits to all rows with new prices")
            Button("Fetch Latest Prices") {
                viewModel.fetchLatestSelected(for: visibleAutoRows)
            }
            .disabled(visibleAutoRows.isEmpty)
            .tint(.green)
            .help("Fetch latest prices for visible Auto instruments")
            Button("View Logs") { viewModel.activeSheet = .logs }
            Button("Symbol Formats") { viewModel.activeSheet = .symbolHelp }
        }
    }

    private var filtersBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                TextField("Search instruments, ticker, ISIN, valor, source, provider", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 320)
                    .onSubmit { viewModel.reload() }
                    .onChange(of: viewModel.searchText) { _, _ in
                        viewModel.scheduleSearch()
                    }
                Picker("", selection: $filter) {
                    Text("All (\(baseRows.count))").tag(UpdateFilter.all)
                    Text("Manual (\(manualCount))").tag(UpdateFilter.manual)
                    Text("Auto (\(autoCount))").tag(UpdateFilter.auto)
                    Text("Needs Update (\(needsUpdateCount))").tag(UpdateFilter.needsUpdate)
                }
                .pickerStyle(.segmented)
                Spacer(minLength: 0)
            }
            Text("Needs Update = missing price or older than \(NextLevelPriceUpdatesViewModel.staleThresholdDays)d")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
                    selected: Set(viewModel.currencyFilters.map(NextLevelPriceUpdatesViewModel.normalizeFilterValue)),
                    emptyLabel: "No currencies",
                    onToggle: { viewModel.toggleCurrencyFilter($0); viewModel.reload() },
                    onClear: { viewModel.clearCurrencyFilters(); viewModel.reload() }
                )
                filterMenu(
                    title: "Update Mode",
                    items: viewModel.availableUpdateModes,
                    selected: viewModel.normalizedUpdateModeFilters,
                    emptyLabel: "No update modes",
                    onToggle: { viewModel.toggleUpdateModeFilter($0); viewModel.reload() },
                    onClear: { viewModel.clearUpdateModeFilters(); viewModel.reload() }
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
                    let normalized = NextLevelPriceUpdatesViewModel.normalizeFilterValue(item)
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
    private var tableArea: some View {
        #if os(macOS)
            Table(sortedRows, sortOrder: $sortOrder) {
                TableColumn(tableHeader("Instrument"), value: \.instrumentSortKey) { row in
                    instrumentCell(row)
                }
                .width(min: 220, ideal: 280, max: 420)

                TableColumn(tableHeader("Current Price"), value: \.currentPriceSortKey) { row in
                    Text(viewModel.formattedPrice(row.instrument.latestPrice))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 90, ideal: 110, max: 140)

                TableColumn(tableHeader("As Of"), value: \.asOfSortKey) { row in
                    asOfCell(row)
                }
                .width(min: 90, ideal: 110, max: 130)

                TableColumn(tableHeader("Update Mode"), value: \.updateModeSortKey) { row in
                    updateModeCell(row)
                }
                .width(min: 90, ideal: 110, max: 130)

                TableColumn(tableHeader("Update Source")) { row in
                    updateSourceCell(row)
                }
                .width(min: 160, ideal: 200, max: 260)

                TableColumn(tableHeader("Update / Status"), value: \.lastUpdateSortKey) { row in
                    updateStatusCell(row)
                }
                .width(min: 220, ideal: 300, max: 360)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .font(Font.system(size: 12))
            .frame(minHeight: 420)
        #else
            Text("Price Update is available on macOS only.")
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.secondary)
        #endif
    }

    private func tableHeader(_ titleKey: LocalizedStringKey) -> Text {
        Text(titleKey).font(.system(size: 12, weight: .semibold))
    }

    @ViewBuilder
    private func instrumentCell(_ row: NextLevelPriceUpdatesViewModel.DisplayRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.instrument.name)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(row.instrument.name)
            HStack(spacing: 6) {
                if let ticker = row.instrument.ticker, !ticker.isEmpty {
                    Text(ticker)
                }
                if let isin = row.instrument.isin, !isin.isEmpty {
                    Text(isin)
                }
                if let valor = row.instrument.valorNr, !valor.isEmpty {
                    Text(valor)
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func asOfCell(_ row: NextLevelPriceUpdatesViewModel.DisplayRow) -> some View {
        let missing = row.instrument.latestPrice == nil
        let staleDays = viewModel.staleDays(for: row)
        let isStale = (staleDays ?? 0) > NextLevelPriceUpdatesViewModel.staleThresholdDays
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.formatAsOf(row.instrument.asOf, timeZoneId: preferences.defaultTimeZone))
                .foregroundColor(isStale ? .red : .primary)
            if missing {
                statusChip(text: "Missing", color: .red)
            } else if isStale, let days = staleDays {
                statusChip(text: "Stale \(days)d", color: .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func updateModeCell(_ row: NextLevelPriceUpdatesViewModel.DisplayRow) -> some View {
        let mode = viewModel.updateMode(for: row)
        Menu {
            Button("Auto") { viewModel.setUpdateMode(.auto, for: row) }
            Button("Manual") { viewModel.setUpdateMode(.manual, for: row) }
        } label: {
            modeChip(mode)
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func updateSourceCell(_ row: NextLevelPriceUpdatesViewModel.DisplayRow) -> some View {
        let mode = viewModel.updateMode(for: row)
        switch mode {
        case .auto:
            VStack(alignment: .leading, spacing: 4) {
                Picker("", selection: viewModel.bindingForProvider(row) {
                    viewModel.persistAutoState(for: row)
                }) {
                    Text("Select provider").tag("")
                    ForEach(viewModel.providerOptions, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)

                TextField("External ID", text: viewModel.bindingForExternalId(row) {
                    viewModel.persistAutoState(for: row)
                })
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            }
        case .manual:
            TextField("source", text: viewModel.bindingForEditedSource(row))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func updateStatusCell(_ row: NextLevelPriceUpdatesViewModel.DisplayRow) -> some View {
        let mode = viewModel.updateMode(for: row)
        switch mode {
        case .manual:
            HStack(spacing: 6) {
                TextField("New Price", text: viewModel.bindingForEditedPrice(row))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                    .controlSize(.small)
                DatePicker("", selection: viewModel.bindingForEditedDate(row), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .controlSize(.small)
                Button("Update") { viewModel.saveRow(row) }
                    .disabled(!viewModel.canSaveManual(row))
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                Button {
                    viewModel.revertRow(row)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!viewModel.hasManualEdits(row.id))
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Revert manual edits")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .auto:
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.autoStatusLabel(for: row))
                    .font(.caption)
                    .foregroundColor(viewModel.autoStatusColor(for: row))
                Text(viewModel.autoLastCheckedLabel(for: row, timeZoneId: preferences.defaultTimeZone))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func modeChip(_ mode: NextLevelPriceUpdatesViewModel.UpdateMode) -> some View {
        let color: Color = mode == .auto ? .green : .blue
        return Text(mode.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

#if DEBUG
    struct NextLevelPriceUpdatesView_Previews: PreviewProvider {
        static var previews: some View {
            NextLevelPriceUpdatesView()
                .environmentObject(DatabaseManager())
                .environmentObject(AppPreferences())
        }
    }
#endif
