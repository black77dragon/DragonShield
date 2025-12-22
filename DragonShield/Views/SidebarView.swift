// DragonShield/Views/SidebarView.swift

// MARK: - Version 1.9

// MARK: - History

// - 1.4 -> 1.5: Added "Edit Account Types" navigation link.
// - 1.5 -> 1.6: Added "Positions" navigation link.
// - 1.6 -> 1.7: Added "Edit Institutions" navigation link.
// - 1.7 -> 1.8: Added Data Import/Export view to replace the old document loader.
// - (Previous history)

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var todoBoardViewModel = KanbanBoardViewModel()
    @State private var showReleaseNotes = false

    // New AppStorage keys for the new structure
    @AppStorage("sidebar.showDashboard") private var showDashboard = true
    @AppStorage("sidebar.showPortfolio") private var showPortfolio = true
    @AppStorage("sidebar.showMarket") private var showMarket = true
    @AppStorage("sidebar.showSystem") private var showSystem = true
    @AppStorage("sidebar.showConfiguration") private var showConfiguration = false

    private var dueTodayOrOverdueCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return todoBoardViewModel.allTodos.filter { todo in
            guard todo.column != .done, todo.column != .archived else { return false }
            guard !todo.isCompleted else { return false }
            guard let dueDate = todo.dueDate else { return false }
            let due = calendar.startOfDay(for: dueDate)
            return due <= today
        }.count
    }

    var body: some View {
        List {
            // 1. Dashboard Group
            DisclosureGroup("Dashboard", isExpanded: $showDashboard) {
                NavigationLink(destination: CategorizedDashboardView()) {
                    HStack(spacing: 8) {
                        Label("Dashboard", systemImage: "square.grid.3x1.below.line.grid.1x2")
                    }
                }
                
                NavigationLink(destination: TodoKanbanBoardView().environmentObject(dbManager)) {
                    HStack(spacing: 8) {
                        Label("To-Do Board", systemImage: "list.bullet.rectangle.fill")
                        if dueTodayOrOverdueCount > 0 {
                            TodoDueBadge(count: dueTodayOrOverdueCount)
                        }
                    }
                }
            }

            // 2. Portfolio Group
            DisclosureGroup("Portfolio", isExpanded: $showPortfolio) {
                NavigationLink(destination: PortfolioThemesAlignedView().environmentObject(dbManager)) {
                    Label("Portfolios", systemImage: "tablecells")
                }
                
                NavigationLink(destination: RiskReportView().environmentObject(dbManager).environmentObject(AssetManager())) {
                    Label("Risk Report", systemImage: "shield")
                }
                
                NavigationLink(destination: PositionsView()) {
                    Label("Positions", systemImage: "tablecells")
                }

                NavigationLink(destination: TradesHistoryView().environmentObject(dbManager)) {
                    Label("Transactions", systemImage: "list.bullet.rectangle.portrait")
                }
                
                NavigationLink(destination: AllocationDashboardView()) {
                    Label("Asset Allocation", systemImage: "chart.pie")
                }

                NavigationLink(destination: HistoricPerformanceView().environmentObject(dbManager)) {
                    Label("Historic Performance", systemImage: "chart.line.uptrend.xyaxis")
                }
                
                NavigationLink(destination: AssetManagementReportView()) {
                    Label("Asset Management Report", systemImage: "chart.bar.fill")
                }
            }

            // 3. Market Group
            DisclosureGroup("Market", isExpanded: $showMarket) {
                NavigationLink(destination: PortfolioView()) {
                    Label("Instruments", systemImage: "pencil.and.list.clipboard")
                }
                
                NavigationLink(destination: PriceUpdatesView().environmentObject(dbManager)) {
                    Label("Price Updates", systemImage: "dollarsign.circle")
                }
                
                NavigationLink(destination: CurrenciesView()) {
                    Label("Currencies & FX", systemImage: "dollarsign.circle.fill")
                }
                
                NavigationLink(destination: IchimokuDragonView()) {
                    HStack(spacing: 8) {
                        Label("Ichimoku Dragon", systemImage: "cloud.sun.rain")
                        Spacer()
                        SidebarStatusBadge(text: "Legacy")
                    }
                }
                .disabled(true)
                .opacity(0.55)

                NavigationLink(destination: AlertsSettingsView().environmentObject(dbManager)) {
                    Label("Alerts & Events", systemImage: "bell")
                }
            }

            // 4. System Group
            DisclosureGroup("System", isExpanded: $showSystem) {
                SidebarSectionHeader(title: "Core")
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gear")
                }

                NavigationLink(destination: DataImportExportView()) {
                    Label("Data Import/Export", systemImage: "square.and.arrow.up.on.square")
                }

                SidebarSectionHeader(title: "Maintenance")
                NavigationLink(destination: DatabaseManagementView()) {
                    Label("Database Management", systemImage: "externaldrive.badge.timemachine")
                }
            }

            // 5. Configuration Group
            DisclosureGroup("Configuration", isExpanded: $showConfiguration) {
                NavigationLink(destination: InstitutionsView()) {
                    Label("Institutions", systemImage: "building.2.fill")
                }
                
                NavigationLink(destination: AccountsView()) {
                    Label("Accounts", systemImage: "building.columns.fill")
                }
                
                NavigationLink(destination: ClassManagementView()) {
                    Label("Asset Classes & Instr. Types", systemImage: "folder")
                }
                
                NavigationLink(destination: AccountTypesView().environmentObject(dbManager)) {
                    Label("Account Types", systemImage: "creditcard")
                }
                
                NavigationLink(destination: TransactionTypesView()) {
                    Label("Transaction Types", systemImage: "tag.circle.fill")
                }
                
                NavigationLink(destination: RiskManagementMaintenanceView().environmentObject(dbManager)) {
                    Label("Instrument Risk Maint.", systemImage: "shield.lefthalf.filled")
                }
                
                NavigationLink(destination: ThemeStatusSettingsView().environmentObject(dbManager)) {
                    Label("Theme Statuses", systemImage: "paintpalette")
                }
                
                NavigationLink(destination: NewsTypeSettingsView().environmentObject(dbManager)) {
                    Label("News Types", systemImage: "newspaper")
                }
                
                NavigationLink(destination: AlertTriggerTypeSettingsView().environmentObject(dbManager)) {
                    Label("Alert Trigger Types", systemImage: "bell.badge")
                }
                
                NavigationLink(destination: TagSettingsView().environmentObject(dbManager)) {
                    Label("Tags", systemImage: "tag.fill")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .dsHeaderSmall()
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            showReleaseNotes = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("VERSION")
                                    .dsCaption()
                                Text(AppVersionProvider.version)
                                    .dsBody()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                    Text("Release Notes")
                                }
                                .dsCaption()
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .help("Click to view release notes")
                        if let lastChange = GitInfoProvider.lastChangeSummary, !lastChange.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("VERSION_LAST_CHANGE")
                                    .dsCaption()
                                Text(lastChange)
                                    .dsBody()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let branch = GitInfoProvider.branch, !branch.isEmpty {
                            Text("Branch: \(branch)")
                                .dsCaption()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 16))
        }
        .listStyle(.sidebar)
        .navigationTitle("Dragon Shield (Gemini Version)")
        .sheet(isPresented: $showReleaseNotes) {
            ReleaseNotesView(version: AppVersionProvider.version)
        }
        .onAppear {
            todoBoardViewModel.refreshFromStorage()
        }
    }
}

private struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.ds.caption)
            .foregroundStyle(DSColor.textSecondary)
            .padding(.top, DSLayout.spaceS)
            .padding(.leading, 2)
    }
}

private struct SidebarStatusBadge: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, DSLayout.spaceS)
            .padding(.vertical, DSLayout.spaceXS)
            .background(DSColor.surfaceSecondary)
            .foregroundStyle(DSColor.textSecondary)
            .clipShape(Capsule())
    }
}

private struct BoardStat: Identifiable {
    let id: String
    let title: String
    let value: String
    let icon: String
    let accent: Color
    var progress: Double?
}

private struct BoardStatCard: View {
    let stat: BoardStat

    var body: some View {
        HStack(alignment: .center, spacing: DSLayout.spaceS) {
            ZStack {
                Circle()
                    .fill(stat.accent.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: stat.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(stat.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stat.title)
                    .font(.ds.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
                Text(stat.value)
                    .font(.ds.headerMedium)
                    .foregroundStyle(stat.accent)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSLayout.spaceM)
        .padding(.vertical, 10)
        .frame(width: 180, height: 60, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: DSLayout.radiusL)
                .fill(DSColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.radiusL)
                .stroke(DSColor.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

private struct KanbanColumnPalette {
    let accent: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let cardBackground: Color
    let cardBorder: Color
    let filterActiveBackground: Color

    var gradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var shadowColor: Color {
        accent.opacity(0.12)
    }
}

private extension KanbanColumn {
    var palette: KanbanColumnPalette {
        switch self {
        case .backlog:
            return KanbanColumnPalette(
                accent: DSColor.accentWarning,
                backgroundTop: DSColor.surface,
                backgroundBottom: DSColor.surfaceSecondary,
                cardBackground: DSColor.surface,
                cardBorder: DSColor.border,
                filterActiveBackground: DSColor.surfaceHighlight
            )
        case .prioritised:
            return KanbanColumnPalette(
                accent: DSColor.accentError,
                backgroundTop: DSColor.surface,
                backgroundBottom: DSColor.surfaceSecondary,
                cardBackground: DSColor.surface,
                cardBorder: DSColor.border,
                filterActiveBackground: DSColor.surfaceHighlight
            )
        case .doing:
            return KanbanColumnPalette(
                accent: DSColor.accentMain,
                backgroundTop: DSColor.surface,
                backgroundBottom: DSColor.surfaceSecondary,
                cardBackground: DSColor.surface,
                cardBorder: DSColor.border,
                filterActiveBackground: DSColor.surfaceHighlight
            )
        case .done:
            return KanbanColumnPalette(
                accent: DSColor.accentSuccess,
                backgroundTop: DSColor.surface,
                backgroundBottom: DSColor.surfaceSecondary,
                cardBackground: DSColor.surface,
                cardBorder: DSColor.border,
                filterActiveBackground: DSColor.surfaceHighlight
            )
        case .archived:
            return KanbanColumnPalette(
                accent: DSColor.textTertiary,
                backgroundTop: DSColor.surface,
                backgroundBottom: DSColor.surfaceSecondary,
                cardBackground: DSColor.surface,
                cardBorder: DSColor.border,
                filterActiveBackground: DSColor.surfaceHighlight
            )
        }
    }

    var displayTitle: String {
        switch self {
        case .prioritised: return "To Do"
        case .doing: return "In Progress"
        default: return title
        }
    }

    var subtitle: String {
        switch self {
        case .backlog: return "Ideas & discovery"
        case .prioritised: return "Ready to take on"
        case .doing: return "Actively moving"
        case .done: return "Wrapped up work"
        case .archived: return "Saved for reference"
        }
    }
}

private extension Double {
    var formattedPercentage: String {
        guard isFinite else { return "0%" }
        let clamped = max(0, min(self, 1))
        return String(format: "%.0f%%", clamped * 100)
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = DatabaseManager()
        NavigationSplitView {
            SidebarView()
        } detail: {
            DashboardView()
        }
        .environmentObject(manager)
        .environmentObject(manager.preferences)
        .environmentObject(AssetManager())
    }
}

private struct TagBadge: View {
    let tag: TagRow
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    private var baseColor: Color {
        guard let hex = tag.color, !hex.isEmpty else { return Color.gray }
        return Color(hex: hex)
    }

    private var textColor: Color {
        guard let hex = tag.color, !hex.isEmpty else { return .primary }
        return Color.textColor(forHex: hex)
    }

    var body: some View {
        let pill = Text("#\(tag.displayName)")
            .font(.ds.caption)
            .padding(.horizontal, DSLayout.spaceS)
            .padding(.vertical, DSLayout.spaceXS)
            .background(
                Capsule()
                    .fill(baseColor.opacity(action == nil ? 0.22 : 0.18))
            )
            .foregroundColor(textColor)

        if let action {
            Button(action: action) {
                pill
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? DSColor.accentMain : DSColor.border, lineWidth: isSelected ? 1.5 : 1)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
        } else {
            pill
        }
    }
}

private struct TodoEditorSheet: View {
    enum Mode {
        case new(defaultColumn: KanbanColumn)
        case edit(existing: KanbanTodo)
    }

    let mode: Mode
    let availableTags: [TagRow]
    var onSave: (String, KanbanPriority, Date?, KanbanColumn, [Int], Bool, KanbanRepeatFrequency?) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var description: String
    @State private var priority: KanbanPriority
    @State private var dueDate: Date?
    @State private var column: KanbanColumn
    @State private var selectedTags: Set<Int>
    @State private var isCompleted: Bool
    @State private var isRepeating: Bool
    @State private var repeatFrequency: KanbanRepeatFrequency?
    @State private var confirmingDeletion = false
    @FocusState private var descriptionFocused: Bool

    init(mode: Mode,
         availableTags: [TagRow],
         prefill: KanbanTodoQuickAddRequest? = nil,
         onSave: @escaping (String, KanbanPriority, Date?, KanbanColumn, [Int], Bool, KanbanRepeatFrequency?) -> Void,
         onDelete: (() -> Void)? = nil)
    {
        self.mode = mode
        self.availableTags = availableTags
        self.onSave = onSave
        self.onDelete = onDelete

        switch mode {
        case let .new(defaultColumn):
            _description = State(initialValue: prefill?.description ?? "")
            _priority = State(initialValue: prefill?.priority ?? .medium)
            _dueDate = State(initialValue: prefill?.dueDate)
            _column = State(initialValue: prefill?.column ?? defaultColumn)
            _selectedTags = State(initialValue: Set(prefill?.tagIDs ?? []))
            let initialRepeatFrequency = prefill?.repeatFrequency
            _repeatFrequency = State(initialValue: initialRepeatFrequency)
            _isRepeating = State(initialValue: initialRepeatFrequency != nil)
            _isCompleted = State(initialValue: prefill?.isCompleted ?? false)
        case let .edit(existing):
            _description = State(initialValue: existing.description)
            _priority = State(initialValue: existing.priority)
            _dueDate = State(initialValue: existing.dueDate)
            _column = State(initialValue: existing.column)
            _selectedTags = State(initialValue: Set(existing.tagIDs))
            _repeatFrequency = State(initialValue: existing.repeatFrequency)
            _isRepeating = State(initialValue: existing.isRepeating)
            _isCompleted = State(initialValue: existing.isCompleted)
        }
    }

    private var title: String {
        switch mode {
        case .new: return "New To Do"
        case .edit: return "Edit To Do"
        }
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        guard !trimmedDescription.isEmpty else { return false }
        if isRepeating {
            return repeatFrequency != nil
        }
        return true
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { dueDate ?? Calendar.current.startOfDay(for: Date()) },
            set: { newValue in dueDate = newValue }
        )
    }

    private var dueDateToggleBinding: Binding<Bool> {
        Binding(
            get: { dueDate != nil },
            set: { newValue in
                if newValue {
                    dueDate = dueDate ?? Calendar.current.startOfDay(for: Date())
                } else {
                    dueDate = nil
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .dsHeaderMedium()

            TextField("Task description", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($descriptionFocused)

            VStack(alignment: .leading, spacing: 12) {
                Picker("Priority", selection: $priority) {
                    ForEach(KanbanPriority.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Column", selection: $column) {
                    ForEach(KanbanColumn.allCases) { column in
                        Text(column.title).tag(column)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Set Due Date", isOn: dueDateToggleBinding)
                if dueDate != nil {
                    DatePicker("Due Date", selection: dueDateBinding, displayedComponents: .date)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Completed", isOn: $isCompleted)
                    .toggleStyle(.switch)
                    .disabled(isRepeating)

                Toggle(isOn: $isRepeating.animation()) {
                    Label("Repeat", systemImage: KanbanRepeatFrequency.weekly.systemImageName)
                }
                .toggleStyle(.switch)

                if isRepeating {
                    Picker("Frequency", selection: Binding(get: {
                        repeatFrequency ?? KanbanRepeatFrequency.weekly
                    }, set: { newValue in
                        repeatFrequency = newValue
                    })) {
                        ForEach(KanbanRepeatFrequency.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Repeat-enabled tasks reset themselves after completion.")
                        .dsCaption()
                }
            }
            .onChange(of: isRepeating) { _, newValue in
                if newValue {
                    if repeatFrequency == nil {
                        repeatFrequency = .weekly
                    }
                    isCompleted = false
                } else {
                    repeatFrequency = nil
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .dsHeaderSmall()
                if availableTags.isEmpty {
                    Text("No tags configured yet. Manage tags via Settings → Tags.")
                        .dsCaption()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(availableTags) { tag in
                                TagBadge(tag: tag, isSelected: selectedTags.contains(tag.id)) {
                                    toggle(tag: tag)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(minHeight: 60, maxHeight: 180)
                }
            }

            Spacer(minLength: 0)

            HStack {
                if onDelete != nil {
                    Button(role: .destructive) {
                        confirmingDeletion = true
                    } label: {
                        Text("Delete")
                    }
                    .confirmationDialog("Delete this to do?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            onDelete?()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) { confirmingDeletion = false }
                    } message: {
                        Text("This action cannot be undone.")
                    }
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    handleSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(minWidth: 440)
        .onAppear {
            descriptionFocused = true
        }
    }

    private func toggle(tag: TagRow) {
        if selectedTags.contains(tag.id) {
            selectedTags.remove(tag.id)
        } else {
            selectedTags.insert(tag.id)
        }
    }

    private func handleSave() {
        guard canSave else { return }
        let tags = Array(selectedTags).sorted()
        let resolvedRepeat = isRepeating ? repeatFrequency : nil
        let resolvedCompletion = isRepeating ? false : isCompleted
        onSave(trimmedDescription,
               priority,
               dueDate,
               column,
               tags,
               resolvedCompletion,
               resolvedRepeat)
        dismiss()
    }
}

private struct KanbanTodoCard: View {
    let todo: KanbanTodo
    let tagLookup: [Int: TagRow]
    let fontSize: KanbanFontSize
    let palette: KanbanColumnPalette
    var onToggleCompletion: (Bool) -> Void
    var onDoubleTap: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    private enum DueState {
        case overdue, dueToday, upcoming, none
    }

    private var dueDateString: String? {
        guard let dueDate = todo.dueDate else { return nil }
        return Self.dateFormatter.string(from: dueDate)
    }

    private var dueState: DueState {
        guard let dueDate = todo.dueDate else { return .none }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        if due < today { return .overdue }
        if due == today { return .dueToday }
        return .upcoming
    }

    private var dueDisplayText: Text {
        switch dueState {
        case .overdue:
            return Text("⚠️ ") + Text(dueDateString ?? "")
        case .dueToday, .upcoming:
            if let value = dueDateString {
                return Text(value)
            }
            fallthrough
        case .none:
            return Text("No date")
        }
    }

    private var dueColor: Color {
        switch dueState {
        case .overdue: return .red
        case .dueToday: return .blue
        case .upcoming, .none: return .secondary
        }
    }

    private var dueWeight: Font.Weight {
        switch dueState {
        case .overdue, .dueToday: return .bold
        case .upcoming, .none: return .regular
        }
    }

    private var dueStateBackgroundColor: Color? {
        switch dueState {
        case .overdue: return Color(hex: "FFE2E2")
        case .dueToday: return Color(hex: "E5F1FF")
        default: return nil
        }
    }

    private var completedColumnBackgroundColor: Color? {
        guard [.done, .archived].contains(todo.column) else { return nil }
        return Color(hex: "E9EAEF")
    }

    private var cardBackgroundColor: Color {
        completedColumnBackgroundColor ?? dueStateBackgroundColor ?? palette.cardBackground
    }

    private var tags: [TagRow] {
        todo.tagIDs.compactMap { tagLookup[$0] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(todo.description)
                        .font(fontSize.primaryFont)
                        .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                        .multilineTextAlignment(.leading)
                        .strikethrough(todo.isCompleted, color: .secondary)

                    if let frequency = todo.repeatFrequency {
                        RepeatBadge(frequency: frequency, fontSize: fontSize)
                    }
                }

                Spacer()

                Button {
                    onToggleCompletion(!todo.isCompleted)
                } label: {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(todo.isCompleted ? palette.accent : Color.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .help(todo.repeatFrequency != nil ? "Complete and reschedule" : (todo.isCompleted ? "Mark as not completed" : "Mark as completed"))
            }

            HStack(spacing: 16) {
                PriorityBadge(priority: todo.priority, fontSize: fontSize)

                Rectangle()
                    .fill(Color(hex: "D8D9E3"))
                    .frame(width: 1, height: 18)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: fontSize.secondaryPointSize - 1, weight: .medium))
                        .foregroundStyle(dueColor)
                    dueDisplayText
                        .font(fontSize.dueDateFont(weight: dueWeight))
                        .foregroundStyle(todo.isCompleted ? Color.secondary : dueColor)
                        .monospacedDigit()
                }
            }

            if !tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(tags) { tag in
                        TagBadge(tag: tag)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(palette.cardBorder, lineWidth: 0.7)
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(todo.priority.color)
                .frame(width: 56, height: 4)
                .offset(x: 20, y: 2)
        }
        .opacity(todo.isCompleted ? 0.6 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .onTapGesture(count: 2, perform: onDoubleTap)
    }

    private struct PriorityBadge: View {
        let priority: KanbanPriority
        let fontSize: KanbanFontSize

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: priority.iconName)
                    .font(.system(size: fontSize.secondaryPointSize, weight: .semibold))
                Text(priority.displayName.uppercased())
                    .font(fontSize.badgeFont)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(priority.color.opacity(0.16))
            )
            .foregroundColor(priority.color)
        }
    }

    private struct RepeatBadge: View {
        let frequency: KanbanRepeatFrequency
        let fontSize: KanbanFontSize

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: frequency.systemImageName)
                    .font(.system(size: fontSize.secondaryPointSize, weight: .semibold))
                Text(frequency.displayName)
                    .font(fontSize.secondaryFont)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.1))
            )
            .foregroundColor(Color.accentColor)
            .help("Repeats \(frequency.displayName)")
        }
    }
}

private struct TodoDueBadge: View {
    let count: Int

    private var displayText: String {
        count > 99 ? "99+" : "\(count)"
    }

    private var accessibilityCountText: String {
        count > 99 ? "99 or more" : "\(count)"
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.red)
            )
            .accessibilityLabel("\(accessibilityCountText) to-dos due soon")
    }
}

private struct KanbanColumnDropDelegate: DropDelegate {
    let column: KanbanColumn
    let viewModel: KanbanBoardViewModel
    @Binding var draggedTodoID: UUID?

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        guard let dragged = draggedTodoID else { return false }
        viewModel.move(id: dragged, to: column, before: nil)
        draggedTodoID = nil
        return true
    }
}

private struct KanbanCardDropDelegate: DropDelegate {
    let target: KanbanTodo
    let column: KanbanColumn
    let viewModel: KanbanBoardViewModel
    @Binding var draggedTodoID: UUID?

    func dropEntered(info _: DropInfo) {
        guard let dragged = draggedTodoID, dragged != target.id else { return }
        viewModel.move(id: dragged, to: column, before: target.id)
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        draggedTodoID = nil
        return true
    }
}

struct TodoKanbanBoardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = KanbanBoardViewModel()
    @State private var availableTags: [TagRow] = []
    @State private var isPresentingNewTodo = false
    @State private var newTodoPrefill: KanbanTodoQuickAddRequest? = nil
    @State private var editingTodo: KanbanTodo?
    @State private var draggedTodoID: UUID?
    @State private var selectedFontSize: KanbanFontSize = .medium
    @State private var sortMode: KanbanSortMode = .dueDate
    @State private var showArchivedCompleted = true
    @State private var columnBackgroundShade: Double = 10
    @State private var isHydratingFontSize = false
    @State private var hasHydratedFontSize = false
    @State private var hasHydratedVisibleColumns = false
    @State private var hasHydratedColumnBackgroundShade = false
    @State private var visibleColumns: Set<KanbanColumn> = Set(KanbanColumn.allCases)

    private var tagLookup: [Int: TagRow] {
        Dictionary(uniqueKeysWithValues: availableTags.map { ($0.id, $0) })
    }

    private var filteredColumns: [KanbanColumn] {
        KanbanColumn.allCases.filter { visibleColumns.contains($0) }
    }

    private var hasSelection: Bool {
        !visibleColumns.isEmpty
    }

    private var columnBackgroundColor: Color {
        let normalized = max(0, min(columnBackgroundShade, 100)) / 100
        let whiteValue = 1 - normalized
        return Color(.sRGB, white: whiteValue, opacity: 1)
    }

    private var columnBorderColor: Color {
        columnBackgroundColor.opacity(0.6)
    }

    private var overdueTodos: [KanbanTodo] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.allTodos.filter { todo in
            guard !todo.isCompleted,
                  let dueDate = todo.dueDate else { return false }
            return calendar.startOfDay(for: dueDate) < today
        }
    }

    private var stats: [BoardStat] {
        let total = viewModel.allTodos.count
        let inProgress = viewModel.count(for: .doing)
        let completed = viewModel.count(for: .done)
        let overdue = overdueTodos.count
        let completionRate = total == 0 ? 0 : Double(completed) / Double(total)
        return [
            BoardStat(id: "total", title: "Total Tasks", value: "\(total)", icon: "list.bullet", accent: Color(hex: "5B6CE3")),
            BoardStat(id: "in-progress", title: "In Progress", value: "\(inProgress)", icon: "hammer", accent: KanbanColumn.doing.palette.accent),
            BoardStat(id: "completed", title: "Completed", value: "\(completed)", icon: "checkmark.circle", accent: KanbanColumn.done.palette.accent),
            BoardStat(id: "overdue", title: "Overdue", value: "\(overdue)", icon: "clock.badge.exclamationmark", accent: Color(hex: "F16063")),
            BoardStat(id: "completion", title: "Completion", value: completionRate.formattedPercentage, icon: "chart.bar", accent: Color(hex: "7C5CFF"), progress: completionRate),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if !hasSelection {
                Text("Select at least one column to show To-Dos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(filteredColumns) { column in
                            columnView(for: column)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .background(Color(hex: "F5F6FB"))
        .navigationTitle("To-Do Board")
        .onAppear {
            viewModel.refreshFromStorage()
            reloadTags()
            hydrateFontSizeIfNeeded()
            hydrateVisibleColumnsIfNeeded()
            hydrateColumnBackgroundShadeIfNeeded()
            if let pending = KanbanTodoQuickAddRouter.shared.consumePendingRequest() {
                newTodoPrefill = pending
                isPresentingNewTodo = true
            }
            if let pendingEdit = KanbanTodoEditRouter.shared.consumePendingEdit() {
                openEditor(for: pendingEdit)
            }
        }
        .alert("Cannot Archive Repeating To-Dos", isPresented: Binding(get: {
            viewModel.archiveBlockedByRepeatingTodos
        }, set: { newValue in
            if !newValue {
                viewModel.archiveBlockedByRepeatingTodos = false
            }
        })) {
            Button("OK", role: .cancel) {
                viewModel.archiveBlockedByRepeatingTodos = false
            }
        } message: {
            Text("Remove the repeat setting before archiving these items.")
        }
        .sheet(isPresented: $isPresentingNewTodo, onDismiss: { newTodoPrefill = nil }) {
            let defaultColumn = newTodoPrefill?.column ?? .backlog
            TodoEditorSheet(mode: .new(defaultColumn: defaultColumn), availableTags: availableTags, prefill: newTodoPrefill) { description, priority, date, column, tagIDs, isCompleted, repeatFrequency in
                viewModel.create(description: description,
                                 priority: priority,
                                 dueDate: date,
                                 column: column,
                                 tagIDs: tagIDs,
                                 isCompleted: isCompleted,
                                 repeatFrequency: repeatFrequency)
                isPresentingNewTodo = false
                newTodoPrefill = nil
            }
        }
        .sheet(item: $editingTodo) { todo in
            TodoEditorSheet(mode: .edit(existing: todo), availableTags: availableTags) { description, priority, date, column, tagIDs, isCompleted, repeatFrequency in
                viewModel.update(id: todo.id,
                                 description: description,
                                 priority: priority,
                                 dueDate: date,
                                 column: column,
                                 tagIDs: tagIDs,
                                 isCompleted: isCompleted,
                                 repeatFrequency: repeatFrequency)
                editingTodo = nil
            } onDelete: {
                viewModel.delete(id: todo.id)
                editingTodo = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kanbanTodoQuickAddRequested)) { output in
            guard let payload = output.object as? KanbanTodoQuickAddRequest else { return }
            let request = KanbanTodoQuickAddRouter.shared.consumePendingRequest() ?? payload
            newTodoPrefill = request
            isPresentingNewTodo = true
        }
        .onReceive(dbManager.preferences.$todoBoardFontSize) { newValue in
            handleExternalFontSizeUpdate(newValue)
        }
        .onChange(of: selectedFontSize) { _, _ in
            persistFontSize()
        }
        .onChange(of: visibleColumns) { _, _ in
            persistVisibleColumns()
        }
        .onChange(of: columnBackgroundShade) { _, _ in
            persistColumnBackgroundShade()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kanbanTodoEditRequested)) { output in
            guard let todoID = output.object as? UUID else { return }
            openEditor(for: todoID)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("get things done")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Track priorities, make progress, and celebrate wins.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                newTodoButton
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(stats) { stat in
                        BoardStatCard(stat: stat)
                    }
                }
                .padding(.vertical, 4)
            }

            configurationRow
        }
    }

    private var newTodoButton: some View {
        Button {
            isPresentingNewTodo = true
        } label: {
            Label("New To-Do", systemImage: "plus.circle.fill")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(hex: "4B5FE6"))
                )
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Color(hex: "4B5FE6").opacity(0.35), radius: 12, x: 0, y: 6)
    }

    private var fontSizeControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Font Size")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker("Font Size", selection: $selectedFontSize) {
                ForEach(KanbanFontSize.allCases, id: \.self) { size in
                    Text(size.label).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E5E7FF"), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
        .frame(width: 200, alignment: .leading)
    }

    private var backgroundShadeControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Column Background")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(max(0, min(columnBackgroundShade, 100))))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $columnBackgroundShade, in: 0 ... 100, step: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E5E7FF"), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
        .frame(width: 220, alignment: .leading)
    }

    private var configurationRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                backgroundShadeControl
                fontSizeControl
                columnSelectionMenu
                sortModeControl
            }
            .padding(.vertical, 4)
        }
    }

    private var columnSelectionMenu: some View {
        Menu {
            Section("Columns") {
                ForEach(KanbanColumn.allCases) { column in
                    let isActive = visibleColumns.contains(column)
                    Button {
                        if isActive {
                            guard visibleColumns.count > 1 else { return }
                            visibleColumns.remove(column)
                        } else {
                            visibleColumns.insert(column)
                        }
                    } label: {
                        Label(column.displayTitle, systemImage: isActive ? "checkmark.circle.fill" : "circle")
                    }
                }
            }

            Section {
                Button("Show All Columns") {
                    visibleColumns = Set(KanbanColumn.allCases)
                }
                Button("Hide Done & Archived") {
                    visibleColumns = Set(KanbanColumn.allCases.filter { ![.done, .archived].contains($0) })
                }
                Button(showArchivedCompleted ? "Hide Completed" : "Show Completed") {
                    showArchivedCompleted.toggle()
                }
            }
        } label: {
            Label("Column Selection", systemImage: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "DEE0EA"), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
                .foregroundStyle(Color(hex: "474C63"))
        }
    }

    private var sortModeControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sort Tasks")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker("Sort Tasks", selection: $sortMode) {
                ForEach(KanbanSortMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "DEE0EA"), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
        .frame(width: 220, alignment: .leading)
    }

    private func columnView(for column: KanbanColumn) -> some View {
        let items = viewModel.todos(in: column)
        let visibleItems = column == .archived && !showArchivedCompleted ? items.filter { !$0.isCompleted } : items
        let hasHiddenCompletedArchivedItems = column == .archived && !showArchivedCompleted && visibleItems.isEmpty && items.contains { $0.isCompleted }
        let containsRepeating = column == .done && items.contains { $0.isRepeating }
        let palette = column.palette
        let sortedItems = sortMode.sort(todos: visibleItems)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(column.displayTitle)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.black)
                    Text(column.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if column == .done && !items.isEmpty {
                    Button {
                        viewModel.archiveDoneTodos()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "E0E2EB"))
                            )
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                    .disabled(containsRepeating)
                    .opacity(containsRepeating ? 0.4 : 1.0)
                    .help(containsRepeating ? "Remove repeat settings before archiving." : "Move all Done items to the Archived column")
                } else if column == .archived {
                    Button {
                        showArchivedCompleted.toggle()
                    } label: {
                        Label(showArchivedCompleted ? "Hide Completed" : "Show Completed",
                              systemImage: showArchivedCompleted ? "eye.slash" : "eye")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "E0E2EB"))
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.black)
                    .help(showArchivedCompleted ? "Hide completed to-dos" : "Show completed to-dos")
                }

                Text("\(sortedItems.count)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "D9DCE8"), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color.black)
            }

            if sortedItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if hasHiddenCompletedArchivedItems {
                        Text("Completed to-dos are hidden. Use the toggle above to reveal them.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No tasks yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black)
                        Text(column.emptyPlaceholder)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 12)
            } else {
                if containsRepeating {
                    Text("Repeat-enabled tasks cannot be archived. Clear repeating before archiving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(sortedItems) { todo in
                            KanbanTodoCard(todo: todo,
                                           tagLookup: tagLookup,
                                           fontSize: selectedFontSize,
                                           palette: palette,
                                           onToggleCompletion: { newValue in
                                               viewModel.setCompletion(for: todo.id, isCompleted: newValue)
                                           },
                                           onDoubleTap: {
                                               editingTodo = todo
                                           })
                                           .onDrag {
                                               draggedTodoID = todo.id
                                               return NSItemProvider(object: todo.id.uuidString as NSString)
                                           }
                                           .onDrop(of: [UTType.text], delegate: KanbanCardDropDelegate(target: todo, column: column, viewModel: viewModel, draggedTodoID: $draggedTodoID))
                        }
                    }
                    .padding(.trailing, 2)
                    .padding(.bottom, 4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 300, alignment: .topLeading)
        .frame(minHeight: 420, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(columnBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(columnBorderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
        .onDrop(of: [UTType.text], delegate: KanbanColumnDropDelegate(column: column, viewModel: viewModel, draggedTodoID: $draggedTodoID))
    }

    private func reloadTags() {
        let repository = TagRepository(dbManager: dbManager)
        availableTags = repository.listActive()
    }

    private func hydrateFontSizeIfNeeded() {
        guard !hasHydratedFontSize else { return }
        hasHydratedFontSize = true
        isHydratingFontSize = true
        if let stored = KanbanFontSize(rawValue: dbManager.preferences.todoBoardFontSize) {
            selectedFontSize = stored
        }
        DispatchQueue.main.async {
            isHydratingFontSize = false
        }
    }

    private func handleExternalFontSizeUpdate(_ rawValue: String) {
        guard !isHydratingFontSize,
              let size = KanbanFontSize(rawValue: rawValue),
              size != selectedFontSize else { return }
        isHydratingFontSize = true
        selectedFontSize = size
        DispatchQueue.main.async {
            isHydratingFontSize = false
        }
    }

    private func persistFontSize() {
        guard !isHydratingFontSize else { return }
        guard dbManager.preferences.todoBoardFontSize != selectedFontSize.rawValue else { return }
        isHydratingFontSize = true
        dbManager.setTodoBoardFontSize(selectedFontSize.rawValue)
        DispatchQueue.main.async {
            isHydratingFontSize = false
        }
    }

    private func hydrateColumnBackgroundShadeIfNeeded() {
        guard !hasHydratedColumnBackgroundShade else { return }
        hasHydratedColumnBackgroundShade = true
        if UserDefaults.standard.object(forKey: columnBackgroundShadeDefaultsKey) != nil {
            columnBackgroundShade = UserDefaults.standard.double(forKey: columnBackgroundShadeDefaultsKey)
        } else {
            columnBackgroundShade = 10
        }
    }

    private func persistColumnBackgroundShade() {
        guard hasHydratedColumnBackgroundShade else { return }
        UserDefaults.standard.set(columnBackgroundShade, forKey: columnBackgroundShadeDefaultsKey)
    }

    private let columnBackgroundShadeDefaultsKey = "TodoBoard.columnBackgroundShade.v1"
    private let visibleColumnsDefaultsKey = "TodoBoard.visibleColumns.v1"
    private var defaultVisibleColumns: Set<KanbanColumn> { Set(KanbanColumn.allCases) }

    private func hydrateVisibleColumnsIfNeeded() {
        guard !hasHydratedVisibleColumns else { return }
        hasHydratedVisibleColumns = true
        let stored = UserDefaults.standard.array(forKey: visibleColumnsDefaultsKey) as? [String]
        let decoded = stored?.compactMap(KanbanColumn.init(rawValue:)) ?? []
        visibleColumns = decoded.isEmpty ? defaultVisibleColumns : Set(decoded)
    }

    private func persistVisibleColumns() {
        guard hasHydratedVisibleColumns else { return }
        let ordered = KanbanColumn.allCases.filter { visibleColumns.contains($0) }
        let payload = (ordered.isEmpty ? KanbanColumn.allCases : ordered).map { $0.rawValue }
        UserDefaults.standard.set(payload, forKey: visibleColumnsDefaultsKey)
    }

    private func openEditor(for todoID: UUID) {
        func setEditingIfFound() -> Bool {
            if let todo = viewModel.allTodos.first(where: { $0.id == todoID }) {
                editingTodo = todo
                return true
            }
            return false
        }

        if setEditingIfFound() { return }

        viewModel.refreshFromStorage()
        if setEditingIfFound() { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            _ = setEditingIfFound()
        }
    }
}
