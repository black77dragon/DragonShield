import SwiftUI

private struct WeeklyChecklistSummary: Identifiable {
    let theme: PortfolioTheme
    let currentEntry: WeeklyChecklistEntry?
    let lastCompleted: WeeklyChecklistEntry?
    let nextDueWeekStart: Date?
    var id: Int { theme.id }
}

private let skippedStatusColor = Color(red: 0.09, green: 0.35, blue: 0.76)

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
                    ForEach(summaries) { summary in
                        summaryRow(summary)
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
            Spacer()
            DSBadge(text: statusLabel, color: statusColor)
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
        .padding(.vertical, 6)
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
        let currentWeek = WeeklyChecklistDateHelper.weekStart(for: Date())
        let themes = dbManager.fetchPortfolioThemes(includeArchived: false, includeSoftDeleted: false)
        let items = themes.map { theme -> WeeklyChecklistSummary in
            if !theme.weeklyChecklistEnabled {
                return WeeklyChecklistSummary(theme: theme, currentEntry: nil, lastCompleted: nil, nextDueWeekStart: nil)
            }
            let current = dbManager.fetchWeeklyChecklist(themeId: theme.id, weekStartDate: currentWeek)
            let lastCompleted = dbManager.fetchLastWeeklyChecklist(themeId: theme.id, status: .completed)
            let nextDue: Date?
            if let current, current.status == .completed || current.status == .skipped {
                nextDue = WeeklyChecklistDateHelper.calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek)
            } else {
                nextDue = currentWeek
            }
            return WeeklyChecklistSummary(theme: theme, currentEntry: current, lastCompleted: lastCompleted, nextDueWeekStart: nextDue)
        }
        summaries = items.sorted { lhs, rhs in
            let lhsCategory = statusCategory(lhs).rawValue
            let rhsCategory = statusCategory(rhs).rawValue
            if lhsCategory != rhsCategory {
                return lhsCategory < rhsCategory
            }
            return lhs.theme.name.localizedCaseInsensitiveCompare(rhs.theme.name) == .orderedAscending
        }
        lastUpdated = Date()
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

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionCard(title: "1. Regime sanity check", subtitle: "Answer in order. If you cannot articulate the regime in one sentence, you are reacting, not allocating.") {
                        TextField("One-sentence regime statement", text: $answers.regimeStatement)
                            .textFieldStyle(.roundedBorder)
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

                    sectionCard(title: "2. Thesis integrity check", subtitle: "For each major position or theme, capture the original thesis and what changed this week.") {
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

                    sectionCard(title: "3. Narrative drift detection", subtitle: "Check the statements that apply and capture any red-flag language.") {
                        Toggle("Explaining price action with better stories, not better evidence", isOn: $answers.narrativeDrift.storyOverEvidence)
                        Toggle("Relaxed or redefined invalidation criteria", isOn: $answers.narrativeDrift.invalidationCriteriaRelaxed)
                        Toggle("Added new reasons to justify an old position", isOn: $answers.narrativeDrift.addedNewReasons)
                        TextEditor(text: $answers.narrativeDrift.redFlagNotes)
                            .frame(minHeight: 80)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.borderStrong))
                            .help("Examples: Longer term..., The market doesn't understand yet..., This is actually bullish if you think about it...")
                    }

                    sectionCard(title: "4. Exposure and sizing check", subtitle: "Capture risks, overlaps, and correlations. Confirm the sizing rules.") {
                        ForEach(answers.exposureCheck.topMacroRisks.indices, id: \.self) { idx in
                            TextField("Top macro risk \(idx + 1)", text: Binding(
                                get: { answers.exposureCheck.topMacroRisks[idx] },
                                set: { answers.exposureCheck.topMacroRisks[idx] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
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

                    sectionCard(title: "5. Action discipline", subtitle: "Choose a single action and write it in one line.") {
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
                Button("Cancel") { cancelChanges() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                Button(saveLabel) { saveProgress() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                Button("Mark Complete") { markComplete() }
                    .buttonStyle(DSButtonStyle(type: .primary, size: .small))
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
            TextField("Original thesis (1-2 lines)", text: bindingForThesis(item.id, \.originalThesis))
                .textFieldStyle(.roundedBorder)
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

    private func normalizeAnswers() {
        if answers.exposureCheck.topMacroRisks.count < 3 {
            answers.exposureCheck.topMacroRisks.append(contentsOf: Array(repeating: "", count: 3 - answers.exposureCheck.topMacroRisks.count))
        } else if answers.exposureCheck.topMacroRisks.count > 3 {
            answers.exposureCheck.topMacroRisks = Array(answers.exposureCheck.topMacroRisks.prefix(3))
        }
    }

    private func cancelChanges() {
        loadState()
    }

    private func captureBaseline() {
        baselineAnswers = answers
        baselineSkipComment = skipComment
        baselineStatus = status
    }

    private var hasUnsavedChanges: Bool {
        answers != baselineAnswers || skipComment != baselineSkipComment || status != baselineStatus
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
        handleSaveResult(ok, newStatus: targetStatus)
        return ok
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
        if ok {
            completedAt = completedAtDate
            skippedAt = nil
        }
        handleSaveResult(ok, newStatus: .completed)
        if ok {
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
        if ok {
            skippedAt = Date()
            completedAt = nil
        }
        handleSaveResult(ok, newStatus: .skipped)
        skipComment = trimmed
        showSkipSheet = false
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
