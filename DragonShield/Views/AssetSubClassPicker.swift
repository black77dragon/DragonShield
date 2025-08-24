import SwiftUI
import Combine
import AppKit

struct AssetSubClassPicker: View {
    let groups: [(id: Int, name: String)]
    @Binding var selectedGroupId: Int

    @State private var isPresented = false
    @State private var searchText = ""
    @State private var debouncedText = ""
    @State private var highlightedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    private let searchSubject = PassthroughSubject<String, Never>()

    private var sortedGroups: [(id: Int, name: String)] {
        AssetSubClassLookup.sort(groups)
    }

    private var filteredGroups: [(id: Int, name: String)] {
        AssetSubClassLookup.filter(sortedGroups, query: debouncedText)
    }

    var body: some View {
        Button {
            highlightedIndex = indexOfSelected()
            isPresented = true
        } label: {
            HStack {
                Text(selectedName)
                    .foregroundColor(.black)
                    .font(.system(size: 16))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search…", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFocused)
                        .onSubmit { selectHighlighted() }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(8)
                Divider()
                ScrollViewReader { proxy in
                    List(selection: Binding(get: { highlightedIndex }, set: { highlightedIndex = $0 })) {
                        if filteredGroups.isEmpty {
                            Text("No matches found. Clear the search to see all.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(0..<filteredGroups.count, id: \.self) { idx in
                                let group = filteredGroups[idx]
                                Text(group.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(highlightedIndex == idx ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .tag(idx)
                                    .onTapGesture {
                                        select(group: group)
                                    }
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                    .onAppear {
                        isSearchFocused = true
                        proxy.scrollTo(highlightedIndex, anchor: .center)
                        announceResultsCount()
                    }
                    .onChange(of: filteredGroups.count) { _, _ in
                        announceResultsCount()
                    }
                    .onChange(of: debouncedText) { _, _ in
                        if highlightedIndex >= filteredGroups.count {
                            highlightedIndex = 0
                        }
                    }
                }
            }
            .frame(width: 260)
            .onReceive(searchSubject.debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)) { value in
                debouncedText = value
            }
            .onExitCommand {
                if !searchText.isEmpty {
                    searchText = ""
                } else {
                    isPresented = false
                }
            }
            .onMoveCommand { direction in
                switch direction {
                case .up:
                    moveHighlight(-1)
                case .down:
                    moveHighlight(1)
                case .pageUp:
                    moveHighlight(-5)
                case .pageDown:
                    moveHighlight(5)
                default:
                    break
                }
            }
        }
        .onChange(of: searchText) { _, value in
            searchSubject.send(value)
        }
    }

    private var selectedName: String {
        groups.first { $0.id == selectedGroupId }?.name ?? "Select Asset SubClass"
    }

    private func indexOfSelected() -> Int {
        sortedGroups.firstIndex { $0.id == selectedGroupId } ?? 0
    }

    private func selectHighlighted() {
        guard !filteredGroups.isEmpty else { return }
        let group = filteredGroups[highlightedIndex]
        select(group: group)
    }

    private func select(group: (id: Int, name: String)) {
        selectedGroupId = group.id
        isPresented = false
    }

    private func moveHighlight(_ delta: Int) {
        guard !filteredGroups.isEmpty else { return }
        highlightedIndex = max(0, min(filteredGroups.count - 1, highlightedIndex + delta))
    }

    private func announceResultsCount() {
        let count = filteredGroups.count
        NSAccessibility.post(element: NSApp, notification: .announcementRequested, userInfo: [
            NSAccessibility.NotificationUserInfoKey.announcement: "\(count) results"
        ])
    }
}
