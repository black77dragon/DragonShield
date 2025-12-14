// DragonShield/Views/PortfolioThemeWorkspaceView.swift
// New Tabbed Workspace for Portfolio Theme details (Option 2)

import SwiftUI
#if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
#endif
#if canImport(Charts)
    import Charts
#endif
#if os(macOS)
    import AppKit
#endif

private struct HoldingsTableFontConfig {
    let rowSize: CGFloat
    let secondarySize: CGFloat
    let headerSize: CGFloat
}

private struct HoldingsColumnsInfoView: View {
    private let items: [(String, String)] = [
        ("Research %", "Baseline allocation suggested by research or strategy."),
        ("User %", "Your custom allocation target for the instrument."),
        ("User % (Norm)", "User target adjusted to sum to 100% of counted holdings (User % > 0)."),
        ("Calc Target CHF", "Budget-based CHF target using the normalised user % of counted holdings."),
        ("Set Target (ST) CHF", "Manually entered CHF target override (sums across all holdings)."),
        ("Normalised %", "Actual holdings percentage calculated from counted positions only."),
        ("Δ Actual-User", "Percentage gap between actual holdings and your user target."),
        ("Δ Calc CHF", "CHF gap between actual holdings and the calculated target."),
        ("ST Delta CHF", "CHF gap between actual holdings and the manual set target."),
        ("Actual CHF", "Current market value of the holdings in CHF (counted + excluded)."),
        ("Notes", "Free-form notes per instrument."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Holdings Column Overview")
                .font(.headline)
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0)
                        .font(.subheadline)
                        .bold()
                    Text(item.1)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct PortfolioThemeWorkspaceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let origin: String
    @Environment(\.dismiss) private var dismiss

    enum WorkspaceTab: String, CaseIterable, Identifiable {
        case overview
        case holdings
        case analytics
        case risks
        case updates
        case settings

        var id: String { rawValue }
        var label: String {
            switch self {
            case .overview: return "Overview"
            case .holdings: return "Holdings"
            case .analytics: return "Analytics"
            case .risks: return "Risks"
            case .updates: return "Updates"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .overview: return "rectangle.grid.2x2"
            case .holdings: return "list.bullet.rectangle"
            case .analytics: return "chart.bar"
            case .risks: return "shield.lefthalf.filled"
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
    @State private var riskSnapshot: PortfolioRiskSnapshot?
    @State private var loadingValuation = false
    // Classic editor references removed; Workspace is the default
    @State private var instrumentCurrencies: [Int: String] = [:]
    @State private var instrumentSectors: [Int: String] = [:]
    // Risks tab state
    @State private var riskSearchText: String = ""
    @State private var riskSort: RiskTableSort = .weight
    @State private var riskSortAscending: Bool = false
    @State private var selectedSRIBucket: Int? = nil
    @State private var selectedLiquidityBucket: Int? = nil
    @State private var riskSRIMetric: RiskMetric = .value
    @State private var riskLiquidityMetric: RiskMetric = .value
    @State private var riskQuickFilters: Set<RiskQuickFilter> = []
    @State private var openInstrumentId: Int? = nil
    @State private var openRiskProfileId: Int? = nil
    @State private var exportErrorMessage: String? = nil
    private let riskColors: [Color] = [
        Color.green.opacity(0.7),
        Color.green,
        Color.yellow,
        Color.orange,
        Color.orange.opacity(0.85),
        Color.red.opacity(0.9),
        Color.red
    ]

    // Meta editing (Settings tab)
    @State private var name: String = ""
    @State private var code: String = ""
    @State private var statusId: Int = 0
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var descriptionText: String = ""
    @State private var institutionId: Int? = nil
    @State private var institutions: [DatabaseManager.InstitutionData] = []
    @State private var updatedAtDate: Date = .init()
    @State private var originalUpdatedAtDate: Date? = nil
    @State private var isArchivedTheme: Bool = false
    @State private var isSoftDeletedTheme: Bool = false

    private enum HoldingsFontSize: String, CaseIterable {
        case xSmall, small, medium, large, xLarge

        var label: String {
            switch self {
            case .xSmall: return "XS"
            case .small: return "S"
            case .medium: return "M"
            case .large: return "L"
            case .xLarge: return "XL"
            }
        }

        var baseSize: CGFloat {
            let index: Int
            switch self {
            case .xSmall: index = 0
            case .small: index = 1
            case .medium: index = 2
            case .large: index = 3
            case .xLarge: index = 4
            }
            return TableFontMetrics.baseSize(for: index)
        }

        var secondarySize: CGFloat { baseSize - 1 }
        var headerSize: CGFloat { baseSize - 1 }
    }

    private static let holdingsFontSizeKey = UserDefaultsKeys.portfolioThemeWorkspaceHoldingsFontSize
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    @State private var holdingsFontSize: HoldingsFontSize = .medium

    init(themeId: Int,
         origin: String,
         initialTab: WorkspaceTab? = nil,
         initialUpdatesSearch: String? = nil,
         initialUpdatesSearchHint: String? = nil)
    {
        self.themeId = themeId
        self.origin = origin
        self.initialTab = initialTab
        self.initialUpdatesSearch = initialUpdatesSearch
        self.initialUpdatesSearchHint = initialUpdatesSearchHint

        if let stored = UserDefaults.standard.string(forKey: Self.holdingsFontSizeKey),
           let size = HoldingsFontSize(rawValue: stored)
        {
            _holdingsFontSize = State(initialValue: size)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                titleBar
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
                    risksTab
                        .tag(WorkspaceTab.risks)
                        .tabItem { Label(WorkspaceTab.risks.label, systemImage: WorkspaceTab.risks.systemImage) }
                    updatesTab
                        .tag(WorkspaceTab.updates)
                        .tabItem { Label(WorkspaceTab.updates.label, systemImage: WorkspaceTab.updates.systemImage) }
                    settingsTab
                        .tag(WorkspaceTab.settings)
                        .tabItem { Label(WorkspaceTab.settings.label, systemImage: WorkspaceTab.settings.systemImage) }
                }
            }
            .navigationTitle("Portfolio: \(displayName)")
        }
        .frame(minWidth: 1500, idealWidth: 1750, minHeight: 720, idealHeight: 800)
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
            if newValue == .overview || newValue == .analytics || newValue == .holdings || newValue == .risks { runValuation() }
        }
    }

    // MARK: - Header

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DSLayout.spaceM) {
            headerInfoLine
            Spacer()
            headerActions
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceS)
        .background(DSColor.surfaceSecondary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DSColor.border),
            alignment: .bottom
        )
    }

    private var titleBar: some View {
        HStack {
            Text("Portfolio: \(displayName)")
                .dsHeaderLarge()
            Spacer()
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.top, DSLayout.spaceL)
        .padding(.bottom, DSLayout.spaceXS)
        .background(DSColor.background)
    }

    private var headerInfoLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: DSLayout.spaceL) {
            Text("Status \(statusDisplay.name)")
                .foregroundColor(statusDisplay.color)
            Text("Total (Actual) \(baseCurrencyCode): \(formatWholeAmount(actualTotalBase))")
            if let snap = riskSnapshot {
                Text("Risk \(snap.portfolioScore, format: .number.precision(.fractionLength(1))) (\(snap.category.rawValue))")
                    .foregroundColor(riskScoreColor(snap.portfolioScore))
            }
            if let delta = deltaToSetTarget {
                let deltaColor: Color = {
                    if delta == 0 { return DSColor.textPrimary }
                    return delta > 0 ? DSColor.accentSuccess : DSColor.accentError
                }()
                Text("Δ vs Set Target: \(formatSignedWholeAmount(delta)) \(baseCurrencyCode)")
                    .foregroundColor(deltaColor)
            } else {
                Text("Δ vs Set Target: —")
            }
            Text("- # Instruments: \(instrumentCountDisplay)")
        }
        .dsBody()
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private var headerActions: some View {
        HStack(spacing: 12) {
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
    // Search text moved inside table for tighter grouping
    @State private var holdingsColumns: Set<HoldingsTable.Column> = Set(HoldingsTable.Column.defaultVisible)
    @State private var showWidthsEditor: Bool = false
    @State private var holdingsReloadToken: Int = 0
    @State private var themeBudgetInput: String = ""

    // Add/Delete Instrument state
    @State private var showAddInstrument: Bool = false
    @State private var addInstrumentQuery: String = ""
    @State private var addInstrumentId: Int = 0
    @State private var showAddInstrumentPicker: Bool = false
    @State private var addResearchPct: Double = 0
    @State private var addUserPct: Double = 0
    @State private var addNotes: String = ""
    @State private var showHoldingsInfo: Bool = false
    @State private var holdingsInfoHovering: Bool = false

    private var holdingsFontConfig: HoldingsTableFontConfig {
        HoldingsTableFontConfig(
            rowSize: holdingsFontSize.baseSize,
            secondarySize: max(8, holdingsFontSize.secondarySize),
            headerSize: holdingsFontSize.headerSize
        )
    }

    private func persistHoldingsFontSize(_ size: HoldingsFontSize) {
        UserDefaults.standard.set(size.rawValue, forKey: Self.holdingsFontSizeKey)
    }

    private var holdingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Holdings").font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Text("Portfolio Target Budget (CHF)")
                        .font(.body.weight(.semibold))
                    TextField("0", text: $themeBudgetInput)
                        .frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveThemeBudget() }
                    Button("Save Budget") { saveThemeBudget() }
                }
                Picker("Font Size", selection: $holdingsFontSize) {
                    ForEach(HoldingsFontSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .labelsHidden()
                .onChange(of: holdingsFontSize) { _, newValue in
                    persistHoldingsFontSize(newValue)
                }
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
                if holdingsColumns != Set(HoldingsTable.Column.defaultVisible) || holdingsFontSize != .medium {
                    Button("Reset View", action: resetHoldingsPreferences)
                        .buttonStyle(.link)
                }
            }
            HoldingsTable(
                themeId: themeId,
                isArchived: isArchivedTheme || isSoftDeletedTheme,
                search: $holdingsSearch,
                columns: holdingsColumns,
                fontConfig: holdingsFontConfig,
                reloadToken: holdingsReloadToken,
                themeBudgetChf: currentBudget(),
                onHoldingsChanged: { loadTheme() }
            )
            .environmentObject(dbManager)

            Button(action: { showHoldingsInfo = true }) {
                Label("ℹ️ more information", systemImage: "info.circle")
            }
            .buttonStyle(.link)
            .padding(.top, 8)
            .onHover { hovering in
                if hovering {
                    showHoldingsInfo = true
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !holdingsInfoHovering { showHoldingsInfo = false }
                    }
                }
            }
            .popover(isPresented: $showHoldingsInfo, arrowEdge: .bottom) {
                HoldingsColumnsInfoView()
                    .padding(20)
                    .frame(minWidth: 320, alignment: Alignment.leading)
                    .onHover { hovering in
                        holdingsInfoHovering = hovering
                        if !hovering {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if !holdingsInfoHovering { showHoldingsInfo = false }
                            }
                        }
                    }
                    .onDisappear {
                        holdingsInfoHovering = false
                    }
            }
        }
        .padding(20)
        .onAppear(perform: restoreHoldingsColumns)
        .onAppear { themeBudgetInput = formatBudgetValue(currentBudget()) }
        .sheet(isPresented: $showWidthsEditor) { ColumnWidthsEditor(onSave: { holdingsReloadToken += 1 }) }
        .sheet(isPresented: $showAddInstrument) { addInstrumentSheet }
    }

    private func resetHoldingsPreferences() {
        holdingsColumns = Set(HoldingsTable.Column.defaultVisible)
        persistHoldingsColumns()
        holdingsFontSize = .medium
        persistHoldingsFontSize(.medium)
        holdingsReloadToken += 1
    }

    private func currentBudget() -> Double? {
        if let t = theme { return t.theoreticalBudgetChf }
        return dbManager.getPortfolioTheme(id: themeId, includeSoftDeleted: true)?.theoreticalBudgetChf
    }

    private func saveThemeBudget() {
        let trimmed = themeBudgetInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.replacingOccurrences(of: "'", with: "")
        let value = Double(normalized)
        // Optimistic update so Target/Δ compute immediately
        if var t = theme { t.theoreticalBudgetChf = value; theme = t }
        if dbManager.updateThemeBudget(themeId: themeId, budgetChf: value) {
            if let updated = dbManager.getPortfolioTheme(id: themeId, includeSoftDeleted: true) {
                applyThemeState(updated)
            }
            themeBudgetInput = formatBudgetValue(currentBudget())
        } else {
            // Still reformat input locally
            themeBudgetInput = formatBudgetValue(value)
        }
        holdingsReloadToken += 1
    }

    private func formatBudgetValue(_ v: Double?) -> String {
        guard let v = v else { return "" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.0f", v)
    }

    private func formatAmount(_ v: Double, decimals: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.maximumFractionDigits = decimals
        f.minimumFractionDigits = decimals
        return f.string(from: NSNumber(value: v)) ?? String(format: decimals == 0 ? "%.0f" : "%.2f", v)
    }

    private func persistHoldingsColumns() {
        let raw = holdingsColumns.map { $0.rawValue }.sorted().joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColumns)
    }

    private func restoreHoldingsColumns() {
        guard let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.portfolioThemeWorkspaceHoldingsColumns), !raw.isEmpty else { return }
        let set = Set(raw.split(separator: ",").compactMap { HoldingsTable.Column(rawValue: String($0)) })
        if !set.isEmpty { holdingsColumns = set }
        // One-time soft migrations: ensure new columns are visible by default
        var changed = false
        if !holdingsColumns.contains(.actualChf) { holdingsColumns.insert(.actualChf); changed = true }
        if !holdingsColumns.contains(.userNorm) { holdingsColumns.insert(.userNorm); changed = true }
        if !holdingsColumns.contains(.targetChf) { holdingsColumns.insert(.targetChf); changed = true }
        if !holdingsColumns.contains(.setTargetChf) { holdingsColumns.insert(.setTargetChf); changed = true }
        if !holdingsColumns.contains(.deltaChf) { holdingsColumns.insert(.deltaChf); changed = true }
        if !holdingsColumns.contains(.setDeltaChf) { holdingsColumns.insert(.setDeltaChf); changed = true }
        if changed { persistHoldingsColumns() }
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
                        ), in: 40 ... 600)
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
        let labelWidth: CGFloat = 120
        return VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Add Instrument to \(name)").font(.headline); Spacer() }
                .padding(.horizontal, 20).padding(.top, 16)
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Instrument").frame(width: labelWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(addInstrumentSelectedDisplay)
                                    .foregroundColor(addInstrumentSelectedDisplay == "No instrument selected" ? .secondary : .primary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button("Choose Instrument…") {
                                    addInstrumentQuery = addInstrumentSelectedDisplay == "No instrument selected" ? "" : addInstrumentSelectedDisplay
                                    showAddInstrumentPicker = true
                                }
                            }
                        }
                        .frame(minWidth: 360, maxWidth: .infinity)
                    }
                    GridRow {
                        Text("Research %").frame(width: labelWidth, alignment: .leading)
                        TextField("", value: $addResearchPct, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    GridRow {
                        Text("User %").frame(width: labelWidth, alignment: .leading)
                        TextField("", value: $addUserPct, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    GridRow {
                        Text("Notes").frame(width: labelWidth, alignment: .leading)
                        TextField("", text: $addNotes)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 360, maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            Divider()
            HStack { Spacer(); Button("Cancel") { showAddInstrument = false }; Button("Add") { addInstrument() }.keyboardShortcut(.defaultAction).disabled(!addValid) }
                .padding(20)
        }
        .frame(width: 600)
        .sheet(isPresented: $showAddInstrumentPicker) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Instrument")
                    .font(.headline)
                FloatingSearchPicker(
                    title: "Choose Instrument",
                    placeholder: "Search instrument, ticker, or ISIN",
                    items: addInstrumentPickerItems,
                    selectedId: addInstrumentPickerBinding,
                    showsClearButton: true,
                    emptyStateText: "No instruments",
                    query: $addInstrumentQuery,
                    onSelection: { _ in
                        showAddInstrumentPicker = false
                    },
                    onClear: {
                        addInstrumentPickerBinding.wrappedValue = nil
                    },
                    onSubmit: { _ in
                        if addInstrumentId > 0 { showAddInstrumentPicker = false }
                    },
                    selectsFirstOnSubmit: false
                )
                .frame(minWidth: 360)
                HStack {
                    Spacer()
                    Button("Close") { showAddInstrumentPicker = false }
                }
            }
            .padding(16)
            .frame(width: 520)
        }
        .onAppear { addUserPct = addResearchPct; addInstrumentQuery = ""; addInstrumentId = 0 }
    }

    private var addInstrumentSelectedDisplay: String {
        if addInstrumentId > 0,
           let match = dbManager.fetchAssets().first(where: { $0.id == addInstrumentId })
        {
            return displayString(for: match)
        }
        let trimmed = addInstrumentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No instrument selected" : trimmed
    }

    private var addInstrumentPickerItems: [FloatingSearchPicker.Item] {
        availableInstrumentRows().map { row in
            FloatingSearchPicker.Item(
                id: AnyHashable(row.id),
                title: displayString(for: row),
                subtitle: nil,
                searchText: instrumentSearchKey(for: row)
            )
        }
    }

    private var addInstrumentPickerBinding: Binding<AnyHashable?> {
        Binding<AnyHashable?>(
            get: { addInstrumentId > 0 ? AnyHashable(addInstrumentId) : nil },
            set: { newValue in
                if let value = newValue as? Int,
                   let match = dbManager.fetchAssets().first(where: { $0.id == value })
                {
                    addInstrumentId = value
                    addInstrumentQuery = displayString(for: match)
                } else {
                    addInstrumentId = 0
                    addInstrumentQuery = ""
                }
            }
        )
    }

    private func availableInstrumentRows() -> [DatabaseManager.InstrumentRow] {
        let inTheme = Set(dbManager.listThemeAssets(themeId: themeId).map { $0.instrumentId })
        return dbManager.fetchAssets().filter { !inTheme.contains($0.id) }
    }

    private func displayString(for ins: DatabaseManager.InstrumentRow) -> String {
        var parts: [String] = [ins.name]
        if let t = ins.tickerSymbol, !t.isEmpty { parts.append(t.uppercased()) }
        if let i = ins.isin, !i.isEmpty { parts.append(i.uppercased()) }
        return parts.joined(separator: " • ")
    }

    private func instrumentSearchKey(for ins: DatabaseManager.InstrumentRow) -> String {
        [
            ins.name,
            ins.tickerSymbol?.uppercased() ?? "",
            ins.isin?.uppercased() ?? "",
            ins.valorNr?.uppercased() ?? "",
            ins.currency.uppercased(),
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
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
            loadTheme()
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

    private enum RiskMetric: String, CaseIterable, Identifiable {
        case value, count
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    private enum RiskQuickFilter: String, CaseIterable, Hashable {
        case highRisk
        case illiquid
        case missingData

        var label: String {
            switch self {
            case .highRisk: return "High risk (6–7)"
            case .illiquid: return "Illiquid"
            case .missingData: return "Missing data"
            }
        }

        var icon: String {
            switch self {
            case .highRisk: return "flame.fill"
            case .illiquid: return "drop.triangle.fill"
            case .missingData: return "exclamationmark.triangle.fill"
            }
        }
    }

    private enum RiskTableSort {
        case name
        case value
        case weight
        case sri
        case liquidity
        case blended
    }

    private enum RiskOverrideState {
        case active
        case expiringSoon
        case expired
    }

    private var risksTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                riskTabHeader
                if loadingValuation && riskSnapshot == nil {
                    ProgressView().controlSize(.small)
                } else if let snap = riskSnapshot {
                    coverageWarnings(snap)
                    riskHeroSection(snap)
                    riskBreakdownSection(snap)
                    riskFiltersBar
                    riskContributionsSection(snap)
                } else {
                    Text("No risk data available. Add holdings or refresh.")
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: Binding(
            get: { openInstrumentId.map { IdentValue(value: $0) } },
            set: { openInstrumentId = $0?.value }
        )) { ident in
            InstrumentDashboardWindowView(instrumentId: ident.value)
                .environmentObject(dbManager)
        }
        .sheet(item: Binding(
            get: { openRiskProfileId.map { IdentValue(value: $0) } },
            set: { openRiskProfileId = $0?.value }
        )) { ident in
            RiskProfileDetailSheet(instrumentId: ident.value)
                .environmentObject(dbManager)
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var riskTabHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Risks").font(.headline)
                Text("Act on SRI & liquidity mix with drill-down.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Recalculate", action: runValuation)
                .buttonStyle(.link)
        }
    }

    @ViewBuilder
    private func coverageWarnings(_ snap: PortfolioRiskSnapshot) -> some View {
        let badges = coverageBadges(for: snap)
        if badges.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label("Coverage & data quality", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(DSColor.accentWarning)
                    Spacer()
                    Text("Missing FX/price rows are excluded from the score.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(badges, id: \.label) { item in
                            coverageBadge(label: item.label, count: item.count, color: item.color)
                        }
                    }
                }
            }
            .padding()
            .background(DSColor.surfaceSecondary)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
        }
    }

    private func coverageBadges(for snap: PortfolioRiskSnapshot) -> [(label: String, count: Int, color: Color)] {
        var items: [(String, Int, Color)] = []
        if snap.excludedFxCount > 0 { items.append(("FX missing", snap.excludedFxCount, DSColor.accentWarning)) }
        if snap.excludedPriceCount > 0 { items.append(("Price missing", snap.excludedPriceCount, DSColor.accentWarning)) }
        if snap.missingRiskCount > 0 { items.append(("Fallback mapping", snap.missingRiskCount, DSColor.accentWarning)) }
        let expiring = snap.overrideSummary.expiringSoon
        let expired = snap.overrideSummary.expired
        if expiring + expired > 0 {
            items.append(("Overrides expiring", expiring + expired, DSColor.accentError))
        }
        return items
    }

    private func coverageBadge(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .cornerRadius(10)
    }

    @ViewBuilder
    private func riskHeroSection(_ snap: PortfolioRiskSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Portfolio Risk Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(snap.portfolioScore, format: .number.precision(.fractionLength(1)))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(riskScoreColor(snap.portfolioScore))
                        Text(snap.category.rawValue)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                let clampedScore = min(max(snap.portfolioScore, 1), 7)
                Gauge(value: clampedScore, in: 1 ... 7) { Text("") } currentValueLabel: {
                    Text(String(format: "%.1f", snap.portfolioScore))
                } minimumValueLabel: {
                    Text("1")
                } maximumValueLabel: {
                    Text("7")
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(
                    Gradient(colors: [DSColor.accentSuccess, .yellow, DSColor.accentWarning, DSColor.accentError])
                )
                .frame(maxWidth: 360)
            }
            HStack(spacing: 12) {
                heroCallout(title: "High risk (6–7)", value: percent(snap.highRiskShare), color: DSColor.accentError, icon: "flame.fill")
                heroCallout(title: "Illiquid", value: percent(snap.illiquidShare), color: .orange, icon: "drop.triangle.fill")
                heroCallout(title: "Overrides", value: "\(snap.overrideSummary.total) total", color: .blue, icon: "shield.checkerboard")
            }
            Text("Base currency \(snap.baseCurrency) • Positions as of \(dateStr(snap.positionsAsOf)) • FX as of \(dateStr(snap.fxAsOf)) • Total \(formatCurrency(snap.totalValueBase))")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private func heroCallout(title: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.headline).foregroundColor(color)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }

    @ViewBuilder
    private func riskBreakdownSection(_ snap: PortfolioRiskSnapshot) -> some View {
        #if canImport(Charts)
            LazyVGrid(columns: [GridItem(.flexible(minimum: 320), spacing: 16), GridItem(.flexible(minimum: 320), spacing: 16)], spacing: 12) {
                sriDonutCard(snap)
                liquidityDonutCard(snap)
            }
        #else
            EmptyView()
        #endif
    }

    @ViewBuilder
    private func sriDonutCard(_ snap: PortfolioRiskSnapshot) -> some View {
        let totalCount = snap.sriBuckets.reduce(0) { $0 + $1.count }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SRI mix").font(.title3).bold()
                Spacer()
                Picker("Metric", selection: $riskSRIMetric) {
                    ForEach(RiskMetric.allCases) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            Chart(snap.sriBuckets) { bucket in
                SectorMark(
                    angle: .value("Share", share(for: bucket, totalValue: snap.totalValueBase, totalCount: totalCount, metric: riskSRIMetric)),
                    innerRadius: .ratio(0.6),
                    angularInset: 2.0
                )
                .foregroundStyle(riskColors[max(0, bucket.bucket - 1)])
                .opacity(selectedSRIBucket == nil || selectedSRIBucket == bucket.bucket ? 1 : 0.3)
            }
            .frame(height: 180)
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0).onEnded { value in
                                guard let plotAnchor = proxy.plotFrame else { return }
                                let plotFrame = geo[plotAnchor]
                                let point = CGPoint(x: value.location.x - plotFrame.origin.x, y: value.location.y - plotFrame.origin.y)
                                let frame = CGRect(origin: .zero, size: plotFrame.size)
                                if let bucket = tappedBucket(for: point, in: frame, buckets: snap.sriBuckets, metric: riskSRIMetric, totalValue: snap.totalValueBase, totalCount: totalCount) {
                                    toggleSRIFilter(bucket)
                                }
                            }
                        )
                }
            }
            HStack {
                if let selected = selectedSRIBucket {
                    Text("Filter: SRI \(selected)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap a slice to filter the table.").font(.footnote).foregroundColor(.secondary)
                }
                Spacer()
                Button(selectedSRIBucket == nil ? "High risk" : "Clear filter") {
                    if selectedSRIBucket == nil {
                        selectedSRIBucket = 6
                    } else {
                        selectedSRIBucket = nil
                    }
                }
                .buttonStyle(.link)
            }
        }
        .padding()
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    @ViewBuilder
    private func liquidityDonutCard(_ snap: PortfolioRiskSnapshot) -> some View {
        let totalCount = snap.liquidityBuckets.reduce(0) { $0 + $1.count }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Liquidity").font(.title3).bold()
                Spacer()
                Picker("Metric", selection: $riskLiquidityMetric) {
                    ForEach(RiskMetric.allCases) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            Chart(snap.liquidityBuckets) { bucket in
                SectorMark(
                    angle: .value("Share", share(for: bucket, totalValue: snap.totalValueBase, totalCount: totalCount, metric: riskLiquidityMetric)),
                    innerRadius: .ratio(0.6),
                    angularInset: 2.0
                )
                .foregroundStyle(liquidityColor(bucket.bucket))
                .opacity(selectedLiquidityBucket == nil || selectedLiquidityBucket == bucket.bucket ? 1 : 0.3)
            }
            .frame(height: 180)
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0).onEnded { value in
                                guard let plotAnchor = proxy.plotFrame else { return }
                                let plotFrame = geo[plotAnchor]
                                let point = CGPoint(x: value.location.x - plotFrame.origin.x, y: value.location.y - plotFrame.origin.y)
                                let frame = CGRect(origin: .zero, size: plotFrame.size)
                                if let bucket = tappedBucket(for: point, in: frame, buckets: snap.liquidityBuckets, metric: riskLiquidityMetric, totalValue: snap.totalValueBase, totalCount: totalCount) {
                                    toggleLiquidityFilter(bucket)
                                }
                            }
                        )
                }
            }
            HStack {
                if let selected = selectedLiquidityBucket {
                    Text("Filter: \(liquidityLabel(selected))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("Tap a slice to filter the table.").font(.footnote).foregroundColor(.secondary)
                }
                Spacer()
                Button(selectedLiquidityBucket == nil ? "Show illiquid" : "Clear filter") {
                    if selectedLiquidityBucket == nil {
                        selectedLiquidityBucket = 2
                    } else {
                        selectedLiquidityBucket = nil
                    }
                }
                .buttonStyle(.link)
            }
        }
        .padding()
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private var riskFiltersBar: some View {
        HStack(spacing: 8) {
            ForEach(RiskQuickFilter.allCases, id: \.self) { filter in
                riskFilterChip(filter)
            }
            Spacer()
            if hasActiveRiskFilters {
                Button("Clear filters") {
                    riskQuickFilters.removeAll()
                    selectedSRIBucket = nil
                    selectedLiquidityBucket = nil
                    riskSearchText = ""
                }
                .buttonStyle(.link)
            }
        }
        .padding(.vertical, 4)
    }

    private func riskFilterChip(_ filter: RiskQuickFilter) -> some View {
        let active = riskQuickFilters.contains(filter)
        let tint = active ? DSColor.accentMain : DSColor.border
        return Button {
            if active {
                riskQuickFilters.remove(filter)
            } else {
                riskQuickFilters.insert(filter)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                Text(filter.label)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(active ? 0.15 : 0.08))
            .foregroundColor(active ? DSColor.accentMain : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func riskContributionsSection(_ snap: PortfolioRiskSnapshot) -> some View {
        let rows = filteredRiskRows
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Instrument contributions").font(.title3).bold()
                    Text("\(rows.count) instruments • \(snap.baseCurrency) weighted")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Export CSV") { exportRiskTable(rows: rows, snapshot: snap) }
                Button("Recalculate", action: runValuation)
                    .buttonStyle(.link)
            }
            HStack(spacing: 8) {
                TextField("Search instruments", text: $riskSearchText)
                    .textFieldStyle(.roundedBorder)
                Spacer()
            }
            Divider()
            HStack(spacing: 8) {
                riskSortToggleButton("Instrument", sort: .name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                riskSortToggleButton("Value (\(snap.baseCurrency))", sort: .value)
                    .frame(width: 150, alignment: .trailing)
                riskSortToggleButton("Weight", sort: .weight)
                    .frame(width: 80, alignment: .trailing)
                riskSortToggleButton("SRI", sort: .sri)
                    .frame(width: 60, alignment: .trailing)
                riskSortToggleButton("Liquidity", sort: .liquidity)
                    .frame(width: 100, alignment: .trailing)
                riskSortToggleButton("Blended", sort: .blended)
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            Divider()
            if rows.isEmpty {
                Text("No instruments match the current filters.")
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(rows) { row in
                        riskContributionRow(row, baseCurrency: snap.baseCurrency)
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private func riskSortToggleButton(_ title: String, sort: RiskTableSort) -> some View {
        Button {
            if riskSort == sort {
                riskSortAscending.toggle()
            } else {
                riskSort = sort
                riskSortAscending = sort == .name
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if riskSort == sort {
                    Image(systemName: riskSortAscending ? "arrow.up" : "arrow.down")
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func riskContributionRow(_ row: PortfolioRiskInstrumentContribution, baseCurrency: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.instrumentName)
                    .fontWeight(.semibold)
                riskFlags(for: row)
            }
            Spacer()
            Text(formatCurrency(row.valueBase))
                .dsMonoSmall()
                .frame(width: 150, alignment: .trailing)
                .foregroundColor(row.valuationStatus == .ok ? DSColor.textPrimary : DSColor.textSecondary)
            Text(percent(row.weight))
                .dsMonoSmall()
                .frame(width: 80, alignment: .trailing)
            Text("SRI \(row.sri)")
                .frame(width: 60, alignment: .trailing)
                .foregroundColor(riskScoreColor(Double(row.sri)))
            Text(liquidityLabel(row.liquidityTier))
                .frame(width: 100, alignment: .trailing)
            Text(row.blendedScore, format: .number.precision(.fractionLength(1)))
                .dsMonoSmall()
                .frame(width: 80, alignment: .trailing)
                .foregroundColor(riskScoreColor(row.blendedScore))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openInstrumentId = row.id
        }
        .contextMenu {
            Button("Open Instrument Maintenance") { openInstrumentId = row.id }
            Button("Open Risk Profile") { openRiskProfileId = row.id }
            if row.valuationStatus != .ok {
                Text(riskStatusLabel(row.valuationStatus))
            }
        }
    }

    private func riskFlags(for row: PortfolioRiskInstrumentContribution) -> some View {
        HStack(spacing: 6) {
            if row.usedFallback {
                DSBadge(text: "Fallback", color: DSColor.accentWarning)
            }
            if row.manualOverride {
                let badge = riskOverrideBadgeText(for: row)
                DSBadge(text: badge.text, color: badge.color)
            }
            if row.valuationStatus != .ok {
                DSBadge(text: riskStatusLabel(row.valuationStatus), color: DSColor.accentError)
            }
        }
    }

    private func riskOverrideBadgeText(for row: PortfolioRiskInstrumentContribution) -> (text: String, color: Color) {
        switch riskOverrideStatus(for: row) {
        case .expired:
            return ("Override expired", DSColor.accentError)
        case .expiringSoon:
            return ("Override expiring", DSColor.accentWarning)
        case .active:
            return ("Override", .blue)
        }
    }

    private func riskOverrideStatus(for row: PortfolioRiskInstrumentContribution) -> RiskOverrideState {
        guard let date = row.overrideExpiresAt else { return .active }
        if date < Date() { return .expired }
        if let soon = Calendar.current.date(byAdding: .day, value: 30, to: Date()), date < soon {
            return .expiringSoon
        }
        return .active
    }

    private func riskStatusLabel(_ status: ValuationStatus) -> String {
        switch status {
        case .ok: return "Counted"
        case .noPosition: return "No position"
        case .fxMissing: return "FX missing"
        case .priceMissing: return "Price missing"
        }
    }

    private func share(for bucket: PortfolioRiskBucket, totalValue: Double, totalCount: Int, metric: RiskMetric) -> Double {
        switch metric {
        case .value:
            return totalValue > 0 ? bucket.valueBase / totalValue : 0
        case .count:
            guard totalCount > 0 else { return 0 }
            return Double(bucket.count) / Double(totalCount)
        }
    }

    private func donutSlices(for buckets: [PortfolioRiskBucket], metric: RiskMetric, totalValue: Double, totalCount: Int) -> [(bucket: Int, start: Double, end: Double)] {
        var slices: [(bucket: Int, start: Double, end: Double)] = []
        var currentAngle: Double = 0
        for bucket in buckets {
            let fraction = share(for: bucket, totalValue: totalValue, totalCount: totalCount, metric: metric)
            guard fraction > 0 else { continue }
            let span = fraction * 2 * .pi
            let end = currentAngle + span
            slices.append((bucket: bucket.bucket, start: currentAngle, end: end))
            currentAngle = end
        }
        return slices
    }

    private func tappedBucket(for location: CGPoint, in frame: CGRect, buckets: [PortfolioRiskBucket], metric: RiskMetric, totalValue: Double, totalCount: Int) -> Int? {
        let outerRadius = Double(min(frame.width, frame.height) / 2)
        let innerRadius = outerRadius * 0.6 // Matches SectorMark innerRadius ratio
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        let distance = hypot(dx, dy)
        guard distance >= innerRadius, distance <= outerRadius else { return nil }

        let startRotation = -Double.pi / 2 // Align 0 with top
        var angle = atan2(dy, dx) - startRotation
        if angle < 0 { angle += 2 * .pi }

        let slices = donutSlices(for: buckets, metric: metric, totalValue: totalValue, totalCount: totalCount)
        for slice in slices where angle >= slice.start && angle < slice.end {
            return slice.bucket
        }
        return nil
    }

    private func toggleSRIFilter(_ bucket: Int) {
        selectedSRIBucket = selectedSRIBucket == bucket ? nil : bucket
    }

    private func toggleLiquidityFilter(_ bucket: Int) {
        selectedLiquidityBucket = selectedLiquidityBucket == bucket ? nil : bucket
    }

    private var filteredRiskRows: [PortfolioRiskInstrumentContribution] {
        guard let snap = riskSnapshot else { return [] }
        var rows = snap.instruments
        if let sri = selectedSRIBucket { rows = rows.filter { $0.sri == sri } }
        if let liq = selectedLiquidityBucket { rows = rows.filter { $0.liquidityTier == liq } }
        if riskQuickFilters.contains(.highRisk) { rows = rows.filter { $0.sri >= 6 || $0.blendedScore >= 6 } }
        if riskQuickFilters.contains(.illiquid) { rows = rows.filter { $0.liquidityTier >= 2 } }
        if riskQuickFilters.contains(.missingData) { rows = rows.filter { $0.usedFallback || $0.valuationStatus != .ok } }
        if !riskSearchText.isEmpty {
            rows = rows.filter { $0.instrumentName.localizedCaseInsensitiveContains(riskSearchText) }
        }
        return sortedRiskRows(rows)
    }

    private func sortedRiskRows(_ rows: [PortfolioRiskInstrumentContribution]) -> [PortfolioRiskInstrumentContribution] {
        rows.sorted { lhs, rhs in
            switch riskSort {
            case .name:
                return riskSortAscending ? lhs.instrumentName.localizedCaseInsensitiveCompare(rhs.instrumentName) == .orderedAscending : lhs.instrumentName.localizedCaseInsensitiveCompare(rhs.instrumentName) == .orderedDescending
            case .value:
                return riskSortAscending ? lhs.valueBase < rhs.valueBase : lhs.valueBase > rhs.valueBase
            case .weight:
                return riskSortAscending ? lhs.weight < rhs.weight : lhs.weight > rhs.weight
            case .sri:
                return riskSortAscending ? lhs.sri < rhs.sri : lhs.sri > rhs.sri
            case .liquidity:
                return riskSortAscending ? lhs.liquidityTier < rhs.liquidityTier : lhs.liquidityTier > rhs.liquidityTier
            case .blended:
                return riskSortAscending ? lhs.blendedScore < rhs.blendedScore : lhs.blendedScore > rhs.blendedScore
            }
        }
    }

    private var hasActiveRiskFilters: Bool {
        selectedSRIBucket != nil || selectedLiquidityBucket != nil || !riskQuickFilters.isEmpty || !riskSearchText.isEmpty
    }

    private func exportRiskTable(rows: [PortfolioRiskInstrumentContribution], snapshot: PortfolioRiskSnapshot) {
        #if os(macOS)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType.commaSeparatedText, .plainText]
            panel.canCreateDirectories = true
            let baseName = theme?.code.isEmpty == false ? theme!.code : "theme"
            panel.nameFieldStringValue = "portfolio_risks_\(baseName).csv"
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try riskCSV(rows: rows, snapshot: snapshot).write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    exportErrorMessage = "Unable to save file: \(error.localizedDescription)"
                }
            }
        #else
            exportErrorMessage = "Export is only available on macOS."
        #endif
    }

    private func riskCSV(rows: [PortfolioRiskInstrumentContribution], snapshot: PortfolioRiskSnapshot) -> String {
        let header = ["Instrument", "Value (\(snapshot.baseCurrency))", "Weight", "SRI", "Liquidity", "Blended", "Flags", "Status"]
        let lines = rows.map { row -> String in
            let flags: [String] = [
                row.usedFallback ? "Fallback" : nil,
                row.manualOverride ? "Override" : nil,
                row.valuationStatus != .ok ? riskStatusLabel(row.valuationStatus) : nil,
            ].compactMap { $0 }
            let cols: [String] = [
                cleanedCSV(row.instrumentName),
                cleanedCSV(formatCurrency(row.valueBase)),
                cleanedCSV(percent(row.weight)),
                cleanedCSV("SRI \(row.sri)"),
                cleanedCSV(liquidityLabel(row.liquidityTier)),
                cleanedCSV(String(format: "%.1f", row.blendedScore)),
                cleanedCSV(flags.isEmpty ? "" : flags.joined(separator: "; ")),
                cleanedCSV(riskStatusLabel(row.valuationStatus)),
            ]
            return cols.joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + lines).joined(separator: "\n")
    }

    private func cleanedCSV(_ value: String) -> String {
        let sanitized = value.replacingOccurrences(of: "\"", with: "'")
        if sanitized.contains(",") {
            return "\"\(sanitized)\""
        }
        return sanitized
    }

    private struct IdentValue: Identifiable {
        let value: Int
        var id: Int { value }
    }

    private struct RiskProfileDetailSheet: View {
        @EnvironmentObject var dbManager: DatabaseManager
        @Environment(\.dismiss) private var dismiss
        let instrumentId: Int

        @State private var profile: DatabaseManager.RiskProfileRow?
        @State private var instrumentName: String = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Risk Profile")
                    .font(.title3)
                    .bold()
                if let profile {
                    VStack(alignment: .leading, spacing: 8) {
                        infoRow("Instrument", value: instrumentName.isEmpty ? "#\(instrumentId)" : instrumentName, bold: true)
                        Divider()
                        infoRow("Computed SRI", value: "\(profile.computedSRI)")
                        infoRow("Computed Liquidity", value: liquidityText(profile.computedLiquidityTier))
                        infoRow("Override SRI", value: profile.overrideSRI.map(String.init) ?? "—")
                        infoRow("Override Liquidity", value: profile.overrideLiquidityTier.map(liquidityText) ?? "—")
                        if let reason = profile.overrideReason, !reason.isEmpty {
                            infoRow("Override reason", value: reason)
                        }
                        if let by = profile.overrideBy {
                            infoRow("Override by", value: by)
                        }
                        if let expires = profile.overrideExpiresAt {
                            infoRow("Override expires", value: DateFormatting.asOfDisplay(expires))
                        }
                        infoRow("Mapping version", value: profile.mappingVersion ?? "—")
                        infoRow("Method", value: profile.calcMethod ?? "—")
                    }
                } else {
                    Text("No risk profile found for this instrument.")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(DSButtonStyle(type: .primary))
                }
            }
            .padding()
            .frame(minWidth: 420)
            .onAppear(perform: load)
        }

        private func infoRow(_ title: String, value: String, bold: Bool = false) -> some View {
            HStack {
                Text(title)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(bold ? .semibold : .regular)
            }
        }

        private func load() {
            profile = dbManager.fetchRiskProfile(instrumentId: instrumentId)
            if let details = dbManager.fetchInstrumentDetails(id: instrumentId) {
                instrumentName = details.name
            }
        }

        private func liquidityText(_ tier: Int) -> String {
            switch tier {
            case 0: return "Liquid"
            case 1: return "Restricted"
            default: return "Illiquid"
            }
        }
    }

    private var updatesTab: some View {
        PortfolioThemeUpdatesView(themeId: themeId, initialSearchText: initialUpdatesSearch, searchHint: initialUpdatesSearchHint)
            .environmentObject(dbManager)
    }

    private var settingsTab: some View {
        let labelWidth: CGFloat = 120
        return Form {
            Section(header: Text("Theme")) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Name").frame(width: labelWidth, alignment: .leading)
                    TextField("", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 320)
                        .padding(.vertical, 2)
                        .background(Color.white)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Code").frame(width: labelWidth, alignment: .leading)
                    Text(code)
                        .foregroundColor(.secondary)
                        .frame(width: 320, alignment: .trailing)
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Status").frame(width: labelWidth, alignment: .leading)
                    Picker("", selection: $statusId) {
                        ForEach(statuses) { s in Text(s.name).tag(s.id) }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                    .padding(.vertical, 2)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                    if isArchivedTheme || isSoftDeletedTheme {
                        Text("Theme content cannot be changed (%, delete instruments etc). Restore first")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Institution").frame(width: labelWidth, alignment: .leading)
                    Picker("", selection: $institutionId) {
                        Text("None").tag(nil as Int?)
                        ForEach(institutions) { inst in Text(inst.name).tag(inst.id as Int?) }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                    .padding(.vertical, 2)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                    Spacer()
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Updated").frame(width: labelWidth, alignment: .leading)
                    DatePicker("", selection: $updatedAtDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .frame(width: 260)
                    Spacer()
                }
                HStack(alignment: .top, spacing: 12) {
                    Text("Description").frame(width: labelWidth, alignment: .leading)
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 100)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                }
                HStack {
                    Spacer()
                    Button("Save Changes") { saveTheme() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(isArchivedTheme || isSoftDeletedTheme)
                        .help((isArchivedTheme || isSoftDeletedTheme) ? "no changes possible, restore theme first" : "")
                }
            }
            Section(header: Text("Danger Zone")) {
                // Soft Deleted toggle on its own line
                HStack(alignment: .center, spacing: 12) {
                    Text("Soft Deleted").frame(width: labelWidth, alignment: .leading)
                    Toggle("", isOn: Binding(
                        get: { isSoftDeletedTheme },
                        set: { newVal in
                            if dbManager.setThemeSoftDelete(id: themeId, softDelete: newVal) {
                                loadTheme()
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    Spacer()
                }
                // Archived Theme toggle on its own line
                HStack(alignment: .center, spacing: 12) {
                    Text("Archived Theme").frame(width: labelWidth, alignment: .leading)
                    Toggle("", isOn: Binding(
                        get: { isArchivedTheme },
                        set: { newVal in
                            if newVal { performArchive() } else { performUnarchive() }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    Spacer()
                }
                // Full Restore button on its own line
                HStack(alignment: .center, spacing: 12) {
                    Text("Full Restore").frame(width: labelWidth, alignment: .leading)
                    Button("Full Restore") {
                        if dbManager.fullRestoreTheme(id: themeId) {
                            loadTheme()
                            let draft = statuses.first { $0.code.uppercased() == "DRAFT" }?.id
                            statusId = draft ?? (statuses.first { $0.isDefault }?.id ?? statusId)
                        }
                    }
                    Spacer()
                }
                // Permanent delete (only available when there are zero holdings)
                HStack(alignment: .center, spacing: 12) {
                    Text("Delete Portfolio").frame(width: labelWidth, alignment: .leading)
                    Button(role: .destructive) { attemptHardDelete() } label: {
                        Label("Delete Portfolio", systemImage: "trash")
                    }
                    .disabled(hasHoldings)
                    .help(hasHoldings ? "Remove all holdings before deleting." : "This permanently deletes the portfolio.")
                    if hasHoldings {
                        Text("Remove all holdings first (\(instrumentCountDisplay) present).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Irreversible action.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .confirmationDialog("Archive this theme?", isPresented: $confirmArchive, titleVisibility: .visible) {
            Button("Archive", role: .destructive) { performArchive() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("You can unarchive later. Edits will be locked.") }
        .confirmationDialog("Soft delete this theme?", isPresented: $confirmSoftDelete, titleVisibility: .visible) {
            Button("Soft Delete", role: .destructive) { performSoftDelete() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This hides the theme from lists. Restore via recycle bin only.") }
        .alert("Cannot delete portfolio", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { newVal in if !newVal { deleteErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
        .alert("Delete portfolio permanently?", isPresented: $confirmHardDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Permanently", role: .destructive) { performHardDelete() }
        } message: {
            Text("This action is irreversible and will permanently delete this portfolio and its metadata.")
        }
    }

    @State private var confirmArchive = false
    @State private var confirmSoftDelete = false
    @State private var confirmHardDelete = false
    @State private var deleteErrorMessage: String? = nil

    private func performArchive() {
        if dbManager.archivePortfolioTheme(id: themeId) {
            loadTheme()
        }
    }

    private func performUnarchive() {
        let defaultStatus = statuses.first { $0.isDefault }?.id ?? statusId
        if dbManager.unarchivePortfolioTheme(id: themeId, statusId: defaultStatus) {
            loadTheme()
            statusId = defaultStatus
        }
    }

    private func performSoftDelete() {
        if dbManager.softDeletePortfolioTheme(id: themeId) {
            loadTheme()
            dismiss()
        }
    }
    private var hasHoldings: Bool { instrumentCountDisplay > 0 }

    private func attemptHardDelete() {
        if hasHoldings {
            deleteErrorMessage = "Delete is disabled while holdings remain in this portfolio."
            return
        }
        let guardResult = dbManager.canHardDeletePortfolioTheme(id: themeId)
        if guardResult.ok {
            confirmHardDelete = true
        } else {
            deleteErrorMessage = guardResult.reason
        }
    }

    private func performHardDelete() {
        if dbManager.hardDeletePortfolioTheme(id: themeId) {
            dismiss()
        } else {
            deleteErrorMessage = "Delete failed. Ensure linked holdings, notes, or updates are cleared."
            loadTheme()
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
            let items = (valuation?.rows ?? []).map { (name: $0.instrumentName, delta: $0.deltaUserPct ?? 0) }
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
        guard let fetched = dbManager.getPortfolioTheme(id: themeId, includeSoftDeleted: true) else { return }
        applyThemeState(fetched)
        name = fetched.name
        code = fetched.code
        statusId = fetched.statusId
        descriptionText = fetched.description ?? ""
        institutionId = fetched.institutionId
        statuses = dbManager.fetchPortfolioThemeStatuses()
        institutions = dbManager.fetchInstitutions()
        if let parsed = Self.isoFormatter.date(from: fetched.updatedAt) {
            updatedAtDate = parsed
            originalUpdatedAtDate = parsed
        }
    }

    private func applyThemeState(_ fetched: PortfolioTheme) {
        theme = fetched
        isArchivedTheme = fetched.archivedAt != nil
        isSoftDeletedTheme = fetched.softDelete
    }

    private func shouldPersistCustomUpdatedAt() -> Bool {
        guard let original = originalUpdatedAtDate else { return true }
        return abs(updatedAtDate.timeIntervalSince(original)) > 0.5
    }

    private func runValuation() {
        loadingValuation = true
        riskSnapshot = nil
        Task {
            let fxService = FXConversionService(dbManager: dbManager)
            let service = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
            let snap = service.snapshot(themeId: themeId)
            let riskService = PortfolioRiskScoringService(dbManager: dbManager, fxService: fxService)
            let risk = riskService.score(themeId: themeId, valuation: snap)
            await MainActor.run {
                self.valuation = snap
                self.riskSnapshot = risk
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
            if shouldPersistCustomUpdatedAt() {
                let isoString = Self.isoFormatter.string(from: updatedAtDate)
                _ = dbManager.setPortfolioThemeUpdatedAt(id: current.id, isoString: isoString)
            }
            loadTheme()
        }
    }

    // MARK: - Utils

    // Counted totals/counts for Holdings tab (based on User % > 0)
    private var countedUserTotalBase: Double? {
        guard let rows = valuation?.rows else { return nil }
        let sum = rows.reduce(0.0) { acc, r in
            (r.userTargetPct > 0 && r.status == .ok) ? acc + r.currentValueBase : acc
        }
        return sum
    }

    private var displayName: String { name.isEmpty ? "—" : name }

    private var statusDisplay: (name: String, color: Color) {
        if let status = statuses.first(where: { $0.id == statusId }) {
            return (status.name, Color(hex: status.colorHex))
        }
        return ("Unknown", .secondary)
    }

    private var baseCurrencyCode: String {
        let trimmed = dbManager.baseCurrency.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "CHF" : trimmed
    }

    private var actualTotalBase: Double? {
        if let included = countedUserTotalBase, included > 0 {
            return included
        }
        return valuation?.totalValueBase
    }

    private var setTargetTotalBase: Double? {
        guard let rows = valuation?.rows else { return nil }
        let sum = rows.reduce(0.0) { $0 + ($1.setTargetChf ?? 0) }
        let hasValue = rows.contains { $0.setTargetChf != nil }
        return hasValue ? sum : nil
    }

    private var deltaToSetTarget: Double? {
        guard let actual = actualTotalBase, let target = setTargetTotalBase else { return nil }
        return actual - target
    }

    private var instrumentCountDisplay: Int {
        theme?.instrumentCount ?? valuation?.rows.count ?? 0
    }

    private func formatWholeAmount(_ value: Double?) -> String {
        guard let value else { return "—" }
        return formatWhole(value)
    }

    private func formatSignedWholeAmount(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value == 0 { return "0" }
        return (value > 0 ? "+" : "-") + formatWhole(abs(value))
    }

    private func formatWhole(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "'"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    private func percent(_ value: Double) -> String {
        let pct = value * 100
        return String(format: "%.1f%%", pct)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = baseCurrencyCode
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func liquidityColor(_ tier: Int) -> Color {
        switch tier {
        case 0: return DSColor.accentSuccess
        case 1: return DSColor.accentWarning
        default: return DSColor.accentError
        }
    }

    private func liquidityLabel(_ tier: Int) -> String {
        switch tier {
        case 0: return "Liquid"
        case 1: return "Restricted"
        default: return "Illiquid"
        }
    }

    private func riskScoreColor(_ score: Double) -> Color {
        if score <= 2.5 { return DSColor.accentSuccess }
        if score <= 4.0 { return Color.blue }
        if score <= 5.5 { return DSColor.accentWarning }
        return DSColor.accentError
    }

    private func currency(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return v.formatted(.currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
    }

    private func currencyWholeCHF(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "'"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let body = formatter.string(from: NSNumber(value: v)) ?? String(format: "%.0f", v)
        return "\(baseCurrencyCode) \(body)"
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
        padding(12)
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

// MARK: - Holdings Table (read-only summary)

private struct HoldingsTable: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.openWindow) private var openWindow
    let themeId: Int
    let isArchived: Bool
    @Binding var search: String
    var columns: Set<Column>
    let fontConfig: HoldingsTableFontConfig
    var reloadToken: Int = 0
    var themeBudgetChf: Double? = nil
    var onHoldingsChanged: (() -> Void)? = nil
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
    // Debounce note saves per instrument to avoid saving on every keystroke
    @State private var noteSaveDebounce: [Int: DispatchWorkItem] = [:]

    @State private var rebalanceTagId: Int? = nil
    @State private var showTotalsInfo: Bool = false
    @State private var totalsInfoHovering: Bool = false
    @State private var hasLoadedRebalanceTag = false

    @FocusState private var focusSearch: Bool
    @FocusState private var focusedSetTargetField: Int?

    private let autoTargetColor = Color(red: 1.0, green: 0.98, blue: 0.82)
    private let manualTargetColor = Color(red: 0.86, green: 0.93, blue: 0.98)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if rows.isEmpty {
                Text("No holdings").foregroundColor(.secondary)
            } else {
                totalsSummary
                    .padding(.bottom, 4)
                // Search strip grouped tightly with table; visually separated
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Search instruments or notes", text: $search)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusSearch)
                        if !search.isEmpty {
                            Button("Clear") { search = "" }
                                .buttonStyle(.link)
                        }
                    }
                    Divider()
                }
                .font(.system(size: fontConfig.secondarySize))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                // Hidden shortcut to focus search (Cmd-F)
                Button("") { focusSearch = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .hidden()
                header
                    .background(GeometryReader { proxy in
                        Color.clear
                            .onAppear { tableWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { _, newWidth in tableWidth = newWidth }
                    })
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(sortedRows) { r in
                            rowView(r)
                        }
                    }
                }
                // Totals row (Research/User % + Counted/Excluded actuals)
                HStack(spacing: 12) {
                    let rTot = researchTotal
                    let uTot = userTotal
                    let rOk = abs(rTot - 100.0) < 0.01
                    let uOk = abs(uTot - 100.0) < 0.01
                    Label("Research sum \(rTot, format: .number)%", systemImage: rOk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(rOk ? .green : .orange)
                    Label("User sum \(uTot, format: .number)%", systemImage: uOk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(uOk ? .green : .orange)
                    // Counted and Excluded totals (Actual CHF)
                    Text("Counted Total: \(currencyWholeCHFLocal(countedActualTotal))")
                        .fontWeight(.semibold)
                    Text("Excluded: \(currencyWholeCHFLocal(excludedActualTotal))")
                        .foregroundColor(.secondary)
                }
                .font(.system(size: fontConfig.secondarySize))
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
        .alert("Remove Instrument from Theme", isPresented: Binding(
            get: { confirmRemoveId != nil },
            set: { newVal in if !newVal { confirmRemoveId = nil } }
        )) {
            Button("Cancel", role: .cancel) { confirmRemoveId = nil }
            Button("Remove", role: .destructive) {
                if let iid = confirmRemoveId { removeInstrument(iid) }
                confirmRemoveId = nil
            }
        } message: {
            if let iid = confirmRemoveId, let row = rows.first(where: { $0.instrumentId == iid }) {
                Text("Are you sure you want to remove \(row.instrumentName) from this theme?")
            } else {
                Text("Are you sure you want to remove this instrument from this theme?")
            }
        }
        .sheet(item: $openUpdates) { t in
            InstrumentUpdatesView(
                themeId: t.themeId,
                instrumentId: t.instrumentId,
                instrumentName: t.instrumentName,
                themeName: dbManager.getPortfolioTheme(id: t.themeId, includeSoftDeleted: true)?.name ?? "",
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
        .onChange(of: focusedSetTargetField) { oldValue, newValue in
            if let previous = oldValue, previous != newValue {
                commitSetTarget(previous)
            }
        }
    }

    private let defaultNumWidth: CGFloat = 80
    private func width(for col: Column) -> CGFloat {
        // Notes uses min width; actual width expands to fill
        if let w = draftColWidths[col] { return w }
        if col == .notes { return colWidths[col] ?? 200 }
        if col == .instrument { return colWidths[col] ?? 300 }
        if col == .actualChf || col == .targetChf || col == .deltaChf || col == .setTargetChf || col == .setDeltaChf { return colWidths[col] ?? 140 }
        return colWidths[col] ?? defaultNumWidth
    }

    private func labelForColumn(_ col: Column) -> String {
        switch col {
        case .actualChf:
            return "Actual \(dbManager.baseCurrency)"
        case .targetChf:
            return "Calc Target \(dbManager.baseCurrency)"
        case .setTargetChf:
            return "Set Target \(dbManager.baseCurrency)"
        case .deltaChf:
            return "Δ Calc \(dbManager.baseCurrency)"
        case .setDeltaChf:
            return "ST Delta \(dbManager.baseCurrency)"
        default:
            return col.title
        }
    }

    private func backgroundColor(for column: Column) -> Color? {
        switch column {
        case .targetChf, .deltaChf:
            return autoTargetColor.opacity(0.45)
        case .setTargetChf, .setDeltaChf:
            return manualTargetColor.opacity(0.45)
        default:
            return nil
        }
    }

    @ViewBuilder
    private func headerCell<Content: View>(for column: Column, @ViewBuilder content: () -> Content) -> some View {
        if let color = backgroundColor(for: column) {
            content()
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                )
        } else {
            content()
        }
    }

    @ViewBuilder
    private func dataCell<Content: View>(for column: Column, @ViewBuilder content: () -> Content) -> some View {
        if let color = backgroundColor(for: column) {
            content()
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                )
        } else {
            content()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if columns.contains(.instrument) { sortHeader(.instrument, title: "Instrument").frame(width: width(for: .instrument), alignment: .leading) }
            if resizable(.instrument) { resizeHandle(for: .instrument) }
            if columns.contains(.research) { sortHeader(.research, title: "Research %").frame(width: width(for: .research), alignment: .trailing) }
            if resizable(.research) { resizeHandle(for: .research) }
            if columns.contains(.user) { sortHeader(.user, title: "User %").frame(width: width(for: .user), alignment: .trailing) }
            if resizable(.user) { resizeHandle(for: .user) }
            if columns.contains(.userNorm) { sortHeader(.userNorm, title: "User % (Norm)").frame(width: width(for: .user), alignment: .trailing) }
            if resizable(.user) { resizeHandle(for: .user) }
            if columns.contains(.targetChf) {
                headerCell(for: .targetChf) {
                    sortHeader(.targetChf, title: "Calc Target \(dbManager.baseCurrency)")
                        .frame(width: width(for: .actualChf), alignment: .trailing)
                }
            }
            if resizable(.actualChf) { resizeHandle(for: .actualChf) }
            if columns.contains(.setTargetChf) {
                headerCell(for: .setTargetChf) {
                    sortHeader(.setTargetChf, title: "Set Target (ST) \(dbManager.baseCurrency)")
                        .frame(width: width(for: .actualChf), alignment: .trailing)
                }
            }
            if resizable(.actualChf) { resizeHandle(for: .actualChf) }
            if columns.contains(.actual) { sortHeader(.actual, title: "Normalised %").frame(width: width(for: .actual), alignment: .trailing) }
            if resizable(.actual) { resizeHandle(for: .actual) }
            if columns.contains(.delta) { sortHeader(.delta, title: "Δ Actual-User").frame(width: width(for: .delta), alignment: .trailing) }
            if resizable(.delta) { resizeHandle(for: .delta) }
            if columns.contains(.deltaChf) {
                headerCell(for: .deltaChf) {
                    sortHeader(.deltaChf, title: "Δ Calc \(dbManager.baseCurrency)")
                        .frame(width: width(for: .actualChf), alignment: .trailing)
                }
            }
            if resizable(.actualChf) { resizeHandle(for: .actualChf) }
            if columns.contains(.setDeltaChf) {
                headerCell(for: .setDeltaChf) {
                    sortHeader(.setDeltaChf, title: "ST Delta \(dbManager.baseCurrency)")
                        .frame(width: width(for: .actualChf), alignment: .trailing)
                }
            }
            if resizable(.actualChf) { resizeHandle(for: .actualChf) }
            if columns.contains(.actualChf) { sortHeader(.actualChf, title: "Actual \(dbManager.baseCurrency)").frame(width: width(for: .actualChf), alignment: .trailing).accessibilityLabel("Actual \(dbManager.baseCurrency)") }
            if resizable(.actualChf) { resizeHandle(for: .actualChf) }
            // Notes first (flex)
            if columns.contains(.notes) { sortHeader(.notes, title: "Notes").frame(minWidth: width(for: .notes), maxWidth: .infinity, alignment: .leading) }
            // Updates header (emoji) after Notes — always visible
            Text("📝").frame(width: 44, alignment: .center)
            if resizable(.notes) { resizeHandle(for: .notes) }
        }
        .font(.system(size: fontConfig.headerSize, weight: .semibold))
        .foregroundColor(.secondary)
    }

    private func resizable(_: Column) -> Bool { true }
    private func resizeSpacer(for _: Column) -> some View {
        // Invisible spacer to match resize handle width in header, keeping column alignment
        Rectangle().fill(Color.clear).frame(width: 6, height: 18)
    }

    @State private var draftColWidths: [Column: CGFloat] = [:]

    private func resizeHandle(for col: Column) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.001)) // wide hit area
            .frame(width: 6, height: 18)
            .overlay(Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 2))
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                var w = width(for: col) + value.translation.width
                w = max(40, min(600, w))
                draftColWidths[col] = round(w)
            }.onEnded { _ in
                if let w = draftColWidths[col] { colWidths[col] = w }
                draftColWidths.removeValue(forKey: col)
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
        case .userNorm:
            let candidates = rows.map { normalizedUserPct($0.instrumentId) ?? 0 } + [100.0, 0.0]
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
        case .targetChf, .setTargetChf, .deltaChf, .setDeltaChf, .actualChf:
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
        colWidths[col] = round(target)
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

    // Extracted row builder to reduce type-checking complexity and provide local formatting helpers.
    @ViewBuilder
    private func rowView(_ r: ValuationRow) -> some View {
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
                    .font(.system(size: fontConfig.rowSize, design: .monospaced))
                    .frame(width: width(for: .research))
                    .disabled(isArchived)
                    .onSubmit { saveRow(r.instrumentId) }
                    .onChange(of: editableResearch(r.instrumentId)) { _, _ in saveRow(r.instrumentId) }
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(invalidKeys.contains(key(for: r.instrumentId, field: .research)) ? Color.red.opacity(0.6) : Color.gray.opacity(0.25)))
                    .help("0–100")
            }
            if resizable(.research) { resizeSpacer(for: .research) }
            if columns.contains(.user) {
                TextField("", value: bindingDouble(for: r.instrumentId, field: .user), format: .number)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: fontConfig.rowSize, design: .monospaced))
                    .frame(width: width(for: .user))
                    .disabled(isArchived)
                    .onSubmit { saveRow(r.instrumentId) }
                    .onChange(of: editableUser(r.instrumentId)) { _, _ in saveRow(r.instrumentId) }
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(invalidKeys.contains(key(for: r.instrumentId, field: .user)) ? Color.red.opacity(0.6) : Color.gray.opacity(0.25)))
                    .help("0–100")
            }
            if resizable(.user) { resizeSpacer(for: .user) }
            if columns.contains(.userNorm) {
                Text(fmtPctWhole(normalizedUserPct(r.instrumentId)))
                    .frame(width: width(for: .user), alignment: .trailing)
            }
            if resizable(.user) { resizeSpacer(for: .user) }
            if columns.contains(.targetChf) {
                dataCell(for: .targetChf) {
                    Text(formatAmountLocal(targetChf(r.instrumentId), decimals: 0))
                        .fontWeight(.bold)
                        .foregroundColor(Theme.primaryAccent)
                        .frame(width: width(for: .actualChf), alignment: .trailing)
                }
            }
            if resizable(.actualChf) { resizeSpacer(for: .targetChf) }
            if columns.contains(.setTargetChf) {
                dataCell(for: .setTargetChf) {
                    TextField("", text: bindingSetTarget(for: r.instrumentId))
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: fontConfig.rowSize, design: .monospaced))
                        .frame(width: width(for: .actualChf), alignment: .trailing)
                        .disabled(isArchived)
                        .focused($focusedSetTargetField, equals: r.instrumentId)
                        .onSubmit { commitSetTarget(r.instrumentId) }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(invalidKeys.contains(key(for: r.instrumentId, field: .setTarget)) ? Color.red.opacity(0.6) : Color.gray.opacity(0.25))
                        )
                }
            }
            if resizable(.actualChf) { resizeSpacer(for: .setTargetChf) }
            if columns.contains(.actual) {
                if editableUser(r.instrumentId) == 0 {
                    Text("").frame(width: width(for: .actual), alignment: .trailing)
                } else {
                    // Recompute Actual % based on counted total
                    let denom = countedActualTotal
                    let apct: Double? = denom > 0 ? (r.currentValueBase / denom) * 100.0 : nil
                    Text(fmtPctWhole(apct)).frame(width: width(for: .actual), alignment: .trailing)
                }
            }
            if resizable(.actual) { resizeSpacer(for: .actual) }
            if columns.contains(.delta) {
                if editableUser(r.instrumentId) == 0 {
                    Text("").frame(width: width(for: .delta), alignment: .trailing)
                } else {
                    Text(fmtPct(r.deltaUserPct))
                        .frame(width: width(for: .delta), alignment: .trailing)
                        .foregroundColor((r.deltaUserPct ?? 0) >= 0 ? .green : .red)
                }
            }
            if resizable(.delta) { resizeSpacer(for: .delta) }
            if columns.contains(.deltaChf) {
                dataCell(for: .deltaChf) {
                    if editableUser(r.instrumentId) == 0 {
                        Text("").frame(width: width(for: .actualChf), alignment: .trailing)
                    } else {
                        let d = (targetChf(r.instrumentId) - r.currentValueBase)
                        Text(formatAmountLocal(d, decimals: 0))
                            .frame(width: width(for: .actualChf), alignment: .trailing)
                            .foregroundColor(d >= 0 ? .green : .red)
                    }
                }
            }
            if resizable(.actualChf) { resizeSpacer(for: .deltaChf) }
            if columns.contains(.setDeltaChf) {
                dataCell(for: .setDeltaChf) {
                    if editableUser(r.instrumentId) == 0 {
                        Text("").frame(width: width(for: .actualChf), alignment: .trailing)
                    } else if let delta = setTargetDelta(r.instrumentId, actual: r.currentValueBase) {
                        Text(formatAmountLocal(delta, decimals: 0))
                            .frame(width: width(for: .actualChf), alignment: .trailing)
                            .foregroundColor(delta >= 0 ? .green : .red)
                    } else {
                        Text("—")
                            .frame(width: width(for: .actualChf), alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if resizable(.actualChf) { resizeSpacer(for: .setDeltaChf) }
            if columns.contains(.actualChf) {
                Text(wholeNumberAmountString(r.currentValueBase))
                    .foregroundColor(editableUser(r.instrumentId) == 0 ? .secondary : .primary)
                    .frame(width: width(for: .actualChf), alignment: .trailing)
            }
            if resizable(.actualChf) { resizeSpacer(for: .actualChf) }
            if columns.contains(.notes) {
                TextField("Notes", text: bindingNotes(for: r.instrumentId))
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 2)
                    .font(.system(size: fontConfig.rowSize))
                    .frame(minWidth: width(for: .notes), maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
                    .disabled(isArchived)
                    .onSubmit { saveRow(r.instrumentId) }
            }
            if resizable(.notes) { resizeSpacer(for: .notes) }
            if let delta = setTargetDelta(r.instrumentId, actual: r.currentValueBase),
               abs(delta) >= 5000,
               editableUser(r.instrumentId) > 0
            {
                Button {
                    triggerRebalance(for: r, delta: delta)
                } label: {
                    Text("🔔")
                }
                .buttonStyle(.borderless)
                .frame(width: 34)
                .help("Create rebalance to-do")
            }
            if !isArchived {
                Button { confirmRemoveId = r.instrumentId } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Remove from theme")
            }
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
        .font(.system(size: fontConfig.rowSize, design: .monospaced))
        .background(editableUser(r.instrumentId) == 0 ? Color.gray.opacity(0.1) : Color.clear)
        .contextMenu { Button("Instrument Updates…") { openUpdates = UpdatesTarget(themeId: themeId, instrumentId: r.instrumentId, instrumentName: r.instrumentName) } }
    }

    private var totalsSummary: some View {
        HStack(alignment: .top, spacing: 12) {
            totalsCard(title: "Calc Target CHF", value: totalCalcTargetChf, accent: Theme.primaryAccent)
            totalsCard(title: "Set Target (ST) CHF", value: totalSetTargetChf, accent: Color.blue)
            totalsCard(title: "Actual CHF", value: totalActualChf, accent: Color.accentColor, extras: actualTotalsBreakdown)
            Spacer(minLength: 8)
            Button(action: { showTotalsInfo = true }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .onHover { hovering in
                if hovering {
                    showTotalsInfo = true
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !totalsInfoHovering { showTotalsInfo = false }
                    }
                }
            }
            .popover(isPresented: $showTotalsInfo, arrowEdge: .top) {
                totalsInfoPopover
                    .padding(16)
                    .frame(minWidth: 320, alignment: .leading)
                    .onHover { hovering in
                        totalsInfoHovering = hovering
                        if !hovering {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if !totalsInfoHovering { showTotalsInfo = false }
                            }
                        }
                    }
                    .onDisappear { totalsInfoHovering = false }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func totalsCard(title: String, value: Double, accent: Color, extras: [(String, Double)] = []) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                totalsPair(label: title, value: formatAmountLocal(value, decimals: 0), accent: accent)
                ForEach(extras.indices, id: \.self) { idx in
                    let extra = extras[idx]
                    totalsPair(label: extra.0, value: formatAmountLocal(extra.1, decimals: 0), accent: .primary)
                }
            }
        }
        .frame(minWidth: 220, alignment: .leading)
        .analyticsCard()
    }

    private func totalsPair(label: String, value: String, accent: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(label):")
                .font(.system(size: max(fontConfig.secondarySize, 12), weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: max(fontConfig.rowSize + 4, CGFloat(14)), weight: .semibold, design: .monospaced))
                .foregroundColor(accent)
        }
    }

    private var totalsInfoPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Totals & Targets").font(.headline)
            infoRow("Actual CHF", "Market value of all holdings (counted + excluded) in base currency.")
            infoRow("Counted", "Portion of Actual CHF that qualifies for targets (User % > 0 with price/FX available); used for normalisation and dashboards.")
            infoRow("Excluded", "Holdings not counted because User % = 0 or missing FX/price.")
            infoRow("Calc Target CHF", "Budget-based CHF target using the normalised User % of counted holdings.")
            infoRow("Set Target (ST) CHF", "Manual CHF target override you enter; sums across all holdings.")
        }
    }

    private func infoRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).bold()
            Text(body)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Local formatter for numeric amounts (no currency code)
    private func formatAmountLocal(_ v: Double, decimals: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.maximumFractionDigits = decimals
        f.minimumFractionDigits = decimals
        return f.string(from: NSNumber(value: v)) ?? String(format: decimals == 0 ? "%.0f" : "%.2f", v)
    }

    // Local CHF whole-number currency with Swiss grouping (apostrophes)
    private var currencyCode: String {
        let code = dbManager.baseCurrency.trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty ? "CHF" : code
    }

    private func currencyWholeCHFLocal(_ v: Double) -> String {
        "\(currencyCode) \(formatAmountLocal(v, decimals: 0))"
    }

    private func ensureRebalanceTagId() -> Int? {
        if hasLoadedRebalanceTag {
            return rebalanceTagId
        }
        hasLoadedRebalanceTag = true
        let repository = TagRepository(dbManager: dbManager)
        let match = repository.listActive().first { tag in
            let code = tag.code.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = tag.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return code.caseInsensitiveCompare("REBALANCE") == .orderedSame ||
                code.caseInsensitiveCompare("#REBALANCE") == .orderedSame ||
                name.caseInsensitiveCompare("REBALANCE") == .orderedSame ||
                name.caseInsensitiveCompare("#REBALANCE") == .orderedSame
        }
        rebalanceTagId = match?.id
        return rebalanceTagId
    }

    private func triggerRebalance(for row: ValuationRow, delta: Double) {
        let direction = delta < 0 ? "SELL" : "BUY"
        let amountText = formatAmountLocal(abs(delta), decimals: 0)
        let description = "Rebalance \(row.instrumentName) \(direction) CHF \(amountText)"
        var tagIDs: [Int] = []
        if let tagId = ensureRebalanceTagId() {
            tagIDs = [tagId]
        }
        let dueDate = Calendar.current.startOfDay(for: Date())
        let request = KanbanTodoQuickAddRequest(description: description,
                                                priority: .medium,
                                                dueDate: dueDate,
                                                column: .prioritised,
                                                tagIDs: tagIDs)
        KanbanTodoQuickAddRouter.shared.stash(request)
        NotificationCenter.default.post(name: .kanbanTodoQuickAddRequested, object: request)
        openWindow(id: "todoBoard")
    }

    private func manualTargetDisplayString(_ value: Double?) -> String {
        guard let value else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        guard var str = formatter.string(from: NSNumber(value: value)) else { return "" }
        if abs(value) < 1 {
            if str.hasPrefix("-0.") {
                str = "-" + str.dropFirst(2)
            } else if str.hasPrefix("0.") {
                str = String(str.dropFirst(1))
            }
        }
        return str
    }

    private func setTargetDraft(_ value: Double?) -> String {
        manualTargetDisplayString(value)
    }

    private func sanitizeAmountString(_ raw: String) -> String {
        var sanitized = raw.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
        if sanitized.contains(".") {
            sanitized = sanitized.replacingOccurrences(of: ",", with: "")
        } else if sanitized.contains(",") {
            sanitized = sanitized.replacingOccurrences(of: ",", with: ".")
        }
        return sanitized
    }

    private func parseAmount(_ raw: String) -> Double? {
        let sanitized = sanitizeAmountString(raw)
        return Double(sanitized)
    }

    private func isPartialNumericDraft(_ raw: String) -> Bool {
        let sanitized = sanitizeAmountString(raw)
        if sanitized.isEmpty { return false }
        if sanitized == "-" || sanitized == "." || sanitized == "-." { return true }
        if sanitized.hasSuffix(".") { return true }
        return false
    }

    private func editableSetTarget(_ instrumentId: Int) -> Double? {
        edits[instrumentId]?.setTargetChf
    }

    private func setTargetDelta(_ instrumentId: Int, actual: Double) -> Double? {
        guard let target = editableSetTarget(instrumentId) else { return nil }
        return target - actual
    }

    private func load() {
        let fx = FXConversionService(dbManager: dbManager)
        let service = PortfolioValuationService(dbManager: dbManager, fxService: fx)
        let snap = service.snapshot(themeId: themeId)
        rows = snap.rows.sorted { $0.instrumentName < $1.instrumentName }
        // seed editable fields from valuation rows
        var dict: [Int: Edit] = [:]
        for r in rows {
            dict[r.instrumentId] = Edit(
                research: r.researchTargetPct,
                user: r.userTargetPct,
                setTargetChf: r.setTargetChf,
                setTargetDraft: setTargetDraft(r.setTargetChf),
                notes: r.notes ?? ""
            )
        }
        edits = dict
        invalidKeys.removeAll()
        // Compute total Actual CHF excluding instruments with User % = 0
        let includedTotal = rows.reduce(0.0) { acc, r in
            let u = editableUser(r.instrumentId)
            return u > 0 ? acc + r.currentValueBase : acc
        }
        total = includedTotal
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
        case .userNorm:
            arr.sort { l, r in
                let lv = normalizedUserPct(l.instrumentId) ?? -1
                let rv = normalizedUserPct(r.instrumentId) ?? -1
                if lv == rv { return tieBreak(l, r) }
                return sortAscending ? (lv < rv) : (lv > rv)
            }
        case .targetChf:
            arr.sort { l, r in
                let lv = targetChf(l.instrumentId)
                let rv = targetChf(r.instrumentId)
                if lv == rv { return tieBreak(l, r) }
                return sortAscending ? (lv < rv) : (lv > rv)
            }
        case .setTargetChf:
            arr.sort { l, r in
                let lv = editableSetTarget(l.instrumentId)
                let rv = editableSetTarget(r.instrumentId)
                if lv == rv { return tieBreak(l, r) }
                switch (lv, rv) {
                case (nil, nil): return tieBreak(l, r)
                case (nil, _): return !sortAscending
                case (_, nil): return sortAscending
                case let (lv?, rv?):
                    if lv == rv { return tieBreak(l, r) }
                    return sortAscending ? (lv < rv) : (lv > rv)
                }
            }
        case .deltaChf:
            arr.sort { l, r in
                let lv = targetChf(l.instrumentId) - l.currentValueBase
                let rv = targetChf(r.instrumentId) - r.currentValueBase
                if lv == rv { return tieBreak(l, r) }
                return sortAscending ? (lv < rv) : (lv > rv)
            }
        case .setDeltaChf:
            arr.sort { l, r in
                let lv = setTargetDelta(l.instrumentId, actual: l.currentValueBase)
                let rv = setTargetDelta(r.instrumentId, actual: r.currentValueBase)
                if lv == rv { return tieBreak(l, r) }
                switch (lv, rv) {
                case (nil, nil): return tieBreak(l, r)
                case (nil, _): return !sortAscending
                case (_, nil): return sortAscending
                case let (lv?, rv?):
                    if lv == rv { return tieBreak(l, r) }
                    return sortAscending ? (lv < rv) : (lv > rv)
                }
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

    // MARK: - Normalization & Targets

    private var sumCountedUser: Double {
        rows.reduce(0.0) { acc, r in
            let u = editableUser(r.instrumentId)
            return u > 0 ? acc + u : acc
        }
    }

    private var countedActualTotal: Double {
        rows.reduce(0.0) { acc, r in
            let u = editableUser(r.instrumentId)
            return u > 0 ? acc + r.currentValueBase : acc
        }
    }

    private var excludedActualTotal: Double {
        rows.reduce(0.0) { acc, r in
            let u = editableUser(r.instrumentId)
            return u == 0 ? acc + r.currentValueBase : acc
        }
    }

    private var totalCalcTargetChf: Double {
        rows.reduce(0.0) { acc, row in
            acc + targetChf(row.instrumentId)
        }
    }

    private var totalSetTargetChf: Double {
        rows.reduce(0.0) { acc, row in
            acc + (editableSetTarget(row.instrumentId) ?? 0)
        }
    }

    private var totalActualChf: Double {
        rows.reduce(0.0) { acc, row in
            acc + row.currentValueBase
        }
    }

    private var actualTotalsBreakdown: [(String, Double)] {
        guard totalActualChf > 0 else { return [] }
        return [
            ("Counted", countedActualTotal),
            ("Excluded", excludedActualTotal),
        ]
    }

    private func normalizedUserPct(_ id: Int) -> Double? {
        let u = editableUser(id)
        guard u > 0 else { return 0 }
        let s = sumCountedUser
        guard s > 0 else { return nil }
        return (u / s) * 100.0
    }

    private func fmtPctWhole(_ v: Double?) -> String {
        guard let x = v else { return "—" }
        return String(format: "%.0f", x.rounded())
    }

    private func wholeNumberAmountString(_ value: Double?) -> String {
        guard let value else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let rounded = value.rounded()
        return formatter.string(from: NSNumber(value: rounded)) ?? String(format: "%.0f", rounded)
    }

    private func targetChf(_ id: Int) -> Double {
        guard let b = themeBudgetChf, b > 0 else { return 0 }
        guard let n = normalizedUserPct(id) else { return 0 }
        return (n / 100.0) * b
    }

    // MARK: - Editing helpers

    private enum Field { case research, user, setTarget }
    private func key(for instrumentId: Int, field: Field) -> String {
        let suffix: String
        switch field {
        case .research: suffix = "research"
        case .user: suffix = "user"
        case .setTarget: suffix = "setTarget"
        }
        return "\(instrumentId):\(suffix)"
    }

    private func bindingDouble(for instrumentId: Int, field: Field) -> Binding<Double> {
        Binding<Double>(
            get: {
                if let e = edits[instrumentId] { return field == .research ? e.research : e.user }
                return 0
            },
            set: { newValue in
                let clamped = max(0, min(100, newValue))
                var e = edits[instrumentId] ?? Edit(research: 0, user: 0, setTargetChf: nil, setTargetDraft: "", notes: "")
                if field == .research { e.research = clamped } else { e.user = clamped }
                edits[instrumentId] = e
                let k = key(for: instrumentId, field: field)
                if newValue != clamped { invalidKeys.insert(k) } else { invalidKeys.remove(k) }
            }
        )
    }

    private func bindingSetTarget(for instrumentId: Int) -> Binding<String> {
        Binding<String>(
            get: { edits[instrumentId]?.setTargetDraft ?? "" },
            set: { newValue in
                var e = edits[instrumentId] ?? Edit(research: 0, user: 0, setTargetChf: nil, setTargetDraft: "", notes: "")
                e.setTargetDraft = newValue
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let keyName = key(for: instrumentId, field: .setTarget)
                if trimmed.isEmpty {
                    e.setTargetChf = nil
                    invalidKeys.remove(keyName)
                } else if let parsed = parseAmount(trimmed) {
                    e.setTargetChf = parsed
                    invalidKeys.remove(keyName)
                } else if isPartialNumericDraft(trimmed) {
                    invalidKeys.remove(keyName)
                } else {
                    e.setTargetChf = nil
                    invalidKeys.insert(keyName)
                }
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
                // Debounce saves to reduce DB writes while typing
                noteSaveDebounce[instrumentId]?.cancel()
                let task = DispatchWorkItem { saveRow(instrumentId) }
                noteSaveDebounce[instrumentId] = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
            }
        )
    }

    private func commitSetTarget(_ instrumentId: Int) {
        guard !invalidKeys.contains(key(for: instrumentId, field: .setTarget)) else { return }
        saveRow(instrumentId)
    }

    private func saveRow(_ instrumentId: Int) {
        guard let e = edits[instrumentId] else { return }
        if invalidKeys.contains(key(for: instrumentId, field: .setTarget)) { return }
        saving.insert(instrumentId)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = dbManager.updateThemeAssetDetailed(
                themeId: themeId,
                instrumentId: instrumentId,
                researchPct: e.research,
                userPct: e.user,
                setTargetChf: e.setTargetChf,
                // Use empty string to explicitly clear notes; nil would mean "no change" in DB layer
                notes: e.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : e.notes
            )
            DispatchQueue.main.async {
                saving.remove(instrumentId)
                if result.0 != nil {
                    load() // refresh valuation/deltas after saving
                    onHoldingsChanged?()
                    showQuickToast("Saved")
                } else {
                    let msg = result.1 ?? "Save failed"
                    LoggingService.shared.log("[UI] updateThemeAsset failed themeId=\(themeId) instrumentId=\(instrumentId): \(msg)", logger: .ui)
                    showQuickToast(msg)
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

    private struct Edit {
        var research: Double
        var user: Double
        var setTargetChf: Double?
        var setTargetDraft: String
        var notes: String

        init(research: Double, user: Double, setTargetChf: Double?, setTargetDraft: String, notes: String) {
            self.research = research
            self.user = user
            self.setTargetChf = setTargetChf
            self.setTargetDraft = setTargetDraft
            self.notes = notes
        }

        init(research: Double, user: Double, notes: String) {
            self.init(research: research, user: user, setTargetChf: nil, setTargetDraft: "", notes: notes)
        }
    }

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
        case instrument, research, user, userNorm, targetChf, setTargetChf, actual, delta, deltaChf, setDeltaChf, actualChf, notes
        var id: String { rawValue }
        var title: String {
            switch self {
            case .instrument: return "Instrument"
            case .research: return "Research %"
            case .user: return "User %"
            case .userNorm: return "User % (Norm)"
            case .targetChf: return "Calc Target CHF"
            case .setTargetChf: return "Set Target (ST) CHF"
            case .actual: return "Normalised %"
            case .delta: return "Δ Actual-User"
            case .deltaChf: return "Δ Calc CHF"
            case .setDeltaChf: return "ST Delta CHF"
            case .actualChf: return "Actual CHF"
            case .notes: return "Notes"
            }
        }

        static let defaultVisible: [Column] = [.instrument, .research, .user, .userNorm, .targetChf, .setTargetChf, .actual, .delta, .deltaChf, .setDeltaChf, .actualChf, .notes]
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
            ForEach(Array(Column.allCases), id: \.self) { col in
                HStack {
                    Text(labelForColumn(col)).frame(width: 140, alignment: .leading)
                    Slider(value: Binding(
                        get: { Double(width(for: col)) },
                        set: { colWidths[col] = CGFloat($0) }
                    ), in: 40 ... 600)
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
        let (ok, err) = dbManager.removeThemeAssetDetailed(themeId: themeId, instrumentId: instrumentId)
        if ok {
            load()
            onHoldingsChanged?()
            showQuickToast("Removed")
        } else { showQuickToast(err ?? "Delete failed"); LoggingService.shared.log("[UI] removeThemeAsset failed themeId=\(themeId) instrumentId=\(instrumentId): \(err ?? "unknown")", logger: .ui) }
    }
}
