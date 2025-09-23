// DragonShield/Views/PortfolioThemeDetailView.swift
// Layout-polished detail editor for portfolio themes.

import SwiftUI
#if canImport(Charts)
import Charts
#endif

enum DetailTab: String, CaseIterable {
    case composition
    case valuation
    case updates
}

struct PortfolioThemeDetailView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let origin: String
    let initialTab: DetailTab
    let initialSearch: String?
    let searchHint: String?
    var onSave: (PortfolioTheme) -> Void
    var onArchive: () -> Void
    var onUnarchive: (Int) -> Void
    var onSoftDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserDefaultsKeys.portfolioThemeDetailLastTab) private var lastTabRaw: String = DetailTab.composition.rawValue
    @State private var selectedTab: DetailTab = .composition

    @State private var theme: PortfolioTheme?
    @State private var name: String = ""
    @State private var code: String = ""
    @State private var statusId: Int = 0
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var descriptionText: String = ""
    @State private var institutionId: Int? = nil
    @State private var institutions: [DatabaseManager.InstitutionData] = []
    @State private var showAddInstitution = false

    @State private var assets: [PortfolioThemeAsset] = []
    @State private var valuation: ValuationSnapshot?
    @State private var valuating = false
    @State private var allInstruments: [(id: Int, name: String)] = []
    @State private var showAdd = false
    @State private var addInstrumentId: Int = 0
    @State private var addInstrumentQuery: String = ""
    @State private var addResearchPct: Double = 0
    @State private var addUserPct: Double = 0
    @State private var addNotes: String = ""
    @State private var alertItem: AlertItem?
    @State private var editingAsset: PortfolioThemeAsset?
    @State private var noteDraft: String = ""

    @State private var compositionSortColumn: CompositionSortColumn = .research
    @State private var compositionSortDirection: CompositionSortDirection = .descending
    @FocusState private var focusedField: CompositionFocusField?

    @State private var tolerance: Double = 2.0
    @State private var onlyOutOfTolerance = false
    @State private var showDeltaResearch = true
    @State private var showDeltaUser = true
    @State private var sortField: SortField = .instrument
    @State private var sortAscending = true

    private struct InstrumentSheetTarget: Identifiable {
        let instrumentId: Int
        let instrumentName: String
        var id: Int { instrumentId }
    }

    @State private var updateCounts: [Int: Int] = [:]
    @State private var instrumentSheet: InstrumentSheetTarget?

    private enum SortField {
        case instrument, deltaResearch, deltaUser
    }

    private enum CompositionSortColumn {
        case instrument, research, user
    }

    private enum CompositionSortDirection {
        case ascending, descending
    }

    private enum CompositionFocusField: Hashable {
        case research(Int)
        case user(Int)
        case notes(Int)
    }

    private let labelWidth: CGFloat = 140
    private let noteMaxLength = NoteEditorView.maxLength

    init(themeId: Int, origin: String, initialTab: DetailTab = .composition, initialSearch: String? = nil, searchHint: String? = nil, onSave: @escaping (PortfolioTheme) -> Void = { _ in }, onArchive: @escaping () -> Void = {}, onUnarchive: @escaping (Int) -> Void = { _ in }, onSoftDelete: @escaping () -> Void = {}) {
        self.themeId = themeId
        self.origin = origin
        self.initialTab = initialTab
        self.initialSearch = initialSearch
        self.searchHint = searchHint
        self.onSave = onSave
        self.onArchive = onArchive
        self.onUnarchive = onUnarchive
        self.onSoftDelete = onSoftDelete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    compositionTab
                        .tag(DetailTab.composition)
                        .tabItem { Text("Composition") }
                    valuationTab
                        .tag(DetailTab.valuation)
                        .tabItem { Text("Valuation") }
                    updatesTab
                        .tag(DetailTab.updates)
                        .tabItem { Text("Updates") }
                }
                Divider()
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Save") { saveTheme() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!valid || isReadOnly)
                }
                .padding(24)
            }
            .navigationTitle("Portfolio Theme Details: \(name)")
        }
        .frame(minWidth: 1200, idealWidth: 1360, minHeight: 640, idealHeight: 720)
        .onAppear {
            loadTheme()
            runValuation()
            selectedTab = initialTab
            lastTabRaw = selectedTab.rawValue
        }
        .onChange(of: selectedTab) { _, newValue in
            lastTabRaw = newValue.rawValue
            if newValue == .valuation { runValuation() }
        }
        .sheet(isPresented: $showAdd) { addSheet }
        .sheet(isPresented: $showAddInstitution) {
            AddInstitutionView { id in
                institutions = dbManager.fetchInstitutions()
                institutionId = id
            }
            .environmentObject(dbManager)
        }
        .sheet(item: $editingAsset) { asset in
            NoteEditorView(
                title: "Edit Note — \(instrumentName(asset.instrumentId))",
                note: $noteDraft,
                isReadOnly: isReadOnly,
                onSave: {
                    var trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.count > noteMaxLength {
                        trimmed = String(trimmed.prefix(noteMaxLength))
                    }
                    var updated = asset
                    updated.notes = trimmed.isEmpty ? nil : trimmed
                    if let idx = assets.firstIndex(where: { $0.id == asset.id }) {
                        assets[idx] = updated
                    }
                    save(updated)
                    editingAsset = nil
                },
                onCancel: { editingAsset = nil }
            )
        }
        .sheet(item: $instrumentSheet) { target in
            InstrumentUpdatesView(
                themeId: themeId,
                instrumentId: target.instrumentId,
                instrumentName: target.instrumentName,
                themeName: name,
                valuation: valuation,
                onClose: { refreshUpdateCounts() }
            )
            .environmentObject(dbManager)
        }
        .alert(item: $alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK"), action: item.action))
        }
    }

    // MARK: - Sections


    private var compositionTab: some View {
        VStack(spacing: 0) {
            if isReadOnly {
                Text("Archived theme - read only")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerBlock
                    Divider()
                    compositionSection
                    Divider()
                    dangerZone
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var valuationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                valuationSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var updatesTab: some View {
        PortfolioThemeUpdatesView(themeId: themeId, initialSearchText: initialSearch, searchHint: searchHint)
            .environmentObject(dbManager)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top row: meta on left, compact notes on right
            HStack(alignment: .top, spacing: 24) {
                // Left column: details stacked vertically
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Name + status line
                        HStack(spacing: 12) {
                            TextField("Name", text: $name)
                                .disabled(isReadOnly)
                            Text(code)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().stroke(Color.secondary))
                            Picker("Status", selection: $statusId) {
                                ForEach(statuses) { status in
                                    Text(status.name).tag(status.id)
                                }
                            }
                            .labelsHidden()
                            .disabled(isReadOnly)
                        }
                        // Archived at + Institution
                        HStack(spacing: 12) {
                            Text("Archived at: \(theme?.archivedAt ?? "-")")
                                .foregroundColor(.secondary)
                            Picker("Institution", selection: $institutionId) {
                                Text("None").tag(nil as Int?)
                                ForEach(institutions) { inst in
                                    Text(inst.name).tag(inst.id as Int?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .disabled(isReadOnly)
                            // 'Add New' removed to simplify header
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: compact notes editor
                VStack(alignment: .leading, spacing: 6) {
                    // Align top of notes editor with name field by removing a preceding label
                    TextEditor(text: $descriptionText)
                        .frame(width: 420, height: 100)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                        .disabled(isReadOnly)
                    Text("\(descriptionText.count) / 2000")
                        .font(.caption)
                        .foregroundColor(descriptionText.count > 2000 ? .red : .secondary)
                }
            }

            // Second row: charts side by side
            #if canImport(Charts)
            if !assets.isEmpty {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User % Distribution").font(.title3).bold()
                        userPieChartWithLegend
                            .frame(height: 380)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Delta (Research − User)").font(.title3).bold()
                        deltaBarChart
                            .frame(minWidth: 360, maxWidth: 520, minHeight: 90)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
                    }
                }
            }
            #endif
        }
    }

    private var compositionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Composition").font(.headline)
            Button("Add Instrument") { showAdd = true }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)
                .disabled(isReadOnly || availableInstruments.isEmpty)

            // Charts moved into headerBlock on the right for a lean top layout

            if assets.isEmpty {
                Text("No instruments attached")
            } else {
                LazyVStack(spacing: 2) {
                    HStack(spacing: 12) {
                        sortableHeader(.instrument, title: "Instrument")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        sortableHeader(.research, title: "Research %")
                            .frame(width: 80, alignment: .trailing)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        sortableHeader(.user, title: "User %")
                            .frame(width: 80, alignment: .trailing)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("Notes")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer().frame(width: 40)
                        Spacer().frame(width: 28)
                        Spacer().frame(width: 28)
                    }
                    ForEach($assets) { $asset in
                        HStack(alignment: .center, spacing: 12) {
                            Text(instrumentName($asset.wrappedValue.instrumentId))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(instrumentName($asset.wrappedValue.instrumentId))
                            TextField("", value: $asset.researchTargetPct, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .disabled(isReadOnly)
                                .focused($focusedField, equals: .research($asset.wrappedValue.instrumentId))
                                .onChange(of: asset.researchTargetPct) { _, _ in
                                    save($asset.wrappedValue)
                                    sortAssets()
                                }
                            TextField("", value: $asset.userTargetPct, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .disabled(isReadOnly)
                                .focused($focusedField, equals: .user($asset.wrappedValue.instrumentId))
                                .onChange(of: asset.userTargetPct) { _, _ in
                                    save($asset.wrappedValue)
                                    sortAssets()
                                }
                            TextField("", text: Binding(
                                get: { $asset.wrappedValue.notes ?? "" },
                                set: { newValue in
                                    var trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if trimmed.count > noteMaxLength {
                                        trimmed = String(trimmed.prefix(noteMaxLength))
                                    }
                                    $asset.wrappedValue.notes = trimmed.isEmpty ? nil : trimmed
                                    save($asset.wrappedValue)
                                }
                            ))
                            .frame(minWidth: 100, maxWidth: .infinity)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help($asset.wrappedValue.notes ?? "")
                            .disabled(isReadOnly)
                            .focused($focusedField, equals: .notes($asset.wrappedValue.instrumentId))
                            Button {
                                instrumentSheet = InstrumentSheetTarget(instrumentId: $asset.wrappedValue.instrumentId, instrumentName: instrumentName($asset.wrappedValue.instrumentId))
                            } label: {
                                let count = updateCounts[$asset.wrappedValue.instrumentId] ?? 0
                                Text(count > 0 ? "📝 \(count)" : "📝")
                            }
                            .buttonStyle(.borderless)
                            .frame(width: 40)
                            .help("Instrument updates")
                            .accessibilityLabel("Instrument updates for \(instrumentName($asset.wrappedValue.instrumentId))")
                            Button {
                                editingAsset = $asset.wrappedValue
                                noteDraft = $asset.wrappedValue.notes ?? ""
                            } label: {
                                Image(systemName: "note.text")
                            }
                            .buttonStyle(.borderless)
                            .frame(width: 28)
                            .help(isReadOnly ? "Read-only — theme archived" : "Edit note")
                            .accessibilityLabel("Edit note for \(instrumentName($asset.wrappedValue.instrumentId))")
                            .disabled(isReadOnly)
                            if !isReadOnly {
                                Button(action: { remove($asset.wrappedValue) }) {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .frame(width: 28)
                            } else {
                                Spacer().frame(width: 28)
                            }
                        }
                        // Grey background when user allocation is 0%
                        .background(($asset.wrappedValue.userTargetPct == 0) ? Color.gray.opacity(0.1) : Color.clear)
                        .padding(.vertical, 1)
                        .contextMenu {
                            Button("Instrument Updates…") {
                                instrumentSheet = InstrumentSheetTarget(instrumentId: $asset.wrappedValue.instrumentId, instrumentName: instrumentName($asset.wrappedValue.instrumentId))
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        Label("Research sum \(researchTotal, format: .number)%", systemImage: researchTotalWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(researchTotalWarning ? .orange : .green)
                        Label("User sum \(userTotal, format: .number)%", systemImage: userTotalWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(userTotalWarning ? .orange : .green)
                    }
                }
            }
        }
    }

#if canImport(Charts)
    private var userPieChartWithLegend: some View {
        let rows = assets
            .filter { $0.userTargetPct > 0 }
            .map { (name: instrumentName($0.instrumentId), value: $0.userTargetPct) }
        let names = rows.map { $0.name }
        let palette: [Color] = [.blue, .green, .orange, .pink, .purple, .teal, .red, .mint, .indigo, .brown, .cyan, .yellow]
        let colors: [Color] = names.enumerated().map { palette[$0.offset % palette.count] }
        return HStack(alignment: .top, spacing: 16) {
            Chart(rows, id: \.name) { row in
                SectorMark(
                    angle: .value("User %", row.value),
                    innerRadius: .ratio(0.55),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Instrument", row.name))
            }
            .chartForegroundStyleScale(domain: names, range: colors)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            Spacer(minLength: 12)
            // Legend aligned to the far right with a border
            VStack(alignment: .leading, spacing: 6) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(names.enumerated()), id: \.0) { idx, name in
                            HStack(spacing: 8) {
                                Circle().fill(colors[idx]).frame(width: 10, height: 10)
                                Text(shortName(name, max: 10))
                                    .font(.caption)
                                    .lineLimit(1)
                                    .help(name)
                            }
                        }
                    }
                }
            }
            .frame(width: 240, alignment: .topLeading)
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))
        }
    }

    private var deltaBarChart: some View {
        let items = assets.map { (name: instrumentName($0.instrumentId), delta: $0.researchTargetPct - $0.userTargetPct) }
        return Chart(items, id: \.name) { it in
            BarMark(
                x: .value("Delta", it.delta),
                y: .value("Instrument", it.name)
            )
            .foregroundStyle(it.delta >= 0 ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
        }
        .chartXAxisLabel("%", alignment: .trailing)
        .chartYScale(domain: items.map { $0.name })
        .chartXScale(domain: minMaxDomain(for: items.map { $0.delta }))
        .chartPlotStyle { plot in
            plot.padding(.vertical, 0)
        }
    }

    private func minMaxDomain(for values: [Double]) -> ClosedRange<Double> {
        let minV = values.min() ?? -10
        let maxV = values.max() ?? 10
        if minV >= 0 { return 0...max(10, maxV) }
        if maxV <= 0 { return min(minV, -10)...0 }
        let bound = max(abs(minV), abs(maxV))
        return -bound...bound
    }
    
    private func shortName(_ s: String, max: Int) -> String {
        guard s.count > max else { return s }
        let end = s.index(s.startIndex, offsetBy: max)
        return String(s[..<end]) + "…"
    }
#endif


private var valuationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text("Valuation").font(.headline)
            Spacer()
            Text("As of: Positions \(valuationPositions)  |  FX \(valuationFx)")
                .font(.subheadline)
            Button("Refresh") { runValuation() }
                .disabled(valuating)
            if valuating {
                ProgressView().controlSize(.small)
            }
        }
        HStack(spacing: 8) {
            Spacer()
            Text("Tolerance ±")
            TextField("", value: $tolerance, format: .number.precision(.fractionLength(1)))
                .frame(width: 64)
                .multilineTextAlignment(.trailing)
            Text("%")
            Toggle("Only out of tolerance", isOn: $onlyOutOfTolerance)
                .disabled(!showDeltaResearch && !showDeltaUser)
                .help((!showDeltaResearch && !showDeltaUser) ? "Enable at least one deviation column" : "")
            Toggle("Δ vs Research", isOn: $showDeltaResearch)
            Toggle("Δ vs User", isOn: $showDeltaUser)
        }
        .font(.caption)
        Text("Legend: within = •, over = ▲, under = ▼")
            .font(.caption2)
            .foregroundColor(.secondary)
        if let snap = valuation {
            let rows = filteredSortedRows(snap.rows)
            let hasIncluded = snap.rows.contains { $0.status == .ok }
            let totalPct: Double = hasIncluded ? 100.0 : 0.0
            let researchColumnWidth: CGFloat = 60
            let userColumnWidth: CGFloat = 60
            if snap.excludedFxCount > 0 {
                Text("FX excluded: \(snap.excludedFxCount)").foregroundColor(.orange)
            }
            if snap.excludedPriceCount > 0 {
                Text("Price missing: \(snap.excludedPriceCount)").foregroundColor(.red)
            }
            if onlyOutOfTolerance && rows.isEmpty && (showDeltaResearch || showDeltaUser) {
                Text("No items outside tolerance")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
            }
            HStack(spacing: 12) {
                Text("Instrument").frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
                Text("Research %").frame(width: researchColumnWidth, alignment: .trailing)
                Text("User %").frame(width: userColumnWidth, alignment: .trailing)
                Text("Current Value (\(dbManager.baseCurrency))").frame(width: 160, alignment: .trailing)
                Text("Actual %").frame(width: 80, alignment: .trailing)
                if showDeltaResearch {
                    Button(action: { toggleSort(.deltaResearch) }) {
                        HStack(spacing: 2) {
                            Text("Δ vs Research")
                            if sortField == .deltaResearch {
                                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            }
                        }
                    }
                    .frame(width: 120, alignment: .trailing)
                }
                if showDeltaUser {
                    Button(action: { toggleSort(.deltaUser) }) {
                        HStack(spacing: 2) {
                            Text("Δ vs User")
                            if sortField == .deltaUser {
                                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            }
                        }
                    }
                    .frame(width: 120, alignment: .trailing)
                }
                Text("Status").frame(width: 140, alignment: .leading)
            }
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        if row.status != .ok {
                            let color: Color = (row.status == .priceMissing) ? .red : (row.status == .fxMissing ? .orange : .gray)
                            let hint: String = {
                                switch row.status {
                                case .priceMissing: return "Price missing — set in Instrument › Price"
                                case .fxMissing: return "FX rate missing — cannot convert to base"
                                case .noPosition: return "No position in latest snapshot"
                                default: return ""
                                }
                            }()
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                                .help(hint)
                        }
                        Text(row.instrumentName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(row.instrumentName)
                    }
                    .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
                    Text(row.researchTargetPct, format: .number.precision(.fractionLength(1)))
                        .frame(width: researchColumnWidth, alignment: .trailing)
                    Text(row.userTargetPct, format: .number.precision(.fractionLength(1)))
                        .frame(width: userColumnWidth, alignment: .trailing)
                    Text(row.currentValueBase, format: .currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
                        .frame(width: 160, alignment: .trailing)
                        .monospacedDigit()
                    Text(row.actualPct, format: .number.precision(.fractionLength(1)))
                        .frame(width: 80, alignment: .trailing)
                    if showDeltaResearch {
                        DeviationChip(delta: row.deltaResearchPct, target: row.researchTargetPct, actual: row.actualPct, tolerance: tolerance, baseline: "Research")
                            .frame(width: 120, alignment: .trailing)
                    }
                    if showDeltaUser {
                        DeviationChip(delta: row.deltaUserPct, target: row.userTargetPct, actual: row.actualPct, tolerance: tolerance, baseline: "User")
                            .frame(width: 120, alignment: .trailing)
                    }
                    Text(row.status.rawValue)
                        .frame(width: 140, alignment: .leading)
                }
            }
            HStack(spacing: 12) {
                Text("Totals").frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: researchColumnWidth)
                Spacer().frame(width: userColumnWidth)
                Text(snap.totalValueBase, format: .currency(code: dbManager.baseCurrency).precision(.fractionLength(2)))
                    .frame(width: 160, alignment: .trailing)
                    .monospacedDigit()
                Text(totalPct, format: .number.precision(.fractionLength(1)))
                    .frame(width: 80, alignment: .trailing)
                if showDeltaResearch { Spacer().frame(width: 120) }
                if showDeltaUser { Spacer().frame(width: 120) }
                Spacer().frame(width: 140)
            }
        } else {
            Text("No valued positions in the latest snapshot.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.gray.opacity(0.1))
        }
    }
}

private func filteredSortedRows(_ rows: [ValuationRow]) -> [ValuationRow] {
    var items = rows
    if onlyOutOfTolerance && (showDeltaResearch || showDeltaUser) {
        items = items.filter { row in
            if showDeltaResearch, let d = row.deltaResearchPct, abs(d) > tolerance {
                return true
            }
            if showDeltaUser, let d = row.deltaUserPct, abs(d) > tolerance {
                return true
            }
            return false
        }
    }
    switch sortField {
    case .deltaResearch:
        items.sort {
            let l = $0.deltaResearchPct ?? 0
            let r = $1.deltaResearchPct ?? 0
            if l == r { return sortAscending ? $0.instrumentName < $1.instrumentName : $0.instrumentName > $1.instrumentName }
            return sortAscending ? l < r : l > r
        }
    case .deltaUser:
        items.sort {
            let l = $0.deltaUserPct ?? 0
            let r = $1.deltaUserPct ?? 0
            if l == r { return sortAscending ? $0.instrumentName < $1.instrumentName : $0.instrumentName > $1.instrumentName }
            return sortAscending ? l < r : l > r
        }
    default:
        items.sort { $0.instrumentName < $1.instrumentName }
    }
    return items
}

private func toggleSort(_ field: SortField) {
    if sortField == field {
        sortAscending.toggle()
    } else {
        sortField = field
        sortAscending = false
    }
}

private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone").font(.headline)
            HStack {
                Text(theme?.archivedAt == nil ? "Archive theme to prevent edits." : "Unarchive theme to allow edits.")
                    .foregroundColor(.secondary)
                Spacer()
                if theme?.archivedAt == nil {
                    Button("Archive Theme") { onArchive(); dismiss() }
                        .tint(.red)
                } else {
                    Button("Unarchive") {
                        let defaultStatus = statuses.first { $0.isDefault }?.id ?? statusId
                        onUnarchive(defaultStatus)
                        dismiss()
                    }
                    Button("Soft Delete") { onSoftDelete(); dismiss() }
                        .tint(.red)
                }
            }
        }
    }

    private func runValuation() {
        valuating = true
        Task {
            let fxService = FXConversionService(dbManager: dbManager)
            let service = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
            let snap = service.snapshot(themeId: themeId)
            await MainActor.run {
                self.valuation = snap
                self.valuating = false
            }
        }
    }

    // MARK: - Add Instrument Sheet

    private var addSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Instrument to Portfolio \(name)")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Form {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
                    GridRow {
                        Text("Instrument")
                            .frame(width: labelWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            MacComboBox(
                                items: availableInstruments.map { $0.name },
                                text: $addInstrumentQuery,
                                onSelectIndex: { idx in
                                    let item = availableInstruments[idx]
                                    addInstrumentId = item.id
                                }
                            )
                            .frame(minWidth: 360)
                        }
                    }
                    GridRow {
                        Text("Research %")
                            .frame(width: labelWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("", value: $addResearchPct, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.leading)
                                .frame(width: 120, alignment: .leading)
                            if let err = researchError {
                                Text(err).foregroundColor(.red)
                            }
                        }
                    }
                    GridRow {
                        Text("User %")
                            .frame(width: labelWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("", value: $addUserPct, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.leading)
                                .frame(width: 120, alignment: .leading)
                            if let err = userError {
                                Text(err).foregroundColor(.red)
                            }
                        }
                    }
                    GridRow {
                        Text("Notes")
                            .frame(width: labelWidth, alignment: .leading)
                        TextField("", text: Binding(
                            get: { addNotes },
                            set: { newValue in
                                var trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.count > noteMaxLength {
                                    trimmed = String(trimmed.prefix(noteMaxLength))
                                }
                                addNotes = trimmed
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 360)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { showAdd = false }
                Button("Add Instrument") { addInstrument() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                    .foregroundColor(.black)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!addValid)
            }
            .padding(24)
        }
        .frame(width: 560)
        .onAppear {
            addUserPct = addResearchPct
            // Start with empty instrument query and no preselection
            addInstrumentQuery = ""
            addInstrumentId = 0
        }
    }

    // MARK: - Helpers

    private func sortableHeader(_ column: CompositionSortColumn, title: String) -> some View {
        Button {
            toggleSort(column)
        } label: {
            HStack(spacing: 2) {
                Text(title)
                    .fontWeight(compositionSortColumn == column ? .bold : .regular)
                Text(sortIndicator(for: column))
                    .foregroundColor(.blue)
                    .opacity(compositionSortColumn == column ? 1.0 : 0.5)
            }
            .foregroundColor(compositionSortColumn == column ? .blue : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), sortable, \(accessibilityOrder(for: column))")
    }

    private func sortIndicator(for column: CompositionSortColumn) -> String {
        if compositionSortColumn == column {
            return compositionSortDirection == .ascending ? "▲" : "▼"
        } else {
            return "▲▼"
        }
    }

    private func accessibilityOrder(for column: CompositionSortColumn) -> String {
        if compositionSortColumn == column {
            return compositionSortDirection == .ascending ? "ascending" : "descending"
        } else {
            return "unsorted"
        }
    }

    private func toggleSort(_ column: CompositionSortColumn) {
        if compositionSortColumn == column {
            compositionSortDirection = compositionSortDirection == .ascending ? .descending : .ascending
        } else {
            compositionSortColumn = column
            compositionSortDirection = (column == .instrument) ? .ascending : .descending
        }
        sortAssets()
    }

    private func sanitized(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private func sortAssets() {
        assets.sort { lhs, rhs in
            switch compositionSortColumn {
            case .instrument:
                let lName = instrumentName(lhs.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let rName = instrumentName(rhs.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let cmp = lName.localizedCaseInsensitiveCompare(rName)
                if cmp != .orderedSame {
                    return compositionSortDirection == .ascending ? cmp == .orderedAscending : cmp == .orderedDescending
                }
                let lResearch = sanitized(lhs.researchTargetPct)
                let rResearch = sanitized(rhs.researchTargetPct)
                if lResearch != rResearch {
                    return lResearch > rResearch
                }
                return lhs.instrumentId < rhs.instrumentId
            case .research:
                let l = sanitized(lhs.researchTargetPct)
                let r = sanitized(rhs.researchTargetPct)
                if l != r {
                    return compositionSortDirection == .ascending ? l < r : l > r
                }
                let lName = instrumentName(lhs.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let rName = instrumentName(rhs.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let cmp = lName.localizedCaseInsensitiveCompare(rName)
                if cmp != .orderedSame {
                    return cmp == .orderedAscending
                }
                return lhs.instrumentId < rhs.instrumentId
            case .user:
                let l = sanitized(lhs.userTargetPct)
                let r = sanitized(rhs.userTargetPct)
                if l != r {
                    return compositionSortDirection == .ascending ? l < r : l > r
                }
                let lName = instrumentName(lhs.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let rName = instrumentName(rhs.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let cmp = lName.localizedCaseInsensitiveCompare(rName)
                if cmp != .orderedSame {
                    return cmp == .orderedAscending
                }
                return lhs.instrumentId < rhs.instrumentId
            }
        }
    }

    private var valuationPositions: String {
        if let date = valuation?.positionsAsOf { return DateFormatter.iso8601DateTime.string(from: date) }
        return "-"
    }

    private var valuationFx: String {
        if let date = valuation?.fxAsOf { return DateFormatter.iso8601DateTime.string(from: date) }
        return "-"
    }

    private var valid: Bool {
        PortfolioTheme.isValidName(name) && descriptionText.count <= 2000
    }
    private var isReadOnly: Bool { theme?.archivedAt != nil }
    private var researchTotal: Double { assets.reduce(0) { $0 + $1.researchTargetPct } }
    private var userTotal: Double { assets.reduce(0) { $0 + $1.userTargetPct } }
    private var researchTotalWarning: Bool { abs(researchTotal - 100.0) > 0.1 }
    private var userTotalWarning: Bool { abs(userTotal - 100.0) > 0.1 }
    private var addValid: Bool {
        addInstrumentId != 0 &&
        PortfolioThemeAsset.isValidPercentage(addResearchPct) &&
        PortfolioThemeAsset.isValidPercentage(addUserPct)
    }
    private var researchError: String? {
        PortfolioThemeAsset.isValidPercentage(addResearchPct) ? nil : "0-100% required"
    }
    private var userError: String? {
        PortfolioThemeAsset.isValidPercentage(addUserPct) ? nil : "0-100% required"
    }

    private var availableInstruments: [(id: Int, name: String)] {
        allInstruments.filter { inst in !assets.contains { $0.instrumentId == inst.id } }
    }

    private func loadTheme() {
        guard let fetched = dbManager.getPortfolioTheme(id: themeId) else {
            LoggingService.shared.log("open theme detail themeId=\(themeId) origin=\(origin) result=not_found", logger: .ui)
            alertItem = AlertItem(title: "Theme Unavailable", message: "This theme is no longer available.", action: { dismiss() })
            return
        }
        if fetched.softDelete {
            LoggingService.shared.log("open theme detail themeId=\(themeId) origin=\(origin) result=soft_deleted", logger: .ui)
            alertItem = AlertItem(title: "Theme Unavailable", message: "This theme is no longer available.", action: { dismiss() })
            return
        }
        theme = fetched
        statuses = dbManager.fetchPortfolioThemeStatuses()
        name = fetched.name
        code = fetched.code
        statusId = fetched.statusId
        descriptionText = fetched.description ?? ""
        institutionId = fetched.institutionId
        institutions = dbManager.fetchInstitutions()
        loadAssets()
        LoggingService.shared.log("open theme detail themeId=\(fetched.id) code=\(fetched.code) origin=\(origin) result=opened", logger: .ui)
        if fetched.archivedAt != nil {
            LoggingService.shared.log("theme \(fetched.id) state=archived_readonly", logger: .ui)
        }
    }

    private func loadAssets() {
        assets = dbManager.listThemeAssets(themeId: themeId)
        allInstruments = dbManager.fetchAssets().map { ($0.id, $0.name) }
        if let first = availableInstruments.first { addInstrumentId = first.id }
        refreshUpdateCounts()
        sortAssets()
    }

    private func instrumentName(_ id: Int) -> String {
        allInstruments.first { $0.id == id }?.name ?? "#\(id)"
    }

    private func saveTheme() {
        guard var current = theme else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        current.name = trimmedName
        current.statusId = statusId
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if dbManager.updatePortfolioTheme(id: current.id, name: current.name, description: desc.isEmpty ? nil : desc, institutionId: institutionId, statusId: current.statusId, archivedAt: current.archivedAt) {
            onSave(current)
            dismiss()
        } else {
            LoggingService.shared.log("updatePortfolioTheme failed id=\(current.id)", logger: .ui)
            alertItem = AlertItem(title: "Error", message: "Failed to save theme.", action: nil)
        }
    }

    private func save(_ asset: PortfolioThemeAsset) {
        if let updated = dbManager.updateThemeAsset(
            themeId: themeId,
            instrumentId: asset.instrumentId,
            researchPct: asset.researchTargetPct,
            userPct: asset.userTargetPct,
            setTargetChf: asset.setTargetChf,
            notes: asset.notes
        ) {
            if let idx = assets.firstIndex(where: { $0.instrumentId == updated.instrumentId }) {
                assets[idx] = updated
            }
            LoggingService.shared.log("updateThemeAsset themeId=\(themeId) instrumentId=\(asset.instrumentId) research=\(asset.researchTargetPct) user=\(asset.userTargetPct)", logger: .ui)
            refreshUpdateCounts()
            sortAssets()
        } else {
            LoggingService.shared.log("updateThemeAsset failed themeId=\(themeId) instrumentId=\(asset.instrumentId)", logger: .ui)
            alertItem = AlertItem(title: "Error", message: "Failed to save changes.", action: nil)
        }
    }

    private func remove(_ asset: PortfolioThemeAsset) {
        if dbManager.removeThemeAsset(themeId: themeId, instrumentId: asset.instrumentId) {
            loadAssets()
        } else {
            LoggingService.shared.log("removeThemeAsset failed themeId=\(themeId) instrumentId=\(asset.instrumentId)", logger: .ui)
            alertItem = AlertItem(title: "Error", message: "Failed to remove instrument.", action: nil)
        }
    }

    private func refreshUpdateCounts() {
        // Always enabled
        var dict: [Int: Int] = [:]
        for a in assets {
            dict[a.instrumentId] = dbManager.countInstrumentUpdates(themeId: themeId, instrumentId: a.instrumentId)
        }
        updateCounts = dict
    }

    private func addInstrument() {
        let userPct = addUserPct == addResearchPct ? nil : addUserPct
        let trimmedNotes = addNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let limitedNotes = String(trimmedNotes.prefix(noteMaxLength))
        let notesToSave = limitedNotes.isEmpty ? nil : limitedNotes
        if dbManager.createThemeAsset(themeId: themeId, instrumentId: addInstrumentId, researchPct: addResearchPct, userPct: userPct, notes: notesToSave) != nil {
            showAdd = false
            addResearchPct = 0
            addUserPct = 0
            addNotes = ""
            loadAssets()
        } else {
            LoggingService.shared.log("createThemeAsset failed themeId=\(themeId) instrumentId=\(addInstrumentId)", logger: .ui)
            alertItem = AlertItem(title: "Error", message: "Failed to add instrument to theme.", action: nil)
        }
    }

    // MARK: - Alert

    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let action: (() -> Void)?
    }
}
