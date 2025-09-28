import Foundation
import SwiftUI
import Combine

let KanbanSnapshotConfigurationKey = "ios_snapshot_todos_json"

enum KanbanSnapshotCodec {
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encodeData(_ todos: [KanbanTodo]) -> Data? {
        try? makeEncoder().encode(todos)
    }

    static func encodeJSON(_ todos: [KanbanTodo]) -> String? {
        guard let data = encodeData(todos) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(data: Data) -> [KanbanTodo]? {
        do {
            return try makeDecoder().decode([KanbanTodo].self, from: data)
        } catch {
            print("[KanbanCodec] decode(data:) failed: \(error)")
            return nil
        }
    }

    static func decode(json: String) -> [KanbanTodo]? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        return decode(data: data)
    }
}

enum KanbanPriority: String, CaseIterable, Identifiable, Codable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var iconName: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        }
    }
}

enum KanbanColumn: String, CaseIterable, Identifiable, Codable {
    case backlog
    case prioritised
    case doing
    case done
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backlog: return "Backlog"
        case .prioritised: return "Prioritised"
        case .doing: return "Doing"
        case .done: return "Done"
        case .archived: return "Archived"
        }
    }

    var accentColor: Color {
        switch self {
        case .backlog: return Color.gray
        case .prioritised: return Color.orange
        case .doing: return Color.accentColor
        case .done: return Color.green
        case .archived: return Color.purple
        }
    }

    var iconName: String {
        switch self {
        case .backlog: return "tray"
        case .prioritised: return "flag.circle.fill"
        case .doing: return "hammer"
        case .done: return "checkmark.circle"
        case .archived: return "archivebox"
        }
    }

    var emptyPlaceholder: String {
        switch self {
        case .backlog: return "Ideas and unprioritised work land here."
        case .prioritised: return "Drag tasks here when they are next up."
        case .doing: return "Drop work in progress into this column."
        case .done: return "Completed tasks will collect here."
        case .archived: return "Archived tasks live here for reference."
        }
    }
}

struct KanbanTodo: Identifiable, Codable, Equatable {
    let id: UUID
    var description: String
    var priority: KanbanPriority
    var dueDate: Date
    var column: KanbanColumn
    var tagIDs: [Int]
    var sortOrder: Double
    var createdAt: Date

    init(id: UUID = UUID(), description: String, priority: KanbanPriority, dueDate: Date, column: KanbanColumn, tagIDs: [Int], sortOrder: Double, createdAt: Date = Date()) {
        self.id = id
        self.description = description
        self.priority = priority
        self.dueDate = dueDate
        self.column = column
        self.tagIDs = tagIDs
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case description
        case priority
        case dueDate
        case column
        case tagIDs
        case sortOrder
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        description = try container.decode(String.self, forKey: .description)
        priority = try container.decode(KanbanPriority.self, forKey: .priority)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        column = try container.decode(KanbanColumn.self, forKey: .column)
        tagIDs = try container.decodeIfPresent([Int].self, forKey: .tagIDs) ?? []
        sortOrder = try container.decodeIfPresent(Double.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(description, forKey: .description)
        try container.encode(priority, forKey: .priority)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(column, forKey: .column)
        try container.encode(tagIDs, forKey: .tagIDs)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct KanbanTodoQuickAddRequest {
    var description: String
    var priority: KanbanPriority
    var dueDate: Date
    var column: KanbanColumn
    var tagIDs: [Int]

    init(description: String,
         priority: KanbanPriority = .medium,
         dueDate: Date = Date(),
         column: KanbanColumn = .backlog,
         tagIDs: [Int] = []) {
        self.description = description
        self.priority = priority
        self.dueDate = dueDate
        self.column = column
        self.tagIDs = tagIDs
    }
}

extension Notification.Name {
    static let kanbanTodoQuickAddRequested = Notification.Name("KanbanTodoQuickAddRequested")
}

@MainActor
final class KanbanTodoQuickAddRouter {
    static let shared = KanbanTodoQuickAddRouter()

    private var pendingRequest: KanbanTodoQuickAddRequest?

    private init() {}

    func stash(_ request: KanbanTodoQuickAddRequest) {
        pendingRequest = request
    }

    func consumePendingRequest() -> KanbanTodoQuickAddRequest? {
        defer { pendingRequest = nil }
        return pendingRequest
    }
}

@MainActor
final class KanbanBoardViewModel: ObservableObject {
    @Published private(set) var todos: [KanbanTodo] = []

    private let storage: UserDefaults
    private var cancellables: Set<AnyCancellable> = []

    static let didUpdateNotification = Notification.Name("KanbanBoardViewModelDidUpdate")

    init(userDefaults: UserDefaults = .standard) {
        self.storage = userDefaults
        NotificationCenter.default.publisher(for: Self.didUpdateNotification)
            .sink { [weak self] note in
                guard let self else { return }
                if let sender = note.object as? KanbanBoardViewModel, sender === self { return }
                self.load()
            }
            .store(in: &cancellables)
        load()
    }

    var allTodos: [KanbanTodo] { todos }
    var isEmpty: Bool { todos.isEmpty }

    func todos(in column: KanbanColumn) -> [KanbanTodo] {
        todos
            .filter { $0.column == column }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    func count(for column: KanbanColumn) -> Int {
        todos.filter { $0.column == column }.count
    }

    func refreshFromStorage() {
        load()
    }

    func create(description: String, priority: KanbanPriority, dueDate: Date, column: KanbanColumn, tagIDs: [Int]) {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (todos.filter { $0.column == column }.map(\.sortOrder).max() ?? -1) + 1
        let todo = KanbanTodo(description: trimmed, priority: priority, dueDate: dueDate, column: column, tagIDs: tagIDs, sortOrder: nextOrder)
        todos.append(todo)
        normalizeSortOrders(for: column)
        save()
    }

    func update(id: UUID, description: String, priority: KanbanPriority, dueDate: Date, column: KanbanColumn, tagIDs: [Int]) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let oldColumn = todos[index].column
        todos[index].description = trimmed
        todos[index].priority = priority
        todos[index].dueDate = dueDate
        todos[index].tagIDs = tagIDs
        if oldColumn != column {
            todos[index].column = column
            let nextOrder = (todos.filter { $0.column == column && $0.id != id }.map(\.sortOrder).max() ?? -1) + 1
            todos[index].sortOrder = nextOrder
            normalizeSortOrders(for: oldColumn)
        }
        normalizeSortOrders(for: column)
        save()
    }

    func delete(id: UUID) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        let column = todos[index].column
        todos.remove(at: index)
        normalizeSortOrders(for: column)
        save()
    }

    func move(id: UUID, to column: KanbanColumn, before targetID: UUID?) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        if let targetID, targetID == id { return }
        let oldColumn = todos[index].column
        todos[index].column = column
        if let targetID, let target = todos.first(where: { $0.id == targetID }) {
            let peers = todos.filter { $0.column == column && $0.id != id }
            let predecessor = peers.filter { $0.sortOrder < target.sortOrder }.max(by: { $0.sortOrder < $1.sortOrder })
            if let predecessor {
                todos[index].sortOrder = (predecessor.sortOrder + target.sortOrder) / 2.0
            } else {
                todos[index].sortOrder = target.sortOrder - 1.0
            }
        } else {
            let maxOrder = todos.filter { $0.column == column && $0.id != id }.map(\.sortOrder).max() ?? -1
            todos[index].sortOrder = maxOrder + 1.0
        }
        normalizeSortOrders(for: column)
        if oldColumn != column {
            normalizeSortOrders(for: oldColumn)
        }
        save()
    }

    func archiveDoneTodos() {
        let doneEntries = todos.enumerated().filter { $0.element.column == .done }
        guard !doneEntries.isEmpty else { return }

        let sortedDone = doneEntries.sorted { lhs, rhs in
            if lhs.element.sortOrder == rhs.element.sortOrder {
                return lhs.element.createdAt < rhs.element.createdAt
            }
            return lhs.element.sortOrder < rhs.element.sortOrder
        }

        let startingOrder = (todos.filter { $0.column == .archived }.map(\.sortOrder).max() ?? -1) + 1
        var nextOrder = startingOrder

        for entry in sortedDone {
            todos[entry.offset].column = .archived
            todos[entry.offset].sortOrder = nextOrder
            nextOrder += 1
        }

        normalizeSortOrders(for: .done)
        normalizeSortOrders(for: .archived)
        save()
    }

    func overwrite(with newTodos: [KanbanTodo]) {
        todos = newTodos
        for column in KanbanColumn.allCases {
            normalizeSortOrders(for: column)
        }
        save()
    }

    private func normalizeSortOrders(for column: KanbanColumn) {
        let filtered = todos.enumerated()
            .filter { $0.element.column == column }
            .sorted { lhs, rhs in
                if lhs.element.sortOrder == rhs.element.sortOrder {
                    return lhs.element.createdAt < rhs.element.createdAt
                }
                return lhs.element.sortOrder < rhs.element.sortOrder
            }
        for (offset, entry) in filtered.enumerated() {
            todos[entry.offset].sortOrder = Double(offset)
        }
    }

    private func load() {
        guard let data = storage.data(forKey: UserDefaultsKeys.kanbanTodos) else {
            todos = []
            return
        }
        if let decoded = KanbanSnapshotCodec.decode(data: data) {
            todos = decoded
        } else {
            todos = []
        }
        for column in KanbanColumn.allCases {
            normalizeSortOrders(for: column)
        }
    }

    private func save() {
        guard let data = KanbanSnapshotCodec.encodeData(todos) else { return }
        storage.set(data, forKey: UserDefaultsKeys.kanbanTodos)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
    }
}
