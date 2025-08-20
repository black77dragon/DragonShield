// DragonShield/Views/EditPortfolioThemeView.swift

import SwiftUI

struct EditPortfolioThemeView: View {
    // Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dbManager: DatabaseManager

    // Theme to edit
    let theme: PortfolioTheme
    var onSave: () -> Void

    // Form state
    @State private var name: String
    @State private var statusId: Int
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var errorMessage: String?

    private let labelWidth: CGFloat = 140

    init(theme: PortfolioTheme, onSave: @escaping () -> Void) {
        self.theme = theme
        self.onSave = onSave
        _name = State(initialValue: theme.name)
        _statusId = State(initialValue: theme.statusId)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 12) {
                    GridRow {
                        Text("Name")
                            .frame(width: labelWidth, alignment: .trailing)
                        TextField("Name", text: $name)
                    }

                    GridRow {
                        Text("Code")
                            .frame(width: labelWidth, alignment: .trailing)
                        Text(theme.code)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.secondary)
                    }

                    GridRow {
                        Text("Status")
                            .frame(width: labelWidth, alignment: .trailing)
                        Picker("Status", selection: $statusId) {
                            ForEach(statuses) { status in
                                Text(status.name).tag(status.id)
                            }
                        }
                        .labelsHidden()
                    }
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Changes") { updateTheme() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
        errorMessage = nil
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
            errorMessage = "Failed to update the theme."
        }
    }
}
