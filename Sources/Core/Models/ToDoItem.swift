import Foundation

public struct ToDoItem: Identifiable, Codable {
    public enum Category: String, CaseIterable, Codable {
        case general = "General"
        case finance = "Finance"
        case development = "Development"
    }

    public enum Priority: String, CaseIterable, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }

    public enum Status: String, CaseIterable, Codable {
        case backlog = "Backlog"
        case prioritised = "Prioritised"
        case doing = "Doing"
        case done = "Done"
    }

    public var id: UUID
    public var description: String
    public var category: Category
    public var priority: Priority
    public var status: Status

    public init(id: UUID, description: String, category: Category, priority: Priority, status: Status) {
        self.id = id
        self.description = description
        self.category = category
        self.priority = priority
        self.status = status
    }
}
