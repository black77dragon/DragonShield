import SwiftUI

// Data model for a single to-do item
struct ToDoItem: Identifiable, Hashable {
    enum Priority: String, CaseIterable, Identifiable {
        case low, medium, high
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }

    enum Status: String, CaseIterable, Identifiable {
        case backlog = "Backlog"
        case prioritised = "Prioritised"
        case doing = "Doing"
        case done = "Done"
        var id: String { rawValue }
    }

    let id: UUID
    var description: String
    var category: String
    var priority: Priority
    var status: Status
}

// View model that persists items while the view lives
class ToDoViewModel: ObservableObject {
    @Published var items: [ToDoItem] = []

    func add(description: String, category: String, priority: ToDoItem.Priority, status: ToDoItem.Status = .backlog) {
        let item = ToDoItem(id: UUID(), description: description, category: category, priority: priority, status: status)
        items.append(item)
    }

    func updateStatus(for id: UUID, to status: ToDoItem.Status) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = status
        }
    }
}

struct ToDoKanbanView: View {
    @StateObject private var viewModel = ToDoViewModel()
    @State private var showAddSheet = false
    @State private var dragItem: UUID?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button("+ Add To-Do") { showAddSheet = true }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).strokeBorder())
                Spacer()
            }
            .padding([.horizontal, .top])

            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(ToDoItem.Status.allCases) { status in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(status.rawValue)
                                .font(.system(size: 17, weight: .semibold))
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.items.filter { $0.status == status }) { item in
                                    card(for: item)
                                }
                            }
                        }
                        .frame(minWidth: 220)
                        .padding()
                        .background(columnHighlight(for: status))
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            providers.first?.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
                                if let data,
                                   let idString = String(data: data as! Data, encoding: .utf8),
                                   let uuid = UUID(uuidString: idString) {
                                    DispatchQueue.main.async {
                                        viewModel.updateStatus(for: uuid, to: status)
                                    }
                                }
                            }
                            return true
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddToDoSheet { desc, cat, prio, status in
                viewModel.add(description: desc, category: cat, priority: prio, status: status)
            }
        }
    }

    private func card(for item: ToDoItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.description)
                .font(.body)
            Text(item.category)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(item.priority.rawValue.capitalized)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(item.priority.color.opacity(0.2))
                .foregroundColor(item.priority.color)
                .clipShape(Capsule())
        }
        .padding(8)
        .frame(minHeight: 44, alignment: .topLeading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onDrag {
            dragItem = item.id
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
    }

    private func columnHighlight(for status: ToDoItem.Status) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.05))
    }
}

private struct AddToDoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var category = "General"
    @State private var priority: ToDoItem.Priority = .low
    @State private var status: ToDoItem.Status = .backlog

    var onAdd: (String, String, ToDoItem.Priority, ToDoItem.Status) -> Void

    var body: some View {
        NavigationView {
            Form {
                TextField("Description", text: $description)
                TextField("Category", text: $category)
                Picker("Priority", selection: $priority) {
                    ForEach(ToDoItem.Priority.allCases) { p in
                        Text(p.rawValue.capitalized).tag(p)
                    }
                }
                Picker("Status", selection: $status) {
                    ForEach(ToDoItem.Status.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
            }
            .navigationTitle("New To-Do")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onAdd(description, category, priority, status)
                        dismiss()
                    }
                    .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct ToDoKanbanView_Previews: PreviewProvider {
    static var previews: some View {
        ToDoKanbanView()
    }
}

