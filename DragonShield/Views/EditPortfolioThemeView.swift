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
    @State private var timelines: [PortfolioTimelineRow] = []
    @State private var timelineId: Int
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var errorMessage: String?

    private let labelWidth: CGFloat = 140

    init(theme: PortfolioTheme, onSave: @escaping () -> Void) {
        self.theme = theme
        self.onSave = onSave
        _name = State(initialValue: theme.name)
        _statusId = State(initialValue: theme.statusId)
        _timelineId = State(initialValue: theme.timelineId ?? 0)
        if let endDate = theme.timeHorizonEndDate,
           let parsed = DateFormatter.iso8601DateOnly.date(from: endDate) ?? ISO8601DateParser.parse(endDate)
        {
            _hasEndDate = State(initialValue: true)
            _endDate = State(initialValue: parsed)
        } else {
            _hasEndDate = State(initialValue: false)
            _endDate = State(initialValue: Date())
        }
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

                    GridRow {
                        Text("Time Horizon")
                            .frame(width: labelWidth, alignment: .trailing)
                        Picker("Time Horizon", selection: $timelineId) {
                            if timelines.isEmpty {
                                Text("No timelines").tag(0)
                            } else {
                                ForEach(timelines) { timeline in
                                    Text("\(timeline.description) (\(timeline.timeIndication))").tag(timeline.id)
                                }
                            }
                        }
                        .labelsHidden()
                        .disabled(timelines.isEmpty)
                    }

                    GridRow {
                        Text("End Date")
                            .frame(width: labelWidth, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Set End Date", isOn: $hasEndDate)
                                .labelsHidden()
                            if hasEndDate {
                                DatePicker("", selection: $endDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || timelineId == 0)
            }
            .padding(24)
        }
        .frame(minWidth: 560, maxWidth: 680)
        .onAppear {
            loadStatuses()
            loadTimelines()
        }
    }

    private func loadStatuses() {
        statuses = dbManager.fetchPortfolioThemeStatuses()
    }

    private func loadTimelines() {
        timelines = dbManager.listPortfolioTimelines(includeInactive: true)
        if timelineId == 0 {
            timelineId = dbManager.defaultPortfolioTimelineId() ?? timelines.first?.id ?? 0
        }
    }

    private func updateTheme() {
        errorMessage = nil
        let success = dbManager.updatePortfolioTheme(
            id: theme.id,
            name: name,
            description: theme.description,
            institutionId: theme.institutionId,
            statusId: statusId,
            archivedAt: theme.archivedAt
        )
        if success, timelineId != 0 {
            let endDateString = hasEndDate ? DateFormatter.iso8601DateOnly.string(from: endDate) : nil
            _ = dbManager.updatePortfolioThemeTimeHorizon(id: theme.id, timelineId: timelineId, timeHorizonEndDate: endDateString)
        }
        if success {
            onSave()
            dismiss()
        } else {
            errorMessage = "Failed to update the theme."
        }
    }
}
