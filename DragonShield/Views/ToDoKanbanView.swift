import SwiftUI

struct ToDoKanbanView: View {
    @StateObject private var storage = ToDoStorage()

    @State private var showForm = false
    @State private var editingItem: ToDoItem? = nil
    @State private var dragOver: ToDoStatus? = nil

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("To-Do Board").font(.system(size: 28, weight: .bold))
                Spacer()
                Button(action: { editingItem = nil; showForm = true }) {
                    Label("Add To-Do", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add To-Do")
            }
            .padding(.bottom, 8)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(ToDoStatus.allCases) { status in
                        column(for: status)
                    }
                }
                .padding(.vertical)
            }
        }
        .padding()
        .sheet(isPresented: $showForm) {
            ToDoFormView(item: editingItem) { item in
                if let existing = editingItem {
                    var updated = item
                    updated.id = existing.id
                    storage.update(updated)
                } else {
                    storage.add(item)
                }
                showForm = false
            }
        }
    }

    private func items(for status: ToDoStatus) -> [ToDoItem] {
        storage.items.filter { $0.status == status }
    }

    private func column(for status: ToDoStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.rawValue).font(.headline)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items(for: status)) { item in
                        card(for: item)
                            .onDrag {
                                NSItemProvider(object: item.id.uuidString as NSString)
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .frame(minWidth: 200, maxWidth: .infinity, alignment: .top)
        .background(dragOver == status ? Color.accentColor.opacity(0.1) : Color.clear)
        .onDrop(of: [.text], isTargeted: nil) { providers in
            handleDrop(providers: providers, status: status)
        }
    }

    private func card(for item: ToDoItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.description)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Text(item.priority.rawValue)
                    .font(.caption)
                    .padding(4)
                    .background(priorityColor(item.priority).opacity(0.2))
                    .cornerRadius(4)
                    .foregroundColor(priorityColor(item.priority))
            }
            Text(item.category.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Button(action: { editingItem = item; showForm = true }) {
                    Image(systemName: "pencil").imageScale(.small)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Edit to-do")

                Button(role: .destructive, action: { storage.delete(item) }) {
                    Image(systemName: "trash").imageScale(.small)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete to-do")
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func priorityColor(_ p: ToDoPriority) -> Color {
        switch p {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func handleDrop(providers: [NSItemProvider], status: ToDoStatus) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: NSString.self) { string, _ in
                if let idStr = string as String?, let uuid = UUID(uuidString: idStr),
                   let idx = storage.items.firstIndex(where: { $0.id == uuid }) {
                    DispatchQueue.main.async {
                        storage.items[idx].status = status
                        storage.save()
                    }
                }
            }
        }
        return true
    }
}

private struct ToDoFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var description: String
    @State private var category: ToDoCategory
    @State private var priority: ToDoPriority
    @State private var status: ToDoStatus

    var onSave: (ToDoItem) -> Void

    init(item: ToDoItem?, onSave: @escaping (ToDoItem) -> Void) {
        _description = State(initialValue: item?.description ?? "")
        _category = State(initialValue: item?.category ?? .home)
        _priority = State(initialValue: item?.priority ?? .medium)
        _status = State(initialValue: item?.status ?? .backlog)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("To-Do").font(.title2).bold()
            TextField("Description", text: $description)
            Picker("Category", selection: $category) {
                ForEach(ToDoCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            Picker("Priority", selection: $priority) {
                ForEach(ToDoPriority.allCases) { pr in
                    Text(pr.rawValue).tag(pr)
                }
            }
            Picker("Status", selection: $status) {
                ForEach(ToDoStatus.allCases) { st in
                    Text(st.rawValue).tag(st)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let item = ToDoItem(description: description, category: category, priority: priority, status: status)
                    onSave(item)
                }
                .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 300)
    }
}

struct ToDoKanbanView_Previews: PreviewProvider {
    static var previews: some View {
        ToDoKanbanView()
    }
}

