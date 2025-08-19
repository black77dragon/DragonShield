import SwiftUI

struct AddPortfolioThemeView: View {
    @Binding var isPresented: Bool
    @ObservedObject var dbManager: DatabaseManager

    // Internal state for the form, ensuring it's fresh every time.
    @State private var name: String = ""
    @State private var code: String = ""
    @State private var description: String = ""
    @State private var statusId: Int64
    
    @State private var errorMessage: String?

    // Initialize with a default status from the database
    init(isPresented: Binding<Bool>, dbManager: DatabaseManager) {
        self._isPresented = isPresented
        self.dbManager = dbManager
        // Set initial state for the statusId, defaulting to the first available status
        self._statusId = State(initialValue: dbManager.portfolioThemeStatuses.first?.id ?? 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Header
            Text("Add New Portfolio Theme")
                .font(.title2)
                .fontWeight(.medium)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.windowBackgroundColor)) // Adapts to light/dark mode

            Divider()

            // 2. Form for data entry
            Form {
                Section {
                    TextField("Name*", text: $name)
                    TextField("Code*", text: $code)
                    TextField("Description (Optional)", text: $description)
                    
                    Picker("Status", selection: $statusId) {
                        ForEach(dbManager.portfolioThemeStatuses) { status in
                            Text(status.name).tag(status.id)
                        }
                    }
                }
            }
            .padding()

            // 3. Error Message Area
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding([.leading, .trailing, .bottom])
            }

            Divider()
            
            // 4. Action Buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveTheme()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || code.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 450, idealWidth: 500, minHeight: 320, idealHeight: 350)
    }

    private func saveTheme() {
        // Validate required fields
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !code.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please fill in all required fields (*)."
            return
        }
        
        errorMessage = nil // Clear previous errors

        let newTheme = PortfolioTheme(
            id: 0, // Database will assign the ID
            name: name,
            code: code,
            description: description.isEmpty ? nil : description,
            statusId: statusId
        )

        do {
            try dbManager.addPortfolioTheme(theme: newTheme)
            isPresented = false // Dismiss sheet on success
        } catch {
            errorMessage = "Failed to save theme: \(error.localizedDescription)"
            print("Error saving theme: \(error)")
        }
    }
}
