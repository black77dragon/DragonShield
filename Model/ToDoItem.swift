import Foundation

struct ToDoItem: Identifiable, Codable {
    enum Category: String, CaseIterable, Codable {
        case general = "General"
        case finance = "Finance"
        case development = "Development"
    }

    enum Priority: String, CaseIterable, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }

    enum Status: String, CaseIterable, Codable {
        case backlog = "Backlog"
        case prioritised = "Prioritised"
        case doing = "Doing"
        case done = "Done"
    }

    var id: UUID
    var description: String
    var category: Category
    var priority: Priority
    var status: Status
}

