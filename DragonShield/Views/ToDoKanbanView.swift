import SwiftUI

struct ToDoKanbanView: View {
    @StateObject private var store = ToDoStore()
    @State private var showEditSheet = false
    @State private var currentItem = ToDoItem(id: UUID(), description: "", category: .personal, priority: .medium, status: .backlog)
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("To-Do Board")
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                Button {
                    currentItem = ToDoItem(id: UUID(), description: "", category: .personal, priority: .medium, status: .backlog)
                    isEditing = false
                    showEditSheet = true
                } label: {
                    Label("Add To-Do", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Add To-Do")
            }
            .padding()

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(ToDoStatus.allCases) { status in
                        KanbanColumn(status: status,
                                     items: store.items.filter { $0.status == status },
                                     onEdit: { item in
                            currentItem = item
                            isEditing = true
                            showEditSheet = true
                        },
                                     onDelete: { item in
                            store.delete(item)
                        },
                                     onDropItem: { id in
                            store.updateStatus(id: id, status: status)
                        })
                        .frame(minWidth: 200, maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showEditSheet) {
            EditToDoView(item: $currentItem) { item in
                if isEditing {
                    store.update(item)
                } else {
                    store.add(item)
                }
                showEditSheet = false
            }
            .frame(width: 400)
        }
        .onAppear { store.load() }
    }
}

private struct KanbanColumn: View {
    let status: ToDoStatus
    let items: [ToDoItem]
    let onEdit: (ToDoItem) -> Void
    let onDelete: (ToDoItem) -> Void
    let onDropItem: (UUID) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.rawValue)
                .font(.headline)
                .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        ToDoCard(item: item, onEdit: onEdit, onDelete: onDelete)
                            .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            if let provider = providers.first {
                _ = provider.loadObject(ofClass: String.self) { string, _ in
                    if let string, let id = UUID(uuidString: string) {
                        DispatchQueue.main.async {
                            onDropItem(id)
                        }
                    }
                }
                return true
            }
            return false
        }
    }
}

private struct ToDoCard: View {
    let item: ToDoItem
    let onEdit: (ToDoItem) -> Void
    let onDelete: (ToDoItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.description)
                .font(.body)
            HStack {
                Text(item.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(item.priority.rawValue)
                    .font(.caption2)
                    .foregroundColor(color(for: item.priority))
            }
        }
        .padding(8)
        .frame(minHeight: 44)
        .background(Color.white.opacity(0.9))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .contextMenu {
            Button("Edit") { onEdit(item) }
            Button(role: .destructive) { onDelete(item) } label: { Text("Delete") }
        }
        .accessibilityElement()
        .accessibilityLabel("To do \(item.description), priority \(item.priority.rawValue)")
    }

    func color(for priority: ToDoPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

private struct EditToDoView: View {
    @Binding var item: ToDoItem
    var onSave: (ToDoItem) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Description", text: $item.description)
                .textFieldStyle(.roundedBorder)
            Picker("Category", selection: $item.category) {
                ForEach(ToDoCategory.allCases) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            Picker("Priority", selection: $item.priority) {
                ForEach(ToDoPriority.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            Picker("Status", selection: $item.status) {
                ForEach(ToDoStatus.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(item)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
}

#Preview {
    ToDoKanbanView()
}
