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
    @State private var errorMessage: String?

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
                            .frame(width: 140, alignment: .trailing)
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        GridRow {
                            Spacer().frame(width: 140)
                            Text("Name is required")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    GridRow {
                        Text("Code")
                            .frame(width: 140, alignment: .trailing)
                        Text(theme.code)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(6)
                            .background(Color.fieldGray)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    GridRow {
                        Text("Status")
                            .frame(width: 140, alignment: .trailing)
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
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Changes") { updateTheme() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
        }
        .frame(minWidth: 560, idealWidth: 620, maxWidth: 680)
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
