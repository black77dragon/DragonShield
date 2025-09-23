#if os(iOS)
import SwiftUI

struct TodoBoardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = KanbanBoardViewModel()
    @State private var tagsByID: [Int: TagRow] = [:]
    @State private var visibleColumns: Set<KanbanColumn> = [.doing, .prioritised, .backlog]

    private let columnOrder: [KanbanColumn] = [.doing, .prioritised, .backlog, .done]

    private var filteredColumns: [KanbanColumn] {
        columnOrder.filter { visibleColumns.contains($0) }
    }

    private var hasSelection: Bool {
        !visibleColumns.isEmpty
    }

    var body: some View {
        List {
            if !hasSelection {
                Text("Select at least one pillar to show To-Dos.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                ForEach(filteredColumns) { column in
                    let todos = viewModel.todos(in: column)
                    Section(header: Header(column: column, count: todos.count)) {
                        if todos.isEmpty {
                            Text("No To-Dos in this pillar.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(todos) { todo in
                                TodoRow(todo: todo, tags: tags(for: todo))
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("To-Dos")
        .toolbar { toolbarContent }
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    private func refresh() async {
        await MainActor.run {
            viewModel.refreshFromStorage()
            print("[TodoBoard] Local cache count: \(viewModel.allTodos.count)")
            importSnapshotTodosIfAvailable()
            reloadTags()
        }
    }

    private func reloadTags() {
        let repository = TagRepository(dbManager: dbManager)
        tagsByID = Dictionary(uniqueKeysWithValues: repository.listActive().map { ($0.id, $0) })
    }

    private func tags(for todo: KanbanTodo) -> [TagRow] {
        todo.tagIDs.compactMap { tagsByID[$0] }
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
                Section("Pillars") {
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
                        visibleColumns = Set(columnOrder.filter { $0 != .done })
                    }
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private struct Header: View {
        let column: KanbanColumn
        let count: Int

        var body: some View {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: column.iconName)
                    .foregroundStyle(column.accentColor)
                Text(column.title)
                    .font(.headline)
                Spacer()
                Text("\(count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .textCase(.none)
        }
    }

    private struct TodoRow: View {
        let todo: KanbanTodo
        let tags: [TagRow]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(todo.description)
                    .font(.headline)
                HStack(spacing: 12) {
                    PriorityBadge(priority: todo.priority)
                    Spacer()
                    Text(todo.dueDate, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(tags) { tag in
                            TagPill(tag: tag)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private struct PriorityBadge: View {
        let priority: KanbanPriority

        var body: some View {
            Label(priority.displayName, systemImage: priority.iconName)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(priority.color.opacity(0.15), in: Capsule())
                .foregroundStyle(priority.color)
        }
    }

    private struct TagPill: View {
        let tag: TagRow

        var body: some View {
            Text("#\(tag.displayName)")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(backgroundColor, in: Capsule())
                .foregroundStyle(foregroundColor)
        }

        private var backgroundColor: Color {
            guard let hex = tag.color, !hex.isEmpty else { return Color.gray.opacity(0.2) }
            return Color(hex: hex).opacity(0.18)
        }

        private var foregroundColor: Color {
            guard let hex = tag.color, !hex.isEmpty else { return .primary }
            return Color.textColor(forHex: hex)
        }
    }
}
#endif
