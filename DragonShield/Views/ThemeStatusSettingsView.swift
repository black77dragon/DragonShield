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
                        Text(status.colorHex)
                            .foregroundColor(ColorContrast.isDark(hex: status.colorHex) ? .white : .black)
                            .padding(4)
                            .background(Color(hex: status.colorHex) ?? .clear)
                            .cornerRadius(4)
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
                    editing = PortfolioThemeStatus(id: 0, code: "", name: "", colorHex: "#10B981", isDefault: false)
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
    @State private var selectedIndex: Int = 0
    @State private var isDefault: Bool = false

    private struct ColorPreset: Identifiable, Hashable {
        let name: String
        let hex: String
        var id: String { name }
    }

    private let presets: [ColorPreset] = [
        ColorPreset(name: "Red", hex: "#EF4444"),
        ColorPreset(name: "Orange", hex: "#F97316"),
        ColorPreset(name: "Amber", hex: "#F59E0B"),
        ColorPreset(name: "Yellow", hex: "#EAB308"),
        ColorPreset(name: "Lime", hex: "#84CC16"),
        ColorPreset(name: "Green", hex: "#22C55E"),
        ColorPreset(name: "Emerald", hex: "#10B981"),
        ColorPreset(name: "Teal", hex: "#14B8A6"),
        ColorPreset(name: "Cyan", hex: "#06B6D4"),
        ColorPreset(name: "Sky", hex: "#0EA5E9"),
        ColorPreset(name: "Blue", hex: "#3B82F6"),
        ColorPreset(name: "Indigo", hex: "#6366F1"),
        ColorPreset(name: "Violet", hex: "#8B5CF6"),
        ColorPreset(name: "Purple", hex: "#A855F7"),
        ColorPreset(name: "Fuchsia", hex: "#D946EF"),
        ColorPreset(name: "Pink", hex: "#EC4899"),
        ColorPreset(name: "Rose", hex: "#F43F5E"),
        ColorPreset(name: "Slate", hex: "#64748B"),
        ColorPreset(name: "Gray", hex: "#6B7280"),
        ColorPreset(name: "Stone", hex: "#78716C")
    ]

    var body: some View {
        Form {
            if isNew {
                TextField("Code", text: $code)
            } else {
                Text("Code: \(status.code)")
            }
            TextField("Name", text: $name)
            Picker(selection: $selectedIndex) {
                ForEach(presets.indices, id: .self) { idx in
                    let preset = presets[idx]
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: preset.hex) ?? .clear)
                            .frame(width: 16, height: 16)
                        Text(preset.name)
                    }.tag(idx)
                }
                Divider()
                Text("Custom…").tag(presets.count)
            } label: {
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: color) ?? .clear)
                        .frame(width: 16, height: 16)
                    Text(selectedIndex < presets.count ? presets[selectedIndex].name : "Custom")
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedIndex) { idx in
                if idx < presets.count {
                    color = presets[idx].hex
                }
            }
            .accessibilityLabel("Color, popup button, current selection: \(selectedIndex < presets.count ? presets[selectedIndex].name : "Custom") (\(color))")

            if selectedIndex == presets.count {
                HStack {
                    Text("Hex")
                    TextField("#RRGGBB", text: $color)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: color) ?? .clear)
                        .frame(width: 20, height: 20)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.secondary))
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
            isDefault = status.isDefault
            if let idx = presets.firstIndex(where: { $0.hex.caseInsensitiveCompare(status.colorHex) == .orderedSame }) {
                selectedIndex = idx
                color = presets[idx].hex
            } else {
                selectedIndex = presets.count
            }
        }
        .frame(minWidth: 300, minHeight: 200)
    }

    private var valid: Bool {
        let codeOk = isNew ? PortfolioThemeStatus.isValidCode(code) : true
        let colorOk = selectedIndex < presets.count ? true : PortfolioThemeStatus.isValidColor(color)
        return codeOk && PortfolioThemeStatus.isValidName(name) && colorOk
    }
}
