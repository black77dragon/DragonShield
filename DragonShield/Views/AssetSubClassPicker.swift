import SwiftUI
import AppKit

struct AssetSubClassPicker: View {
    @Binding var isPresented: Bool
    let allItems: [AssetSubClassItem]
    @Binding var selectedId: Int

    @State private var searchText = ""
    @State private var query = ""
    @State private var highlightedId: Int?
    @State private var searchTask: DispatchWorkItem?
    @FocusState private var searchFocused: Bool

    private var filteredItems: [AssetSubClassItem] {
        let base = filterAssetSubClasses(allItems, query: query)
        return sortAssetSubClasses(base)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { selectHighlighted() }
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        let task = DispatchWorkItem {
                            query = newValue
                            updateHighlight()
                        }
                        searchTask = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
                    }
                    .onExitCommand {
                        if !searchText.isEmpty {
                            searchText = ""
                        } else {
                            isPresented = false
                        }
                    }
            }
            .padding(8)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if filteredItems.isEmpty {
                            Text("No matches found. Clear the search to see all.")
                                .foregroundColor(.gray)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(filteredItems, id: \.id) { item in
                                Button {
                                    selectedId = item.id
                                    isPresented = false
                                } label: {
                                    HStack {
                                        Text(item.name)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Spacer()
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(highlightedId == item.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                }
                                .buttonStyle(.plain)
                                .id(item.id)
                            }
                        }
                    }
                }
                .frame(maxHeight: 360)
                .onAppear {
                    updateHighlight()
                    DispatchQueue.main.async {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                    searchFocused = true
                }
                .onMoveCommand { direction in
                    navigate(direction: direction, proxy: proxy)
                }
            }
        }
        .frame(width: 300)
        .onChange(of: filteredItems.count) { _, count in
            NSAccessibility.post(notification: .announcementRequested, userInfo: [NSAccessibility.NotificationUserInfoKey.announcement: "\(count) results"])
        }
    }

    private func updateHighlight() {
        let items = filteredItems
        if let idx = items.firstIndex(where: { $0.id == selectedId }) {
            highlightedId = items[idx].id
        } else {
            highlightedId = items.first?.id
        }
    }

    private func navigate(direction: MoveCommandDirection, proxy: ScrollViewProxy) {
        let items = filteredItems
        guard !items.isEmpty else { return }
        var idx = items.firstIndex { $0.id == highlightedId } ?? 0
        switch direction {
        case .up: idx = max(idx - 1, 0)
        case .down: idx = min(idx + 1, items.count - 1)
        case .pageUp: idx = max(idx - 10, 0)
        case .pageDown: idx = min(idx + 10, items.count - 1)
        default: break
        }
        highlightedId = items[idx].id
        proxy.scrollTo(highlightedId, anchor: .center)
    }

    private func selectHighlighted() {
        if let id = highlightedId {
            selectedId = id
            isPresented = false
        }
    }
}
