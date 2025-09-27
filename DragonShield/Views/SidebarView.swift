// DragonShield/Views/SidebarView.swift
// MARK: - Version 1.9
// MARK: - History
// - 1.4 -> 1.5: Added "Edit Account Types" navigation link.
// - 1.5 -> 1.6: Added "Positions" navigation link.
// - 1.6 -> 1.7: Added "Edit Institutions" navigation link.
// - 1.7 -> 1.8: Added Data Import/Export view to replace the old document loader.
// - (Previous history)

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

struct SidebarView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @AppStorage("sidebar.showOverview") private var showOverview = true
    @AppStorage("sidebar.showManagement") private var showManagement = true
    @AppStorage("sidebar.showConfiguration") private var showConfiguration = true
    @AppStorage("sidebar.showStaticData") private var showStaticData = true
    @AppStorage("sidebar.showSystem") private var showSystem = true

    private var applicationStartupIconName: String {
        if #available(macOS 13.0, iOS 16.0, *) {
            return "rocket.fill"
        } else {
            return "paperplane.fill"
        }
    }

    var body: some View {
        List {
            DisclosureGroup("Overview", isExpanded: $showOverview) {
                NavigationLink(destination: DashboardView()) {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }

                NavigationLink(destination: IchimokuDragonView()) {
                    Label("Ichimoku Dragon", systemImage: "cloud.sun.rain")
                }

                NavigationLink(destination: PositionsView()) {
                    Label("Positions", systemImage: "tablecells")
                }

                NavigationLink(destination: PerformanceView()) {
                    Label("Performance", systemImage: "chart.bar.fill")
                        .foregroundColor(.gray)
                }
                .disabled(true)

                NavigationLink(destination: TodoKanbanBoardView().environmentObject(dbManager)) {
                    Label("To-Do Board", systemImage: "list.bullet.rectangle.fill")
                }
            }

            DisclosureGroup("Management", isExpanded: $showManagement) {
                NavigationLink(destination: AllocationDashboardView()) {
                    Label("Asset Allocation", systemImage: "chart.pie")
                }
                NavigationLink(destination: NewPortfoliosView().environmentObject(dbManager)) {
                    Label("New Portfolios", systemImage: "tablecells.badge.ellipsis")
                }

                NavigationLink(destination: InstrumentPricesMaintenanceView().environmentObject(dbManager)) {
                    Label("Prices", systemImage: "dollarsign.circle")
                }

                NavigationLink(destination: AlertsSettingsView().environmentObject(dbManager)) {
                    Label("Alerts & Events", systemImage: "bell")
                }

                NavigationLink(destination: TradesHistoryView().environmentObject(dbManager)) {
                    Label("Transactions", systemImage: "list.bullet.rectangle.portrait")
                }
            }

            DisclosureGroup("Configuration", isExpanded: $showConfiguration) {
                NavigationLink(destination: InstitutionsView()) {
                    Label("Institutions", systemImage: "building.2.fill")
                }

                NavigationLink(destination: CurrenciesView()) {
                    Label("Currencies & FX", systemImage: "dollarsign.circle.fill")
                }

                NavigationLink(destination: AccountsView()) {
                    Label("Accounts", systemImage: "building.columns.fill")
                }

                NavigationLink(destination: PortfolioView()) {
                    Label("Instruments", systemImage: "pencil.and.list.clipboard")
                }
            }

            DisclosureGroup("Static Data", isExpanded: $showStaticData) {
                NavigationLink(destination: ClassManagementView()) {
                    Label("Asset Classes", systemImage: "folder")
                }

                NavigationLink(destination: AccountTypesView().environmentObject(dbManager)) {
                    Label("Account Types", systemImage: "creditcard")
                }

                NavigationLink(destination: TransactionTypesView()) {
                    Label("Transaction Types", systemImage: "tag.circle.fill")
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

            DisclosureGroup("System", isExpanded: $showSystem) {
                NavigationLink(destination: ApplicationStartupView()) {
                    Label("Application Start Up", systemImage: applicationStartupIconName)
                }

                NavigationLink(destination: DataImportExportView()) {
                    Label("Data Import/Export", systemImage: "square.and.arrow.up.on.square")
                }

                NavigationLink(destination: DatabaseManagementView()) {
                    Label("Database Management", systemImage: "externaldrive.badge.timemachine")
                }


                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Dragon Shield")
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DashboardView()
        }
        .environmentObject(DatabaseManager())
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
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
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
    var onSave: (String, KanbanPriority, Date, KanbanColumn, [Int]) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var description: String
    @State private var priority: KanbanPriority
    @State private var dueDate: Date
    @State private var column: KanbanColumn
    @State private var selectedTags: Set<Int>
    @State private var confirmingDeletion = false
    @FocusState private var descriptionFocused: Bool

    init(mode: Mode, availableTags: [TagRow], prefill: KanbanTodoQuickAddRequest? = nil, onSave: @escaping (String, KanbanPriority, Date, KanbanColumn, [Int]) -> Void, onDelete: (() -> Void)? = nil) {
        self.mode = mode
        self.availableTags = availableTags
        self.onSave = onSave
        self.onDelete = onDelete

        switch mode {
        case .new(let defaultColumn):
            _description = State(initialValue: prefill?.description ?? "")
            _priority = State(initialValue: prefill?.priority ?? .medium)
            _dueDate = State(initialValue: prefill?.dueDate ?? Date())
            _column = State(initialValue: prefill?.column ?? defaultColumn)
            _selectedTags = State(initialValue: Set(prefill?.tagIDs ?? []))
        case .edit(let existing):
            _description = State(initialValue: existing.description)
            _priority = State(initialValue: existing.priority)
            _dueDate = State(initialValue: existing.dueDate)
            _column = State(initialValue: existing.column)
            _selectedTags = State(initialValue: Set(existing.tagIDs))
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
        !trimmedDescription.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))

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

            DatePicker("Date", selection: $dueDate, displayedComponents: .date)

            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.headline)
                if availableTags.isEmpty {
                    Text("No tags configured yet. Manage tags via Settings → Tags.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
        onSave(trimmedDescription, priority, dueDate, column, Array(selectedTags).sorted())
        dismiss()
    }
}

private struct KanbanTodoCard: View {
    let todo: KanbanTodo
    let tagLookup: [Int: TagRow]
    let fontSize: KanbanFontSize
    var onDoubleTap: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    private enum DueState {
        case overdue, dueToday, upcoming
    }

    private var dueDateString: String {
        Self.dateFormatter.string(from: todo.dueDate)
    }

    private var dueState: DueState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: todo.dueDate)
        if due < today { return .overdue }
        if due == today { return .dueToday }
        return .upcoming
    }

    private var dueDisplayText: Text {
        switch dueState {
        case .overdue:
            return Text("⚠️ ") + Text(dueDateString)
        case .dueToday, .upcoming:
            return Text(dueDateString)
        }
    }

    private var dueColor: Color {
        switch dueState {
        case .overdue: return .red
        case .dueToday: return .blue
        case .upcoming: return .secondary
        }
    }

    private var dueWeight: Font.Weight {
        switch dueState {
        case .overdue, .dueToday: return .bold
        case .upcoming: return .regular
        }
    }

    private var tags: [TagRow] {
        todo.tagIDs.compactMap { tagLookup[$0] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(todo.description)
                .font(fontSize.primaryFont)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 12) {
                PriorityBadge(priority: todo.priority, fontSize: fontSize)
                Spacer()
                dueDisplayText
                    .font(fontSize.dueDateFont(weight: dueWeight))
                    .foregroundColor(dueColor)
                    .monospacedDigit()
            }

            if !tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(tags) { tag in
                        TagBadge(tag: tag)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(todo.priority.color.opacity(0.35), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .onTapGesture(count: 2, perform: onDoubleTap)
    }

    private struct PriorityBadge: View {
        let priority: KanbanPriority
        let fontSize: KanbanFontSize

        var body: some View {
            Label(priority.displayName, systemImage: priority.iconName)
                .font(fontSize.badgeFont)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(priority.color.opacity(0.18))
                )
                .foregroundColor(priority.color)
        }
    }
}

private struct CounterBadge: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.headline)
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.18))
        )
    }
}

private struct KanbanColumnDropDelegate: DropDelegate {
    let column: KanbanColumn
    let viewModel: KanbanBoardViewModel
    @Binding var draggedTodoID: UUID?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
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

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedTodoID, dragged != target.id else { return }
        viewModel.move(id: dragged, to: column, before: target.id)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
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
    @State private var isHydratingFontSize = false
    @State private var hasHydratedFontSize = false

    private var tagLookup: [Int: TagRow] {
        Dictionary(uniqueKeysWithValues: availableTags.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(KanbanColumn.allCases) { column in
                        columnView(for: column)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("To-Do Board")
        .onAppear {
            viewModel.refreshFromStorage()
            reloadTags()
            hydrateFontSizeIfNeeded()
            if let pending = KanbanTodoQuickAddRouter.shared.consumePendingRequest() {
                newTodoPrefill = pending
                isPresentingNewTodo = true
            }
        }
        .sheet(isPresented: $isPresentingNewTodo, onDismiss: { newTodoPrefill = nil }) {
            let defaultColumn = newTodoPrefill?.column ?? .backlog
            TodoEditorSheet(mode: .new(defaultColumn: defaultColumn), availableTags: availableTags, prefill: newTodoPrefill) { description, priority, date, column, tagIDs in
                viewModel.create(description: description, priority: priority, dueDate: date, column: column, tagIDs: tagIDs)
                isPresentingNewTodo = false
                newTodoPrefill = nil
            }
        }
        .sheet(item: $editingTodo) { todo in
            TodoEditorSheet(mode: .edit(existing: todo), availableTags: availableTags) { description, priority, date, column, tagIDs in
                viewModel.update(id: todo.id, description: description, priority: priority, dueDate: date, column: column, tagIDs: tagIDs)
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
        .onReceive(dbManager.$todoBoardFontSize) { newValue in
            handleExternalFontSizeUpdate(newValue)
        }
        .onChange(of: selectedFontSize) { _, _ in
            persistFontSize()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                isPresentingNewTodo = true
            } label: {
                Label("New To Do", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)

            Spacer()

            fontSizePicker

            HStack(spacing: 12) {
                CounterBadge(title: "Prioritised", count: viewModel.count(for: .prioritised), color: KanbanColumn.prioritised.accentColor)
                CounterBadge(title: "Doing", count: viewModel.count(for: .doing), color: KanbanColumn.doing.accentColor)
                CounterBadge(title: "Done", count: viewModel.count(for: .done), color: KanbanColumn.done.accentColor)
            }
        }
    }

    private var fontSizePicker: some View {
        Picker("Font Size", selection: $selectedFontSize) {
            ForEach(KanbanFontSize.allCases, id: \.self) { size in
                Text(size.label).tag(size)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
        .labelsHidden()
    }

    private func columnView(for column: KanbanColumn) -> some View {
        let items = viewModel.todos(in: column)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: column.iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(column.accentColor)
                Text(column.title)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(items.count, format: .number)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if items.isEmpty {
                Text(column.emptyPlaceholder)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(items) { todo in
                    KanbanTodoCard(todo: todo, tagLookup: tagLookup, fontSize: selectedFontSize) {
                        editingTodo = todo
                    }
                    .onDrag {
                        draggedTodoID = todo.id
                        return NSItemProvider(object: todo.id.uuidString as NSString)
                    }
                    .onDrop(of: [UTType.text], delegate: KanbanCardDropDelegate(target: todo, column: column, viewModel: viewModel, draggedTodoID: $draggedTodoID))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 280, alignment: .topLeading)
        .frame(minHeight: 360, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(column.accentColor.opacity(0.25), lineWidth: 1)
        )
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
        if let stored = KanbanFontSize(rawValue: dbManager.todoBoardFontSize) {
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
        guard dbManager.todoBoardFontSize != selectedFontSize.rawValue else { return }
        isHydratingFontSize = true
        dbManager.setTodoBoardFontSize(selectedFontSize.rawValue)
        DispatchQueue.main.async {
            isHydratingFontSize = false
        }
    }
}
