import SwiftUI

struct TodoDashboardTile: DashboardTile {
    init() {}
    static let tileID = "todo_dashboard"
    static let tileName = "To-Do Tracker"
    static let iconName = "checklist"

    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = KanbanBoardViewModel()
    @Environment(\.openWindow) private var openWindow
    @State private var selectedFontSize: KanbanFontSize = .medium
    @State private var hasHydratedFontSize = false
    @State private var isHydratingFontSize = false

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
        return DashboardCard(title: Self.tileName, headerAccessory: headerAccessory(for: todos.count)) {
            if todos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("All caught up!")
                        .font(.system(size: selectedFontSize.secondaryPointSize, weight: .semibold))
                    Text("Nothing prioritised or in progress right now.")
                        .font(selectedFontSize.secondaryFont)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(todos) { todo in
                        Button {
                            openWindow(id: "todoBoard")
                        } label: {
                            TodoRow(todo: todo, fontSize: selectedFontSize)
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
            hydrateFontSizeIfNeeded()
        }
        .onReceive(dbManager.$todoBoardFontSize) { newValue in
            handleExternalFontSizeUpdate(newValue)
        }
        .onChange(of: selectedFontSize) { _, _ in
            persistFontSize()
        }
        .accessibilityElement(children: .contain)
    }

    private func headerAccessory(for count: Int) -> AnyView {
        AnyView(
            HStack(spacing: 12) {
                fontSizePicker
                if count > 0 {
                    counterBadge(count: count)
                }
            }
        )
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

    private func counterBadge(count: Int) -> some View {
        HStack(spacing: 6) {
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
    }

    private struct TodoRow: View {
        let todo: KanbanTodo
        let fontSize: KanbanFontSize

        private enum DueState {
            case overdue, dueToday, upcoming
        }

        private var dueDateText: String {
            TodoDashboardTile.dateFormatter.string(from: todo.dueDate)
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
                return Text("⚠️ ") + Text(dueDateText)
            case .dueToday, .upcoming:
                return Text(dueDateText)
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
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: todo.priority.iconName)
                    .foregroundColor(todo.priority.color)
                    .font(.system(size: fontSize.secondaryPointSize, weight: .semibold))
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.description)
                        .font(fontSize.primaryFont)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Text(todo.column.title)
                        .font(fontSize.secondaryFont)
                        .foregroundColor(.secondary)
                }
                Spacer()
                dueDisplayText
                    .font(fontSize.dueDateFont(weight: dueWeight))
                    .monospacedDigit()
                    .foregroundColor(dueColor)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
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
