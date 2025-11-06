import Foundation

enum KanbanSortMode: String, CaseIterable, Identifiable {
    case dueDate
    case priority
    case priorityThenDueDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dueDate: return "Due Date"
        case .priority: return "Priority"
        case .priorityThenDueDate: return "Priority + Date"
        }
    }

    func sort(todos: [KanbanTodo]) -> [KanbanTodo] {
        switch self {
        case .dueDate:
            return todos.sorted { lhs, rhs in
                Self.dueDateKey(for: lhs) < Self.dueDateKey(for: rhs)
            }
        case .priority:
            return todos.sorted { lhs, rhs in
                if lhs.priority.sortRank != rhs.priority.sortRank {
                    return lhs.priority.sortRank < rhs.priority.sortRank
                }
                return Self.defaultKey(for: lhs) < Self.defaultKey(for: rhs)
            }
        case .priorityThenDueDate:
            return todos.sorted { lhs, rhs in
                if lhs.priority.sortRank != rhs.priority.sortRank {
                    return lhs.priority.sortRank < rhs.priority.sortRank
                }
                return Self.dueDateKey(for: lhs) < Self.dueDateKey(for: rhs)
            }
        }
    }

    private static func dueDateKey(for todo: KanbanTodo) -> (Int, Date, Double, Date, String) {
        let hasNoDate = todo.dueDate == nil
        return (
            hasNoDate ? 1 : 0,
            todo.dueDate ?? .distantFuture,
            todo.sortOrder,
            todo.createdAt,
            todo.id.uuidString
        )
    }

    private static func defaultKey(for todo: KanbanTodo) -> (Double, Date, String) {
        (todo.sortOrder, todo.createdAt, todo.id.uuidString)
    }
}
