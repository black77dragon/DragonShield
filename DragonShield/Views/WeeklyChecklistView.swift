import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
    import PDFKit
#endif
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
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                openMostCurrentWeeklyReport(for: summary)
            }
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

    private func openMostCurrentWeeklyReport(for summary: WeeklyChecklistSummary) {
        guard summary.theme.weeklyChecklistEnabled else { return }
        openWindow(id: "weeklyChecklistPortfolio", value: summary.theme.id)
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
    @State private var hasUnsavedChanges = false
    @State private var pendingWeekKey: String?
    @State private var showUnsavedConfirm = false
    @State private var saveHandler: (() -> Bool)?

    var body: some View {
        let items = historyItems
        let selectedItem = items.first { $0.id == selectedWeekKey }
        return VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                List(selection: selectionBinding) {
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
                        hasUnsavedChanges: $hasUnsavedChanges,
                        saveHandler: $saveHandler,
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
        .alert("Unsaved changes", isPresented: $showUnsavedConfirm) {
            Button("Save") {
                guard let pendingWeekKey else { return }
                let ok = saveHandler?() ?? false
                if ok {
                    selectedWeekKey = pendingWeekKey
                }
                self.pendingWeekKey = nil
            }
            Button("Discard", role: .destructive) {
                guard let pendingWeekKey else { return }
                selectedWeekKey = pendingWeekKey
                self.pendingWeekKey = nil
            }
            Button("Cancel", role: .cancel) {
                pendingWeekKey = nil
            }
        } message: {
            Text("You have unsaved changes. Save before switching weeks?")
        }
    }

    private var selectionBinding: Binding<String> {
        Binding(
            get: { selectedWeekKey },
            set: { newValue in
                handleSelectionChange(newValue)
            }
        )
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

    private func handleSelectionChange(_ newValue: String) {
        guard newValue != selectedWeekKey else { return }
        if hasUnsavedChanges {
            pendingWeekKey = newValue
            showUnsavedConfirm = true
        } else {
            selectedWeekKey = newValue
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
    @Binding var hasUnsavedChanges: Bool
    @Binding var saveHandler: (() -> Bool)?
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
    @State private var isGeneratingPDF = false
    @State private var pdfExportDocument = WeeklyChecklistPDFDocument.empty
    @State private var isShowingPDFExporter = false
    @State private var exportErrorMessage: String?
    @State private var isShowingExportError = false
    @State private var reportGeneratedAt: Date?
    private static let reportPDFWidth: CGFloat = 1200

    private enum TooltipText {
        static let thesis = "A structured, testable investment belief linking macro conditions, asset edge, growth, and risks to portfolio actions."
        static let baseThesis = "The long-lived core logic of the investment; changes only on structural regime or thesis breaks."
        static let hook = "A concise narrative summarizing the macro tailwind, why the thesis works, portfolio posture, and exit logic."
        static let weeklyPulse = "The recurring lightweight review cycle focused on signal over noise."
        static let score = "Normalized strength rating of a thesis dimension; ordinal guidance, not precision measurement."
        static let delta = "Directional change versus the prior week, capturing momentum rather than absolute level."
        static let macroScore = "Strength of the macro or regime tailwind supporting the thesis."
        static let edgeScore = "Degree of structural advantage or moat (e.g., scarcity, decentralization, network effects)."
        static let growthScore = "Adoption and scaling trajectory of the asset or platform."
        static let netScore = "Simple average of Macro, Edge, and Growth scores; used to bias action, not optimize outcomes."
        static let actionTag = "Forced single weekly decision: none, watch, add, trim, or exit."
        static let changeLog = "One-sentence causal explanation of what changed and why scores or actions moved."
        static let riskRule = "A predefined condition that alters how the thesis should be treated if triggered."
        static let breaker = "Thesis-breaking risk; if triggered, the core thesis is invalidated and exit is typically required."
        static let warn = "Cautionary risk; degrades expected returns or increases volatility but does not invalidate the thesis."
        static let trigger = "A concrete, observable condition that activates a risk rule."
        static let triggeredFlag = "Boolean indicator showing whether a risk trigger is currently active."
        static let portfolioPosture = "How the thesis is expressed in sizing, concentration, and role (core vs venture)."
        static let trimLogic = "Predefined conditions for reducing exposure without invalidating the thesis."
        static let exitLogic = "Predefined conditions for fully closing the position, usually tied to breaker risks or lifecycle goals."
    }

    private struct InfoTooltipIcon: View {
        let help: String
        @State private var isShowingTooltip = false

        var body: some View {
            Text("ⓘ")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
                .onHover { hovering in
                    isShowingTooltip = hovering
                }
                .popover(isPresented: $isShowingTooltip, arrowEdge: .bottom) {
                    Text(help)
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: 260, alignment: .leading)
                }
                .help(help)
                .accessibilityLabel("Info")
                .accessibilityHint(help)
        }
    }

    private func termLabel(_ text: String, help: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            InfoTooltipIcon(help: help)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar(includeActions: true, includeReportHeader: false)
            Divider()
            ScrollView {
                reportBody(includeActions: true)
            }
            .scrollIndicators(.visible)
        }
        .onAppear {
            registerSaveHandler()
            loadState()
        }
        .onChange(of: weekStartDate) { _, _ in
            registerSaveHandler()
            loadState()
        }
        .onChange(of: entry?.id ?? -1) { _, _ in
            registerSaveHandler()
            loadState()
        }
        .onChange(of: answers) { _, _ in updateDirtyState() }
        .onChange(of: skipComment) { _, _ in updateDirtyState() }
        .onChange(of: status) { _, _ in updateDirtyState() }
        .onDisappear {
            saveHandler = nil
        }
        .sheet(isPresented: $showSkipSheet) {
            SkipWeekSheet(skipComment: skipComment, onCancel: { showSkipSheet = false }, onConfirm: handleSkip)
        }
        .fileExporter(
            isPresented: $isShowingPDFExporter,
            document: pdfExportDocument,
            contentType: .pdf,
            defaultFilename: pdfExportDocument.suggestedFilename,
            onCompletion: handleFileExportResult
        )
        .alert("Print Failed", isPresented: $isShowingExportError, presenting: exportErrorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
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

    private func reportBody(includeActions: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(
                title: "Thesis weekly pulse",
                titleHelp: TooltipText.weeklyPulse,
                subtitle: "Capture scores, deltas, and the one-line change that matters."
            ) {
                if answers.thesisChecks.isEmpty {
                    Text("No thesis entries yet.")
                        .foregroundColor(.secondary)
                }
                ForEach(answers.thesisChecks) { item in
                    thesisCard(item, includeActions: includeActions)
                }
                if includeActions {
                    Button("Add thesis entry") {
                        answers.thesisChecks.append(ThesisCheck())
                    }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                }
            }
        }
        .padding(16)
    }

    private var printableReportView: some View {
        VStack(spacing: 0) {
            topBar(includeActions: false, includeReportHeader: true)
            Divider()
            reportBody(includeActions: false)
        }
        .frame(width: Self.reportPDFWidth, alignment: .leading)
        .background(DSColor.background)
    }

    private func topBar(includeActions: Bool, includeReportHeader: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if includeReportHeader {
                reportHeader
            }
            HStack(spacing: 12) {
                if includeActions {
                    Button(saveLabel) { saveProgress() }
                        .buttonStyle(DSButtonStyle(type: saveButtonType, size: .small))
                    Button("Mark Complete") { markComplete() }
                        .buttonStyle(DSButtonStyle(type: .success, size: .small))
                        .disabled(!canComplete)
                        .help("Complete all thesis entries before marking complete.")
                    Button("Skip Week") { showSkipSheet = true }
                        .buttonStyle(DSButtonStyle(type: .destructive, size: .small))
                    Button {
                        Task { await exportReportAsPDF() }
                    } label: {
                        Label {
                            Text(isGeneratingPDF ? "Preparing…" : "Report")
                        } icon: {
                            Text("🗒️")
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                    .disabled(isGeneratingPDF)
                    .help("Create a PDF copy of this weekly report.")
                }
                Spacer()
                DSBadge(text: statusLabel, color: statusColor)
                if includeActions {
                    Button("Exit") { requestExit() }
                        .buttonStyle(WeeklyChecklistExitButtonStyle())
                }
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
            if includeActions, let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(DSColor.surface)
    }

    private var reportHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Risk Report")
                    .font(.title2.weight(.semibold))
                Text("\(themeName) • \(WeeklyChecklistDateHelper.weekLabel(weekStartDate))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Generated")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(reportTimestampText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var reportTimestampText: String {
        WeeklyChecklistDateHelper.timestampFormatter.string(from: reportGeneratedAt ?? Date())
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

    private var pdfDefaultFileName: String {
        let dateComponent = WeeklyChecklistDateHelper.weekKey(weekStartDate)
        let themeComponent = fileSafeComponent(themeName)
        return "Weekly-Risk-Report-\(themeComponent)-\(dateComponent)"
    }

    private func fileSafeComponent(_ value: String) -> String {
        let parts = value.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let cleaned = parts.filter { !$0.isEmpty }.joined(separator: "-")
        return cleaned.isEmpty ? "Theme" : cleaned
    }

    @available(macOS 13.0, iOS 16.0, *)
    private func renderPDFData<Content: View>(from view: Content) -> Data? {
        #if os(macOS)
            guard let visualData = rasterizedPDFData(from: view) else {
                return nil
            }
            guard let appendixData = textAppendixPDFData() else {
                return visualData
            }
            return mergePDFData(primary: visualData, appendix: appendixData) ?? visualData
        #else
            let sizedView = view.fixedSize(horizontal: false, vertical: true)
            let controller = UIHostingController(rootView: sizedView)
            let targetSize = controller.sizeThatFits(in: CGSize(width: Self.reportPDFWidth, height: .greatestFiniteMagnitude))
            controller.view.bounds = CGRect(origin: .zero, size: targetSize)
            controller.view.backgroundColor = .clear
            controller.view.layoutIfNeeded()
            let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: targetSize))
            let data = renderer.pdfData { context in
                context.beginPage()
                controller.view.layer.render(in: context.cgContext)
            }
            if data.count > 1024 {
                return data
            }
            return rasterizedPDFData(from: view)
        #endif
    }

    @available(macOS 13.0, iOS 16.0, *)
    private func rasterizedPDFData<Content: View>(from view: Content) -> Data? {
        let renderer = ImageRenderer(content: view)
        #if os(macOS)
            renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        #else
            renderer.scale = UIScreen.main.scale
        #endif
        guard let cgImage = renderer.cgImage else { return nil }
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            return nil
        }
        context.beginPDFPage(nil)
        context.draw(cgImage, in: mediaBox)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    #if os(macOS)
    private func textAppendixPDFData() -> Data? {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.textStorage?.setAttributedString(reportTextAppendix())
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        let width = Self.reportPDFWidth
        let containerWidth = width - (textView.textContainerInset.width * 2)
        textView.textContainer?.containerSize = NSSize(width: containerWidth, height: .greatestFiniteMagnitude)
        textView.frame = NSRect(origin: .zero, size: NSSize(width: width, height: 1))
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
        let height = max(usedRect.height + (textView.textContainerInset.height * 2), 200)
        textView.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
        textView.layoutSubtreeIfNeeded()
        return textView.dataWithPDF(inside: textView.bounds)
    }

    private func mergePDFData(primary: Data, appendix: Data) -> Data? {
        guard let primaryDoc = PDFDocument(data: primary),
              let appendixDoc = PDFDocument(data: appendix) else {
            return nil
        }
        for index in 0..<appendixDoc.pageCount {
            if let page = appendixDoc.page(at: index) {
                primaryDoc.insert(page, at: primaryDoc.pageCount)
            }
        }
        return primaryDoc.dataRepresentation()
    }

    private func reportTextAppendix() -> NSAttributedString {
        let text = NSMutableAttributedString()
        let headingStyle = paragraphStyle(lineSpacing: 4, paragraphSpacing: 10)
        let sectionStyle = paragraphStyle(lineSpacing: 3, paragraphSpacing: 8)
        let bodyStyle = paragraphStyle(lineSpacing: 3, paragraphSpacing: 6)
        let heading = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            NSAttributedString.Key.paragraphStyle: headingStyle
        ]
        let section = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            NSAttributedString.Key.paragraphStyle: sectionStyle
        ]
        let label = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12, weight: .medium),
            NSAttributedString.Key.paragraphStyle: bodyStyle
        ]
        let body = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12),
            NSAttributedString.Key.paragraphStyle: bodyStyle
        ]

        func appendLine(_ string: String, _ attrs: [NSAttributedString.Key: Any]) {
            text.append(NSAttributedString(string: "\(string)\n", attributes: attrs))
        }

        appendLine("Weekly Risk Report (Text Extract)", heading)
        appendLine("Theme: \(themeName)", body)
        appendLine("Week: \(WeeklyChecklistDateHelper.weekLabel(weekStartDate))", body)
        appendLine("Status: \(statusLabel)", body)
        appendLine("Generated: \(reportTimestampText)", body)
        if revision > 0 {
            appendLine("Revision: \(revision)", body)
        }
        if let lastEditedAt {
            appendLine("Last edited: \(WeeklyChecklistDateHelper.timestampFormatter.string(from: lastEditedAt))", body)
        }
        if let completedAt {
            appendLine("Completed at: \(WeeklyChecklistDateHelper.timestampFormatter.string(from: completedAt))", body)
        }
        if let skippedAt {
            appendLine("Skipped at: \(WeeklyChecklistDateHelper.timestampFormatter.string(from: skippedAt))", body)
        }
        if !skipComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendLine("Skip comment: \(skipComment.trimmingCharacters(in: .whitespacesAndNewlines))", body)
        }
        appendLine("", body)

        if answers.thesisChecks.isEmpty {
            appendLine("No thesis entries.", body)
            return text
        }

        for (index, item) in answers.thesisChecks.enumerated() {
            appendLine("Thesis \(index + 1)", section)
            appendLine("Position / Theme: \(valueOrPlaceholder(item.position))", body)
            appendLine("Base Thesis: \(valueOrPlaceholder(item.originalThesis))", body)
            appendLine("Macro Score: \(scoreText(item.macroScore))", body)
            appendLine("Macro Delta: \(deltaText(item.macroDelta))", body)
            appendLine("Macro Note: \(valueOrPlaceholder(item.macroNote))", body)
            appendLine("Edge Score: \(scoreText(item.edgeScore))", body)
            appendLine("Edge Delta: \(deltaText(item.edgeDelta))", body)
            appendLine("Edge Note: \(valueOrPlaceholder(item.edgeNote))", body)
            appendLine("Growth Score: \(scoreText(item.growthScore))", body)
            appendLine("Growth Delta: \(deltaText(item.growthDelta))", body)
            appendLine("Growth Note: \(valueOrPlaceholder(item.growthNote))", body)
            if let netScore = item.netScore {
                appendLine(String(format: "Net Score: %.1f", netScore), body)
            }
            appendLine("Action Tag: \(item.actionTag.map(actionTagLabel) ?? "None")", body)
            appendLine("Change Log: \(valueOrPlaceholder(item.changeLog))", body)
            if item.risks.isEmpty {
                appendLine("Risks: None", body)
            } else {
                appendLine("Risks:", label)
                for risk in item.risks {
                    let riskLine = " - Level: \(riskLevelLabel(risk.level)), Rule: \(valueOrPlaceholder(risk.rule)), Trigger: \(valueOrPlaceholder(risk.trigger)), Triggered: \(riskTriggeredLabel(risk.triggered))"
                    appendLine(riskLine, body)
                }
            }
            appendLine("", body)
        }
        return text
    }

    private func paragraphStyle(lineSpacing: CGFloat, paragraphSpacing: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        return style
    }
    #endif

    @MainActor
    private func exportReportAsPDF() async {
        guard !isGeneratingPDF else { return }

        #if os(macOS)
            guard #available(macOS 13.0, *) else {
                presentExportError("Printing requires macOS 13 or newer.")
                return
            }
        #else
            guard #available(iOS 16.0, macCatalyst 16.0, *) else {
                presentExportError("Printing requires iOS/macCatalyst 16 or newer.")
                return
            }
        #endif

        isGeneratingPDF = true
        defer { isGeneratingPDF = false }
        reportGeneratedAt = Date()

        if #available(macOS 13.0, iOS 16.0, *) {
            if let data = renderPDFData(from: printableReportView) {
                pdfExportDocument = WeeklyChecklistPDFDocument(data: data, suggestedFilename: pdfDefaultFileName)
                isShowingPDFExporter = true
            } else {
                presentExportError("Unable to render the report to PDF.")
            }
        }
    }

    @MainActor
    private func handleFileExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            exportErrorMessage = nil
        case let .failure(error):
            presentExportError("Failed to save the PDF: \(error.localizedDescription)")
        }
        pdfExportDocument = .empty
    }

    private func presentExportError(_ message: String) {
        exportErrorMessage = message
        isShowingExportError = true
        pdfExportDocument = .empty
    }

    private func thesisCard(_ item: ThesisCheck, includeActions: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            termLabel("A. Main Thesis", help: TooltipText.thesis)
                .font(.title3.weight(.semibold))
            termLabel("Hook (North Star)", help: TooltipText.hook)
                .font(.caption)
                .foregroundColor(.secondary)
            if includeActions {
                TextField("Position / Theme", text: bindingForThesis(item.id, \.position))
                    .textFieldStyle(.roundedBorder)
            } else {
                reportTextField(item.position, placeholder: "Position / Theme")
            }
            termLabel("Base Thesis", help: TooltipText.baseThesis)
                .font(.caption)
                .foregroundColor(.secondary)
            if includeActions {
                adaptiveTextField("Base thesis (locked, 1-2 lines)", text: bindingForThesis(item.id, \.originalThesis))
            } else {
                reportTextArea(item.originalThesis, placeholder: "Base thesis (locked, 1-2 lines)", minHeight: 72)
            }
            scoreRow(
                title: "B. Macro Score",
                titleHelp: TooltipText.macroScore,
                score: bindingForThesis(item.id, \.macroScore),
                delta: bindingForThesis(item.id, \.macroDelta),
                note: bindingForThesis(item.id, \.macroNote),
                notePlaceholder: "Macro note (tailwind / headwind)",
                includeActions: includeActions
            )
            scoreRow(
                title: "C. Edge Score",
                titleHelp: TooltipText.edgeScore,
                score: bindingForThesis(item.id, \.edgeScore),
                delta: bindingForThesis(item.id, \.edgeDelta),
                note: bindingForThesis(item.id, \.edgeNote),
                notePlaceholder: "Edge note (moat in 4 words)",
                includeActions: includeActions
            )
            scoreRow(
                title: "D. Growth Score",
                titleHelp: TooltipText.growthScore,
                score: bindingForThesis(item.id, \.growthScore),
                delta: bindingForThesis(item.id, \.growthDelta),
                note: bindingForThesis(item.id, \.growthNote),
                notePlaceholder: "Growth note (next buyer + trigger)",
                includeActions: includeActions
            )
            if let netScore = item.netScore {
                HStack(spacing: 4) {
                    Text(String(format: "Net score: %.1f", netScore))
                    InfoTooltipIcon(help: TooltipText.netScore)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            termLabel("Action Tag", help: TooltipText.actionTag)
                .font(.subheadline.weight(.semibold))
            termLabel("Portfolio Posture", help: TooltipText.portfolioPosture)
                .font(.caption)
                .foregroundColor(.secondary)
            if includeActions {
                Picker("Action", selection: bindingForThesis(item.id, \.actionTag)) {
                    Text("Select...").tag(ThesisActionTag?.none)
                    ForEach(ThesisActionTag.allCases, id: \.self) { tag in
                        Text(actionTagLabel(tag)).tag(Optional(tag))
                    }
                }
                .labelsHidden()
            } else {
                reportPickerLabel(
                    text: item.actionTag.map(actionTagLabel) ?? "Select...",
                    tint: DSColor.textPrimary,
                    fill: DSColor.surfaceSecondary,
                    border: DSColor.borderStrong,
                    minWidth: 140
                )
            }
            HStack(spacing: 12) {
                termLabel("Trim Logic", help: TooltipText.trimLogic)
                termLabel("Exit Logic", help: TooltipText.exitLogic)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            termLabel("Change Log", help: TooltipText.changeLog)
                .font(.caption)
                .foregroundColor(.secondary)
            if includeActions {
                adaptiveTextField("Change log (one sentence)", text: bindingForThesis(item.id, \.changeLog), minLines: 1, maxLines: 4)
            } else {
                reportTextArea(item.changeLog, placeholder: "Change log (one sentence)", minHeight: 52)
            }
            riskSection(for: item, includeActions: includeActions)
            if includeActions {
                Button("Remove thesis") {
                    answers.thesisChecks.removeAll { $0.id == item.id }
                }
                .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
            }
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

    private func scoreRow(
        title: String,
        titleHelp: String,
        score: Binding<Int?>,
        delta: Binding<ThesisScoreDelta?>,
        note: Binding<String>,
        notePlaceholder: String,
        includeActions: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                termLabel(title, help: titleHelp)
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    termLabel("Score (1-10)", help: TooltipText.score)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if includeActions {
                        scorePicker(score)
                    } else {
                        reportPickerLabel(
                            text: score.wrappedValue.map(String.init) ?? "Score",
                            tint: scoreTint(score.wrappedValue),
                            fill: scoreBackground(score.wrappedValue),
                            border: scoreBorder(score.wrappedValue),
                            minWidth: 84
                        )
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    termLabel("Delta (up / flat / down)", help: TooltipText.delta)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if includeActions {
                        deltaPicker(delta)
                    } else {
                        reportPickerLabel(
                            text: delta.wrappedValue.map(deltaLabel) ?? "Delta",
                            tint: deltaTint(delta.wrappedValue),
                            fill: deltaBackground(delta.wrappedValue),
                            border: deltaBorder(delta.wrappedValue),
                            minWidth: 110
                        )
                    }
                }
                .frame(maxWidth: 160)
            }
            if includeActions {
                adaptiveTextField(notePlaceholder, text: note, minLines: 1, maxLines: 3)
            } else {
                reportTextArea(note.wrappedValue, placeholder: notePlaceholder, minHeight: 46)
            }
        }
    }

    private func reportTextField(_ value: String, placeholder: String) -> some View {
        reportTextBox(
            value: value,
            placeholder: placeholder,
            minHeight: 34
        )
    }

    private func reportTextArea(_ value: String, placeholder: String, minHeight: CGFloat) -> some View {
        reportTextBox(
            value: value,
            placeholder: placeholder,
            minHeight: minHeight
        )
    }

    private func reportTextBox(value: String, placeholder: String, minHeight: CGFloat) -> some View {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayText = trimmed.isEmpty ? placeholder : trimmed
        return Text(displayText)
            .font(.body)
            .foregroundColor(trimmed.isEmpty ? .secondary : DSColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(DSColor.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DSColor.borderStrong, lineWidth: 1)
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    private func valueOrPlaceholder(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "n/a" : trimmed
    }

    private func scoreText(_ score: Int?) -> String {
        score.map(String.init) ?? "n/a"
    }

    private func deltaText(_ delta: ThesisScoreDelta?) -> String {
        delta.map(deltaLabel) ?? "n/a"
    }

    private func scorePicker(_ score: Binding<Int?>) -> some View {
        ChecklistDropdown(
            placeholder: "Score",
            options: Array(1...10),
            selection: score,
            labelText: { $0.map(String.init) ?? "Score" },
            optionText: { String($0) },
            tint: scoreTint,
            fill: scoreBackground,
            border: scoreBorder,
            minWidth: 84
        )
    }

    private func deltaPicker(_ delta: Binding<ThesisScoreDelta?>) -> some View {
        ChecklistDropdown(
            placeholder: "Delta",
            options: ThesisScoreDelta.allCases,
            selection: delta,
            labelText: { $0.map(deltaLabel) ?? "Delta" },
            optionText: deltaLabel,
            tint: deltaTint,
            fill: deltaBackground,
            border: deltaBorder,
            minWidth: 110
        )
    }

    private struct ChecklistDropdown<Option: Hashable>: View {
        let placeholder: String
        let options: [Option]
        @Binding var selection: Option?
        let labelText: (Option?) -> String
        let optionText: (Option) -> String
        let tint: (Option?) -> Color
        let fill: (Option?) -> Color
        let border: (Option?) -> Color
        let minWidth: CGFloat

        @State private var isPresented = false

        var body: some View {
            Button {
                isPresented = true
            } label: {
                DropdownLabel(
                    text: labelText(selection),
                    tint: tint(selection),
                    fill: fill(selection),
                    border: border(selection),
                    minWidth: minWidth
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Button(placeholder) {
                        selection = nil
                        isPresented = false
                    }
                    .buttonStyle(.plain)
                    Divider()
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection = option
                            isPresented = false
                        } label: {
                            HStack {
                                Text(optionText(option))
                                Spacer()
                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .frame(minWidth: minWidth + 40)
            }
        }
    }

    private struct DropdownLabel: View {
        let text: String
        let tint: Color
        let fill: Color
        let border: Color
        let minWidth: CGFloat

        var body: some View {
            HStack(spacing: 8) {
                Text(text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: minWidth)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.radiusS)
                    .stroke(border, lineWidth: 1)
            )
        }
    }

    private func pickerLabel(text: String, tint: Color, fill: Color, border: Color, minWidth: CGFloat, showsChevron: Bool = true) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.subheadline.weight(.semibold))
            if showsChevron {
                Spacer(minLength: 6)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minWidth: minWidth, alignment: .leading)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.radiusS)
                .stroke(border, lineWidth: 1)
        )
    }

    private func reportPickerLabel(text: String, tint: Color, fill: Color, border: Color, minWidth: CGFloat) -> some View {
        pickerLabel(
            text: text,
            tint: tint,
            fill: fill,
            border: border,
            minWidth: minWidth,
            showsChevron: false
        )
    }

    private func scoreTint(_ score: Int?) -> Color {
        guard let score else { return DSColor.textSecondary }
        switch score {
        case 1...4:
            return .numberRed
        case 5...7:
            return .numberAmber
        case 8...10:
            return .numberGreen
        default:
            return DSColor.textSecondary
        }
    }

    private func scoreBackground(_ score: Int?) -> Color {
        guard score != nil else { return DSColor.surfaceSecondary }
        return scoreTint(score).opacity(0.24)
    }

    private func scoreBorder(_ score: Int?) -> Color {
        guard score != nil else { return DSColor.borderStrong }
        return scoreTint(score).opacity(0.4)
    }

    private func deltaTint(_ delta: ThesisScoreDelta?) -> Color {
        switch delta {
        case .up:
            return .numberGreen
        case .down:
            return .numberRed
        case .flat:
            return .secondary
        case .none:
            return DSColor.textSecondary
        }
    }

    private func deltaBackground(_ delta: ThesisScoreDelta?) -> Color {
        switch delta {
        case .up:
            return Color.numberGreen.opacity(0.24)
        case .down:
            return Color.numberRed.opacity(0.24)
        case .flat:
            return Color.secondary.opacity(0.18)
        case .none:
            return DSColor.surfaceSecondary
        }
    }

    private func deltaBorder(_ delta: ThesisScoreDelta?) -> Color {
        switch delta {
        case .up:
            return Color.numberGreen.opacity(0.4)
        case .down:
            return Color.numberRed.opacity(0.4)
        case .flat:
            return Color.secondary.opacity(0.35)
        case .none:
            return DSColor.borderStrong
        }
    }

    private func riskSection(for item: ThesisCheck, includeActions: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("E. Risks")
                .font(.title3.weight(.semibold))
            if item.risks.isEmpty {
                Text("No risks logged.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ForEach(item.risks) { risk in
                riskRow(thesisId: item.id, riskId: risk.id, includeActions: includeActions)
            }
            if includeActions {
                Button("Add risk") {
                    addRisk(to: item.id)
                }
                .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
        }
    }

    private func riskRow(thesisId: UUID, riskId: UUID, includeActions: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Level")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    termLabel("Breaker", help: TooltipText.breaker)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    termLabel("Warn", help: TooltipText.warn)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if includeActions {
                    Picker("Level", selection: bindingForRisk(thesisId, riskId, \.level)) {
                        ForEach(ThesisRiskLevel.allCases, id: \.self) { level in
                            Text(riskLevelLabel(level)).tag(level)
                        }
                    }
                    .labelsHidden()
                } else {
                    let levelValue = bindingForRisk(thesisId, riskId, \.level).wrappedValue
                    reportPickerLabel(
                        text: riskLevelLabel(levelValue),
                        tint: DSColor.textPrimary,
                        fill: DSColor.surfaceSecondary,
                        border: DSColor.borderStrong,
                        minWidth: 90
                    )
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                termLabel("Risk Rule", help: TooltipText.riskRule)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if includeActions {
                    TextField("Rule", text: bindingForRisk(thesisId, riskId, \.rule))
                        .textFieldStyle(.roundedBorder)
                } else {
                    reportTextField(bindingForRisk(thesisId, riskId, \.rule).wrappedValue, placeholder: "Rule")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                termLabel("Trigger", help: TooltipText.trigger)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if includeActions {
                    TextField("Trigger", text: bindingForRisk(thesisId, riskId, \.trigger))
                        .textFieldStyle(.roundedBorder)
                } else {
                    reportTextField(bindingForRisk(thesisId, riskId, \.trigger).wrappedValue, placeholder: "Trigger")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                termLabel("Triggered Flag", help: TooltipText.triggeredFlag)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if includeActions {
                    Picker("Triggered", selection: bindingForRisk(thesisId, riskId, \.triggered)) {
                        ForEach(ThesisRiskTriggered.allCases, id: \.self) { triggered in
                            Text(riskTriggeredLabel(triggered)).tag(triggered)
                        }
                    }
                    .labelsHidden()
                } else {
                    let triggeredValue = bindingForRisk(thesisId, riskId, \.triggered).wrappedValue
                    reportPickerLabel(
                        text: riskTriggeredLabel(triggeredValue),
                        tint: DSColor.textPrimary,
                        fill: DSColor.surfaceSecondary,
                        border: DSColor.borderStrong,
                        minWidth: 110
                    )
                }
            }
            if includeActions {
                Button("Remove") {
                    removeRisk(from: thesisId, riskId: riskId)
                }
                .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
                .padding(.top, 18)
            }
        }
    }

    private func bindingForRisk<Value>(_ thesisId: UUID, _ riskId: UUID, _ keyPath: WritableKeyPath<ThesisRisk, Value>) -> Binding<Value> {
        Binding(
            get: {
                guard let thesisIndex = answers.thesisChecks.firstIndex(where: { $0.id == thesisId }),
                      let riskIndex = answers.thesisChecks[thesisIndex].risks.firstIndex(where: { $0.id == riskId }) else {
                    return ThesisRisk()[keyPath: keyPath]
                }
                return answers.thesisChecks[thesisIndex].risks[riskIndex][keyPath: keyPath]
            },
            set: { newValue in
                guard let thesisIndex = answers.thesisChecks.firstIndex(where: { $0.id == thesisId }),
                      let riskIndex = answers.thesisChecks[thesisIndex].risks.firstIndex(where: { $0.id == riskId }) else {
                    return
                }
                answers.thesisChecks[thesisIndex].risks[riskIndex][keyPath: keyPath] = newValue
            }
        )
    }

    private func addRisk(to thesisId: UUID) {
        guard let thesisIndex = answers.thesisChecks.firstIndex(where: { $0.id == thesisId }) else { return }
        answers.thesisChecks[thesisIndex].risks.append(ThesisRisk())
    }

    private func removeRisk(from thesisId: UUID, riskId: UUID) {
        guard let thesisIndex = answers.thesisChecks.firstIndex(where: { $0.id == thesisId }) else { return }
        answers.thesisChecks[thesisIndex].risks.removeAll { $0.id == riskId }
    }

    private func deltaLabel(_ delta: ThesisScoreDelta) -> String {
        switch delta {
        case .up: return "Up"
        case .flat: return "Flat"
        case .down: return "Down"
        }
    }

    private func actionTagLabel(_ tag: ThesisActionTag) -> String {
        switch tag {
        case .none: return "None"
        case .watch: return "Watch"
        case .add: return "Add"
        case .trim: return "Trim"
        case .exit: return "Exit"
        }
    }

    private func riskLevelLabel(_ level: ThesisRiskLevel) -> String {
        switch level {
        case .breaker: return "Breaker"
        case .warn: return "Warn"
        }
    }

    private func riskTriggeredLabel(_ triggered: ThesisRiskTriggered) -> String {
        switch triggered {
        case .yes: return "Yes"
        case .no: return "No"
        }
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
        !answers.thesisChecks.isEmpty && answers.thesisChecks.allSatisfy { isThesisComplete($0) }
    }

    private func isThesisComplete(_ item: ThesisCheck) -> Bool {
        let hasPosition = !item.position.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasThesis = !item.originalThesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasScores = item.macroScore != nil && item.edgeScore != nil && item.growthScore != nil
        let hasAction = item.actionTag != nil
        let hasChangeLog = !item.changeLog.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasPosition && hasThesis && hasScores && hasAction && hasChangeLog
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

    private func captureBaseline() {
        baselineAnswers = answers
        baselineSkipComment = skipComment
        baselineStatus = status
        updateDirtyState()
    }

    private var isDirty: Bool {
        answers != baselineAnswers || skipComment != baselineSkipComment || status != baselineStatus
    }

    private func registerSaveHandler() {
        saveHandler = saveProgress
    }

    private func updateDirtyState() {
        hasUnsavedChanges = isDirty
    }

    private func requestExit() {
        if isDirty {
            showExitConfirm = true
        } else {
            onExit()
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        titleHelp: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        DSCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                if let titleHelp {
                    termLabel(title, help: titleHelp)
                        .font(.headline)
                } else {
                    Text(title)
                        .font(.headline)
                }
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
        handleSaveResult(ok, newStatus: targetStatus)
        return ok
    }

    private func markComplete() {
        errorMessage = nil
        guard canComplete else {
            errorMessage = "Fill in all thesis entries before completing this week."
            return
        }
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

private struct WeeklyChecklistPDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [.pdf] }
    static var empty: WeeklyChecklistPDFDocument {
        WeeklyChecklistPDFDocument(data: Data(), suggestedFilename: "Weekly-Risk-Report")
    }

    var data: Data
    var suggestedFilename: String

    init(data: Data, suggestedFilename: String) {
        self.data = data
        self.suggestedFilename = suggestedFilename
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        suggestedFilename = "Weekly-Risk-Report"
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = suggestedFilename
        return wrapper
    }
}
