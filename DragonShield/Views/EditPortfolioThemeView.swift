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

    private let labelWidth: CGFloat = 140

    init(theme: PortfolioTheme, onSave: @escaping () -> Void) {
        self.theme = theme
        self.onSave = onSave
        _name = State(initialValue: theme.name)
        _statusId = State(initialValue: theme.statusId)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Portfolio Theme")
                .font(.title2)
                .fontWeight(.medium)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.windowBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Name")
                        .frame(width: labelWidth, alignment: .trailing)
                    TextField("", text: $name)
                        .accessibilityLabel("Name")
                }
                if name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Name is required")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.leading, labelWidth + 8)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Code")
                        .frame(width: labelWidth, alignment: .trailing)
                    Text(theme.code)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Status")
                        .frame(width: labelWidth, alignment: .trailing)
                    Picker("", selection: $statusId) {
                        ForEach(statuses) { status in
                            Text(status.name).tag(status.id)
                        }
                    }
                    .labelsHidden()
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.leading, labelWidth + 8)
                }
            }
            .padding(24)

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
