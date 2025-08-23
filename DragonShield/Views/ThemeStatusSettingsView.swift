import SwiftUI

struct ThemeStatusSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var editing: PortfolioThemeStatus?
    @State private var isNew: Bool = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            List {
                ForEach(statuses) { status in
                    HStack {
                        Text(status.code).frame(width: 80, alignment: .leading)
                        Text(status.name).frame(width: 120, alignment: .leading)
                        ColorChip(hex: status.colorHex)
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Button(action: { dbManager.setDefaultThemeStatus(id: status.id); load() }) {
                            Image(systemName: status.isDefault ? "largecircle.fill.circle" : "circle")
                        }.buttonStyle(.plain)
                        Button("Edit") {
                            editing = status
                            isNew = false
                        }
                    }
                }
            }
            HStack {
                Button("+ Add Status") {
                    editing = PortfolioThemeStatus(id: 0, code: "", name: "", colorHex: ThemeStatusColorPreset.defaultPreset.hex, isDefault: false)
                    isNew = true
                }
                Spacer()
            }.padding()
        }
        .navigationTitle("Theme Statuses")
        .onAppear(perform: load)
        .sheet(item: $editing, onDismiss: load) { status in
            ThemeStatusEditView(status: status, isNew: isNew) { updated in
                let ok: Bool
                if isNew {
                    ok = dbManager.insertPortfolioThemeStatus(code: updated.code, name: updated.name, colorHex: updated.colorHex, isDefault: updated.isDefault)
                } else {
                    ok = dbManager.updatePortfolioThemeStatus(id: updated.id, name: updated.name, colorHex: updated.colorHex, isDefault: updated.isDefault)
                }
                if !ok {
                    errorMessage = "Failed to save theme status"
                    showErrorAlert = true
                }
            }
        }
        .alert("Database Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func load() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
    }
}

struct ThemeStatusEditView: View {
    @State var status: PortfolioThemeStatus
    let isNew: Bool
    var onSave: (PortfolioThemeStatus) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var name: String = ""
    @State private var color: String = ThemeStatusColorPreset.defaultPreset.hex
    @State private var selection: String = ThemeStatusColorPreset.defaultPreset.hex
    @State private var isDefault: Bool = false

    private let customTag = "custom"

    var body: some View {
        Form {
            if isNew {
                TextField("Code", text: $code)
            } else {
                Text("Code: \(status.code)")
            }
            TextField("Name", text: $name)
            Picker("Color", selection: $selection) {
                ForEach(ThemeStatusColorPreset.all) { preset in
                    HStack {
                        ColorChip(hex: preset.hex)
                        Text(preset.name)
                    }.tag(preset.hex)
                }
                Text("Custom…").tag(customTag)
            }
            if selection == customTag {
                HStack {
                    TextField("Hex", text: $color)
                    ColorChip(hex: color)
                }
                if !PortfolioThemeStatus.isValidColor(color) {
                    Text("Use format #RRGGBB.").foregroundColor(.red)
                }
            }
            Toggle("Default", isOn: $isDefault)
            HStack {
                Spacer()
                Button("Save") {
                    let updatedStatus: PortfolioThemeStatus
                    if isNew {
                        updatedStatus = PortfolioThemeStatus(id: 0, code: code.uppercased(), name: name, colorHex: color, isDefault: isDefault)
                    } else {
                        var updated = status
                        updated.name = name
                        updated.colorHex = color
                        updated.isDefault = isDefault
                        updatedStatus = updated
                    }
                    onSave(updatedStatus)
                    dismiss()
                }
                .disabled(!valid)
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            code = status.code
            name = status.name
            color = status.colorHex
            if let preset = ThemeStatusColorPreset.preset(for: status.colorHex) {
                selection = preset.hex
                color = preset.hex
            } else {
                selection = customTag
            }
            isDefault = status.isDefault
        }
        .onChange(of: selection) { newValue in
            if newValue != customTag {
                color = newValue
            }
        }
        .frame(minWidth: 300, minHeight: 200)
    }

    private var valid: Bool {
        let codeOk = isNew ? PortfolioThemeStatus.isValidCode(code) : true
        return codeOk && PortfolioThemeStatus.isValidName(name) && PortfolioThemeStatus.isValidColor(color)
    }
}

struct ColorChip: View {
    let hex: String
    var label: String { hex.uppercased() }

    var body: some View {
        Text(label)
            .font(.system(size: 12))
            .padding(4)
            .background(Color(hex: hex) ?? .clear)
            .foregroundColor(Color.contrastColor(for: hex))
            .cornerRadius(4)
    }
}
