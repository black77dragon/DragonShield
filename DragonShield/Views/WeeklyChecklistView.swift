import SwiftUI
#if os(macOS)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

private struct WeeklyChecklistSummary: Identifiable {
    let theme: PortfolioTheme
    let currentEntry: WeeklyChecklistEntry?
    let lastCompleted: WeeklyChecklistEntry?
    let nextDueWeekStart: Date?
    var countedValueBase: Double?
    var id: Int { theme.id }
}

private let skippedStatusColor = Color(red: 0.09, green: 0.35, blue: 0.76)
private let highPriorityColor = DSColor.accentError

private enum WeeklyChecklistStatusCategory: Int {
    case due
    case skipped
    case completed
    case disabled
}

struct WeeklyChecklistOverviewView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.openWindow) private var openWindow
    @State private var summaries: [WeeklyChecklistSummary] = []
    @State private var lastUpdated: Date?
    @State private var valuationTask: Task<Void, Never>? = nil

    private static let countedValueColumnWidth: CGFloat = 150
    private static let priorityColumnWidth: CGFloat = 34
    private static let statusColumnWidth: CGFloat = 120
    private static let actionColumnWidth: CGFloat = 96
    private static let countedValueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CHF"
        formatter.currencySymbol = ""
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            counterRow
            if summaries.isEmpty {
                Text("No portfolios available for weekly reviews.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } else {
                List {
                    Section(header: summaryHeader) {
                        ForEach(summaries) { summary in
                            summaryRow(summary)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: .weeklyChecklistUpdated)) { _ in
            load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Weekly Macro & Portfolio Checklist")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Refresh") { load() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
            Text("Review each non-exempt portfolio every week. Skips require a comment.")
                .font(.callout)
                .foregroundColor(.secondary)
            if let lastUpdated {
                Text("Last updated \(WeeklyChecklistDateHelper.timestampFormatter.string(from: lastUpdated))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var counterRow: some View {
        HStack(spacing: 8) {
            DSBadge(text: "Due \(dueCount)", color: DSColor.accentWarning)
            DSBadge(text: "Skipped \(skippedCount)", color: skippedStatusColor)
            DSBadge(text: "Completed \(completedCount)", color: DSColor.accentSuccess)
            Spacer()
        }
    }

    private func summaryRow(_ summary: WeeklyChecklistSummary) -> some View {
        let statusLabel = statusText(summary)
        let statusColor = statusColor(summary)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.theme.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Text("Last completed: \(lastCompletedText(summary))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Next due: \(nextDueText(summary))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            priorityColumn(summary)
                .frame(width: Self.priorityColumnWidth, alignment: .center)
            countedValueView(summary)
            DSBadge(text: statusLabel, color: statusColor)
                .frame(width: Self.statusColumnWidth, alignment: .center)
            actionView(summary)
                .frame(width: Self.actionColumnWidth, alignment: .center)
        }
        .padding(.vertical, 6)
    }

    private var summaryHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Portfolio")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Priority")
                .frame(width: Self.priorityColumnWidth, alignment: .center)
            Text("Counted Val (CHF)")
                .frame(width: Self.countedValueColumnWidth, alignment: .trailing)
            Text("Status")
                .frame(width: Self.statusColumnWidth, alignment: .center)
            Text("Action")
                .frame(width: Self.actionColumnWidth, alignment: .center)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .textCase(nil)
    }

    private func priorityColumn(_ summary: WeeklyChecklistSummary) -> some View {
        Image(systemName: "flame.fill")
            .foregroundColor(highPriorityColor)
            .opacity(summary.theme.weeklyChecklistHighPriority ? 1 : 0)
            .help("High priority portfolio")
    }

    @ViewBuilder
    private func countedValueView(_ summary: WeeklyChecklistSummary) -> some View {
        if let value = summary.countedValueBase {
            Text(formattedCountedValue(value))
                .font(.subheadline.monospacedDigit())
                .frame(width: Self.countedValueColumnWidth, alignment: .trailing)
        } else {
            HStack(spacing: 4) {
                Text("—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ProgressView()
                    .controlSize(.small)
            }
            .frame(width: Self.countedValueColumnWidth, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func actionView(_ summary: WeeklyChecklistSummary) -> some View {
        if summary.theme.weeklyChecklistEnabled {
            Button("Review") {
                openWindow(id: "weeklyChecklistPortfolio", value: summary.theme.id)
            }
            .buttonStyle(DSButtonStyle(type: .primary, size: .small))
        } else {
            Button("Enable") {
                enableChecklist(summary.theme.id)
            }
            .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
        }
    }

    private func statusText(_ summary: WeeklyChecklistSummary) -> String {
        if !summary.theme.weeklyChecklistEnabled { return "Exempt" }
        guard let entry = summary.currentEntry else { return "Due" }
        switch entry.status {
        case .draft: return "In progress"
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        }
    }

    private func statusColor(_ summary: WeeklyChecklistSummary) -> Color {
        if !summary.theme.weeklyChecklistEnabled { return .secondary }
        guard let entry = summary.currentEntry else { return DSColor.accentWarning }
        switch entry.status {
        case .draft: return DSColor.accentMain
        case .completed: return DSColor.accentSuccess
        case .skipped: return skippedStatusColor
        }
    }

    private func lastCompletedText(_ summary: WeeklyChecklistSummary) -> String {
        guard let last = summary.lastCompleted else { return "n/a" }
        return WeeklyChecklistDateHelper.weekFormatter.string(from: last.weekStartDate)
    }

    private func nextDueText(_ summary: WeeklyChecklistSummary) -> String {
        guard summary.theme.weeklyChecklistEnabled else { return "n/a" }
        guard let nextDue = summary.nextDueWeekStart else { return "n/a" }
        return WeeklyChecklistDateHelper.weekFormatter.string(from: nextDue)
    }

    private var dueCount: Int {
        summaries.filter { statusCategory($0) == .due }.count
    }

    private var skippedCount: Int {
        summaries.filter { statusCategory($0) == .skipped }.count
    }

    private var completedCount: Int {
        summaries.filter { statusCategory($0) == .completed }.count
    }

    private func statusCategory(_ summary: WeeklyChecklistSummary) -> WeeklyChecklistStatusCategory {
        guard summary.theme.weeklyChecklistEnabled else { return .disabled }
        guard let entry = summary.currentEntry else { return .due }
        switch entry.status {
        case .draft: return .due
        case .completed: return .completed
        case .skipped: return .skipped
        }
    }

    private func enableChecklist(_ themeId: Int) {
        _ = dbManager.setPortfolioThemeWeeklyChecklistEnabled(id: themeId, enabled: true)
    }

    private func load() {
        valuationTask?.cancel()
        let currentWeek = WeeklyChecklistDateHelper.weekStart(for: Date())
        let themes = dbManager.fetchPortfolioThemes(includeArchived: false, includeSoftDeleted: false)
        let items = themes.map { theme -> WeeklyChecklistSummary in
            if !theme.weeklyChecklistEnabled {
                return WeeklyChecklistSummary(theme: theme, currentEntry: nil, lastCompleted: nil, nextDueWeekStart: nil, countedValueBase: nil)
            }
            let current = dbManager.fetchWeeklyChecklist(themeId: theme.id, weekStartDate: currentWeek)
            let lastCompleted = dbManager.fetchLastWeeklyChecklist(themeId: theme.id, status: .completed)
            let nextDue: Date?
            if let current, current.status == .completed || current.status == .skipped {
                nextDue = WeeklyChecklistDateHelper.calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek)
            } else {
                nextDue = currentWeek
            }
            return WeeklyChecklistSummary(theme: theme, currentEntry: current, lastCompleted: lastCompleted, nextDueWeekStart: nextDue, countedValueBase: nil)
        }
        summaries = items.sorted { lhs, rhs in
            let lhsCategory = statusCategory(lhs).rawValue
            let rhsCategory = statusCategory(rhs).rawValue
            if lhsCategory != rhsCategory {
                return lhsCategory < rhsCategory
            }
            if lhs.theme.weeklyChecklistHighPriority != rhs.theme.weeklyChecklistHighPriority {
                return lhs.theme.weeklyChecklistHighPriority && !rhs.theme.weeklyChecklistHighPriority
            }
            return lhs.theme.name.localizedCaseInsensitiveCompare(rhs.theme.name) == .orderedAscending
        }
        lastUpdated = Date()
        loadValuations(themeIds: summaries.map { $0.theme.id })
    }

    private func loadValuations(themeIds: [Int]) {
        valuationTask?.cancel()
        guard !themeIds.isEmpty else { return }
        valuationTask = Task {
            let fxService = FXConversionService(dbManager: dbManager)
            let valuationService = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
            for id in themeIds {
                if Task.isCancelled { break }
                let snapshot = valuationService.snapshot(themeId: id)
                await MainActor.run {
                    if let index = summaries.firstIndex(where: { $0.theme.id == id }) {
                        summaries[index].countedValueBase = snapshot.includedTotalValueBase
                    }
                }
            }
        }
    }

    private func formattedCountedValue(_ value: Double) -> String {
        let raw = Self.countedValueFormatter.string(from: NSNumber(value: value)) ?? "—"
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WeeklyChecklistPortfolioView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    let themeId: Int
    let themeName: String

    @State private var entries: [WeeklyChecklistEntry] = []
    @State private var selectedWeekKey: String = ""

    var body: some View {
        let items = historyItems
        let selectedItem = items.first { $0.id == selectedWeekKey }
        return VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                List(selection: $selectedWeekKey) {
                    ForEach(items) { item in
                        historyRow(item)
                            .tag(item.id)
                    }
                }
                .listStyle(.sidebar)
                .frame(maxHeight: .infinity)
                .frame(minWidth: 240, idealWidth: 260, maxWidth: 300)
                Divider()
                if let selectedItem {
                    WeeklyChecklistEditorView(
                        themeId: themeId,
                        themeName: themeName,
                        weekStartDate: selectedItem.weekStartDate,
                        entry: selectedItem.entry,
                        onSaved: handleSaved,
                        onExit: { dismiss() }
                    )
                    .environmentObject(dbManager)
                    .frame(maxHeight: .infinity)
                } else {
                    Text("Select a week to review.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 820)
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: .weeklyChecklistUpdated)) { _ in
            load()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Checklist - \(themeName)")
                    .font(.title3.weight(.semibold))
                Text("Each week must be completed or skipped with a comment.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private func historyRow(_ item: WeeklyChecklistHistoryItem) -> some View {
        let statusLabel = itemStatusText(item)
        let statusColor = itemStatusColor(item)
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(WeeklyChecklistDateHelper.weekLabel(item.weekStartDate))
                    .font(.subheadline)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            DSBadge(text: statusLabel, color: statusColor)
        }
        .padding(.vertical, 4)
    }

    private func itemStatusText(_ item: WeeklyChecklistHistoryItem) -> String {
        guard let entry = item.entry else { return "Not started" }
        switch entry.status {
        case .draft: return "In progress"
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        }
    }

    private func itemStatusColor(_ item: WeeklyChecklistHistoryItem) -> Color {
        guard let entry = item.entry else { return DSColor.accentWarning }
        switch entry.status {
        case .draft: return DSColor.accentMain
        case .completed: return DSColor.accentSuccess
        case .skipped: return skippedStatusColor
        }
    }

    private func handleSaved() {
        load()
        NotificationCenter.default.post(name: .weeklyChecklistUpdated, object: nil)
    }

    private func load() {
        entries = dbManager.listWeeklyChecklists(themeId: themeId, limit: nil)
        let currentWeek = WeeklyChecklistDateHelper.weekStart(for: Date())
        let currentKey = WeeklyChecklistDateHelper.weekKey(currentWeek)
        if selectedWeekKey.isEmpty {
            selectedWeekKey = currentKey
        }
        if !entries.contains(where: { WeeklyChecklistDateHelper.weekKey($0.weekStartDate) == selectedWeekKey }) {
            selectedWeekKey = currentKey
        }
    }

    private struct WeeklyChecklistHistoryItem: Identifiable {
        let weekStartDate: Date
        let entry: WeeklyChecklistEntry?
        var id: String { WeeklyChecklistDateHelper.weekKey(weekStartDate) }
    }

    private var historyItems: [WeeklyChecklistHistoryItem] {
        let currentWeek = WeeklyChecklistDateHelper.weekStart(for: Date())
        var items = entries
            .sorted { $0.weekStartDate > $1.weekStartDate }
            .map { WeeklyChecklistHistoryItem(weekStartDate: $0.weekStartDate, entry: $0) }
        if !items.contains(where: { WeeklyChecklistDateHelper.weekKey($0.weekStartDate) == WeeklyChecklistDateHelper.weekKey(currentWeek) }) {
            items.insert(WeeklyChecklistHistoryItem(weekStartDate: currentWeek, entry: nil), at: 0)
        }
        return items
    }
}

struct WeeklyChecklistEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let themeName: String
    let weekStartDate: Date
    let entry: WeeklyChecklistEntry?
    let onSaved: () -> Void
    let onExit: () -> Void

    @State private var answers = WeeklyChecklistAnswers()
    @State private var status: WeeklyChecklistStatus = .draft
    @State private var skipComment: String = ""
    @State private var errorMessage: String?
    @State private var showSkipSheet = false
    @State private var lastEditedAt: Date?
    @State private var completedAt: Date?
    @State private var skippedAt: Date?
    @State private var revision: Int = 0
    @State private var baselineAnswers = WeeklyChecklistAnswers()
    @State private var baselineSkipComment: String = ""
    @State private var baselineStatus: WeeklyChecklistStatus = .draft
    @State private var showExitConfirm = false
    @State private var thesisDrafts: [ThesisAssessmentDraft] = []
    @State private var baselineThesisDrafts: [ThesisAssessmentDraft] = []
    @State private var showThesisManager = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionCard(title: "1. Regime sanity check", subtitle: "Answer in order. If you cannot articulate the regime in one sentence, you are reacting, not allocating.") {
                        adaptiveTextField("One-sentence regime statement", text: $answers.regimeStatement)
                            .help("Required for completion.")
                        Picker("Regime change vs noise", selection: $answers.regimeAssessment) {
                            Text("Select...").tag(RegimeAssessment?.none)
                            ForEach(RegimeAssessment.allCases, id: \.self) { item in
                                Text(item.rawValue.capitalized).tag(Optional(item))
                            }
                        }
                        TextField("Liquidity", text: $answers.liquidity)
                            .textFieldStyle(.roundedBorder)
                        TextField("Rates (real, not nominal)", text: $answers.rates)
                            .textFieldStyle(.roundedBorder)
                        TextField("Policy stance", text: $answers.policyStance)
                            .textFieldStyle(.roundedBorder)
                        TextField("Risk appetite", text: $answers.riskAppetite)
                            .textFieldStyle(.roundedBorder)
                    }

                    sectionCard(title: "2. Thesis assessments", subtitle: "Review linked theses with driver and risk scores. Update deltas and capture actions.") {
                        if thesisDrafts.isEmpty {
                            Text("No theses linked to this portfolio yet.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach($thesisDrafts) { $draft in
                                DisclosureGroup(isExpanded: $draft.isExpanded) {
                                    ThesisAssessmentPanel(draft: $draft)
                                } label: {
                                    Text(draft.thesisName)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        Button("Manage Thesis Links") { showThesisManager = true }
                            .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                    }

                    sectionCard(title: "3. Thesis integrity notes (legacy)", subtitle: "Optional free-form notes for positions not covered by thesis definitions.") {
                        if answers.thesisChecks.isEmpty {
                            Text("No positions added yet.")
                                .foregroundColor(.secondary)
                        }
                        ForEach(answers.thesisChecks) { item in
                            thesisCard(item)
                        }
                        Button("Add position") {
                            answers.thesisChecks.append(ThesisCheck())
                        }
                        .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                    }

                    sectionCard(title: "4. Narrative drift detection", subtitle: "Check the statements that apply and capture any red-flag language.") {
                        Toggle("Explaining price action with better stories, not better evidence", isOn: $answers.narrativeDrift.storyOverEvidence)
                        Toggle("Relaxed or redefined invalidation criteria", isOn: $answers.narrativeDrift.invalidationCriteriaRelaxed)
                        Toggle("Added new reasons to justify an old position", isOn: $answers.narrativeDrift.addedNewReasons)
                        TextEditor(text: $answers.narrativeDrift.redFlagNotes)
                            .frame(minHeight: 80)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.borderStrong))
                            .help("Examples: Longer term..., The market doesn't understand yet..., This is actually bullish if you think about it...")
                    }

                    sectionCard(title: "5. Exposure and sizing check", subtitle: "Capture risks, overlaps, and correlations. Confirm the sizing rules.") {
                        ForEach(answers.exposureCheck.topMacroRisks.indices, id: \.self) { idx in
                            let binding = Binding(
                                get: { answers.exposureCheck.topMacroRisks[idx] },
                                set: { answers.exposureCheck.topMacroRisks[idx] = $0 }
                            )
                            adaptiveTextField("Top macro risk \(idx + 1)", text: binding)
                        }
                        TextEditor(text: $answers.exposureCheck.sharedRiskPositions)
                            .frame(minHeight: 70)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.borderStrong))
                            .help("Which positions express the same risk?")
                        TextEditor(text: $answers.exposureCheck.hiddenCorrelations)
                            .frame(minHeight: 70)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.borderStrong))
                            .help("Hidden correlations to acknowledge.")
                        Toggle("No single theme can hurt sleep if wrong", isOn: $answers.exposureCheck.sleepRiskAcknowledged)
                        Toggle("Upsizing requires fresh confirmation, not comfort", isOn: $answers.exposureCheck.upsizingRuleConfirmed)
                    }

                    sectionCard(title: "6. Action discipline", subtitle: "Choose a single action and write it in one line.") {
                        Picker("Decision", selection: $answers.actionDiscipline.decision) {
                            Text("Select...").tag(ActionDecision?.none)
                            ForEach(ActionDecision.allCases, id: \.self) { decision in
                                Text(decisionLabel(decision)).tag(Optional(decision))
                            }
                        }
                        TextField("Decision (one line)", text: $answers.actionDiscipline.decisionLine)
                            .textFieldStyle(.roundedBorder)
                            .help("Required for completion.")
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.visible)
        }
        .onAppear(perform: loadState)
        .onChange(of: weekStartDate) { _, _ in loadState() }
        .onChange(of: entry?.id ?? -1) { _, _ in loadState() }
        .sheet(isPresented: $showSkipSheet) {
            SkipWeekSheet(skipComment: skipComment, onCancel: { showSkipSheet = false }, onConfirm: handleSkip)
        }
        .sheet(isPresented: $showThesisManager, onDismiss: loadThesisDrafts) {
            PortfolioThesisLinkManagerView(themeId: themeId)
                .environmentObject(dbManager)
        }
        .alert("Unsaved changes", isPresented: $showExitConfirm) {
            Button("Save") {
                if saveProgress() {
                    onExit()
                }
            }
            Button("Discard", role: .destructive) { onExit() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Save before closing?")
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(saveLabel) { saveProgress() }
                    .buttonStyle(DSButtonStyle(type: saveButtonType, size: .small))
                Button("Mark Complete") { markComplete() }
                    .buttonStyle(DSButtonStyle(type: .success, size: .small))
                Button("Skip Week") { showSkipSheet = true }
                    .buttonStyle(DSButtonStyle(type: .destructive, size: .small))
                Spacer()
                DSBadge(text: statusLabel, color: statusColor)
                Button("Exit") { requestExit() }
                    .buttonStyle(WeeklyChecklistExitButtonStyle())
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(WeeklyChecklistDateHelper.weekLabel(weekStartDate))
                        .font(.headline)
                    Text(themeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                statusFootnote
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(DSColor.surface)
    }

    private var statusLabel: String {
        switch status {
        case .draft: return "In progress"
        case .completed: return "Completed"
        case .skipped: return "Skipped"
        }
    }

    private var statusColor: Color {
        switch status {
        case .draft: return DSColor.accentMain
        case .completed: return DSColor.accentSuccess
        case .skipped: return skippedStatusColor
        }
    }

    private var statusFootnote: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if revision > 0 {
                Text("Revision \(revision)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let lastEditedAt {
                Text("Last edited \(WeeklyChecklistDateHelper.timestampFormatter.string(from: lastEditedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func thesisCard(_ item: ThesisCheck) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Position / Theme", text: bindingForThesis(item.id, \.position))
                .textFieldStyle(.roundedBorder)
            adaptiveTextField("Original thesis (1-2 lines)", text: bindingForThesis(item.id, \.originalThesis))
            TextField("New data this week", text: bindingForThesis(item.id, \.newData))
                .textFieldStyle(.roundedBorder)
            Picker("Impact", selection: bindingForThesis(item.id, \.impact)) {
                Text("Select...").tag(ThesisImpact?.none)
                ForEach(ThesisImpact.allCases, id: \.self) { impact in
                    Text(impact.rawValue.capitalized).tag(Optional(impact))
                }
            }
            Toggle("If I did not own this, I would still enter today", isOn: bindingForThesis(item.id, \.wouldEnterToday))
            Button("Remove position") {
                answers.thesisChecks.removeAll { $0.id == item.id }
            }
            .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
        }
        .padding(10)
        .background(DSColor.surfaceSubtle)
        .cornerRadius(8)
    }

    private func bindingForThesis<Value>(_ id: UUID, _ keyPath: WritableKeyPath<ThesisCheck, Value>) -> Binding<Value> {
        Binding(
            get: {
                answers.thesisChecks.first(where: { $0.id == id })?[keyPath: keyPath] ?? defaultValue(for: keyPath)
            },
            set: { newValue in
                guard let idx = answers.thesisChecks.firstIndex(where: { $0.id == id }) else { return }
                answers.thesisChecks[idx][keyPath: keyPath] = newValue
            }
        )
    }

    private func defaultValue<Value>(for keyPath: WritableKeyPath<ThesisCheck, Value>) -> Value {
        ThesisCheck()[keyPath: keyPath]
    }

    private func adaptiveTextField(_ title: String, text: Binding<String>, minLines: Int = 2, maxLines: Int = 15) -> some View {
        AdaptiveTextEditor(title: title, text: text, minLines: minLines, maxLines: maxLines)
    }

    private struct AdaptiveTextEditor: View {
        let title: String
        @Binding var text: String
        let minLines: Int
        let maxLines: Int

        @State private var measuredHeight: CGFloat = 0

        private let contentPadding = EdgeInsets(top: 7, leading: 6, bottom: 7, trailing: 6)
        private let sliderWidth: CGFloat = 4
        private let sliderPadding: CGFloat = 4
        private let overflowTolerance: CGFloat = 1

        var body: some View {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(height: editorHeight)
                    .scrollIndicators(.visible)
                    .tint(.blue)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.borderStrong))

                if text.isEmpty {
                    Text(title)
                        .foregroundColor(.secondary)
                        .padding(contentPadding)
                        .allowsHitTesting(false)
                }

                measurementText
            }
            .onPreferenceChange(HeightKey.self) { measuredHeight = $0 }
            .overlay(alignment: .trailing) {
                if showsOverflowIndicator {
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: sliderWidth, height: sliderHeight)
                        .padding(.trailing, sliderPadding)
                }
            }
        }

        private var measurementText: some View {
            Text(text.isEmpty ? " " : text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .padding(contentPadding)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
                    }
                )
                .opacity(0)
                .allowsHitTesting(false)
        }

        private var editorHeight: CGFloat {
            max(minHeight, min(maxHeight, measuredHeight))
        }

        private var showsOverflowIndicator: Bool {
            measuredHeight > maxHeight + overflowTolerance
        }

        private var sliderHeight: CGFloat {
            max(24, min(64, maxHeight * 0.25))
        }

        private var minHeight: CGFloat {
            lineHeight * CGFloat(max(1, minLines)) + contentPadding.top + contentPadding.bottom
        }

        private var maxHeight: CGFloat {
            lineHeight * CGFloat(max(1, maxLines)) + contentPadding.top + contentPadding.bottom
        }

        private var lineHeight: CGFloat {
            #if os(macOS)
                NSFont.systemFont(ofSize: NSFont.systemFontSize).boundingRectForFont.height
            #elseif canImport(UIKit)
                UIFont.preferredFont(forTextStyle: .body).lineHeight
            #else
                17
            #endif
        }

        private struct HeightKey: PreferenceKey {
            static var defaultValue: CGFloat = 0

            static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
                value = max(value, nextValue())
            }
        }
    }

    private var canComplete: Bool {
        !answers.regimeStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        answers.actionDiscipline.decision != nil &&
        !answers.actionDiscipline.decisionLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func decisionLabel(_ decision: ActionDecision) -> String {
        switch decision {
        case .doNothing: return "Do nothing"
        case .trim: return "Trim"
        case .add: return "Add"
        case .exit: return "Exit"
        }
    }

    private func loadState() {
        if let entry {
            answers = entry.answers ?? WeeklyChecklistAnswers()
            status = entry.status
            skipComment = entry.skipComment ?? ""
            lastEditedAt = entry.lastEditedAt
            completedAt = entry.completedAt
            skippedAt = entry.skippedAt
            revision = entry.revision
        } else {
            answers = WeeklyChecklistAnswers()
            status = .draft
            skipComment = ""
            lastEditedAt = nil
            completedAt = nil
            skippedAt = nil
            revision = 0
            prefillThesisChecks()
        }
        loadThesisDrafts()
        normalizeAnswers()
        errorMessage = nil
        captureBaseline()
    }

    private func prefillThesisChecks() {
        guard let priorEntry = dbManager.listWeeklyChecklists(themeId: themeId, limit: 1).first,
              let priorChecks = priorEntry.answers?.thesisChecks,
              !priorChecks.isEmpty else { return }
        answers.thesisChecks = priorChecks.map { prior in
            var copy = ThesisCheck()
            copy.position = prior.position
            copy.originalThesis = prior.originalThesis
            return copy
        }
    }

    private func loadThesisDrafts() {
        let linkDetails = dbManager.listPortfolioThesisLinkDetails(themeId: themeId).filter { $0.link.status == .active }
        guard !linkDetails.isEmpty else {
            thesisDrafts = []
            return
        }
        var drafts: [ThesisAssessmentDraft] = []
        let entryId = entry?.id
        for (index, detail) in linkDetails.enumerated() {
            let drivers = dbManager.listThesisDrivers(thesisDefId: detail.link.thesisDefId)
            let risks = dbManager.listThesisRisks(thesisDefId: detail.link.thesisDefId)

            var currentDriverItems: [DriverWeeklyAssessmentItem] = []
            var currentRiskItems: [RiskWeeklyAssessmentItem] = []
            var verdict: ThesisVerdict?
            var topChanges = ""
            var actions = ""
            if let entryId,
               let assessment = dbManager.fetchPortfolioThesisWeeklyAssessment(weeklyChecklistId: entryId, portfolioThesisId: detail.link.id)
            {
                verdict = assessment.verdict
                topChanges = assessment.topChangesText ?? ""
                actions = assessment.actionsSummary ?? ""
                currentDriverItems = dbManager.fetchDriverAssessmentItems(assessmentId: assessment.id)
                currentRiskItems = dbManager.fetchRiskAssessmentItems(assessmentId: assessment.id)
            }

            var priorDriverScores: [Int: Int] = [:]
            var priorRiskScores: [Int: Int] = [:]
            var priorDriverItems: [DriverWeeklyAssessmentItem] = []
            var priorRiskItems: [RiskWeeklyAssessmentItem] = []
            if let prior = dbManager.fetchLatestPortfolioThesisWeeklyAssessment(portfolioThesisId: detail.link.id, beforeWeekStartDate: weekStartDate) {
                priorDriverItems = dbManager.fetchDriverAssessmentItems(assessmentId: prior.id)
                priorRiskItems = dbManager.fetchRiskAssessmentItems(assessmentId: prior.id)
                priorDriverScores = Dictionary(uniqueKeysWithValues: priorDriverItems.compactMap { item in
                    guard let score = item.score else { return nil }
                    return (item.driverDefId, score)
                })
                priorRiskScores = Dictionary(uniqueKeysWithValues: priorRiskItems.compactMap { item in
                    guard let score = item.score else { return nil }
                    return (item.riskDefId, score)
                })
            }

            let driverItems = buildDriverItems(definitions: drivers, current: currentDriverItems, prior: priorDriverItems)
            let riskItems = buildRiskItems(definitions: risks, current: currentRiskItems, prior: priorRiskItems)
            let draft = ThesisAssessmentDraft(
                portfolioThesisId: detail.link.id,
                thesisName: detail.thesisName,
                thesisSummary: detail.thesisSummary,
                drivers: drivers,
                risks: risks,
                verdict: verdict,
                topChangesText: topChanges,
                actionsSummary: actions,
                driverItems: driverItems,
                riskItems: riskItems,
                priorDriverScores: priorDriverScores,
                priorRiskScores: priorRiskScores,
                isExpanded: index == 0
            )
            drafts.append(draft)
        }
        thesisDrafts = drafts
    }

    private func buildDriverItems(definitions: [ThesisDriverDefinition], current: [DriverWeeklyAssessmentItem], prior: [DriverWeeklyAssessmentItem]) -> [DriverWeeklyAssessmentItem] {
        definitions.map { definition in
            if let existing = current.first(where: { $0.driverDefId == definition.id }) {
                var updated = existing
                updated.sortOrder = definition.sortOrder
                return updated
            }
            if let priorItem = prior.first(where: { $0.driverDefId == definition.id }) {
                return DriverWeeklyAssessmentItem(
                    id: 0,
                    assessmentId: 0,
                    driverDefId: priorItem.driverDefId,
                    rag: priorItem.rag,
                    score: priorItem.score,
                    deltaVsPrior: nil,
                    changeSentence: "",
                    evidenceRefs: priorItem.evidenceRefs,
                    implication: priorItem.implication,
                    sortOrder: definition.sortOrder
                )
            }
            return DriverWeeklyAssessmentItem(
                id: 0,
                assessmentId: 0,
                driverDefId: definition.id,
                rag: nil,
                score: nil,
                deltaVsPrior: nil,
                changeSentence: "",
                evidenceRefs: [],
                implication: nil,
                sortOrder: definition.sortOrder
            )
        }
    }

    private func buildRiskItems(definitions: [ThesisRiskDefinition], current: [RiskWeeklyAssessmentItem], prior: [RiskWeeklyAssessmentItem]) -> [RiskWeeklyAssessmentItem] {
        definitions.map { definition in
            if let existing = current.first(where: { $0.riskDefId == definition.id }) {
                var updated = existing
                updated.sortOrder = definition.sortOrder
                return updated
            }
            if let priorItem = prior.first(where: { $0.riskDefId == definition.id }) {
                return RiskWeeklyAssessmentItem(
                    id: 0,
                    assessmentId: 0,
                    riskDefId: priorItem.riskDefId,
                    rag: priorItem.rag,
                    score: priorItem.score,
                    deltaVsPrior: nil,
                    changeSentence: "",
                    evidenceRefs: priorItem.evidenceRefs,
                    thesisImpact: priorItem.thesisImpact,
                    recommendedAction: priorItem.recommendedAction,
                    sortOrder: definition.sortOrder
                )
            }
            return RiskWeeklyAssessmentItem(
                id: 0,
                assessmentId: 0,
                riskDefId: definition.id,
                rag: nil,
                score: nil,
                deltaVsPrior: nil,
                changeSentence: "",
                evidenceRefs: [],
                thesisImpact: nil,
                recommendedAction: nil,
                sortOrder: definition.sortOrder
            )
        }
    }

    private func normalizeAnswers() {
        if answers.exposureCheck.topMacroRisks.count < 3 {
            answers.exposureCheck.topMacroRisks.append(contentsOf: Array(repeating: "", count: 3 - answers.exposureCheck.topMacroRisks.count))
        } else if answers.exposureCheck.topMacroRisks.count > 3 {
            answers.exposureCheck.topMacroRisks = Array(answers.exposureCheck.topMacroRisks.prefix(3))
        }
    }

    private func captureBaseline() {
        baselineAnswers = answers
        baselineSkipComment = skipComment
        baselineStatus = status
        baselineThesisDrafts = normalizedDrafts(thesisDrafts)
    }

    private var hasUnsavedChanges: Bool {
        answers != baselineAnswers || skipComment != baselineSkipComment || status != baselineStatus || normalizedDrafts(thesisDrafts) != baselineThesisDrafts
    }

    private func normalizedDrafts(_ drafts: [ThesisAssessmentDraft]) -> [ThesisAssessmentDraft] {
        drafts.map { draft in
            var copy = draft
            copy.isExpanded = false
            return copy
        }
    }

    private func requestExit() {
        if hasUnsavedChanges {
            showExitConfirm = true
        } else {
            onExit()
        }
    }

    private func sectionCard<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        DSCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var saveLabel: String {
        if status == .completed || status == .skipped {
            return "Save Changes"
        }
        return "Save Draft"
    }

    private var saveButtonType: DSButtonStyleType {
        if status == .completed || status == .skipped {
            return .secondary
        }
        return .primary
    }

    @discardableResult
    private func saveProgress() -> Bool {
        errorMessage = nil
        let targetStatus: WeeklyChecklistStatus = (status == .completed || status == .skipped) ? status : .draft
        let completed = targetStatus == .completed ? (completedAt ?? entry?.completedAt ?? Date()) : nil
        let skipped = targetStatus == .skipped ? (skippedAt ?? entry?.skippedAt ?? Date()) : nil
        let comment = targetStatus == .skipped ? skipComment.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        if targetStatus == .skipped, let comment, comment.isEmpty {
            errorMessage = "Skipping requires a comment."
            return false
        }
        let ok = dbManager.upsertWeeklyChecklist(
            themeId: themeId,
            weekStartDate: weekStartDate,
            status: targetStatus,
            answers: answers,
            skipComment: comment,
            completedAt: completed,
            skippedAt: skipped
        )
        let persisted = persistThesisAssessmentsIfNeeded(ok: ok)
        handleSaveResult(persisted, newStatus: targetStatus)
        return persisted
    }

    private func markComplete() {
        errorMessage = nil
        let completedAtDate = Date()
        let ok = dbManager.upsertWeeklyChecklist(
            themeId: themeId,
            weekStartDate: weekStartDate,
            status: .completed,
            answers: answers,
            skipComment: nil,
            completedAt: completedAtDate,
            skippedAt: nil
        )
        let persisted = persistThesisAssessmentsIfNeeded(ok: ok)
        if persisted {
            completedAt = completedAtDate
            skippedAt = nil
        }
        handleSaveResult(persisted, newStatus: .completed)
        if persisted {
            onExit()
        }
    }

    private func handleSkip(_ comment: String) {
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Skipping requires a comment."
            return
        }
        let ok = dbManager.upsertWeeklyChecklist(
            themeId: themeId,
            weekStartDate: weekStartDate,
            status: .skipped,
            answers: answers,
            skipComment: trimmed,
            completedAt: nil,
            skippedAt: Date()
        )
        let persisted = persistThesisAssessmentsIfNeeded(ok: ok)
        if persisted {
            skippedAt = Date()
            completedAt = nil
        }
        handleSaveResult(persisted, newStatus: .skipped)
        skipComment = trimmed
        showSkipSheet = false
    }

    private func persistThesisAssessmentsIfNeeded(ok: Bool) -> Bool {
        guard ok else { return false }
        guard !thesisDrafts.isEmpty else { return true }
        guard let updatedEntry = dbManager.fetchWeeklyChecklist(themeId: themeId, weekStartDate: weekStartDate) else { return false }
        let persisted = persistThesisAssessments(weeklyChecklistId: updatedEntry.id)
        if !persisted {
            errorMessage = "Unable to save thesis assessments."
        }
        return persisted
    }

    private func persistThesisAssessments(weeklyChecklistId: Int) -> Bool {
        for draft in thesisDrafts {
            let driverItems = normalizeDriverItems(draft.driverItems, priorScores: draft.priorDriverScores)
                .sorted { $0.sortOrder < $1.sortOrder }
            let riskItems = normalizeRiskItems(draft.riskItems, priorScores: draft.priorRiskScores)
                .sorted { $0.sortOrder < $1.sortOrder }
            let driverStrength = ThesisScoring.weightedAverage(items: driverItems.map { item in
                let weight = draft.drivers.first(where: { $0.id == item.driverDefId })?.weight
                return (score: item.score, weight: weight)
            })
            let riskPressure = ThesisScoring.weightedAverage(items: riskItems.map { item in
                let weight = draft.risks.first(where: { $0.id == item.riskDefId })?.weight
                return (score: item.score, weight: weight)
            })
            let suggested = ThesisScoring.verdictSuggestion(
                driverStrength: driverStrength,
                riskPressure: riskPressure,
                driverItems: driverItems,
                riskItems: riskItems,
                riskDefinitions: draft.risks
            )
            let verdict = draft.verdict ?? suggested
            let rag = verdict.map { verdict in
                switch verdict {
                case .valid: return ThesisRAG.green
                case .watch: return ThesisRAG.amber
                case .impaired, .broken: return ThesisRAG.red
                }
            }

            let ok = dbManager.upsertPortfolioThesisWeeklyAssessment(
                weeklyChecklistId: weeklyChecklistId,
                portfolioThesisId: draft.portfolioThesisId,
                verdict: verdict,
                rag: rag,
                driverStrengthScore: driverStrength,
                riskPressureScore: riskPressure,
                topChangesText: draft.topChangesText.trimmingCharacters(in: .whitespacesAndNewlines),
                actionsSummary: draft.actionsSummary.trimmingCharacters(in: .whitespacesAndNewlines),
                driverItems: driverItems,
                riskItems: riskItems
            )
            if !ok { return false }
        }
        return true
    }

    private func normalizeDriverItems(_ items: [DriverWeeklyAssessmentItem], priorScores: [Int: Int]) -> [DriverWeeklyAssessmentItem] {
        items.map { item in
            var updated = item
            let score = item.score
            updated.rag = item.rag ?? ThesisRAG.driverRAG(for: score)
            if let score, let prior = priorScores[item.driverDefId] {
                updated.deltaVsPrior = score - prior
            } else {
                updated.deltaVsPrior = nil
            }
            if let sentence = updated.changeSentence?.trimmingCharacters(in: .whitespacesAndNewlines), sentence.isEmpty {
                updated.changeSentence = nil
            }
            return updated
        }
    }

    private func normalizeRiskItems(_ items: [RiskWeeklyAssessmentItem], priorScores: [Int: Int]) -> [RiskWeeklyAssessmentItem] {
        items.map { item in
            var updated = item
            let score = item.score
            updated.rag = item.rag ?? ThesisRAG.riskRAG(for: score)
            if let score, let prior = priorScores[item.riskDefId] {
                updated.deltaVsPrior = score - prior
            } else {
                updated.deltaVsPrior = nil
            }
            if let sentence = updated.changeSentence?.trimmingCharacters(in: .whitespacesAndNewlines), sentence.isEmpty {
                updated.changeSentence = nil
            }
            return updated
        }
    }

    private func handleSaveResult(_ ok: Bool, newStatus: WeeklyChecklistStatus) {
        if ok {
            status = newStatus
            lastEditedAt = Date()
            if newStatus == .completed {
                skipComment = ""
                skippedAt = nil
            }
            refreshFromDB()
            NotificationCenter.default.post(name: .weeklyChecklistUpdated, object: nil)
            onSaved()
        } else {
            errorMessage = "Unable to save checklist. Please try again."
        }
    }

    private func refreshFromDB() {
        guard let updated = dbManager.fetchWeeklyChecklist(themeId: themeId, weekStartDate: weekStartDate) else { return }
        answers = updated.answers ?? answers
        status = updated.status
        skipComment = updated.skipComment ?? ""
        lastEditedAt = updated.lastEditedAt
        completedAt = updated.completedAt
        skippedAt = updated.skippedAt
        revision = updated.revision
        normalizeAnswers()
        loadThesisDrafts()
        captureBaseline()
    }

    private struct SkipWeekSheet: View {
        @State private var comment: String
        let onCancel: () -> Void
        let onConfirm: (String) -> Void

        init(skipComment: String, onCancel: @escaping () -> Void, onConfirm: @escaping (String) -> Void) {
            _comment = State(initialValue: skipComment)
            self.onCancel = onCancel
            self.onConfirm = onConfirm
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Skip this week")
                    .font(.headline)
                Text("Provide a short reason for skipping. This is required.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $comment)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.borderStrong))
                HStack {
                    Spacer()
                    Button("Cancel") { onCancel() }
                        .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                    Button("Skip Week") { onConfirm(comment) }
                        .buttonStyle(DSButtonStyle(type: .destructive, size: .small))
                }
            }
            .padding()
            .frame(minWidth: 420)
        }
    }

    private struct WeeklyChecklistExitButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.ds.body.weight(.medium))
                .padding(.horizontal, 16)
                .frame(height: DSLayout.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: DSLayout.radiusM)
                        .fill(DSColor.surfaceSecondary.opacity(configuration.isPressed ? 0.85 : 1.0))
                )
                .foregroundColor(DSColor.textSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusM)
                        .stroke(DSColor.border, lineWidth: 1)
                )
        }
    }
}
