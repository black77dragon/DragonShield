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

    private let labelWidth: CGFloat = 140

    var body: some View {
        VStack(spacing: 0) {
            if isReadOnly {
                Text("Archived theme – read only")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerBlock
                    compositionSection
                    valuationSection
                    dangerZone
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()
                Button("Save") { saveTheme() }
                    .disabled(!valid || isReadOnly)
                Button("Cancel") { dismiss() }
            }
            .padding(24)
        }
        .frame(minWidth: 960)
        .onAppear {
            loadTheme()
            runValuation()
        }
        .sheet(isPresented: $showAdd) { addSheet }
        .alert(item: $alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK"), action: item.action))
        }
    }

    // MARK: - Sections

    private var headerBlock: some View {
        HStack(spacing: 16) {
            TextField("Name", text: $name)
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
            Text("Archived at: \(theme?.archivedAt ?? "—")")
                .foregroundColor(.secondary)
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
                HStack {
                    Text("Instrument").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Research %").frame(width: 72, alignment: .trailing)
                    Text("User %").frame(width: 72, alignment: .trailing)
                    Text("Notes").frame(minWidth: 200, alignment: .leading)
                    Spacer().frame(width: 40)
                }
                ForEach($assets) { $asset in
                    HStack(alignment: .center) {
                        Text(instrumentName($asset.wrappedValue.instrumentId))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        TextField("", value: $asset.researchTargetPct, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .disabled(isReadOnly)
                            .onChange(of: asset.researchTargetPct) { _ in
                                save($asset.wrappedValue)
                            }
                        TextField("", value: $asset.userTargetPct, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .disabled(isReadOnly)
                            .onChange(of: asset.userTargetPct) { _ in
                                save($asset.wrappedValue)
                            }
                        TextField("", text: Binding(
                            get: { $asset.wrappedValue.notes ?? "" },
                            set: { newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                $asset.wrappedValue.notes = trimmed.isEmpty ? nil : trimmed
                            }
                        ))
                        .frame(minWidth: 200)
                        .disabled(isReadOnly)
                        .onChange(of: asset.notes) { _ in
                            save($asset.wrappedValue)
                        }
                        if !isReadOnly {
                            Button(action: { remove($asset.wrappedValue) }) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                HStack {
                    Label("Research sum \(researchTotal, format: .number)%", systemImage: researchTotalWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(researchTotalWarning ? .orange : .green)
                    Label("User sum \(userTotal, format: .number)%", systemImage: userTotalWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(userTotalWarning ? .orange : .green)
                }
                .padding(.top, 8)
            }
        }
    }


private var valuationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text("Valuation").font(.headline)
            Spacer()
            Button("Refresh") { runValuation() }
                .disabled(valuating)
            if valuating {
                ProgressView().controlSize(.small)
            }
        }
        if let snap = valuation {
            let pos = snap.positionsAsOf.map { DateFormatter.iso8601DateTime.string(from: $0) } ?? "—"
            let fx = snap.fxAsOf.map { DateFormatter.iso8601DateTime.string(from: $0) } ?? "—"
            let totalPct = snap.rows.filter { $0.status == "OK" }.reduce(0) { $0 + $1.actualPct }
            Text("As of: Positions \(pos)  |  FX \(fx)")
            Text("Total Value (\(dbManager.baseCurrency)): \(snap.totalValueBase, format: .currency(code: dbManager.baseCurrency))")
            if snap.excludedFxCount > 0 {
                Text("Excluded: \(snap.excludedFxCount)").foregroundColor(.orange)
            }
            if snap.totalValueBase == 0 {
                Text("No valued positions in the latest snapshot.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
            }
            HStack {
                Text("Instrument").frame(maxWidth: .infinity, alignment: .leading)
                Text("Research %").frame(width: 72, alignment: .trailing)
                Text("User %").frame(width: 72, alignment: .trailing)
                Text("Current Value").frame(width: 120, alignment: .trailing)
                Text("Actual %").frame(width: 72, alignment: .trailing)
                Text("Status").frame(width: 120, alignment: .leading)
                Text("Notes").frame(minWidth: 100, alignment: .leading)
            }
            ForEach(snap.rows) { row in
                HStack {
                    Text(row.instrumentName).frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.researchTargetPct, format: .number.precision(.fractionLength(1))).frame(width: 72, alignment: .trailing)
                    Text(row.userTargetPct, format: .number.precision(.fractionLength(1))).frame(width: 72, alignment: .trailing)
                    if let value = row.currentValueBase {
                        Text(value, format: .currency(code: dbManager.baseCurrency).precision(.fractionLength(2))).frame(width: 120, alignment: .trailing)
                    } else {
                        Text("—").frame(width: 120, alignment: .trailing)
                    }
                    Text(row.actualPct, format: .number.precision(.fractionLength(1))).frame(width: 72, alignment: .trailing)
                    Text(row.status).frame(width: 120, alignment: .leading)
                    Text(row.notes ?? "").frame(minWidth: 100, alignment: .leading)
                }
            }
            HStack {
                Text("Totals").frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 72)
                Spacer().frame(width: 72)
                Text(snap.totalValueBase, format: .currency(code: dbManager.baseCurrency).precision(.fractionLength(2))).frame(width: 120, alignment: .trailing)
                Text(totalPct, format: .number.precision(.fractionLength(1))).frame(width: 72, alignment: .trailing)
                Spacer().frame(width: 120)
                Spacer().frame(minWidth: 100)
            }
        } else {
            Text("No valued positions in the latest snapshot.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.gray.opacity(0.1))
        }
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
            let service = PortfolioValuationService(dbManager: dbManager)
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
                        TextField("Notes", text: $addNotes)
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

    private var valid: Bool { PortfolioTheme.isValidName(name) }
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        current.name = trimmed
        current.statusId = statusId
        if dbManager.updatePortfolioTheme(id: current.id, name: current.name, statusId: current.statusId, archivedAt: current.archivedAt) {
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
        let notesToSave = trimmedNotes.isEmpty ? nil : trimmedNotes
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

