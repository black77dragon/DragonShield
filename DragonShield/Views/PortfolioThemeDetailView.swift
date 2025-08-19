// DragonShield/Views/PortfolioThemeDetailView.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: Edit view for PortfolioTheme.

import SwiftUI

struct PortfolioThemeDetailView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State var theme: PortfolioTheme
    let isNew: Bool
    var onSave: (PortfolioTheme) -> Bool
    var onArchive: () -> Void
    var onUnarchive: (Int) -> Void
    var onSoftDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var code: String = ""
    @State private var statusId: Int = 0
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    if isNew {
                        TextField("Code", text: $code)
                            .textFieldStyle(.roundedBorder)
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
                if !isNew {
                    Section("Danger Zone") {
                        if theme.archivedAt == nil {
                            Button("Archive Theme") {
                                onArchive()
                                dismiss()
                            }
                        } else {
                            Button("Unarchive") {
                                let defaultStatus = statuses.first { $0.isDefault }?.id ?? statusId
                                onUnarchive(defaultStatus)
                                dismiss()
                            }
                            Button("Soft Delete") {
                                onSoftDelete()
                                dismiss()
                            }
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Save") {
                    var updated = theme
                    if isNew {
                        updated = PortfolioTheme(id: 0, name: name, code: code.uppercased(), statusId: statusId, createdAt: "", updatedAt: "", archivedAt: nil, softDelete: false)
                    } else {
                        updated.name = name
                        updated.statusId = statusId
                    }
                    if onSave(updated) {
                        dismiss()
                    } else {
                        errorMessage = "Failed to save theme"
                        showErrorAlert = true
                    }
                }
                .disabled(!valid)
                Button("Cancel") { dismiss() }
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            statuses = dbManager.fetchPortfolioThemeStatuses()
            name = theme.name
            code = theme.code
            statusId = theme.statusId
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var valid: Bool {
        let nameOk = PortfolioTheme.isValidName(name)
        let codeOk = isNew ? PortfolioTheme.isValidCode(code.uppercased()) : true
        return nameOk && codeOk
    }
}
