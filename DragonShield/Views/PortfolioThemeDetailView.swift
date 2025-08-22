// DragonShield/Views/PortfolioThemeDetailView.swift
// Layout-polished detail editor for portfolio themes.

import SwiftUI

struct PortfolioThemeDetailView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let origin: String
    var onSave: (PortfolioTheme) -> Void = { _ in }
    var onArchive: () -> Void = {}
    var onUnarchive: (Int) -> Void = { _ in }
    var onSoftDelete: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

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
    @State private var addResearchPct: Double = 0
    @State private var addUserPct: Double = 0
    @State private var addNotes: String = ""
    @State private var alertItem: AlertItem?
    @State private var editingAsset: PortfolioThemeAsset?
    @State private var noteDraft: String = ""

    @State private var tolerance: Double = 2.0
    @State private var onlyOutOfTolerance = false
    @State private var showDeltaResearch = true
    @State private var showDeltaUser = true
    @State private var sortField: SortField = .instrument
    @State private var sortAscending = true

    private enum SortField {
        case instrument, deltaResearch, deltaUser
    }

    private let labelWidth: CGFloat = 140
    private let noteMaxLength = NoteEditorView.maxLength

    enum Tab: String { case composition, valuation, updates }
    @State var selectedTab: Tab = .composition
    @State var updates: [PortfolioThemeUpdate] = []
    @State var editingUpdate: PortfolioThemeUpdate?
    @State private var creatingUpdate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Composition").tag(Tab.composition)
                    Text("Valuation").tag(Tab.valuation)
                    if dbManager.portfolioThemeUpdatesEnabled {
                        Text("Updates").tag(Tab.updates)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == .composition {
                    compositionTab
                } else if selectedTab == .valuation {
                    valuationTab
                } else {
                    updatesSection
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Save") { saveTheme() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(selectedTab == .updates || !valid || isReadOnly)
                }
                .padding(24)
            }
            .navigationTitle("Portfolio Theme Details: \(name)")
        }
        .frame(minWidth: 980, idealWidth: 1100, minHeight: 640, idealHeight: 720)
        .onAppear {
            loadTheme()
            runValuation()
            if origin == "post_create" && dbManager.portfolioThemeUpdatesEnabled {
                selectedTab = .updates
            } else if let saved = UserDefaults.standard.string(forKey: "PortfolioThemeDetailView.lastTab"), let t = Tab(rawValue: saved), (t != .updates || dbManager.portfolioThemeUpdatesEnabled) {
                selectedTab = t
            }
            LoggingService.shared.log("{\"themeId\":\(themeId),\"action\":\"details_open\",\"tab\":\"\(selectedTab.rawValue)\",\"source\":\"\(origin)\"}", logger: .ui)
        }
        .onChange(of: selectedTab) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "PortfolioThemeDetailView.lastTab")
            if newValue == .updates { loadUpdates() }
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
        .sheet(isPresented: $creatingUpdate) {
            if let t = theme {
                ThemeUpdateEditorView(theme: t, onSave: { _ in
                    loadUpdates()
                }, onCancel: {})
                .environmentObject(dbManager)
            }
        }
        .sheet(item: $editingUpdate) { upd in
            if let t = theme {
                ThemeUpdateEditorView(theme: t, update: upd, onSave: { _ in
                    loadUpdates()
                }, onCancel: {})
                .environmentObject(dbManager)
            }
        }
        .alert(item: $alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK"), action: item.action))
        }
    }

    // MARK: - Sections

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
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
                Text("Archived at: \(theme?.archivedAt ?? "-")")
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .trailing, spacing: 4) {
                TextEditor(text: $descriptionText)
                    .frame(minHeight: 60)
                    .disabled(isReadOnly)
                Text("\(descriptionText.count) / 2000")
                    .font(.caption)
                    .foregroundColor(descriptionText.count > 2000 ? .red : .secondary)
            }
            HStack {
                Picker("Institution", selection: $institutionId) {
                    Text("None").tag(nil as Int?)
                    ForEach(institutions) { inst in
                        Text(inst.name).tag(inst.id as Int?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(isReadOnly)
                Button("Add New…") { showAddInstitution = true }
                    .disabled(isReadOnly)
            }
        }
    }

    private var compositionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Composition").font(.headline)
            Button("+ Add Instrument") { showAdd = true }
                .buttonStyle(.borderedProminent)
                .disabled(isReadOnly || availableInstruments.isEmpty)

            if assets.isEmpty {
                Text("No instruments attached")
            } else {
                HStack(spacing: 12) {
                    Text("Instrument")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("Research %")
                        .frame(width: 80, alignment: .trailing)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("User %")
                        .frame(width: 80, alignment: .trailing)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("Notes")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
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
                            .onChange(of: asset.researchTargetPct) {
                                save($asset.wrappedValue)
                            }
                        TextField("", value: $asset.userTargetPct, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .disabled(isReadOnly)
                            .onChange(of: asset.userTargetPct) {
                                save($asset.wrappedValue)
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
                }
                HStack(spacing: 12) {
                    Label("Research sum \(researchTotal, format: .number)%", systemImage: researchTotalWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(researchTotalWarning ? .orange : .green)
                    Label("User sum \(userTotal, format: .number)%", systemImage: userTotalWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(userTotalWarning ? .orange : .green)
                }
                .padding(.top, 8)
            }
        }
    }

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
        VStack(spacing: 0) {
            if isReadOnly {
                Text("Archived theme - read only")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    valuationSection
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var updatesSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isReadOnly {
                    Text("Theme archived — composition locked; updates permitted")
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.yellow.opacity(0.1))
                }
                HStack {
                    Spacer()
                    Button("+ New Update") { creatingUpdate = true }
                        .buttonStyle(.borderedProminent)
                }
                ForEach(updates) { upd in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(upd.createdAt)
                            Text("• \(upd.author)")
                            Text("• \(upd.type.rawValue)")
                        }
                        .font(.caption)
                        Text("Title: \(upd.title)").bold()
                        Text(upd.bodyText)
                        Text("Breadcrumb: Positions \(upd.positionsAsOf ?? "—") • Total CHF \(upd.totalValueChf.map { String(format: "%.2f", $0) } ?? "—")")
                            .font(.footnote)
                        HStack {
                            Button("Edit") { editingUpdate = upd }
                            Button("Delete") { deleteUpdate(upd) }
                        }
                    }
                    Divider()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }


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
            if snap.excludedFxCount > 0 {
                Text("Excluded: \(snap.excludedFxCount)").foregroundColor(.orange)
            }
            if onlyOutOfTolerance && rows.isEmpty && (showDeltaResearch || showDeltaUser) {
                Text("No items outside tolerance")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
            }
            HStack(spacing: 12) {
                Text("Instrument").frame(maxWidth: .infinity, alignment: .leading)
                Text("Research %").frame(width: 80, alignment: .trailing)
                Text("User %").frame(width: 80, alignment: .trailing)
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
                    Text(row.instrumentName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(row.instrumentName)
                    Text(row.researchTargetPct, format: .number.precision(.fractionLength(1)))
                        .frame(width: 80, alignment: .trailing)
                    Text(row.userTargetPct, format: .number.precision(.fractionLength(1)))
                        .frame(width: 80, alignment: .trailing)
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
                Text("Totals").frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 80)
                Spacer().frame(width: 80)
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

    private func loadUpdates() {
        updates = dbManager.listThemeUpdates(themeId: themeId)
    }

    private func deleteUpdate(_ upd: PortfolioThemeUpdate) {
        if dbManager.deleteThemeUpdate(id: upd.id) {
            updates.removeAll { $0.id == upd.id }
        }
    }

    // MARK: - Add Instrument Sheet

    private var addSheet: some View {
        VStack(spacing: 0) {
            Form {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
                    GridRow {
                        Text("Instrument")
                            .frame(width: labelWidth, alignment: .trailing)
                        Picker("Instrument", selection: $addInstrumentId) {
                            ForEach(availableInstruments, id: \.id) { item in
                                Text(item.name).tag(item.id)
                            }
                        }
                        .labelsHidden()
                    }
                    GridRow {
                        Text("Research %")
                            .frame(width: labelWidth, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("", value: $addResearchPct, format: .number)
                                .multilineTextAlignment(.trailing)
                            if let err = researchError {
                                Text(err).foregroundColor(.red)
                            }
                        }
                    }
                    GridRow {
                        Text("User %")
                            .frame(width: labelWidth, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("", value: $addUserPct, format: .number)
                                .multilineTextAlignment(.trailing)
                            if let err = userError {
                                Text(err).foregroundColor(.red)
                            }
                        }
                    }
                    GridRow {
                        Text("Notes")
                            .frame(width: labelWidth, alignment: .trailing)
                        TextField("Notes", text: Binding(
                            get: { addNotes },
                            set: { newValue in
                                var trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.count > noteMaxLength {
                                    trimmed = String(trimmed.prefix(noteMaxLength))
                                }
                                addNotes = trimmed
                            }
                        ))
                    }
                }
            }
            .padding(.vertical, 24)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { showAdd = false }
                Button("Add") { addInstrument() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!addValid)
            }
            .padding(24)
        }
        .frame(width: 520)
        .onAppear { addUserPct = addResearchPct }
    }

    // MARK: - Helpers

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
            notes: asset.notes
        ) {
            if let idx = assets.firstIndex(where: { $0.instrumentId == updated.instrumentId }) {
                assets[idx] = updated
            }
            LoggingService.shared.log("updateThemeAsset themeId=\(themeId) instrumentId=\(asset.instrumentId) research=\(asset.researchTargetPct) user=\(asset.userTargetPct)", logger: .ui)
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

