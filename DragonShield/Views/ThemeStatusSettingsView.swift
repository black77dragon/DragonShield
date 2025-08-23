// DragonShield/Views/ThemeStatusSettingsView.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: Manage PortfolioThemeStatus entries.

import SwiftUI

struct ThemeStatusSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var editing: PortfolioThemeStatus?
    @State private var isNew: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack {
            List {
                ForEach(statuses) { status in
                    HStack {
                        Text(status.code).frame(width: 80, alignment: .leading)
                        Text(status.name).frame(width: 120, alignment: .leading)
                        ColorChip(hex: status.colorHex, label: status.colorHex)
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
                    editing = PortfolioThemeStatus(id: 0, code: "", name: "", colorHex: PortfolioThemeStatus.defaultColorHex, isDefault: false)
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
    @State private var color: String = ""
    @State private var isDefault: Bool = false
    @State private var selectedPreset: ThemeStatusColorPreset?
    @State private var useCustom: Bool = false

    private let columns = Array(repeating: GridItem(.fixed(100), spacing: 8), count: 3)

    var body: some View {
        Form {
            if isNew {
                TextField("Code", text: $code)
            } else {
                Text("Code: \(status.code)")
            }
            TextField("Name", text: $name)
            Menu {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(PortfolioThemeStatus.colorPresets) { preset in
                        Button {
                            selectedPreset = preset
                            color = preset.hex
                            useCustom = false
                        } label: {
                            ColorChip(hex: preset.hex, label: preset.name)
                        }
                    }
                }
                Divider()
                Button("Custom…") { useCustom = true }
            } label: {
                HStack {
                    ColorChip(hex: color, label: selectedPreset?.name ?? "Custom")
                    Image(systemName: "chevron.down")
                }
            }
            .accessibilityLabel("Color, current selection: \(selectedPreset?.name ?? "Custom") (\(color))")
            if useCustom {
                TextField("Hex", text: $color)
                    .onChange(of: color) { _ in
                        selectedPreset = nil
                    }
                if !PortfolioThemeStatus.isValidColor(color) {
                    Text("Use format #RRGGBB.").foregroundColor(.red).font(.caption)
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
            isDefault = status.isDefault
            if let preset = PortfolioThemeStatus.preset(for: status.colorHex) {
                selectedPreset = preset
                useCustom = false
            } else {
                useCustom = true
            }
        }
        .frame(minWidth: 300, minHeight: 260)
    }

    private var valid: Bool {
        let codeOk = isNew ? PortfolioThemeStatus.isValidCode(code) : true
        let nameOk = PortfolioThemeStatus.isValidName(name)
        let colorOk = useCustom ? PortfolioThemeStatus.isValidColor(color) : (selectedPreset != nil)
        return codeOk && nameOk && colorOk
    }
}

