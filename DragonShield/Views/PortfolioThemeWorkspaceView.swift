// DragonShield/Views/PortfolioThemeWorkspaceView.swift
// New Tabbed Workspace for Portfolio Theme details (Option 2)

import SwiftUI
#if canImport(Charts)
import Charts
#endif
#if os(macOS)
import AppKit
#endif

struct PortfolioThemeWorkspaceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let origin: String
    @Environment(\.dismiss) private var dismiss

    enum WorkspaceTab: String, CaseIterable, Identifiable {
        case overview
        case holdings
        case analytics
        case updates
        case settings

        var id: String { rawValue }
        var label: String {
            switch self {
            case .overview: return "Overview"
            case .holdings: return "Holdings"
            case .analytics: return "Analytics"
            case .updates: return "Updates"
            case .settings: return "Settings"
            }
        }
        var systemImage: String {
            switch self {
            case .overview: return "rectangle.grid.2x2"
            case .holdings: return "list.bullet.rectangle"
            case .analytics: return "chart.bar"
            case .updates: return "doc.text"
            case .settings: return "gearshape"
            }
        }
    }

    // Optional initial routing for external callers
    let initialTab: WorkspaceTab?
    let initialUpdatesSearch: String?
    let initialUpdatesSearchHint: String?

    @AppStorage(UserDefaultsKeys.portfolioThemeWorkspaceLastTab) private var lastTabRaw: String = WorkspaceTab.overview.rawValue
    @State private var selectedTab: WorkspaceTab = .overview

    @State private var theme: PortfolioTheme?
    @State private var valuation: ValuationSnapshot?
    @State private var loadingValuation = false
    // Classic editor references removed; Workspace is the default
    @State private var instrumentCurrencies: [Int: String] = [:]
    @State private var instrumentSectors: [Int: String] = [:]

    // Meta editing (Settings tab)
    @State private var name: String = ""
    @State private var code: String = ""
    @State private var statusId: Int = 0
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var descriptionText: String = ""
    @State private var institutionId: Int? = nil
    @State private var institutions: [DatabaseManager.InstitutionData] = []

    init(themeId: Int,
         origin: String,
         initialTab: WorkspaceTab? = nil,
         initialUpdatesSearch: String? = nil,
         initialUpdatesSearchHint: String? = nil) {
        self.themeId = themeId
        self.origin = origin
        self.initialTab = initialTab
        self.initialUpdatesSearch = initialUpdatesSearch
        self.initialUpdatesSearchHint = initialUpdatesSearchHint
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header strip
                header
                Divider()
                // Tabs content
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(WorkspaceTab.overview)
                        .tabItem { Label(WorkspaceTab.overview.label, systemImage: WorkspaceTab.overview.systemImage) }
                    holdingsTab
                        .tag(WorkspaceTab.holdings)
                        .tabItem { Label(WorkspaceTab.holdings.label, systemImage: WorkspaceTab.holdings.systemImage) }
                    analyticsTab
                        .tag(WorkspaceTab.analytics)
                        .tabItem { Label(WorkspaceTab.analytics.label, systemImage: WorkspaceTab.analytics.systemImage) }
                    updatesTab
                        .tag(WorkspaceTab.updates)
                        .tabItem { Label(WorkspaceTab.updates.label, systemImage: WorkspaceTab.updates.systemImage) }
                    settingsTab
                        .tag(WorkspaceTab.settings)
                        .tabItem { Label(WorkspaceTab.settings.label, systemImage: WorkspaceTab.settings.systemImage) }
                }
            }
            .navigationTitle("Theme Workspace: \(name)")
        }
        .frame(minWidth: 1200, idealWidth: 1400, minHeight: 720, idealHeight: 800)
        .onAppear {
            // Choose initial tab: explicit override > search in updates > last saved > default
            if let t = initialTab {
                selectedTab = t
            } else if initialUpdatesSearch != nil {
                selectedTab = .updates
            } else {
                selectedTab = WorkspaceTab(rawValue: lastTabRaw) ?? .overview
            }
            loadTheme()
            runValuation()
            loadInstrumentCurrencies()
        }
            .onChange(of: selectedTab) { _, newValue in
                lastTabRaw = newValue.rawValue
                if newValue == .overview || newValue == .analytics || newValue == .holdings { runValuation() }
            }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "—" : name)
                    .font(.title2).bold()
                HStack(spacing: 12) {
                    Tag(text: code)
                    if let s = statuses.first(where: { $0.id == statusId }) {
                        Tag(text: s.name, color: Color(hex: s.colorHex))
                    }
                    if let instId = institutionId, let inst = institutions.first(where: { $0.id == instId }) {
                        Tag(text: inst.name, color: .secondary)
                    }
                    if let t = theme, let archived = t.archivedAt {
                        Tag(text: "Archived: \(archived)", color: .orange)
                    }
                }
            }
            Spacer()
            HStack(spacing: 16) {
                // Quick stats in header (large, total bold)
                Text("Total: \(currency(valuation?.totalValueBase))")
                    .font(.title2).bold()
                    .accessibilityLabel("Total value \((valuation?.totalValueBase ?? 0).formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2))))")
                Text("Instruments: \(theme?.instrumentCount ?? 0)")
                    .font(.title2)
                    .accessibilityLabel("Instrument count \(theme?.instrumentCount ?? 0)")
                Button(role: .none) { runValuation() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                Button(role: .cancel) { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut("w", modifiers: .command)
                .help("Close")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Tabs
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if loadingValuation { ProgressView().controlSize(.small) }
                kpiRow
                #if canImport(Charts)
                HStack(alignment: .top, spacing: 16) {
                    actualAllocationDonut
                    deltasBar
                }
                .redacted(reason: loadingValuation ? .placeholder : [])
                #endif
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @State private var holdingsSearch: String = ""
    @FocusState private var focusHoldingsSearch: Bool
    @State private var holdingsColumns: Set<HoldingsTable.Column> = Set(HoldingsTable.Column.defaultVisible)
    @State private var showWidthsEditor: Bool = false
    @State private var holdingsReloadToken: Int = 0

    // Add/Delete Instrument state
    @State private var showAddInstrument: Bool = false
    @State private var addInstrumentQuery: String = ""
    @State private var addInstrumentId: Int = 0
    @State private var addResearchPct: Double = 0
    @State private var addUserPct: Double = 0
    @State private var addNotes: String = ""
    private var holdingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Holdings").font(.headline)
                Spacer()
                Menu {
                    Text("Columns").font(.caption).foregroundColor(.secondary)
                    Divider()
                    ForEach(HoldingsTable.Column.allCases) { col in
                        Toggle(isOn: Binding(
                            get: { holdingsColumns.contains(col) },
                            set: { on in
                                if on { holdingsColumns.insert(col) } else { holdingsColumns.remove(col) }
                                persistHoldingsColumns()
                            }
                        )) { Text(col == .actualChf ? "Actual \(dbManager.baseCurrency)" : col.title) }
                    }
                    Divider()
                    Button("Adjust Widths…") { showWidthsEditor = true }
                } label: {
                    Label("Columns", systemImage: "slider.horizontal.3")
                }
                Button(action: { showAddInstrument = true }) { Label("Add Instrument", systemImage: "plus") }
            }
            HStack(spacing: 8) {
                TextField("Search instruments or notes", text: $holdingsSearch)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusHoldingsSearch)
                if !holdingsSearch.isEmpty {
                    Button("Clear") { holdingsSearch = "" }
                        .buttonStyle(.link)
                }
            }
            // Hidden shortcut to focus search (Cmd-F)
            Button("") { focusHoldingsSearch = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
            HoldingsTable(themeId: themeId, isArchived: theme?.archivedAt != nil, search: holdingsSearch, columns: holdingsColumns, reloadToken: holdingsReloadToken)
                .environmentObject(dbManager)
        }
        .padding(20)
        .onAppear(perform: restoreHoldingsColumns)
        .sheet(isPresented: $showWidthsEditor) { ColumnWidthsEditor(onSave: { holdingsReloadToken += 1 }) }
        .sheet(isPresented: $showAddInstrument) { addInstrumentSheet }
    }

    private func persistHoldingsColumns() {
        let raw = holdingsColumns.map { $0.rawValue }.sorted().joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColumns)
    }
    private func restoreHoldingsColumns() {
        guard let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColumns), !raw.isEmpty else { return }
        let set = Set(raw.split(separator: ",").compactMap { HoldingsTable.Column(rawValue: String($0)) })
        if !set.isEmpty { holdingsColumns = set }
        // One-time soft migration: ensure Actual [baseCurrency] column is visible
        if !holdingsColumns.contains(.actualChf) {
            holdingsColumns.insert(.actualChf)
            persistHoldingsColumns()
        }
    }

    // MARK: - Column Widths Editor (sheet in parent scope)
    private func ColumnWidthsEditor(onSave: @escaping () -> Void) -> some View {
        ColumnWidthsEditorSheet(onSave: onSave)
    }

    private struct ColumnWidthsEditorSheet: View {
        @Environment(\.dismiss) private var dismiss
        @State private var widths: [HoldingsTable.Column: Double] = [:]
        var onSave: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Adjust Column Widths").font(.headline)
                ForEach(HoldingsTable.Column.allCases) { col in
                    HStack(spacing: 12) {
                        Text(col.title).frame(width: 160, alignment: .leading)
                        Slider(value: Binding(
                            get: { widths[col] ?? defaultWidth(for: col) },
                            set: { widths[col] = $0 }
                        ), in: 40...600)
                        Text("\(Int(widths[col] ?? defaultWidth(for: col))) pt").frame(width: 80, alignment: .trailing)
                    }
                }
                HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save") { persist(); onSave(); dismiss() }.keyboardShortcut(.defaultAction) }
            }
            .padding(20)
            .frame(width: 520)
            .onAppear(perform: restore)
        }

        private func defaultWidth(for col: HoldingsTable.Column) -> Double {
            switch col {
            case .instrument: return 300
            case .notes: return 200
            default: return 80
            }
        }

        private func restore() {
            guard let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColWidths) else { return }
            var map: [HoldingsTable.Column: Double] = [:]
            for part in raw.split(separator: ",") {
                let kv = part.split(separator: ":")
                if kv.count == 2, let c = HoldingsTable.Column(rawValue: String(kv[0])), let w = Double(kv[1]) {
                    map[c] = max(40, w)
                }
            }
            if !map.isEmpty { widths = map }
        }
        private func persist() {
            let raw = HoldingsTable.Column.allCases.compactMap { col -> String? in
                if let w = widths[col] { return "\(col.rawValue):\(Int(w))" }
                return nil
            }.joined(separator: ",")
            UserDefaults.standard.set(raw, forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColWidths)
        }
    }

    // MARK: - Add Instrument Sheet
    private var addInstrumentSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Add Instrument to \(name)").font(.headline); Spacer() }
                .padding(.horizontal, 20).padding(.top, 16)
            Form {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("Instrument").frame(width: 120, alignment: .leading)
                        MacComboBox(
                            items: availableInstruments().map { $0.name },
                            text: $addInstrumentQuery,
                            onSelectIndex: { idx in
                                let items = availableInstruments()
                                if idx >= 0 && idx < items.count { addInstrumentId = items[idx].id }
                            }
                        )
                        .frame(minWidth: 360)
                    }
                    HStack(alignment: .center, spacing: 8) {
                        Text("Research %").frame(width: 120, alignment: .leading)
                        TextField("", value: $addResearchPct, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    HStack(alignment: .center, spacing: 8) {
                        Text("User %").frame(width: 120, alignment: .leading)
                        TextField("", value: $addUserPct, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("Notes").frame(width: 120, alignment: .leading)
                        TextField("", text: $addNotes)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 360)
                    }
                }
                .padding(.vertical, 12)
            }
            Divider()
            HStack { Spacer(); Button("Cancel") { showAddInstrument = false }; Button("Add") { addInstrument() }.keyboardShortcut(.defaultAction).disabled(!addValid) }
                .padding(20)
        }
        .frame(width: 600)
        .onAppear { addUserPct = addResearchPct; addInstrumentQuery = ""; addInstrumentId = 0 }
    }

    private func availableInstruments() -> [(id: Int, name: String)] {
        let inTheme = Set(dbManager.listThemeAssets(themeId: themeId).map { $0.instrumentId })
        return dbManager.fetchAssets().map { ($0.id, $0.name) }.filter { !inTheme.contains($0.id) }
    }
    private var addValid: Bool { addInstrumentId > 0 && addResearchPct >= 0 && addResearchPct <= 100 && addUserPct >= 0 && addUserPct <= 100 }
    private func addInstrument() {
        let userPct = addUserPct == addResearchPct ? nil : addUserPct
        let notes = addNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if dbManager.createThemeAsset(themeId: themeId, instrumentId: addInstrumentId, researchPct: addResearchPct, userPct: userPct, notes: notes.isEmpty ? nil : notes) != nil {
            showAddInstrument = false
            addInstrumentQuery = ""; addInstrumentId = 0; addResearchPct = 0; addUserPct = 0; addNotes = ""
            holdingsReloadToken += 1
            runValuation()
        }
    }

    // Bulk actions removed per request

    @State private var analyticsRange: AnalyticsRange = .ytd
    @State private var showBenchmark: Bool = false
    @State private var benchmarkSymbol: String = "^GSPC"
    private var analyticsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Analytics").font(.headline)
                HStack(spacing: 8) {
                    Picker("Range", selection: $analyticsRange) {
                        ForEach(AnalyticsRange.allCases) { r in Text(r.label).tag(r) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Benchmark", isOn: $showBenchmark)
                    TextField("^GSPC", text: $benchmarkSymbol)
                        .frame(width: 120)
                        .disabled(!showBenchmark)
                    Spacer()
                    if showBenchmark {
                        Text("Overlay coming soon").font(.caption).foregroundColor(.secondary)
                    }
                }
                #if canImport(Charts)
                let cols = [GridItem(.flexible(minimum: 280), spacing: 16), GridItem(.flexible(minimum: 280), spacing: 16)]
                if loadingValuation {
                    ProgressView().controlSize(.small)
                }
                LazyVGrid(columns: cols, alignment: .leading, spacing: 16) {
                    Group { actualAllocationDonut }
                        .analyticsCard()
                    Group { contributionBars }
                        .analyticsCard()
                    Group { currencyExposureDonut }
                        .analyticsCard()
                    Group { sectorExposureBars }
                        .analyticsCard()
                    Group { moversByDeltaBars }
                        .analyticsCard()
                }
                .redacted(reason: loadingValuation ? .placeholder : [])
                #endif
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private enum AnalyticsRange: String, CaseIterable, Identifiable { case oneM, threeM, ytd, oneY, all; var id: String { rawValue }; var label: String { switch self { case .oneM: return "1M"; case .threeM: return "3M"; case .ytd: return "YTD"; case .oneY: return "1Y"; case .all: return "All" } } }

    

    private var updatesTab: some View {
        PortfolioThemeUpdatesView(themeId: themeId, initialSearchText: initialUpdatesSearch, searchHint: initialUpdatesSearchHint)
            .environmentObject(dbManager)
    }

    private var settingsTab: some View {
        Form {
            Section(header: Text("Theme")) {
                let labelWidth: CGFloat = 120
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Name").frame(width: labelWidth, alignment: .leading)
                    TextField("", text: $name).frame(width: 320)
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Code").frame(width: labelWidth, alignment: .leading)
                    Text(code).foregroundColor(.secondary)
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Status").frame(width: labelWidth, alignment: .leading)
                    Picker("", selection: $statusId) {
                        ForEach(statuses) { s in Text(s.name).tag(s.id) }
                    }
                    .labelsHidden().frame(width: 240)
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Institution").frame(width: labelWidth, alignment: .leading)
                    Picker("", selection: $institutionId) {
                        Text("None").tag(nil as Int?)
                        ForEach(institutions) { inst in Text(inst.name).tag(inst.id as Int?) }
                    }
                    .labelsHidden().frame(width: 240)
                    Spacer()
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("Description").frame(width: labelWidth, alignment: .leading)
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                }
                HStack {
                    Spacer()
                    Button("Save Changes") { saveTheme() }.keyboardShortcut(.defaultAction)
                }
            }
            Section(header: Text("Danger Zone")) {
                if let t = theme, t.archivedAt == nil {
                    HStack {
                        Text("Archive theme to prevent edits.")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Archive Theme", role: .destructive) { confirmArchive = true }
                    }
                } else {
                    HStack {
                        Text("Unarchive to allow edits, or soft delete.")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Unarchive") { performUnarchive() }
                        Button("Soft Delete", role: .destructive) { confirmSoftDelete = true }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .confirmationDialog("Archive this theme?", isPresented: $confirmArchive, titleVisibility: .visible) {
            Button("Archive", role: .destructive) { performArchive() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("You can unarchive later. Edits will be locked.") }
        .confirmationDialog("Soft delete this theme?", isPresented: $confirmSoftDelete, titleVisibility: .visible) {
            Button("Soft Delete", role: .destructive) { performSoftDelete() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This hides the theme from lists. Restore via recycle bin only.") }
    }

    @State private var confirmArchive = false
    @State private var confirmSoftDelete = false

    private func performArchive() {
        if dbManager.archivePortfolioTheme(id: themeId) {
            theme = dbManager.getPortfolioTheme(id: themeId)
        }
    }
    private func performUnarchive() {
        let defaultStatus = statuses.first { $0.isDefault }?.id ?? statusId
        if dbManager.unarchivePortfolioTheme(id: themeId, statusId: defaultStatus) {
            theme = dbManager.getPortfolioTheme(id: themeId)
            statusId = defaultStatus
        }
    }
    private func performSoftDelete() {
        if dbManager.softDeletePortfolioTheme(id: themeId) {
            dismiss()
        }
    }

    // MARK: - Overview widgets
    private var kpiRow: some View {
        HStack(spacing: 12) {
            KPI(title: "Total Value (\(dbManager.baseCurrency))", value: currency(valuation?.totalValueBase))
            KPI(title: "Instruments", value: String(theme?.instrumentCount ?? 0))
            KPI(title: "Positions as of", value: dateStr(valuation?.positionsAsOf))
            KPI(title: "FX as of", value: dateStr(valuation?.fxAsOf))
            if let v = valuation, v.excludedFxCount > 0 || v.excludedPriceCount > 0 {
                KPI(title: "Excluded", value: "FX \(v.excludedFxCount) / Price \(v.excludedPriceCount)", accent: .orange)
            }
        }
    }

    #if canImport(Charts)
    private var actualAllocationDonut: some View {
        let rows = (valuation?.rows ?? []).filter { $0.status == .ok && $0.actualPct > 0 }
        let data = rows.map { (name: $0.instrumentName, value: $0.actualPct) }
        let names = data.map { $0.name }
        let palette: [Color] = [.blue, .green, .orange, .pink, .purple, .teal, .red, .mint, .indigo, .brown, .cyan, .yellow]
        let colors: [Color] = names.enumerated().map { palette[$0.offset % palette.count] }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Allocation by Actual %").font(.title3).bold()
            HStack(alignment: .top, spacing: 16) {
                Chart(data, id: \.name) { row in
                    SectorMark(angle: .value("Actual %", row.value), innerRadius: .ratio(0.55), angularInset: 1.5)
                        .foregroundStyle(by: .value("Instrument", row.name))
                }
                .chartForegroundStyleScale(domain: names, range: colors)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .frame(height: 320)
                .accessibilityLabel("Allocation by Actual percent, donut chart")
                VStack(alignment: .leading, spacing: 6) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(names.enumerated()), id: \.0) { idx, name in
                                HStack(spacing: 8) {
                                    Circle().fill(colors[idx]).frame(width: 10, height: 10)
                                    Text(shortName(name, max: 18)).font(.caption).lineLimit(1).help(name)
                                }
                            }
                        }
                    }
                }
                .frame(width: 220)
            }
        }
    }

    private var deltasBar: some View {
        let items = (valuation?.rows ?? []).map { (name: $0.instrumentName, delta: ($0.deltaUserPct ?? 0)) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Delta (Actual − User %)").font(.title3).bold()
            Chart(items, id: \.name) { it in
                BarMark(x: .value("Delta", it.delta), y: .value("Instrument", it.name))
                    .foregroundStyle(it.delta >= 0 ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
            }
            .chartXAxisLabel("%", alignment: .trailing)
            .frame(minWidth: 360, maxWidth: .infinity, minHeight: 320)
            .accessibilityLabel("Delta percentage bar chart")
        }
    }

    private var contributionBars: some View {
        let rows = (valuation?.rows ?? []).filter { $0.status == .ok }
        let top = rows.sorted { $0.currentValueBase > $1.currentValueBase }.prefix(12)
        struct Item: Identifiable { let id = UUID(); let name: String; let value: Double }
        let items = top.map { Item(name: $0.instrumentName, value: $0.currentValueBase) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Top Contribution (\(dbManager.baseCurrency))").font(.title3).bold()
            Chart(items) { it in
                BarMark(x: .value("Value", it.value), y: .value("Instrument", it.name))
                    .foregroundStyle(Theme.primaryAccent)
            }
            .chartXAxisLabel(dbManager.baseCurrency, alignment: .trailing)
            .frame(minHeight: 280)
            .accessibilityLabel("Top contribution bar chart")
        }
    }

    private var currencyExposureDonut: some View {
        // Aggregate by instrument currency
        let rows = (valuation?.rows ?? []).filter { $0.status == .ok }
        var buckets: [String: Double] = [:]
        for r in rows {
            let cur = instrumentCurrencies[r.instrumentId] ?? "—"
            buckets[cur, default: 0] += r.currentValueBase
        }
        let data = buckets.map { (currency: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
        let names = data.map { $0.currency }
        let palette: [Color] = [.blue, .green, .orange, .pink, .purple, .teal, .red, .mint, .indigo, .brown, .cyan, .yellow]
        let colors: [Color] = names.enumerated().map { palette[$0.offset % palette.count] }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Currency Exposure").font(.title3).bold()
            HStack(alignment: .top, spacing: 16) {
                Chart(data, id: \.currency) { row in
                    SectorMark(angle: .value("Value", row.value), innerRadius: .ratio(0.55), angularInset: 1.5)
                        .foregroundStyle(by: .value("Currency", row.currency))
                }
                .chartForegroundStyleScale(domain: names, range: colors)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .frame(height: 280)
                .accessibilityLabel("Currency exposure donut chart")
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(names.enumerated()), id: \.0) { idx, name in
                        HStack(spacing: 8) {
                            Circle().fill(colors[idx]).frame(width: 10, height: 10)
                            Text(name).font(.caption)
                        }
                    }
                }
                .frame(width: 160)
            }
        }
    }
    private var moversByDeltaBars: some View {
        let rows = (valuation?.rows ?? []).filter { $0.status == .ok }
        // top 10 by absolute delta to user target
        struct Item: Identifiable { let id = UUID(); let name: String; let delta: Double }
        let items = rows.compactMap { r -> Item? in
            guard let d = r.deltaUserPct else { return nil }
            return Item(name: r.instrumentName, delta: d)
        }
        .sorted { abs($0.delta) > abs($1.delta) }
        .prefix(10)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Top Movers (Δ Actual − User %)").font(.title3).bold()
            Chart(items) { it in
                BarMark(x: .value("Δ", it.delta), y: .value("Instrument", it.name))
                    .foregroundStyle(it.delta >= 0 ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
            }
            .frame(minHeight: 280)
            .accessibilityLabel("Top movers by delta bar chart")
        }
    }

    private var sectorExposureBars: some View {
        // Aggregate by sector (fallback "Unknown")
        let rows = (valuation?.rows ?? []).filter { $0.status == .ok }
        var buckets: [String: Double] = [:]
        for r in rows {
            let sec = (instrumentSectors[r.instrumentId] ?? "Unknown").trimmingCharacters(in: .whitespacesAndNewlines)
            buckets[sec.isEmpty ? "Unknown" : sec, default: 0] += r.currentValueBase
        }
        struct Item: Identifiable { let id = UUID(); let name: String; let value: Double }
        let items = buckets.map { Item(name: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Sector Exposure (\(dbManager.baseCurrency))").font(.title3).bold()
            Chart(items) { it in
                BarMark(x: .value("Value", it.value), y: .value("Sector", it.name))
            }
            .frame(minHeight: 280)
            .accessibilityLabel("Sector exposure bar chart")
        }
    }
    #endif

    // MARK: - Data
    private func loadTheme() {
        guard let fetched = dbManager.getPortfolioTheme(id: themeId) else { return }
        theme = fetched
        name = fetched.name
        code = fetched.code
        statusId = fetched.statusId
        descriptionText = fetched.description ?? ""
        institutionId = fetched.institutionId
        statuses = dbManager.fetchPortfolioThemeStatuses()
        institutions = dbManager.fetchInstitutions()
    }

    private func runValuation() {
        loadingValuation = true
        Task {
            let fxService = FXConversionService(dbManager: dbManager)
            let service = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
            let snap = service.snapshot(themeId: themeId)
            await MainActor.run {
                self.valuation = snap
                self.loadingValuation = false
                self.loadInstrumentSectors()
            }
        }
    }

    private func saveTheme() {
        guard var current = theme else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        current.name = trimmedName
        current.statusId = statusId
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if dbManager.updatePortfolioTheme(id: current.id, name: current.name, description: desc.isEmpty ? nil : desc, institutionId: institutionId, statusId: current.statusId, archivedAt: current.archivedAt) {
            loadTheme()
        }
    }

    // MARK: - Utils
    private func currency(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func dateStr(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        return f.string(from: d)
    }

    private func shortName(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        let head = s.prefix(max - 1)
        return head + "…"
    }

    private func loadInstrumentCurrencies() {
        var map: [Int: String] = [:]
        for row in dbManager.fetchAssets() {
            map[row.id] = row.currency
        }
        instrumentCurrencies = map
    }

    private func loadInstrumentSectors() {
        var map: [Int: String] = [:]
        for id in valuation?.rows.map({ $0.instrumentId }) ?? [] {
            if let d = dbManager.fetchInstrumentDetails(id: id) {
                map[id] = d.sector ?? ""
            }
        }
        instrumentSectors = map
    }
}

// MARK: - Simple KPI view
private struct KPI: View {
    let title: String
    let value: String
    var accent: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(accent)
        }
        .padding(12)
        .frame(minWidth: 200, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
    }
}

// Lightweight card styling for analytics tiles
private extension View {
    func analyticsCard() -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2))
            )
    }
}

// MARK: - Simple Tag view
private struct Tag: View {
    let text: String
    var color: Color = .secondary
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().stroke(color.opacity(0.8)))
    }
}

// MARK: - Holdings Table (read-only summary)
private struct HoldingsTable: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let isArchived: Bool
    var search: String = ""
    var columns: Set<Column>
    var reloadToken: Int = 0
    @State private var rows: [ValuationRow] = []
    @State private var total: Double = 0
    @State private var saving: Set<Int> = [] // instrumentId currently saving
    @State private var edits: [Int: Edit] = [:] // instrumentId -> current editable fields
    @State private var invalidKeys: Set<String> = [] // "<instrumentId>:<field>" markers for subtle validation
    @State private var tableWidth: CGFloat = 0
    @State private var sortField: Column = .instrument
    @State private var sortAscending: Bool = true
    @State private var colWidths: [Column: CGFloat] = [:]
    @State private var updateCounts: [Int: Int] = [:]
    @State private var openUpdates: UpdatesTarget?
    @State private var confirmRemoveId: Int? = nil
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if rows.isEmpty {
                Text("No holdings").foregroundColor(.secondary)
            } else {
                header
                    .background(GeometryReader { proxy in
                        Color.clear
                            .onAppear { tableWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { _, newWidth in tableWidth = newWidth }
                    })
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(sortedRows) { r in
                            HStack(spacing: 8) {
                                if columns.contains(.instrument) {
                                    Text(r.instrumentName)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .padding(6)
                                        .frame(width: width(for: .instrument), alignment: .leading)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
                                }
                                if resizable(.instrument) { resizeSpacer(for: .instrument) }
                                if columns.contains(.research) {
                                    TextField("", value: bindingDouble(for: r.instrumentId, field: .research), format: .number)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: width(for: .research))
                                        .disabled(isArchived)
                                        .onSubmit { saveRow(r.instrumentId) }
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(invalidKeys.contains(key(for: r.instrumentId, field: .research)) ? Color.red.opacity(0.6) : Color.gray.opacity(0.25)))
                                        .help("0–100")
                                }
                                if resizable(.research) { resizeSpacer(for: .research) }
                                if columns.contains(.user) {
                                    TextField("", value: bindingDouble(for: r.instrumentId, field: .user), format: .number)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: width(for: .user))
                                        .disabled(isArchived)
                                        .onSubmit { saveRow(r.instrumentId) }
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(invalidKeys.contains(key(for: r.instrumentId, field: .user)) ? Color.red.opacity(0.6) : Color.gray.opacity(0.25)))
                                        .help("0–100")
                                }
                                if resizable(.user) { resizeSpacer(for: .user) }
                                if columns.contains(.actual) {
                                    Text(fmtPct(r.actualPct))
                                        .frame(width: width(for: .actual), alignment: .trailing)
                                }
                                if resizable(.actual) { resizeSpacer(for: .actual) }
                                if columns.contains(.delta) {
                                    Text(fmtPct(r.deltaUserPct))
                                        .frame(width: width(for: .delta), alignment: .trailing)
                                        .foregroundColor((r.deltaUserPct ?? 0) >= 0 ? .green : .red)
                                }
                                if resizable(.delta) { resizeSpacer(for: .delta) }
                                if columns.contains(.actualChf) {
                                    Text(r.currentValueBase, format: .currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
                                        .frame(width: width(for: .actualChf), alignment: .trailing)
                                }
                                if resizable(.actualChf) { resizeSpacer(for: .actualChf) }
                                if columns.contains(.notes) {
                                    TextField("Notes", text: bindingNotes(for: r.instrumentId))
                                        .textFieldStyle(.roundedBorder)
                                        .padding(.vertical, 2)
                                        .frame(minWidth: width(for: .notes), maxWidth: .infinity, alignment: .leading)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
                                        .disabled(isArchived)
                                        .onSubmit { saveRow(r.instrumentId) }
                                }
                                if resizable(.notes) { resizeSpacer(for: .notes) }
                                if !isArchived {
                                    Button {
                                        confirmRemoveId = r.instrumentId
                                    } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless)
                                    .help("Remove from theme")
                                }
                                // Updates column — requested at the very end (after trash)
                                
                                Button {
                                    openUpdates = UpdatesTarget(themeId: themeId, instrumentId: r.instrumentId, instrumentName: r.instrumentName)
                                } label: {
                                    let c = updateCounts[r.instrumentId] ?? 0
                                    Text(c > 0 ? "📝 \(c)" : "📝")
                                }
                                .buttonStyle(.borderless)
                                .frame(width: 44)
                                .help("Instrument updates")
                                .accessibilityLabel(Text("Instrument updates for \(r.instrumentName). Count: \(updateCounts[r.instrumentId] ?? 0)"))
                                .keyboardShortcut(.return, modifiers: .command)
                                
                                if saving.contains(r.instrumentId) { ProgressView().controlSize(.small) }
                            }
                            .font(.system(.body, design: .monospaced))
                            .contextMenu {
                                Button("Instrument Updates…") {
                                    openUpdates = UpdatesTarget(themeId: themeId, instrumentId: r.instrumentId, instrumentName: r.instrumentName)
                                }
                            }
                        }
                    }
                }
                // Totals row (Research/User %)
                HStack(spacing: 12) {
                    let rTot = researchTotal
                    let uTot = userTotal
                    let rOk = abs(rTot - 100.0) < 0.01
                    let uOk = abs(uTot - 100.0) < 0.01
                    Label("Research sum \(rTot, format: .number)%", systemImage: rOk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(rOk ? .green : .orange)
                    Label("User sum \(uTot, format: .number)%", systemImage: uOk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(uOk ? .green : .orange)
                    Text("Total: \(total, format: .currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))")
                }
                .font(.caption)
                .padding(.top, 6)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showToast {
                Text(toastMessage)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.75)))
                    .foregroundColor(.white)
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .onAppear { restoreWidths(); load() }
        .onChange(of: reloadToken) { _, _ in load() }
        .sheet(item: $openUpdates) { t in
            InstrumentUpdatesView(
                themeId: t.themeId,
                instrumentId: t.instrumentId,
                instrumentName: t.instrumentName,
                themeName: dbManager.getPortfolioTheme(id: t.themeId)?.name ?? "",
                valuation: nil,
                onClose: { loadUpdateCounts() }
            )
            .environmentObject(dbManager)
        }
        .confirmationDialog(
            "Remove this instrument from the theme?",
            isPresented: Binding(get: { confirmRemoveId != nil }, set: { if !$0 { confirmRemoveId = nil } })
        ) {
            Button("Remove — Do. Or do not. There is no try.", role: .destructive) {
                if let id = confirmRemoveId { removeInstrument(id) }
                confirmRemoveId = nil
            }
            Button("Cancel", role: .cancel) { confirmRemoveId = nil }
        } message: {
            Text("Once removed, even a Jedi can't undo with a wave. ✨")
        }
    }

    private let defaultNumWidth: CGFloat = 80
    private func width(for col: Column) -> CGFloat {
        // Notes uses min width; actual width expands to fill
        if col == .notes { return colWidths[col] ?? 200 }
        if col == .instrument { return colWidths[col] ?? 300 }
        if col == .actualChf { return colWidths[col] ?? 140 }
        return colWidths[col] ?? defaultNumWidth
    }

    private var header: some View {
        HStack(spacing: 8) {
            if columns.contains(.instrument) { sortHeader(.instrument, title: "Instrument").frame(width: width(for: .instrument), alignment: .leading) }
            if resizable(.instrument) { resizeHandle(for: .instrument) }
            if columns.contains(.research) { sortHeader(.research, title: "Research %").frame(width: width(for: .research), alignment: .trailing) }
            if resizable(.research) { resizeHandle(for: .research) }
            if columns.contains(.user) { sortHeader(.user, title: "User %").frame(width: width(for: .user), alignment: .trailing) }
            if resizable(.user) { resizeHandle(for: .user) }
            if columns.contains(.actual) { sortHeader(.actual, title: "Actual %").frame(width: width(for: .actual), alignment: .trailing) }
            if resizable(.actual) { resizeHandle(for: .actual) }
            if columns.contains(.delta) { sortHeader(.delta, title: "Δ Actual-User").frame(width: width(for: .delta), alignment: .trailing) }
            if resizable(.delta) { resizeHandle(for: .delta) }
            if columns.contains(.actualChf) { sortHeader(.actualChf, title: "Actual \(dbManager.baseCurrency)").frame(width: width(for: .actualChf), alignment: .trailing).accessibilityLabel("Actual \(dbManager.baseCurrency)") }
            if resizable(.actualChf) { resizeHandle(for: .actualChf) }
            // Notes first (flex)
            if columns.contains(.notes) { sortHeader(.notes, title: "Notes").frame(minWidth: width(for: .notes), maxWidth: .infinity, alignment: .leading) }
            // Updates header (emoji) after Notes — always visible
            Text("📝").frame(width: 44, alignment: .center)
            if resizable(.notes) { resizeHandle(for: .notes) }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func resizable(_ col: Column) -> Bool { true }
    private func resizeSpacer(for col: Column) -> some View {
        // Invisible spacer to match resize handle width in header, keeping column alignment
        Rectangle().fill(Color.clear).frame(width: 6, height: 18)
    }
    private func resizeHandle(for col: Column) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.001)) // wide hit area
            .frame(width: 6, height: 18)
            .overlay(Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 2))
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                var w = width(for: col) + value.translation.width
                w = max(40, min(600, w))
                colWidths[col] = w
            }.onEnded { _ in
                persistWidths()
            })
            .onTapGesture(count: 2) { autoFit(col) }
            .help("Drag to resize column")
    }

    private func autoFit(_ col: Column) {
        let padding: CGFloat = 24 // approximate inner padding/decoration
        var target: CGFloat = defaultNumWidth
        switch col {
        case .instrument:
            let maxNameWidth: CGFloat = rows.reduce(80) { acc, r in
                max(acc, measureText(r.instrumentName, monospaced: false))
            }
            target = max(160, min(600, maxNameWidth + padding))
        case .research:
            let candidates = rows.map { editableResearch($0.instrumentId) } + [100.0, 0.0]
            let maxW = candidates.reduce(60) { acc, v in
                max(acc, measureText(String(format: "%.2f", v), monospaced: true))
            }
            target = max(60, min(200, maxW + padding))
        case .user:
            let candidates = rows.map { editableUser($0.instrumentId) } + [100.0, 0.0]
            let maxW = candidates.reduce(60) { acc, v in
                max(acc, measureText(String(format: "%.2f", v), monospaced: true))
            }
            target = max(60, min(200, maxW + padding))
        case .actual:
            let vals = rows.map { $0.actualPct } + [0, 100]
            let maxW = vals.reduce(60) { acc, v in
                max(acc, measureText(String(format: "%.2f", v), monospaced: true))
            }
            target = max(60, min(200, maxW + padding))
        case .delta:
            let vals = rows.compactMap { $0.deltaUserPct } + [-100, 0, 100]
            let maxW = vals.reduce(60) { acc, v in
                max(acc, measureText(String(format: "%.2f", v), monospaced: true))
            }
            target = max(60, min(220, maxW + padding))
        case .actualChf:
            let codes = dbManager.baseCurrency
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = codes
            f.maximumFractionDigits = 2
            let maxStr = rows.reduce("0") { acc, r in
                let s = f.string(from: NSNumber(value: r.currentValueBase)) ?? acc
                return (s.count > acc.count) ? s : acc
            }
            let maxW = measureText(maxStr, monospaced: false)
            target = max(100, min(240, maxW + padding))
        case .notes:
            target = 300
        }
        colWidths[col] = target
        persistWidths()
    }

    private func measureText(_ s: String, monospaced: Bool) -> CGFloat {
        #if os(macOS)
        let font: NSFont = monospaced ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) : NSFont.systemFont(ofSize: 13)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let w = (s as NSString).size(withAttributes: attrs).width
        return ceil(w)
        #else
        return CGFloat(s.count) * 7
        #endif
    }

    private func load() {
        let fx = FXConversionService(dbManager: dbManager)
        let service = PortfolioValuationService(dbManager: dbManager, fxService: fx)
        let snap = service.snapshot(themeId: themeId)
        rows = snap.rows.sorted { $0.instrumentName < $1.instrumentName }
        // seed editable fields from valuation rows
        var dict: [Int: Edit] = [:]
        for r in rows {
            dict[r.instrumentId] = Edit(research: r.researchTargetPct, user: r.userTargetPct, notes: r.notes ?? "")
        }
        edits = dict
        total = snap.totalValueBase
        restoreSort()
        loadUpdateCounts()
    }

    private func loadUpdateCounts() {
        // Always enabled
        var map: [Int: Int] = [:]
        for r in rows {
            map[r.instrumentId] = dbManager.countInstrumentUpdates(themeId: themeId, instrumentId: r.instrumentId)
        }
        updateCounts = map
    }

    private func fmtPct(_ v: Double?) -> String {
        guard let x = v else { return "—" }
        return String(format: "%.2f", x)
    }
    private var sortedRows: [ValuationRow] {
        var arr = filteredRows
        switch sortField {
        case .instrument:
            arr.sort { l, r in
                let c = l.instrumentName.localizedCaseInsensitiveCompare(r.instrumentName)
                if c == .orderedSame { return l.instrumentId < r.instrumentId }
                return sortAscending ? (c == .orderedAscending) : (c == .orderedDescending)
            }
        case .research:
            arr.sort { l, r in
                let lv = editableResearch(l.instrumentId)
                let rv = editableResearch(r.instrumentId)
                if lv == rv { return tieBreak(l, r) }
                return sortAscending ? (lv < rv) : (lv > rv)
            }
        case .user:
            arr.sort { l, r in
                let lv = editableUser(l.instrumentId)
                let rv = editableUser(r.instrumentId)
                if lv == rv { return tieBreak(l, r) }
                return sortAscending ? (lv < rv) : (lv > rv)
            }
        case .actual:
            arr.sort { l, r in
                let lv = l.actualPct
                let rv = r.actualPct
                if lv == rv { return tieBreak(l, r) }
                return sortAscending ? (lv < rv) : (lv > rv)
            }
        case .delta:
            arr.sort { l, r in
                let lNil = l.deltaUserPct == nil
                let rNil = r.deltaUserPct == nil
                if lNil != rNil { return rNil } // nils last
                let lv = l.deltaUserPct ?? 0
                let rv = r.deltaUserPct ?? 0
                if lv == rv { return tieBreak(l, r) }
                return sortAscending ? (lv < rv) : (lv > rv)
            }
        case .notes:
            arr.sort { l, r in
                let ln = editableNotes(l.instrumentId).localizedCaseInsensitiveCompare(editableNotes(r.instrumentId))
                if ln == .orderedSame { return tieBreak(l, r) }
                return sortAscending ? (ln == .orderedAscending) : (ln == .orderedDescending)
            }
        case .actualChf:
            arr.sort { l, r in
                let lv = l.currentValueBase
                let rv = r.currentValueBase
                if lv == rv { return tieBreak(l, r) }
                return sortAscending ? (lv < rv) : (lv > rv)
            }
        }
        return arr
    }
    private func tieBreak(_ l: ValuationRow, _ r: ValuationRow) -> Bool {
        if l.instrumentName != r.instrumentName {
            return l.instrumentName < r.instrumentName
        }
        return l.instrumentId < r.instrumentId
    }
    private func editableResearch(_ id: Int) -> Double { edits[id]?.research ?? rows.first(where: { $0.instrumentId == id })?.researchTargetPct ?? 0 }
    private func editableUser(_ id: Int) -> Double { edits[id]?.user ?? rows.first(where: { $0.instrumentId == id })?.userTargetPct ?? 0 }
    private func editableNotes(_ id: Int) -> String { edits[id]?.notes ?? rows.first(where: { $0.instrumentId == id })?.notes ?? "" }

    private func sortHeader(_ col: Column, title: String) -> some View {
        Button {
            if sortField == col { sortAscending.toggle() } else { sortField = col; sortAscending = (col == .instrument) }
            persistSort()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if sortField == col {
                    Text(sortAscending ? "▲" : "▼").foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Sort by \(title)")
    }
    private var filteredRows: [ValuationRow] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows }
        let ql = q.lowercased()
        return rows.filter { r in
            if r.instrumentName.lowercased().contains(ql) { return true }
            if let n = r.notes?.lowercased(), n.contains(ql) { return true }
            return false
        }
    }

    // MARK: - Editing helpers
    private enum Field { case research, user }
    private func key(for instrumentId: Int, field: Field) -> String {
        "\(instrumentId):\(field == .research ? "research" : "user")"
    }
    private func bindingDouble(for instrumentId: Int, field: Field) -> Binding<Double> {
        Binding<Double>(
            get: {
                if let e = edits[instrumentId] { return field == .research ? e.research : e.user }
                return 0
            },
            set: { newValue in
                let clamped = max(0, min(100, newValue))
                var e = edits[instrumentId] ?? Edit(research: 0, user: 0, notes: "")
                if field == .research { e.research = clamped } else { e.user = clamped }
                edits[instrumentId] = e
                let k = key(for: instrumentId, field: field)
                if newValue != clamped { invalidKeys.insert(k) } else { invalidKeys.remove(k) }
            }
        )
    }
    private func bindingNotes(for instrumentId: Int) -> Binding<String> {
        Binding<String>(
            get: { edits[instrumentId]?.notes ?? "" },
            set: { newValue in
                var e = edits[instrumentId] ?? Edit(research: 0, user: 0, notes: "")
                e.notes = String(newValue.prefix(NoteEditorView.maxLength))
                edits[instrumentId] = e
            }
        )
    }

    private func saveRow(_ instrumentId: Int) {
        guard let e = edits[instrumentId] else { return }
        saving.insert(instrumentId)
        DispatchQueue.global(qos: .userInitiated).async {
            let updated = dbManager.updateThemeAsset(
                themeId: themeId,
                instrumentId: instrumentId,
                researchPct: e.research,
                userPct: e.user,
                notes: e.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : e.notes
            )
            DispatchQueue.main.async {
                saving.remove(instrumentId)
                if updated != nil {
                    load() // refresh valuation/deltas after saving
                    showQuickToast("Saved")
                } else {
                    LoggingService.shared.log("updateThemeAsset failed themeId=\(themeId) instrumentId=\(instrumentId)", logger: .ui)
                    showQuickToast("Save failed")
                }
            }
        }
    }

    private func showQuickToast(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { showToast = false }
        }
    }

    private func persistSort() {
        let dir = sortAscending ? "asc" : "desc"
        UserDefaults.standard.set("\(sortField.rawValue)|\(dir)", forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsSort)
    }
    private func restoreSort() {
        guard let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsSort) else { return }
        let parts = raw.split(separator: "|")
        guard parts.count == 2, let col = Column(rawValue: String(parts[0])) else { return }
        sortField = col
        sortAscending = (parts[1] == "asc")
    }

    private struct Edit { var research: Double; var user: Double; var notes: String }
    private struct UpdatesTarget: Identifiable { let themeId: Int; let instrumentId: Int; let instrumentName: String; var id: Int { instrumentId } }

    // Totals computed from current editable values
    private var researchTotal: Double {
        let ids = rows.map { $0.instrumentId }
        let sum = ids.reduce(0.0) { $0 + editableResearch($1) }
        return (sum * 100).rounded() / 100
    }
    private var userTotal: Double {
        let ids = rows.map { $0.instrumentId }
        let sum = ids.reduce(0.0) { $0 + editableUser($1) }
        return (sum * 100).rounded() / 100
    }

    // Visible columns
    enum Column: String, CaseIterable, Identifiable, Hashable {
        case instrument, research, user, actual, delta, actualChf, notes
        var id: String { rawValue }
        var title: String {
            switch self {
            case .instrument: return "Instrument"
            case .research: return "Research %"
            case .user: return "User %"
            case .actual: return "Actual %"
            case .delta: return "Δ Actual-User"
            case .actualChf: return "Actual CHF"
            case .notes: return "Notes"
            }
        }
        static let defaultVisible: [Column] = [.instrument, .research, .user, .actual, .delta, .actualChf, .notes]
    }

    // MARK: - Column widths persistence
    private func restoreWidths() {
        guard let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColWidths) else { return }
        var map: [Column: CGFloat] = [:]
        for part in raw.split(separator: ",") {
            let kv = part.split(separator: ":")
            if kv.count == 2, let c = Column(rawValue: String(kv[0])), let w = Double(kv[1]) {
                map[c] = max(40, CGFloat(w))
            }
        }
        if !map.isEmpty { colWidths = map }
    }
    private func persistWidths() {
        let raw = Column.allCases.compactMap { col -> String? in
            if let w = colWidths[col] { return "\(col.rawValue):\(Int(w))" }
            return nil
        }.joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColWidths)
    }
    // Editor as a helper view
    @ViewBuilder
    private func ColumnWidthsEditor(onSave: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjust Column Widths").font(.headline)
            ForEach(Column.allCases) { col in
                HStack {
                    Text(col == .actualChf ? "Actual \(dbManager.baseCurrency)" : col.title).frame(width: 140, alignment: .leading)
                    Slider(value: Binding(
                        get: { Double(width(for: col)) },
                        set: { colWidths[col] = CGFloat($0) }
                    ), in: 40...600)
                    Text("\(Int(width(for: col))) pt").frame(width: 80, alignment: .trailing)
                }
            }
            HStack {
                Spacer()
                Button(role: .cancel) { persistWidths(); onSave() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func removeInstrument(_ instrumentId: Int) {
        guard !isArchived else { return }
        if dbManager.removeThemeAsset(themeId: themeId, instrumentId: instrumentId) {
            load()
        }
    }
}
