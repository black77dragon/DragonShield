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
    @State private var addNotes: String = ""
    @State private var alertItem: AlertItem?

    private let labelWidth: CGFloat = 140

    var body: some View {
        VStack(spacing: 0) {
            if theme != nil && isReadOnly {
                Text("Archived theme. Read-only")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.2))
            }
            if theme != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        compositionSection
                        dangerZone
                    }
                    .padding(24)
                    .frame(minWidth: 960, alignment: .leading)
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
            } else {
                Text("This theme is no longer available.")
                    .padding()
            }
        }
        .onAppear(perform: loadTheme)
        .sheet(isPresented: $showAdd) { addSheet }
        .alert(item: $alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK"), action: item.action))
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .disabled(isReadOnly)
            Text(code)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.gray.opacity(0.2)))
                .foregroundStyle(.secondary)
            Picker("Status", selection: $statusId) {
                ForEach(statuses) { status in
                    Text(status.name).tag(status.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(isReadOnly)
            Text("Archived at: \(theme?.archivedAt ?? "—")")
                .foregroundStyle(.secondary)
        }
    }

    private var compositionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Composition")
                .font(.headline)
            if !isReadOnly {
                Button("+ Add Instrument") { showAdd = true }
                    .buttonStyle(.borderedProminent)
            }
            if assets.isEmpty {
                Text("No instruments attached")
            } else {
                Table($assets) {
                    TableColumn("Instrument") { $asset in
                        Text(instrumentName($asset.instrumentId.wrappedValue))
                    }
                    TableColumn("Research %") { $asset in
                        TextField("", value: $asset.researchTargetPct, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .disabled(isReadOnly)
                            .onSubmit { save($asset.wrappedValue) }
                    }
                    .width(72)
                    TableColumn("User %") { $asset in
                        TextField("", value: $asset.userTargetPct, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .disabled(isReadOnly)
                            .onSubmit { save($asset.wrappedValue) }
                    }
                    .width(72)
                    TableColumn("Notes") { $asset in
                        TextField("", text: Binding(
                            get: { $asset.notes.wrappedValue ?? "" },
                            set: { $asset.notes.wrappedValue = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minWidth: 200, alignment: .leading)
                        .disabled(isReadOnly)
                        .onSubmit { save($asset.wrappedValue) }
                    }
                    .width(min: 200)
                    TableColumn("Actions") { $asset in
                        if !isReadOnly {
                            Button("Remove") { remove($asset.wrappedValue) }
                        }
                    }
                    .width(80)
                }
                HStack(spacing: 8) {
                    statusBadge(text: String(format: "Research sum %.1f%%", researchTotal), ok: abs(researchTotal - 100) < 0.1)
                    Text("|")
                    statusBadge(text: String(format: "User sum %.1f%%", userTotal), ok: abs(userTotal - 100) < 0.1)
                }
                .padding(.top, 8)
            }
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone")
                .font(.headline)
            HStack {
                Text("Destructive actions")
                    .foregroundColor(.secondary)
                Spacer()
                if theme?.archivedAt == nil {
                    Button("Archive Theme", role: .destructive) {
                        onArchive()
                        dismiss()
                    }
                } else {
                    Button("Unarchive", role: .destructive) {
                        let defaultStatus = statuses.first { $0.isDefault }?.id ?? statusId
                        onUnarchive(defaultStatus)
                        dismiss()
                    }
                }
            }
        }
    }

    private var addSheet: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Instrument")
                        .frame(width: labelWidth, alignment: .trailing)
                    Picker("", selection: $addInstrumentId) {
                        ForEach(availableInstruments, id: \.id) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                    .labelsHidden()
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Research %")
                        .frame(width: labelWidth, alignment: .trailing)
                    TextField("", value: $addResearchPct, format: .number)
                        .multilineTextAlignment(.trailing)
                }
                if !PortfolioThemeAsset.isValidPercentage(addResearchPct) {
                    Text("Enter 0–100")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.leading, labelWidth + 8)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("User %")
                        .frame(width: labelWidth, alignment: .trailing)
                    TextField("", value: $addUserPct, format: .number)
                        .multilineTextAlignment(.trailing)
                }
                if !PortfolioThemeAsset.isValidPercentage(addUserPct) {
                    Text("Enter 0–100")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.leading, labelWidth + 8)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Notes")
                        .frame(width: labelWidth, alignment: .trailing)
                    TextField("", text: $addNotes)
                }
            }
            .padding(24)
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { showAdd = false }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { addInstrument() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!PortfolioThemeAsset.isValidPercentage(addResearchPct) || !PortfolioThemeAsset.isValidPercentage(addUserPct))
            }
            .padding(24)
        }
        .frame(width: 520)
    }

    private func addInstrument() {
        let userPct = addUserPct == addResearchPct ? nil : addUserPct
        if dbManager.createThemeAsset(themeId: themeId, instrumentId: addInstrumentId, researchPct: addResearchPct, userPct: userPct, notes: addNotes.isEmpty ? nil : addNotes) != nil {
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

    private func statusBadge(text: String, ok: Bool) -> some View {
        Text(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((ok ? Color.green : Color.orange).opacity(0.2))
            .foregroundColor(ok ? .green : .orange)
            .clipShape(Capsule())
    }

    private var valid: Bool { PortfolioTheme.isValidName(name) }
    private var isReadOnly: Bool { theme?.archivedAt != nil }
    private var researchTotal: Double { assets.reduce(0) { $0 + $1.researchTargetPct } }
    private var userTotal: Double { assets.reduce(0) { $0 + $1.userTargetPct } }

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
