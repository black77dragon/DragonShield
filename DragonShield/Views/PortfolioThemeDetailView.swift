// DragonShield/Views/PortfolioThemeDetailView.swift
// MARK: - Version 1.1
// MARK: - History
// - Add composition editor for attaching instruments with target percentages.

import SwiftUI

struct PortfolioThemeDetailView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State var theme: PortfolioTheme
    let isNew: Bool
    var onSave: (PortfolioTheme) -> Void
    var onArchive: () -> Void
    var onUnarchive: (Int) -> Void
    var onSoftDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var code: String = ""
    @State private var statusId: Int = 0
    @State private var statuses: [PortfolioThemeStatus] = []

    @State private var assets: [PortfolioThemeAsset] = []
    @State private var allInstruments: [(id: Int, name: String)] = []
    @State private var showAdd = false
    @State private var addInstrumentId: Int = 0
    @State private var addResearchPct: Double = 0
    @State private var addUserPct: Double = 0

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                Section {
                    TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                    if isNew {
                        TextField("Code", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: code) { code = code.uppercased() }
                    } else {
                        Text("Code: \(theme.code)")
                    }
                    Picker("Status", selection: $statusId) {
                        ForEach(statuses) { status in
                            Text(status.name).tag(status.id)
                        }
                    }
                    Text("Archived at: \(theme.archivedAt ?? "—")")
                }
                compositionSection
                if !isNew {
                    Section("Danger Zone") {
                        if theme.archivedAt == nil {
                            Button("Archive Theme") {
                                onArchive(); dismiss()
                            }
                        } else {
                            Button("Unarchive") {
                                let defaultStatus = statuses.first { $0.isDefault }?.id ?? statusId
                                onUnarchive(defaultStatus); dismiss()
                            }
                            Button("Soft Delete") { onSoftDelete(); dismiss() }
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Save") {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    var updated = theme
                    if isNew {
                        updated = PortfolioTheme(id: 0, name: trimmedName, code: code.uppercased(), statusId: statusId, createdAt: "", updatedAt: "", archivedAt: nil, softDelete: false)
                    } else {
                        updated.name = trimmedName
                        updated.statusId = statusId
                    }
                    onSave(updated)
                    dismiss()
                }.disabled(!valid)
                Button("Cancel") { dismiss() }
            }
            .padding([.top, .leading, .trailing])
        }
        .frame(minWidth: 620, minHeight: 420)
        .onAppear {
            statuses = dbManager.fetchPortfolioThemeStatuses()
            name = theme.name
            code = theme.code
            statusId = theme.statusId
            loadAssets()
        }
        .sheet(isPresented: $showAdd) { addSheet }
    }

    private var valid: Bool {
        let nameOk = PortfolioTheme.isValidName(name)
        let codeOk = isNew ? PortfolioTheme.isValidCode(code.uppercased()) : true
        return nameOk && codeOk
    }

    private var isReadOnly: Bool { theme.archivedAt != nil }

    private var researchTotal: Double { assets.reduce(0) { $0 + $1.researchTargetPct } }
    private var userTotal: Double { assets.reduce(0) { $0 + $1.userTargetPct } }

    @ViewBuilder
    private var compositionSection: some View {
        Section("Composition") {
            if assets.isEmpty {
                Text("No instruments attached")
            } else {
                ForEach($assets) { $asset in
                    HStack {
                        Text(instrumentName(asset.instrumentId))
                        TextField("Research %", value: $asset.researchTargetPct, format: .number)
                            .frame(width: 80)
                            .disabled(isReadOnly)
                            .onSubmit { save(asset) }
                        TextField("User %", value: $asset.userTargetPct, format: .number)
                            .frame(width: 80)
                            .disabled(isReadOnly)
                            .onSubmit { save(asset) }
                        if !isReadOnly {
                            Button("Remove") { remove(asset) }
                        }
                    }
                }
                HStack {
                    Text(String(format: "Research sum %.1f%%", researchTotal))
                    Text(String(format: "| User sum %.1f%%", userTotal))
                        .foregroundColor(abs(userTotal - 100.0) > 0.1 ? .orange : .primary)
                }
            }
            if !isReadOnly {
                Button("+ Add Instrument") { showAdd = true }
            }
        }
    }

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Instrument", selection: $addInstrumentId) {
                ForEach(availableInstruments, id: \.id) { item in
                    Text(item.name).tag(item.id)
                }
            }
            TextField("Research %", value: $addResearchPct, format: .number)
            TextField("User %", value: $addUserPct, format: .number)
            HStack {
                Button("Add") {
                    let userPct = addUserPct == addResearchPct ? nil : addUserPct
                    _ = dbManager.createThemeAsset(themeId: theme.id, instrumentId: addInstrumentId, researchPct: addResearchPct, userPct: userPct)
                    showAdd = false
                    addResearchPct = 0; addUserPct = 0
                    loadAssets()
                }
                Button("Cancel") { showAdd = false }
            }
        }
        .padding()
        .frame(minWidth: 300)
    }

    private var availableInstruments: [(id: Int, name: String)] {
        allInstruments.filter { inst in !assets.contains { $0.instrumentId == inst.id } }
    }

    private func loadAssets() {
        assets = dbManager.listThemeAssets(themeId: theme.id)
        allInstruments = dbManager.fetchAssets().map { ($0.id, $0.name) }
        if let first = availableInstruments.first { addInstrumentId = first.id }
    }

    private func instrumentName(_ id: Int) -> String {
        allInstruments.first { $0.id == id }?.name ?? "#\(id)"
    }

    private func save(_ asset: PortfolioThemeAsset) {
        _ = dbManager.updateThemeAsset(themeId: theme.id, instrumentId: asset.instrumentId, researchPct: asset.researchTargetPct, userPct: asset.userTargetPct, notes: asset.notes)
        loadAssets()
    }

    private func remove(_ asset: PortfolioThemeAsset) {
        _ = dbManager.removeThemeAsset(themeId: theme.id, instrumentId: asset.instrumentId)
        loadAssets()
    }
}
