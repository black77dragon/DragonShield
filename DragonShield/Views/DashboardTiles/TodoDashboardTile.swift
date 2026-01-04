import SwiftUI

struct TodoDashboardTile: DashboardTile {
    init() {}
    static let tileID = "todo_dashboard"
    static let tileName = "To-Do Tracker"
    static let iconName = "checklist"

    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var preferences: AppPreferences
    @StateObject private var viewModel = KanbanBoardViewModel()
    @Environment(\.openWindow) private var openWindow
    @State private var selectedFontSize: KanbanFontSize = .medium
    @State private var hasHydratedFontSize = false
    @State private var isHydratingFontSize = false
    @State private var todoRowHeight: CGFloat = 0

    private static let maxVisibleTodos = 4
    private static let todoRowSpacing: CGFloat = 8
    private static let dividerHeight: CGFloat = 1

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    @MainActor private var actionableTodos: [KanbanTodo] {
        let prioritised = viewModel.todos(in: .prioritised).filter { !$0.isCompleted }
        let doing = viewModel.todos(in: .doing).filter { !$0.isCompleted }
        let combined = prioritised + doing
        return combined.sorted(by: TodoDashboardTile.dueDateComparator)
    }

    private static let columnOrder: [KanbanColumn: Int] = [.prioritised: 0, .doing: 1]

    private static func dueDateComparator(_ lhs: KanbanTodo, _ rhs: KanbanTodo) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?) where l != r:
            return l < r
        case (nil, nil):
            break
        case (nil, _):
            return false
        case (_, nil):
            return true
        default:
            break
        }

        if lhs.priority.sortRank != rhs.priority.sortRank {
            return lhs.priority.sortRank < rhs.priority.sortRank
        }

        let lhsColumnRank = columnOrder[lhs.column] ?? Int.max
        let rhsColumnRank = columnOrder[rhs.column] ?? Int.max
        if lhsColumnRank != rhsColumnRank {
            return lhsColumnRank < rhsColumnRank
        }

        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Self.todoRowSpacing) {
                        ForEach(todos) { todo in
                            Button {
                                KanbanTodoEditRouter.shared.requestEdit(for: todo.id)
                                openWindow(id: "todoBoard")
                            } label: {
                                TodoRow(todo: todo, fontSize: selectedFontSize)
                                    .background(todoRowHeightReader)
                            }
                            .buttonStyle(.plain)

                            if todo.id != todos.last?.id {
                                Divider()
                            }
                        }
                    }
                    .onPreferenceChange(TodoRowHeightPreferenceKey.self) { newValue in
                        if newValue > 0, abs(newValue - todoRowHeight) > 0.5 {
                            todoRowHeight = newValue
                        }
                    }
                }
                .scrollIndicators(.visible)
                .frame(maxHeight: todoListMaxHeight(for: todos.count))
            }
        }
        .onAppear {
            viewModel.refreshFromStorage()
            hydrateFontSizeIfNeeded()
        }
        .onReceive(preferences.$todoBoardFontSize) { newValue in
            handleExternalFontSizeUpdate(newValue)
        }
        .onChange(of: selectedFontSize) { _, _ in
            todoRowHeight = 0
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
            case overdue, dueToday, upcoming, none
        }

        private var dueDateText: String? {
            guard let dueDate = todo.dueDate else { return nil }
            return TodoDashboardTile.dateFormatter.string(from: dueDate)
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
                return Text("⚠️ ") + Text(dueDateText ?? "")
            case .dueToday, .upcoming:
                if let text = dueDateText {
                    return Text(text)
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

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: todo.priority.iconName)
                    .foregroundColor(todo.priority.color)
                    .font(.system(size: fontSize.secondaryPointSize, weight: .semibold))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(todo.description)
                            .font(fontSize.primaryFont)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        if let frequency = todo.repeatFrequency {
                            Image(systemName: frequency.systemImageName)
                                .font(.system(size: fontSize.secondaryPointSize, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .help("Repeats \(frequency.displayName)")
                        }
                    }
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

    private struct TodoRowHeightPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    private var todoRowHeightReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: TodoRowHeightPreferenceKey.self, value: proxy.size.height)
        }
    }

    private func todoListMaxHeight(for count: Int) -> CGFloat? {
        guard count > Self.maxVisibleTodos else { return nil }
        let rowHeight = todoRowHeight > 0 ? todoRowHeight : estimatedTodoRowHeight(for: selectedFontSize)
        let dividerCount = max(0, Self.maxVisibleTodos - 1)
        let gapHeight = CGFloat(dividerCount) * (Self.todoRowSpacing * 2 + Self.dividerHeight)
        return rowHeight * CGFloat(Self.maxVisibleTodos) + gapHeight
    }

    private func estimatedTodoRowHeight(for fontSize: KanbanFontSize) -> CGFloat {
        let primaryLineHeight = fontSize.primaryPointSize * 1.2
        let secondaryLineHeight = fontSize.secondaryPointSize * 1.2
        let primaryLines: CGFloat = 2
        let lineSpacing: CGFloat = 4
        let verticalPadding: CGFloat = 8
        return primaryLineHeight * primaryLines + secondaryLineHeight + lineSpacing + verticalPadding
    }

    private func hydrateFontSizeIfNeeded() {
        guard !hasHydratedFontSize else { return }
        hasHydratedFontSize = true
        isHydratingFontSize = true
        if let stored = KanbanFontSize(rawValue: preferences.todoBoardFontSize) {
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
        guard preferences.todoBoardFontSize != selectedFontSize.rawValue else { return }
        isHydratingFontSize = true
        dbManager.setTodoBoardFontSize(selectedFontSize.rawValue)
        DispatchQueue.main.async {
            isHydratingFontSize = false
        }
    }
}
