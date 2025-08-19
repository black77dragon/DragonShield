// DragonShield/Views/PortfolioThemeDetailView.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.1 -> 1.2: Allow navigation via themeId, fetch fresh data, handle archived/read-only and soft-deleted themes.

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
    @State private var allInstruments: [(id: Int, name: String)] = []
    @State private var showAdd = false
    @State private var addInstrumentId: Int = 0
    @State private var addResearchPct: Double = 0
    @State private var addUserPct: Double = 0
    @State private var alertItem: AlertItem?

    var body: some View {
        VStack(alignment: .leading) {
            if let theme = theme {
                Form {
                    Section {
                        TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                        Text("Code: \(code)")
                        Picker("Status", selection: $statusId) {
                            ForEach(statuses) { status in
                                Text(status.name).tag(status.id)
                            }
                        }
                        Text("Archived at: \(theme.archivedAt ?? "—")")
                    }
                    if isReadOnly {
                        Section {
                            Text("Archived themes are read-only.")
                                .foregroundColor(.secondary)
                        }
                    }
                    compositionSection
                    Section("Danger Zone") {
                        if theme.archivedAt == nil {
                            Button("Archive Theme") { onArchive(); dismiss() }
                        } else {
                            Button("Unarchive") {
                                let defaultStatus = statuses.first { $0.isDefault }?.id ?? statusId
                                onUnarchive(defaultStatus)
                                dismiss()
                            }
                            Button("Soft Delete") { onSoftDelete(); dismiss() }
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Save") {
                        saveTheme()
                    }
                    .disabled(!valid || isReadOnly)
                    Button("Cancel") { dismiss() }
                }
                .padding([.top, .leading, .trailing])
            } else {
                Text("This theme is no longer available.")
            }
        }
        .frame(minWidth: 620, minHeight: 420)
        .onAppear(perform: loadTheme)
        .sheet(isPresented: $showAdd) { addSheet }
        .alert(item: $alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK"), action: item.action))
        }
    }

    private var valid: Bool {
        PortfolioTheme.isValidName(name)
    }

    private var isReadOnly: Bool { theme?.archivedAt != nil }

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
                    if dbManager.createThemeAsset(themeId: themeId, instrumentId: addInstrumentId, researchPct: addResearchPct, userPct: userPct) != nil {
                        showAdd = false
                        addResearchPct = 0; addUserPct = 0
                        loadAssets()
                    } else {
                        LoggingService.shared.log("createThemeAsset failed themeId=\(themeId) instrumentId=\(addInstrumentId)", logger: .ui)
                        alertItem = AlertItem(title: "Error", message: "Failed to add instrument to theme.", action: nil)
                    }
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
        if dbManager.updateThemeAsset(themeId: themeId, instrumentId: asset.instrumentId, researchPct: asset.researchTargetPct, userPct: asset.userTargetPct, notes: asset.notes) != nil {
            loadAssets()
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
}

extension PortfolioThemeDetailView {
    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let action: (() -> Void)?
    }
}
