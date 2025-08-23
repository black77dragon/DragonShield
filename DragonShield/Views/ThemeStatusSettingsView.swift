// DragonShield/Views/ThemeStatusSettingsView.swift
// MARK: - Version 1.1
// MARK: - History
// - Initial creation: Manage PortfolioThemeStatus entries.
// - 1.1: Add preset color picker with custom hex option and contrast-aware chips.

import SwiftUI

struct ThemeStatusSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var editing: PortfolioThemeStatus?
    @State private var isNew: Bool = false
    // no alert state; errors shown inline in sheet

    var body: some View {
        VStack {
            List {
                ForEach(statuses) { status in
                    HStack {
                        Text(status.code).frame(width: 80, alignment: .leading)
                        Text(status.name).frame(width: 120, alignment: .leading)
                        ColorSwatch(hex: status.colorHex)
                            .help(ThemeStatusColorPreset.matching(hex: status.colorHex)?.name.map { "\($0) (\(status.colorHex))" } ?? status.colorHex)
                            .frame(width: 40, alignment: .leading)
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
                    editing = PortfolioThemeStatus(id: 0, code: "", name: "", colorHex: "", isDefault: false)
                    isNew = true
                }
                Spacer()
            }.padding()
        }
        .navigationTitle("Theme Statuses")
        .onAppear(perform: load)
        .sheet(item: $editing, onDismiss: load) { status in
            ThemeStatusEditView(status: status, isNew: isNew) { updated in
                if isNew {
                    return dbManager.insertPortfolioThemeStatus(code: updated.code, name: updated.name, colorHex: updated.colorHex, isDefault: updated.isDefault)
                } else {
                    return dbManager.updatePortfolioThemeStatus(id: updated.id, name: updated.name, colorHex: updated.colorHex, isDefault: updated.isDefault)
                }
            }
        }
    }

    private func load() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
    }
}

struct ThemeStatusEditView: View {
    @State var status: PortfolioThemeStatus
    let isNew: Bool
    var onSave: (PortfolioThemeStatus) -> ThemeStatusSaveError?
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var name: String = ""
    @State private var selection: String = ""
    @State private var customHex: String = ""
    @State private var isDefault: Bool = false
    @State private var dbError: ThemeStatusSaveError?

    private var currentHex: String {
        selection == "custom" ? customHex : selection
    }

    private var selectedName: String {
        if selection == "custom" {
            return "Custom"
        }
        return ThemeStatusColorPreset.matching(hex: selection)?.name ?? "Custom"
    }

    var body: some View {
        Form {
            if isNew {
                TextField("Code", text: $code)
            } else {
                Text("Code: \(status.code)")
            }
            TextField("Name", text: $name)
            Picker(selection: $selection, label: HStack {
                Rectangle()
                    .fill(Color(hex: currentHex))
                    .frame(width: 16, height: 16)
                    .cornerRadius(2)
                Text(selectedName)
            }) {
                ForEach(themeStatusColorPresets) { preset in
                    HStack {
                        Rectangle()
                            .fill(Color(hex: preset.hex))
                            .frame(width: 16, height: 16)
                            .cornerRadius(2)
                        Text(preset.name)
                    }
                    .tag(preset.hex)
                }
                Divider()
                Text("Custom…").tag("custom")
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selection) { newValue in
                if newValue != "custom" {
                    customHex = newValue
                }
            }

            if selection == "custom" {
                HStack {
                    TextField("Hex", text: $customHex)
                    Rectangle()
                        .fill(Color(hex: customHex))
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary))
                }
                if !PortfolioThemeStatus.isValidColor(customHex) {
                    Text("Use format #RRGGBB.")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Toggle("Default", isOn: $isDefault)
            if let dbError {
                Text(message(for: dbError))
                    .foregroundColor(.red)
                    .font(.caption)
            }
            HStack {
                Spacer()
                Button("Save") {
                    let hex = currentHex
                    let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let updatedStatus: PortfolioThemeStatus
                    if isNew {
                        updatedStatus = PortfolioThemeStatus(id: 0, code: trimmedCode, name: trimmedName, colorHex: hex, isDefault: isDefault)
                    } else {
                        var updated = status
                        updated.name = trimmedName
                        updated.colorHex = hex
                        updated.isDefault = isDefault
                        updatedStatus = updated
                    }
                    dbError = onSave(updatedStatus)
                    if dbError == nil { dismiss() }
                }
                .disabled(!valid)
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            code = status.code
            name = status.name
            if isNew {
                let def = ThemeStatusColorPreset.default
                selection = def.hex
                customHex = def.hex
            } else if let match = ThemeStatusColorPreset.matching(hex: status.colorHex) {
                selection = match.hex
                customHex = match.hex
            } else {
                selection = "custom"
                customHex = status.colorHex
            }
            isDefault = status.isDefault
        }
        .frame(minWidth: 300, minHeight: 240)
    }

    private var valid: Bool {
        let codeVal = isNew ? PortfolioThemeStatus.isValidCode(code) : true
        let nameVal = PortfolioThemeStatus.isValidName(name)
        return codeVal && nameVal && PortfolioThemeStatus.isValidColor(currentHex)
    }

    private func message(for error: ThemeStatusSaveError) -> String {
        switch error {
        case .invalidCode:
            return "Code is invalid. Use A–Z, 0–9, _ (2–10)."
        case .codeExists:
            return "A status with this Code already exists."
        case .nameExists:
            return "A status with this Name already exists."
        case .defaultRace:
            return "Could not set default. Please retry."
        case .database:
            return "Save failed. See logs for details."
        }
    }
}
struct ColorSwatch: View {
    let hex: String

    var body: some View {
        Rectangle()
            .fill(Color(hex: hex))
            .frame(width: 14, height: 14)
            .cornerRadius(3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary, lineWidth: 1))
    }
}
