import Foundation

enum ToDoCategory: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case personal = "Personal"
    case work = "Work"
    case home = "Home"
    case errands = "Errands"
}

enum ToDoPriority: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum ToDoStatus: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case backlog = "Backlog"
    case prioritised = "Prioritised"
    case doing = "Doing"
    case done = "Done"
}

struct ToDoItem: Identifiable, Codable {
    let id: UUID
    var description: String
    var category: ToDoCategory
    var priority: ToDoPriority
    var status: ToDoStatus
}
