// DragonShield/Views/AddPortfolioThemeView.swift

import SwiftUI

struct AddPortfolioThemeView: View {
    // Environment and Bindings
    @EnvironmentObject var dbManager: DatabaseManager
    @Binding var isPresented: Bool
    var onSave: () -> Void // Callback to reload the list view

    // Form State
    @State private var name: String = ""
    @State private var code: String = ""
    @State private var statusId: Int = 0 // Use Int, not Int64
    @State private var statuses: [PortfolioThemeStatus] = []
    @State private var weeklyChecklistExempt: Bool = false
    @State private var weeklyChecklistHighPriority: Bool = false
    @State private var timelines: [PortfolioTimelineRow] = []
    @State private var timelineId: Int = 0
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = .init()
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Text("Add New Portfolio Theme")
                .font(.title2)
                .fontWeight(.medium)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.windowBackgroundColor))

            Divider()

            Form {
                Section {
                    TextField("Name*", text: $name)
                    TextField("Code*", text: $code)

                    Picker("Status", selection: $statusId) {
                        ForEach(statuses) { status in
                            Text(status.name).tag(status.id)
                        }
                    }

                    Picker("Time Horizon", selection: $timelineId) {
                        if timelines.isEmpty {
                            Text("No timelines configured").tag(0)
                        } else {
                            ForEach(timelines) { timeline in
                                Text("\(timeline.description) (\(timeline.timeIndication))").tag(timeline.id)
                            }
                        }
                    }
                    .disabled(timelines.isEmpty)

                    Toggle("Set Time Horizon End Date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    }

                    Toggle("Exempt from Weekly Checklist", isOn: $weeklyChecklistExempt)
                        .help("Exclude this portfolio from weekly checklist scheduling and reminders.")
                    Toggle("High Priority (Weekly Checklist)", isOn: $weeklyChecklistHighPriority)
                        .help("Highlight this portfolio in weekly checklist views.")
                }
            }
            .padding()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding([.leading, .trailing, .bottom])
            }

            Divider()

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
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || code.trimmingCharacters(in: .whitespaces).isEmpty || timelineId == 0)
            }
            .padding()
        }
        .frame(minWidth: 450, idealWidth: 500, minHeight: 280, idealHeight: 300)
        .onAppear(perform: loadInitialData)
    }

    private func loadInitialData() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
        // Default to the first status if available
        if let firstStatus = statuses.first {
            statusId = firstStatus.id
        }
        timelines = dbManager.listPortfolioTimelines(includeInactive: false)
        timelineId = dbManager.defaultPortfolioTimelineId() ?? timelines.first?.id ?? 0
    }

    private func saveTheme() {
        errorMessage = nil // Clear previous errors

        // The create method returns an optional PortfolioTheme, so we check for nil
        let newTheme = dbManager.createPortfolioTheme(
            name: name,
            code: code,
            description: nil,
            institutionId: nil,
            statusId: statusId,
            weeklyChecklistEnabled: !weeklyChecklistExempt,
            weeklyChecklistHighPriority: weeklyChecklistHighPriority,
            timelineId: timelineId == 0 ? nil : timelineId,
            timeHorizonEndDate: hasEndDate ? DateFormatter.iso8601DateOnly.string(from: endDate) : nil
        )

        if newTheme != nil {
            onSave() // Trigger the reload in the parent view
            isPresented = false // Dismiss on success
        } else {
            errorMessage = "Failed to save the theme to the database."
            print("Error: dbManager.createPortfolioTheme returned nil.")
        }
    }
}
