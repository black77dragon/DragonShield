import SwiftUI

struct TodoDashboardTile: DashboardTile {
    init() {}
    static let tileID = "todo_dashboard"
    static let tileName = "To-Do Tracker"
    static let iconName = "checklist"

    @StateObject private var viewModel = KanbanBoardViewModel()
    @Environment(\.openWindow) private var openWindow

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    private var actionableTodos: [KanbanTodo] {
        let prioritised = viewModel.todos(in: .prioritised)
        let doing = viewModel.todos(in: .doing)
        return prioritised + doing
    }

    var body: some View {
        let todos = actionableTodos
        return DashboardCard(title: Self.tileName, headerAccessory: counterAccessory(for: todos.count)) {
            if todos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("All caught up!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Nothing prioritised or in progress right now.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(todos) { todo in
                        Button {
                            openWindow(id: "todoBoard")
                        } label: {
                            TodoRow(todo: todo)
                        }
                        .buttonStyle(.plain)

                        if todo.id != todos.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.refreshFromStorage()
        }
        .accessibilityElement(children: .contain)
    }

    private func counterAccessory(for count: Int) -> AnyView? {
        guard count > 0 else { return nil }
        let badge = HStack(spacing: 6) {
            Image(systemName: "list.bullet")
                .font(.caption)
                .foregroundColor(.accentColor)
            Text("\(count)")
                .font(.caption.bold())
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.15))
        )
        return AnyView(badge)
    }

    private struct TodoRow: View {
        let todo: KanbanTodo

        private var dueDateText: String {
            TodoDashboardTile.dateFormatter.string(from: todo.dueDate)
        }

        private var dueDateColor: Color {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let due = calendar.startOfDay(for: todo.dueDate)
            if due < today {
                return .red
            }
            if due == today {
                return .orange
            }
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(due, inSameDayAs: tomorrow) {
                return .orange
            }
            return .secondary
        }

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: todo.priority.iconName)
                    .foregroundColor(todo.priority.color)
                    .font(.body)
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.description)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Text(todo.column.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(dueDateText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(dueDateColor)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
    }
}
