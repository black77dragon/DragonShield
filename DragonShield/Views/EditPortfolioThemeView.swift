// DragonShield/Views/EditPortfolioThemeView.swift

import SwiftUI

struct EditPortfolioThemeView: View {
    // Environment
    @Environment(\.dismiss) private var dismiss // Handles closing the sheet
    @EnvironmentObject var dbManager: DatabaseManager
    
    // The theme to edit, passed from the list view
    let theme: PortfolioTheme
    
    // Callback to reload the list after saving
    var onSave: () -> Void

    // Local state for the form, initialized from the theme
    @State private var name: String
    @State private var statusId: Int
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var errorMessage: String?

    init(theme: PortfolioTheme, onSave: @escaping () -> Void) {
        self.theme = theme
        self.onSave = onSave
        // Initialize the view's state with the theme's current values
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

            Form {
                Section {
                    // Display the code, but don't allow it to be edited
                    LabeledContent("Code") {
                        Text(theme.code).foregroundColor(.secondary)
                    }
                    
                    TextField("Name", text: $name)
                    
                    Picker("Status", selection: $statusId) {
                        ForEach(statuses) { status in
                            Text(status.name).tag(status.id)
                        }
                    }
                }
            }
            .padding()

            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red).padding()
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save Changes") {
                    updateTheme()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 450, idealWidth: 500, minHeight: 280, idealHeight: 300)
        .onAppear(perform: loadStatuses)
    }

    private func loadStatuses() {
        self.statuses = dbManager.fetchPortfolioThemeStatuses()
    }

    private func updateTheme() {
        errorMessage = nil
        
        let success = dbManager.updatePortfolioTheme(
            id: theme.id,
            name: self.name,
            statusId: self.statusId,
            archivedAt: theme.archivedAt
        )

        if success {
            onSave()  // Reload the main list
            dismiss() // Close the sheet
        } else {
            errorMessage = "Failed to update the theme."
        }
    }
}
