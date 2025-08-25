// DragonShield/Views/ThemeStatusSettingsView.swift
// MARK: - Version 1.2
// MARK: - History
// - Initial creation: Manage PortfolioThemeStatus entries.
// - 1.1: Add preset color picker with custom hex option and contrast-aware chips.
// - 1.2: Replace pop-up editor with professional sheet layout and inline validation.

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
                        ColorSwatch(hex: status.colorHex, size: 14)
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
                        Button("Delete", role: .destructive) {
                            switch dbManager.deletePortfolioThemeStatus(id: status.id) {
                            case .success:
                                load()
                            case .failure(let err):
                                errorMessage = err.localizedDescription
                                showErrorAlert = true
                            }
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
            }
            .padding()
        }
        .navigationTitle("Theme Statuses")
        .onAppear(perform: load)
        .sheet(item: $editing, onDismiss: load) { status in
            ThemeStatusEditView(status: status, isNew: isNew) { updated in
                if isNew {
                    switch dbManager.insertPortfolioThemeStatus(code: updated.code, name: updated.name, colorHex: updated.colorHex, isDefault: updated.isDefault) {
                    case .success:
                        return nil
                    case .failure(let err):
                        return err
                    }
                } else {
                    switch dbManager.updatePortfolioThemeStatus(id: updated.id, name: updated.name, colorHex: updated.colorHex, isDefault: updated.isDefault) {
                    case .success:
                        return nil
                    case .failure(let err):
                        return err
                    }
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
    var onSave: (PortfolioThemeStatus) -> ThemeStatusDBError?
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var name: String = ""
    @State private var selection: String = ThemeStatusColorPreset.default.hex
    @State private var customHex: String = ThemeStatusColorPreset.default.hex
    @State private var isDefault: Bool = false

    @State private var codeError: String?
    @State private var nameError: String?
    @State private var colorError: String?
    @State private var sheetError: String = ""
    @State private var showSheetError: Bool = false

    private var title: String { isNew ? "Add Theme Status" : "Edit Theme Status" }

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
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .padding(.bottom, 4)

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
                GridRow {
                    Text("Code")
                        .frame(width: 140, alignment: .leading)
                    if isNew {
                        TextField("Code", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: code) { _, newValue in
                                code = newValue.uppercased()
                                validate()
                            }
                    } else {
                        Text(status.code)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let codeError {
                    GridRow {
                        Spacer().frame(width: 140)
                        Text(codeError)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                GridRow {
                    Text("Name")
                        .frame(width: 140, alignment: .leading)
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { _, _ in validate() }
                }
                if let nameError {
                    GridRow {
                        Spacer().frame(width: 140)
                        Text(nameError)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                GridRow {
                    Text("Color")
                        .frame(width: 140, alignment: .leading)
                    Picker(selection: $selection, label: HStack {
                        ColorSwatch(hex: currentHex, size: 16)
                        Text(selectedName)
                    }) {
                        ForEach(themeStatusColorPresets) { preset in
                            HStack {
                                ColorSwatch(hex: preset.hex, size: 16)
                                Text(preset.name)
                            }
                            .tag(preset.hex)
                        }
                        Divider()
                        Text("Custom…").tag("custom")
                    }
                    .onChange(of: selection) { _, newValue in
                        if newValue != "custom" {
                            customHex = newValue
                        }
                        validate()
                    }
                }

                if selection == "custom" {
                    GridRow {
                        Text("Custom Hex")
                            .frame(width: 140, alignment: .leading)
                        HStack {
                            TextField("#RRGGBB", text: $customHex)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: customHex) { _, _ in validate() }
                            ColorSwatch(hex: customHex, size: 24)
                        }
                    }
                    if let colorError {
                        GridRow {
                            Spacer().frame(width: 140)
                            Text(colorError)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }

                GridRow {
                    Text("Default")
                        .frame(width: 140, alignment: .leading)
                    Toggle("Set as default", isOn: $isDefault)
                        .labelsHidden()
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!valid)
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 340)
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
            validate()
        }
        .onSubmit {
            if valid {
                save()
            }
        }
        .alert("Save Failed", isPresented: $showSheetError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(sheetError)
        }
    }

    private func validate() {
        if isNew {
            codeError = PortfolioThemeStatus.isValidCode(code) ? nil : "Code must be 2–10 characters: A–Z, 0–9, _ (start with a letter)."
        }
        nameError = PortfolioThemeStatus.isValidName(name) ? nil : "Name must be 2–40 characters."
        colorError = PortfolioThemeStatus.isValidColor(currentHex) ? nil : "Use format #RRGGBB."
    }

    private func save() {
        let hex = currentHex
        let updatedStatus: PortfolioThemeStatus
        if isNew {
            updatedStatus = PortfolioThemeStatus(id: 0, code: code.uppercased(), name: name, colorHex: hex, isDefault: isDefault)
        } else {
            var updated = status
            updated.name = name
            updated.colorHex = hex
            updated.isDefault = isDefault
            updatedStatus = updated
        }
        if let error = onSave(updatedStatus) {
            switch error {
            case .duplicateCode, .invalidCode:
                codeError = error.localizedDescription
            case .duplicateName:
                nameError = error.localizedDescription
            default:
                sheetError = error.localizedDescription
                showSheetError = true
            }
        } else {
            dismiss()
        }
    }

    private var valid: Bool {
        codeError == nil && nameError == nil && colorError == nil
    }
}

struct ColorSwatch: View {
    let hex: String
    var size: CGFloat = 14

    var body: some View {
        Rectangle()
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
            .cornerRadius(3)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary, lineWidth: 1))
            .accessibilityLabel(hex)
    }
}

