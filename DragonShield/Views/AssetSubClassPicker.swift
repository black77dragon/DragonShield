import SwiftUI
import Combine
import OSLog

/// Searchable picker for choosing an asset sub-class.
struct AssetSubClassPicker: View {
    @Binding var selectedId: Int
    let items: [AssetSubClassItem]

    @State private var isPresented = false
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var highlightedId: Int?
    @FocusState private var isSearchFocused: Bool

    private let logger = Logger.ui

    var body: some View {
        Button { isPresented = true } label: {
            HStack {
                Text(displayName(for: selectedId) ?? "Select Asset SubClass")
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
                        .focused($isSearchFocused)
                        .onSubmit(selectHighlighted)
                    if !searchText.isEmpty {
                        Button("✕") { searchText = "" }
                            .buttonStyle(BorderlessButtonStyle())
                            .foregroundColor(.gray)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                Divider()

                if filteredItems.isEmpty {
                    Text("No matches found. Clear the search to see all.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ScrollViewReader { proxy in
                        List(filteredItems, id: \.id, selection: $highlightedId) { item in
                            Text(item.name)
                                .tag(item.id)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture { select(item) }
                        }
                        .listStyle(.plain)
                        .onAppear {
                            highlightedId = selectedId
                            DispatchQueue.main.async {
                                if let id = highlightedId {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                                isSearchFocused = true
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                }
            }
            .onExitCommand { handleEscape() }
            .onReceive(Just(searchText).debounce(for: .milliseconds(150), scheduler: RunLoop.main)) { value in
                debouncedSearch = value
                highlightedId = filteredItems.first?.id
            }
            .frame(width: 300)
        }
    }

    private var filteredItems: [AssetSubClassItem] {
        AssetSubClassFilter.filter(items, query: debouncedSearch)
    }

    private func displayName(for id: Int) -> String? {
        items.first(where: { $0.id == id })?.name
    }

    private func select(_ item: AssetSubClassItem) {
        selectedId = item.id
        logger.debug("Selected asset sub-class: \(item.name, privacy: .public)")
        isPresented = false
    }

    private func selectHighlighted() {
        if let id = highlightedId, let item = items.first(where: { $0.id == id }) {
            select(item)
        }
    }

    private func handleEscape() {
        if !searchText.isEmpty {
            searchText = ""
        } else {
            isPresented = false
        }
    }
}

