import Foundation

enum ToDoCategory: String, CaseIterable, Codable, Identifiable {
    case home = "Home"
    case work = "Work"
    case finance = "Finance"
    case personal = "Personal"

    var id: String { rawValue }
}

enum ToDoPriority: String, CaseIterable, Codable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

enum ToDoStatus: String, CaseIterable, Codable, Identifiable {
    case backlog = "Backlog"
    case prioritised = "Prioritised"
    case doing = "Doing"
    case done = "Done"

    var id: String { rawValue }
}

struct ToDoItem: Identifiable, Codable {
    var id: UUID
    var description: String
    var category: ToDoCategory
    var priority: ToDoPriority
    var status: ToDoStatus

    init(id: UUID = UUID(), description: String, category: ToDoCategory, priority: ToDoPriority, status: ToDoStatus = .backlog) {
        self.id = id
        self.description = description
        self.category = category
        self.priority = priority
        self.status = status
    }
}

