import SwiftUI
import UniformTypeIdentifiers

struct ToDoKanbanView: View {
    @StateObject private var store = ToDoStore()

    @State private var showEditor = false
    @State private var editItem: ToDoItem?
    @State private var dragOver: ToDoItem.Status?

    private let dragType = UTType.text.identifier

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()
                Button("Add To-Do") { editItem = nil; showEditor = true }
                    .accessibilityLabel("Add To-Do")
            }
            .padding([.top, .horizontal])

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(ToDoItem.Status.allCases, id: \..self) { status in
                        column(for: status)
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showEditor) {
            ToDoEditor(store: store, item: editItem)
        }
        .onAppear { store.load() }
    }

    private func items(for status: ToDoItem.Status) -> [ToDoItem] {
        store.items.filter { $0.status == status }
    }

    private func column(for status: ToDoItem.Status) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.rawValue)
                .font(.headline)
                .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items(for: status)) { item in
                        ToDoCard(item: item, onEdit: {
                            editItem = item
                            showEditor = true
                        }, onDelete: {
                            store.delete(item)
                        })
                        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(minWidth: 200, maxWidth: .infinity)
        .background(dragOver == status ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(8)
        .onDrop(of: [dragType], delegate: DropReceiver(status: status, store: store, dragOver: $dragOver))
    }

    struct ToDoCard: View {
        let item: ToDoItem
        var onEdit: () -> Void
        var onDelete: () -> Void

        private var priorityColor: Color {
            switch item.priority {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }

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
                        .padding(4)
                        .background(priorityColor.opacity(0.2))
                        .foregroundColor(priorityColor)
                        .cornerRadius(4)
                }
                HStack {
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit To-Do")
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete To-Do")
                }
            }
            .padding()
            .frame(minHeight: 44, alignment: .topLeading)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }

    struct ToDoEditor: View {
        @Environment(\.presentationMode) private var presentationMode
        @ObservedObject var store: ToDoStore
        var item: ToDoItem?

        @State private var description: String = ""
        @State private var category: ToDoItem.Category = .general
        @State private var priority: ToDoItem.Priority = .medium
        @State private var status: ToDoItem.Status = .backlog

        init(store: ToDoStore, item: ToDoItem?) {
            self.store = store
            self.item = item
            _description = State(initialValue: item?.description ?? "")
            _category = State(initialValue: item?.category ?? .general)
            _priority = State(initialValue: item?.priority ?? .medium)
            _status = State(initialValue: item?.status ?? .backlog)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Description", text: $description)
                Picker("Category", selection: $category) {
                    ForEach(ToDoItem.Category.allCases, id: \..self) { Text($0.rawValue) }
                }
                Picker("Priority", selection: $priority) {
                    ForEach(ToDoItem.Priority.allCases, id: \..self) { Text($0.rawValue) }
                }
                Picker("Status", selection: $status) {
                    ForEach(ToDoItem.Status.allCases, id: \..self) { Text($0.rawValue) }
                }
                HStack {
                    Spacer()
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    Button("Save") {
                        let new = ToDoItem(id: item?.id ?? UUID(), description: description, category: category, priority: priority, status: status)
                        if item == nil {
                            store.add(new)
                        } else {
                            store.update(new)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
            .frame(width: 300)
        }
    }

    struct DropReceiver: DropDelegate {
        let status: ToDoItem.Status
        let store: ToDoStore
        @Binding var dragOver: ToDoItem.Status?

        func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.text]) }
        func dropEntered(info: DropInfo) { dragOver = status }
        func dropExited(info: DropInfo) { if dragOver == status { dragOver = nil } }
        func performDrop(info: DropInfo) -> Bool {
            dragOver = nil
            guard let provider = info.itemProviders(for: [.text]).first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                if let str = data as? Data, let idString = String(data: str, encoding: .utf8), let id = UUID(uuidString: idString) {
                    DispatchQueue.main.async { store.updateStatus(id: id, to: status) }
                } else if let str = data as? String, let id = UUID(uuidString: str) {
                    DispatchQueue.main.async { store.updateStatus(id: id, to: status) }
                }
            }
            return true
        }
    }
}

struct ToDoKanbanView_Previews: PreviewProvider {
    static var previews: some View {
        ToDoKanbanView()
    }
}
