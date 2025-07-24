import SwiftUI

// Data model for a To Do item
struct ToDoItem: Identifiable, Equatable, Codable {
    let id: UUID
    var description: String
    var category: String
    var priority: Priority
    var status: Status
}

/// Priority levels for a ToDoItem
enum Priority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var color: Color {
        switch self {
        case .low: return .success
        case .medium: return .warning
        case .high: return .error
        }
    }
}

/// Workflow status for a ToDoItem
enum Status: String, CaseIterable, Codable {
    case backlog = "Backlog"
    case prioritised = "Prioritised"
    case doing = "Doing"
    case done = "Done"
}

/// View model that stores all To Do items in memory
final class ToDoViewModel: ObservableObject {
    @Published var items: [ToDoItem] = []

    func add(description: String, category: String, priority: Priority, status: Status = .backlog) {
        let item = ToDoItem(id: UUID(), description: description, category: category, priority: priority, status: status)
        items.append(item)
    }

    func move(itemID: UUID, to status: Status) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].status = status
    }
}

struct ToDoKanbanView: View {
    @StateObject private var viewModel = ToDoViewModel()
    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: { showingAdd = true }) {
                    Label("Add To-Do", systemImage: "plus")
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
            }
            .padding(.horizontal)
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Status.allCases, id: \.self) { status in
                        KanbanColumn(status: status)
                            .frame(minWidth: 220, maxWidth: 220)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddToDoSheet(viewModel: viewModel)
        }
    }

    // Single column for a status
    @ViewBuilder
    private func KanbanColumn(status: Status) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.rawValue)
                .font(.system(size: 17, weight: .semibold))
            LazyVStack(spacing: 12) {
                ForEach(viewModel.items.filter { $0.status == status }) { item in
                    ToDoCard(item: item)
                        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.fieldGray)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted[status] ? Theme.primaryAccent : Color.clear, lineWidth: 2)
        )
        .onDrop(of: [.text], isTargeted: Binding(
            get: { isTargeted[status] },
            set: { isTargeted[status] = $0 }
        )) { providers in
            handleDrop(providers: providers, for: status)
        }
    }

    @State private var isTargeted: [Status: Bool] = [:]

    private func handleDrop(providers: [NSItemProvider], for status: Status) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { string, _ in
                    if let string, let uuid = UUID(uuidString: string) {
                        DispatchQueue.main.async {
                            viewModel.move(itemID: uuid, to: status)
                        }
                    }
                }
            }
        }
        return true
    }
}

private struct ToDoCard: View {
    let item: ToDoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.description)
                .font(.body)
                .foregroundColor(.primary)
            Text(item.category)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(item.priority.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(item.priority.color.opacity(0.15))
                .foregroundColor(item.priority.color)
                .clipShape(Capsule())
                .padding(.top, 2)
        }
        .padding(8)
        .frame(minHeight: 44, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

private struct AddToDoSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var viewModel: ToDoViewModel

    @State private var description = ""
    @State private var category = ""
    @State private var priority: Priority = .low
    @State private var status: Status = .backlog

    var body: some View {
        NavigationView {
            Form {
                TextField("Description", text: $description)
                TextField("Category", text: $category)
                Picker("Priority", selection: $priority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                Picker("Status", selection: $status) {
                    ForEach(Status.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
            }
            .navigationTitle("Add To-Do")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.add(description: description, category: category, priority: priority, status: status)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 320)
    }
}

#Preview {
    ToDoKanbanView()
}
