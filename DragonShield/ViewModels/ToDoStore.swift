import Foundation
import SwiftUI

class ToDoStore: ObservableObject {
    @Published var items: [ToDoItem] = []

    private let fileURL: URL

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("todo_items.json")
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
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            save()
        }
    }

    func delete(_ item: ToDoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func updateStatus(id: UUID, status: ToDoStatus) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = status
            save()
        }
    }
}
