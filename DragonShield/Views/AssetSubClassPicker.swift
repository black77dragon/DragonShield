import SwiftUI

@MainActor
struct AssetSubClassPicker: View {
    let items: [(id: Int, name: String)]
    @Binding var selection: Int
    var onSelect: (() -> Void)?

    @State private var isPresented = false
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var highlightedId: Int?
    @State private var debounceTask: Task<Void, Never>? = nil

    private var filteredItems: [(id: Int, name: String)] {
        AssetSubClassSearch.filter(items, query: debouncedSearch)
    }

    var body: some View {
        Button {
            searchText = ""
            debouncedSearch = ""
            highlightedId = selection
            isPresented.toggle()
        } label: {
            HStack {
                Text(items.first(where: { $0.id == selection })?.name ?? "Select Asset SubClass")
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
                searchBar
                Divider()
                listView
            }
            .frame(maxHeight: 360)
            .onAppear {
                highlightedId = selection
            }
        }
        .onChange(of: searchText) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                debouncedSearch = newValue
                if let first = filteredItems.first {
                    highlightedId = first.id
                } else {
                    highlightedId = nil
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(8)
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            List(selection: $highlightedId) {
                ForEach(filteredItems, id: \.id) { item in
                    Text(item.name)
                        .tag(item.id)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = item.id
                            onSelect?()
                            isPresented = false
                        }
                }
                if filteredItems.isEmpty {
                    Text("No matches found. Clear the search to see all.")
                        .foregroundColor(.gray)
                        .tag(-1)
                }
            }
            .frame(maxHeight: 300)
            .onAppear {
                if let id = highlightedId {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onChange(of: highlightedId) { _, newValue in
                if let newValue = newValue {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}
