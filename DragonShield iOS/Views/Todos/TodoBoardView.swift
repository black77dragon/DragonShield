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
        let todos = viewModel.todos(in: column)
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
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(todos) { todo in
                        TodoCard(todo: todo, fontSize: selectedFontSize, tags: tags(for: todo))
                    }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(todo.description)
                .font(fontSize.primaryFont)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            HStack(spacing: 12) {
                PriorityBadge(priority: todo.priority, fontSize: fontSize)
                Spacer()
                dueDisplayText
                    .font(fontSize.dueDateFont(weight: dueWeight))
                    .foregroundStyle(dueColor)
                    .monospacedDigit()
            }

            if !tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(tags) { tag in
                        TagPill(tag: tag)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(todo.priority.color.opacity(0.3), lineWidth: 1)
        )
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
