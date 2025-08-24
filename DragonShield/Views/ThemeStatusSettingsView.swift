// DragonShield/Views/ThemeStatusSettingsView.swift
// MARK: - Version 1.2
// MARK: - History
// - Initial creation: Manage PortfolioThemeStatus entries.
// - 1.1: Add preset color picker with custom hex option and contrast-aware chips.
// - 1.2: Professional sheet layout with grid alignment and inline validation.

import SwiftUI

struct ThemeStatusSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var editing: PortfolioThemeStatus?
    @State private var isNew: Bool = false

    var body: some View {
        VStack {
            List {
                ForEach(statuses) { status in
                    HStack {
                        Text(status.code).frame(width: 80, alignment: .leading)
                        Text(status.name).frame(width: 120, alignment: .leading)
                        ColorSwatch(hex: status.colorHex)
                            .help(ThemeStatusColorPreset.matching(hex: status.colorHex).map { "\($0.name) (\($0.hex))" } ?? status.colorHex)
                            .frame(width: 30, alignment: .leading)
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
            ThemeStatusEditView(status: status, isNew: isNew) {
                load()
            }
            .environmentObject(dbManager)
        }
    }

    private func load() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
    }
}

struct ThemeStatusEditView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State var status: PortfolioThemeStatus
    let isNew: Bool
    var onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var name: String = ""
    @State private var selection: String = ThemeStatusColorPreset.default.hex
    @State private var customHex: String = ThemeStatusColorPreset.default.hex
    @State private var isDefault: Bool = false

    @State private var codeError: String?
    @State private var nameError: String?
    @State private var customError: String?

    enum Field: Hashable { case code, name, customHex }
    @FocusState private var focus: Field?

    private var currentHex: String { selection == "custom" ? customHex : selection }
    private var selectedName: String { selection == "custom" ? "Custom" : ThemeStatusColorPreset.matching(hex: selection)?.name ?? "Custom" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(isNew ? "Add Theme Status" : "Edit Theme Status")
                    .font(.title2).bold()
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!valid)
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
                GridRow {
                    Text("Code").frame(width: 140, alignment: .leading)
                    TextField("Code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .focused($focus, equals: .code)
                        .disabled(!isNew)
                        .onSubmit { save() }
                    Spacer()
                }
                if let codeError {
                    GridRow {
                        Spacer().frame(width: 140)
                        Text(codeError).foregroundColor(.red).font(.caption)
                        Spacer()
                    }
                }
                GridRow {
                    Text("Name").frame(width: 140, alignment: .leading)
                    TextField("Name", text: $name)
                        .focused($focus, equals: .name)
                        .onSubmit { save() }
                    Spacer()
                }
                if let nameError {
                    GridRow {
                        Spacer().frame(width: 140)
                        Text(nameError).foregroundColor(.red).font(.caption)
                        Spacer()
                    }
                }
                GridRow {
                    Text("Color").frame(width: 140, alignment: .leading)
                    Picker(selection: $selection, label: HStack {
                        Rectangle()
                            .fill(Color(hex: currentHex))
                            .frame(width: 16, height: 16)
                            .cornerRadius(3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary))
                        Text(selectedName)
                    }) {
                        ForEach(themeStatusColorPresets) { preset in
                            HStack {
                                Rectangle()
                                    .fill(Color(hex: preset.hex))
                                    .frame(width: 16, height: 16)
                                    .cornerRadius(3)
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary))
                                Text(preset.name)
                            }
                            .tag(preset.hex)
                            .accessibilityLabel("\(preset.name), \(preset.hex)")
                        }
                        Divider()
                        Text("Custom…").tag("custom")
                    }
                    .pickerStyle(MenuPickerStyle())
                    Spacer()
                }
                if selection == "custom" {
                    GridRow {
                        Text("Custom Hex").frame(width: 140, alignment: .leading)
                        HStack {
                            TextField("#RRGGBB", text: $customHex)
                                .focused($focus, equals: .customHex)
                                .onSubmit { save() }
                            Rectangle()
                                .fill(Color(hex: customHex))
                                .frame(width: 24, height: 24)
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary))
                        }
                        Spacer()
                    }
                    if let customError {
                        GridRow {
                            Spacer().frame(width: 140)
                            Text(customError).foregroundColor(.red).font(.caption)
                            Spacer()
                        }
                    }
                }
                GridRow {
                    Text("Default").frame(width: 140, alignment: .leading)
                    Toggle("Set as default", isOn: $isDefault)
                    Spacer()
                }
            }
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 340)
        .onAppear { setup() }
    }

    private var valid: Bool {
        let codeOk = isNew ? PortfolioThemeStatus.isValidCode(code) : true
        let nameOk = PortfolioThemeStatus.isValidName(name)
        let colorOk = PortfolioThemeStatus.isValidColor(currentHex)
        return codeOk && nameOk && colorOk && codeError == nil && nameError == nil && customError == nil
    }

    private func setup() {
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

    private func save() {
        codeError = nil
        nameError = nil
        customError = nil
        guard valid else { return }
        let hex = currentHex
        let updated: PortfolioThemeStatus
        if isNew {
            updated = PortfolioThemeStatus(id: 0, code: code.uppercased(), name: name, colorHex: hex, isDefault: isDefault)
        } else {
            var u = status
            u.name = name
            u.colorHex = hex
            u.isDefault = isDefault
            updated = u
        }
        let result: Result<Void, ThemeStatusSaveError>
        if isNew {
            result = dbManager.insertPortfolioThemeStatus(code: updated.code, name: updated.name, colorHex: updated.colorHex, isDefault: updated.isDefault)
        } else {
            result = dbManager.updatePortfolioThemeStatus(id: updated.id, name: updated.name, colorHex: updated.colorHex, isDefault: updated.isDefault)
        }
        switch result {
        case .success:
            onComplete()
            dismiss()
        case .failure(let error):
            switch error {
            case .codeInvalid:
                codeError = "Code must be 2–10 characters: A–Z, 0–9, _ (start with a letter)."
            case .codeExists:
                codeError = "A status with this Code already exists."
            case .nameExists:
                nameError = "A status with this Name already exists."
            case .couldNotSetDefault:
                nameError = "Could not set default. Please retry."
            case .unknown:
                customError = "Save failed. See logs for details."
            }
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
            .accessibilityLabel(hex)
    }
}
