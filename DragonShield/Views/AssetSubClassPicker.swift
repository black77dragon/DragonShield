import SwiftUI
import Combine

struct AssetSubClassPicker: View {
    let groups: [(id: Int, name: String)]
    @Binding var selection: Int

    @State private var isPresented = false
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var highlightedId: Int?

    private let debounceInterval = 0.15

    private var filteredGroups: [(id: Int, name: String)] {
        AssetSubClassFilter.filter(groups, query: debouncedSearch)
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack {
                Text(groups.first(where: { $0.id == selection })?.name ?? "Select Asset SubClass")
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
                        .foregroundColor(.gray)
                    TextField("Search…", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit { selectHighlighted() }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(8)
                Divider()
                ScrollViewReader { proxy in
                    List {
                        ForEach(filteredGroups, id: \.id) { group in
                            Text(group.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .background(highlightedId == group.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                .id(group.id)
                                .onTapGesture {
                                    selection = group.id
                                    isPresented = false
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .frame(maxHeight: 360)
                    .onAppear {
                        highlightedId = selection
                        DispatchQueue.main.async {
                            proxy.scrollTo(selection, anchor: .center)
                        }
                    }
                    .onChange(of: filteredGroups) { _ in
                        highlightedId = filteredGroups.first?.id
                    }
                    .onMoveCommand { direction in
                        guard !filteredGroups.isEmpty else { return }
                        switch direction {
                        case .down:
                            moveHighlight(by: 1)
                        case .up:
                            moveHighlight(by: -1)
                        case .pageDown:
                            moveHighlight(by: 5)
                        case .pageUp:
                            moveHighlight(by: -5)
                        default:
                            break
                        }
                        if let id = highlightedId {
                            withAnimation { proxy.scrollTo(id, anchor: .center) }
                        }
                    }
                }
                if filteredGroups.isEmpty {
                    Text("No matches found. Clear the search to see all.")
                        .foregroundColor(.gray)
                        .padding(8)
                } else {
                    Text("\(filteredGroups.count) results")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .accessibilityLabel("\(filteredGroups.count) results")
                        .padding(4)
                }
            }
            .frame(width: 300)
            .onExitCommand {
                if !searchText.isEmpty {
                    searchText = ""
                } else {
                    isPresented = false
                }
            }
        }
        .onReceive(Just(searchText).debounce(for: .milliseconds(Int(debounceInterval * 1000)), scheduler: RunLoop.main)) { value in
            debouncedSearch = value
        }
    }

    private func moveHighlight(by offset: Int) {
        guard let current = highlightedId, let currentIndex = filteredGroups.firstIndex(where: { $0.id == current }) else {
            highlightedId = filteredGroups.first?.id
            return
        }
        let newIndex = max(0, min(filteredGroups.count - 1, currentIndex + offset))
        highlightedId = filteredGroups[newIndex].id
    }

    private func selectHighlighted() {
        if let id = highlightedId {
            selection = id
            isPresented = false
        }
    }
}

