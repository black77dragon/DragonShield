#if os(iOS)
import SwiftUI

struct TodoBoardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = KanbanBoardViewModel()
    @State private var tagsByID: [Int: TagRow] = [:]
    @State private var visibleColumns: Set<KanbanColumn> = Set(KanbanColumn.allCases)
    @State private var selectedFontSize: KanbanFontSize = .medium
    @State private var hasHydratedFontSize = false
    @State private var isHydratingFontSize = false

    private let columnOrder = KanbanColumn.allCases

    private var filteredColumns: [KanbanColumn] {
        columnOrder.filter { visibleColumns.contains($0) }
    }

    private var hasSelection: Bool {
        !visibleColumns.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if !hasSelection {
                    Text("Select at least one column to show To-Dos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 48)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if viewModel.isEmpty {
                    emptyState
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(filteredColumns) { column in
                                columnView(for: column)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("To-Do Board")
        .toolbar { toolbarContent }
        .refreshable { await refresh() }
        .task { await refresh() }
        .onAppear { hydrateFontSizeIfNeeded() }
        .onReceive(dbManager.$todoBoardFontSize) { handleExternalFontSizeUpdate($0) }
        .onChangeCompat(of: selectedFontSize) { _ in
            persistFontSize()
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stay on top of your To-Dos")
                        .font(.title2.weight(.semibold))
                    Text("Track progress across backlog, priorities, and work in flight.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                fontSizePicker
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CounterBadge(title: "Backlog", count: viewModel.count(for: .backlog), color: KanbanColumn.backlog.accentColor)
                    CounterBadge(title: "Prioritised", count: viewModel.count(for: .prioritised), color: KanbanColumn.prioritised.accentColor)
                    CounterBadge(title: "Doing", count: viewModel.count(for: .doing), color: KanbanColumn.doing.accentColor)
                    CounterBadge(title: "Done", count: viewModel.count(for: .done), color: KanbanColumn.done.accentColor)
                    CounterBadge(title: "Archived", count: viewModel.count(for: .archived), color: KanbanColumn.archived.accentColor)
                }
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
        .frame(maxWidth: 220)
        .labelsHidden()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing scheduled yet")
                .font(.headline)
            Text("Add To-Dos from the desktop app or Quick Add to start filling the board.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func columnView(for column: KanbanColumn) -> some View {
        let todos = sortedTodos(for: column)
        let containsRepeating = column == .done && todos.contains { $0.isRepeating }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: column.iconName)
                    .font(.headline)
                    .foregroundColor(column.accentColor)
                Text(column.title)
                    .font(.headline)
                Spacer()
                if column == .done && !todos.isEmpty {
                    Button {
                        viewModel.archiveDoneTodos()
                    } label: {
                        Label("Archive Done", systemImage: "archivebox")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(KanbanColumn.archived.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(containsRepeating)
                    .opacity(containsRepeating ? 0.35 : 1.0)
                    .accessibilityHint(containsRepeating ? "Remove repeat settings before archiving." : "Move all done items to archive")
                }
                Text("\(todos.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if todos.isEmpty {
                Text(column.emptyPlaceholder)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if containsRepeating {
                        Text("Repeat-enabled tasks cannot be archived. Clear repeating before archiving.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                    }

                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(todos) { todo in
                                TodoCard(todo: todo,
                                         fontSize: selectedFontSize,
                                         tags: tags(for: todo),
                                         onToggleCompletion: { newValue in
                                    viewModel.setCompletion(for: todo.id, isCompleted: newValue)
                                })
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    .frame(maxHeight: .infinity)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 280, alignment: .topLeading)
        .frame(minHeight: 360, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(column.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func tags(for todo: KanbanTodo) -> [TagRow] {
        todo.tagIDs.compactMap { tagsByID[$0] }
    }

    private func sortedTodos(for column: KanbanColumn) -> [KanbanTodo] {
        viewModel.todos(in: column)
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (lhsDate?, rhsDate?):
                    if lhsDate != rhsDate { return lhsDate < rhsDate }
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    break
                }

                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private func refresh() async {
        await MainActor.run {
            viewModel.refreshFromStorage()
            importSnapshotTodosIfAvailable()
            reloadTags()
        }
    }

    private func reloadTags() {
        let repository = TagRepository(dbManager: dbManager)
        tagsByID = Dictionary(uniqueKeysWithValues: repository.listActive().map { ($0.id, $0) })
    }

    private func importSnapshotTodosIfAvailable() {
        guard dbManager.hasOpenConnection() else {
            print("[TodoBoard] Database not open; skipping snapshot import")
            return
        }
        guard let payload = dbManager.configurationValue(for: KanbanSnapshotConfigurationKey) else {
            print("[TodoBoard] Snapshot JSON missing from Configuration")
            return
        }
        if payload.isEmpty {
            print("[TodoBoard] Snapshot JSON empty string")
            return
        }
        guard let todos = KanbanSnapshotCodec.decode(json: payload) else {
            print("[TodoBoard] Failed to decode snapshot JSON (length=\(payload.count))")
            return
        }
        print("[TodoBoard] Imported \(todos.count) snapshot to-dos")
        viewModel.overwrite(with: todos)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Columns") {
                    ForEach(columnOrder) { column in
                        let binding = Binding(
                            get: { visibleColumns.contains(column) },
                            set: { isPresented in
                                if isPresented {
                                    visibleColumns.insert(column)
                                } else {
                                    visibleColumns.remove(column)
                                }
                            }
                        )
                        Toggle(isOn: binding) {
                            Label(column.title, systemImage: column.iconName)
                        }
                    }
                }

                Section {
                    Button("Show All") {
                        visibleColumns = Set(columnOrder)
                    }
                    Button("Hide Completed") {
                        visibleColumns = Set(columnOrder.filter { ![.done, .archived].contains($0) })
                    }
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
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

private struct TodoCard: View {
    let todo: KanbanTodo
    let fontSize: KanbanFontSize
    let tags: [TagRow]
    var onToggleCompletion: (Bool) -> Void

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

    private var urgencyBackgroundColor: Color? {
        guard [.backlog, .prioritised, .doing].contains(todo.column) else { return nil }
        switch dueState {
        case .overdue: return Color.red.opacity(0.16)
        case .dueToday: return Color.blue.opacity(0.14)
        default: return nil
        }
    }

    private var cardBackgroundColor: Color {
        urgencyBackgroundColor ?? Color(uiColor: .systemBackground)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                onToggleCompletion(!todo.isCompleted)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(todo.isCompleted ? .green : .secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? "Mark as not completed" : "Mark as completed")
            .accessibilityHint(todo.repeatFrequency != nil ? "Completing will reschedule the due date." : "")

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(todo.description)
                            .font(fontSize.primaryFont)
                            .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                            .multilineTextAlignment(.leading)
                            .strikethrough(todo.isCompleted, color: .secondary)

                        if let frequency = todo.repeatFrequency {
                            RepeatBadge(frequency: frequency, fontSize: fontSize)
                        }
                    }

                    HStack(spacing: 12) {
                        PriorityBadge(priority: todo.priority, fontSize: fontSize)
                        Spacer()
                        dueDisplayText
                            .font(fontSize.dueDateFont(weight: dueWeight))
                            .foregroundStyle(todo.isCompleted ? Color.secondary : dueColor)
                            .monospacedDigit()
                    }
                }

                if !tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(tags) { tag in
                            TagPill(tag: tag)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(todo.priority.color.opacity(0.3), lineWidth: 1)
        )
        .opacity(todo.isCompleted ? 0.65 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
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
            .foregroundColor(.accentColor)
            .accessibilityLabel("Repeats \(frequency.displayName)")
        }
    }
}

private struct TagPill: View {
    let tag: TagRow

    private var backgroundColor: Color {
        guard let hex = tag.color, !hex.isEmpty else { return Color.gray.opacity(0.2) }
        return Color(hex: hex).opacity(0.18)
    }

    private var textColor: Color {
        guard let hex = tag.color, !hex.isEmpty else { return .primary }
        return Color.textColor(forHex: hex)
    }

    var body: some View {
        Text("#\(tag.displayName)")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(textColor)
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
                .foregroundStyle(.secondary)
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

private extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform: @escaping (V) -> Void) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value, initial: false) { _, newValue in
                perform(newValue)
            }
        } else {
            self.onChange(of: value, perform: perform)
        }
    }
}
#endif
