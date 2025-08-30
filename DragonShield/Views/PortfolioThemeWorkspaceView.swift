// DragonShield/Views/PortfolioThemeWorkspaceView.swift
// New Tabbed Workspace for Portfolio Theme details (Option 2)

import SwiftUI
#if canImport(Charts)
import Charts
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

    @AppStorage(UserDefaultsKeys.portfolioThemeWorkspaceLastTab) private var lastTabRaw: String = WorkspaceTab.overview.rawValue
    @State private var selectedTab: WorkspaceTab = .overview

    @State private var theme: PortfolioTheme?
    @State private var valuation: ValuationSnapshot?
    @State private var loadingValuation = false
    @State private var showClassicDetail = false
    @State private var instrumentCurrencies: [Int: String] = [:]

    // Meta editing (Settings tab)
    @State private var name: String = ""
    @State private var code: String = ""
    @State private var statusId: Int = 0
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var descriptionText: String = ""
    @State private var institutionId: Int? = nil
    @State private var institutions: [DatabaseManager.InstitutionData] = []

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
            selectedTab = WorkspaceTab(rawValue: lastTabRaw) ?? .overview
            loadTheme()
            runValuation()
            loadInstrumentCurrencies()
        }
        .onChange(of: selectedTab) { _, newValue in
            lastTabRaw = newValue.rawValue
            if newValue == .overview || newValue == .analytics || newValue == .holdings { runValuation() }
        }
        .sheet(isPresented: $showClassicDetail) {
            PortfolioThemeDetailView(themeId: themeId, origin: origin) { _ in } onArchive: {} onUnarchive: { _ in } onSoftDelete: {}
                .environmentObject(dbManager)
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
                Button(role: .none) { runValuation() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                Button { showClassicDetail = true } label: {
                    Label("Open Classic", systemImage: "square.on.square")
                }
                .help("Open the classic detail editor for full controls")
                .keyboardShortcut("k", modifiers: .command)
                Button(role: .cancel) { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Tabs
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                kpiRow
                #if canImport(Charts)
                HStack(alignment: .top, spacing: 16) {
                    actualAllocationDonut
                    deltasBar
                }
                #endif
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @State private var holdingsSearch: String = ""
    @FocusState private var focusHoldingsSearch: Bool
    @State private var holdingsColumns: Set<HoldingsTable.Column> = Set(HoldingsTable.Column.defaultVisible)
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
                        )) { Text(col.title) }
                    }
                } label: {
                    Label("Columns", systemImage: "slider.horizontal.3")
                }
                Button { showClassicDetail = true } label: { Label("Edit in Classic", systemImage: "pencil") }
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
            HoldingsTable(themeId: themeId, isArchived: theme?.archivedAt != nil, search: holdingsSearch, columns: holdingsColumns)
                .environmentObject(dbManager)
        }
        .padding(20)
        .onAppear(perform: restoreHoldingsColumns)
    }

    private func persistHoldingsColumns() {
        let raw = holdingsColumns.map { $0.rawValue }.sorted().joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColumns)
    }
    private func restoreHoldingsColumns() {
        guard let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColumns), !raw.isEmpty else { return }
        let set = Set(raw.split(separator: ",").compactMap { HoldingsTable.Column(rawValue: String($0)) })
        if !set.isEmpty { holdingsColumns = set }
    }

    private var analyticsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Analytics").font(.headline)
                Text("Early preview: basic allocation analytics below. More coming soon (currency exposure, contribution, factor buckets).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #if canImport(Charts)
                actualAllocationDonut
                contributionBars
                currencyExposureDonut
                #endif
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var updatesTab: some View {
        PortfolioThemeUpdatesView(themeId: themeId, initialSearchText: nil, searchHint: nil)
            .environmentObject(dbManager)
    }

    private var settingsTab: some View {
        Form {
            Section(header: Text("Theme")) {
                HStack { Text("Name"); Spacer(); TextField("", text: $name).frame(width: 320) }
                HStack { Text("Code"); Spacer(); Text(code).foregroundColor(.secondary) }
                HStack {
                    Text("Status"); Spacer()
                    Picker("", selection: $statusId) {
                        ForEach(statuses) { s in Text(s.name).tag(s.id) }
                    }
                    .labelsHidden().frame(width: 240)
                }
                HStack {
                    Text("Institution"); Spacer()
                    Picker("", selection: $institutionId) {
                        Text("None").tag(nil as Int?)
                        ForEach(institutions) { inst in Text(inst.name).tag(inst.id as Int?) }
                    }
                    .labelsHidden().frame(width: 240)
                }
                VStack(alignment: .leading) {
                    Text("Description")
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                }
                HStack {
                    Spacer()
                    Button("Save Changes") { saveTheme() }.keyboardShortcut(.defaultAction)
                }
            }
            if let t = theme, t.archivedAt == nil {
                Section(header: Text("Actions")) {
                    Button("Archive in Classic…", role: .destructive) { showClassicDetail = true }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
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
    @State private var rows: [ValuationRow] = []
    @State private var total: Double = 0
    @State private var saving: Set<Int> = [] // instrumentId currently saving
    @State private var edits: [Int: Edit] = [:] // instrumentId -> current editable fields

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if rows.isEmpty {
                Text("No holdings").foregroundColor(.secondary)
            } else {
                header
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredRows) { r in
                            HStack(spacing: 8) {
                                if columns.contains(.instrument) {
                                    Text(r.instrumentName)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                if columns.contains(.research) {
                                    TextField("", value: bindingDouble(for: r.instrumentId, field: .research), format: .number)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: numWidth)
                                        .disabled(isArchived)
                                        .onSubmit { saveRow(r.instrumentId) }
                                }
                                if columns.contains(.user) {
                                    TextField("", value: bindingDouble(for: r.instrumentId, field: .user), format: .number)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: numWidth)
                                        .disabled(isArchived)
                                        .onSubmit { saveRow(r.instrumentId) }
                                }
                                if columns.contains(.actual) {
                                    Text(fmtPct(r.actualPct))
                                        .frame(width: numWidth, alignment: .trailing)
                                }
                                if columns.contains(.delta) {
                                    Text(fmtPct(r.deltaUserPct))
                                        .frame(width: numWidth, alignment: .trailing)
                                        .foregroundColor((r.deltaUserPct ?? 0) >= 0 ? .green : .red)
                                }
                                if columns.contains(.notes) {
                                    TextField("Notes", text: bindingNotes(for: r.instrumentId))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: notesWidth, alignment: .leading)
                                        .disabled(isArchived)
                                        .onSubmit { saveRow(r.instrumentId) }
                                }
                                if saving.contains(r.instrumentId) { ProgressView().controlSize(.small) }
                            }
                            .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
        }
        .onAppear(perform: load)
    }

    private let numWidth: CGFloat = 80
    private let notesWidth: CGFloat = 160

    private var header: some View {
        HStack(spacing: 8) {
            if columns.contains(.instrument) { Text("Instrument").frame(maxWidth: .infinity, alignment: .leading) }
            if columns.contains(.research) { Text("Research %").frame(width: numWidth, alignment: .trailing) }
            if columns.contains(.user) { Text("User %").frame(width: numWidth, alignment: .trailing) }
            if columns.contains(.actual) { Text("Actual %").frame(width: numWidth, alignment: .trailing) }
            if columns.contains(.delta) { Text("Δ Actual-User").frame(width: numWidth, alignment: .trailing) }
            if columns.contains(.notes) { Text("Notes").frame(width: notesWidth, alignment: .leading) }
        }
        .font(.caption)
        .foregroundColor(.secondary)
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
    }

    private func fmtPct(_ v: Double?) -> String {
        guard let x = v else { return "—" }
        return String(format: "%.2f", x)
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
            _ = dbManager.updateThemeAsset(
                themeId: themeId,
                instrumentId: instrumentId,
                researchPct: e.research,
                userPct: e.user,
                notes: e.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : e.notes
            )
            DispatchQueue.main.async {
                saving.remove(instrumentId)
                load() // refresh valuation/deltas after saving
            }
        }
    }

    private struct Edit { var research: Double; var user: Double; var notes: String }

    // Visible columns
    enum Column: String, CaseIterable, Identifiable, Hashable {
        case instrument, research, user, actual, delta, notes
        var id: String { rawValue }
        var title: String {
            switch self {
            case .instrument: return "Instrument"
            case .research: return "Research %"
            case .user: return "User %"
            case .actual: return "Actual %"
            case .delta: return "Δ Actual-User"
            case .notes: return "Notes"
            }
        }
        static let defaultVisible: [Column] = [.instrument, .research, .user, .actual, .delta, .notes]
    }
}
