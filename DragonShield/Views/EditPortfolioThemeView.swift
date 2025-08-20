// DragonShield/Views/EditPortfolioThemeView.swift

import SwiftUI

struct EditPortfolioThemeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dbManager: DatabaseManager

    let theme: PortfolioTheme
    var onSave: () -> Void

    @State private var name: String
    @State private var statusId: Int
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var updateError: String?

    init(theme: PortfolioTheme, onSave: @escaping () -> Void) {
        self.theme = theme
        self.onSave = onSave
        _name = State(initialValue: theme.name)
        _statusId = State(initialValue: theme.statusId)
    }

    private var nameValid: Bool { PortfolioTheme.isValidName(name) }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
                    GridRow {
                        Text("Name")
                            .frame(width: 140, alignment: .leading)
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    if !nameValid {
                        GridRow {
                            Spacer().frame(width: 140)
                            Text("Name must be 1-64 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    GridRow {
                        Text("Code")
                            .frame(width: 140, alignment: .leading)
                        Text(theme.code)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GridRow {
                        Text("Status")
                            .frame(width: 140, alignment: .leading)
                        Picker("", selection: $statusId) {
                            ForEach(statuses) { status in
                                Text(status.name).tag(status.id)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .padding(24)
            }

            if let updateError = updateError {
                Text(updateError)
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Changes") { updateTheme() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!nameValid)
            }
            .padding(24)
        }
        .frame(minWidth: 560, maxWidth: 680)
        .onAppear(perform: loadStatuses)
    }

    private func loadStatuses() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
    }

    private func updateTheme() {
        updateError = nil
        let success = dbManager.updatePortfolioTheme(
            id: theme.id,
            name: name,
            statusId: statusId,
            archivedAt: theme.archivedAt
        )
        if success {
            onSave()
            dismiss()
        } else {
            updateError = "Failed to update the theme."
        }
    }
}
