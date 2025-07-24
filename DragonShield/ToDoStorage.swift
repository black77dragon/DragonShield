import Foundation
import Combine

class ToDoStorage: ObservableObject {
    @Published var items: [ToDoItem] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DragonShield")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("todos.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([ToDoItem].self, from: data) {
            items = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL)
        }
    }

    func add(_ item: ToDoItem) {
        items.append(item)
        save()
    }

    func update(_ item: ToDoItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
            save()
        }
    }

    func delete(_ item: ToDoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }
}

