import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@MainActor
struct AssetSubClassPicker: View {
    struct Item: Identifiable, Hashable {
        let id: Int
        let name: String
    }

    let items: [Item]
    @Binding var selection: Int

    @State private var isPresented = false
    @State private var searchText = ""
    @State private var filtered: [Item] = []
    @State private var highlighted: Int?
    @FocusState private var searchFocused: Bool
    @State private var debounceWorkItem: DispatchWorkItem?

    private var sortedItems: [Item] {
        AssetSubClassPickerModel.sort(items)
    }

    var body: some View {
        Button {
            filtered = sortedItems
            highlighted = selection
            searchText = ""
            isPresented = true
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
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search…", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($searchFocused)
                        .onChange(of: searchText) { _ in
                            debounceWorkItem?.cancel()
                            let task = DispatchWorkItem { applyFilter() }
                            debounceWorkItem = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            applyFilter()
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(8)
                Divider()
                if filtered.isEmpty {
                    Text("No matches found. Clear the search to see all.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ScrollViewReader { proxy in
                        List(filtered, id: \.id, selection: $highlighted) { item in
                            Text(item.name)
                                .tag(item.id)
                                .id(item.id)
                                .onTapGesture {
                                    selection = item.id
                                    isPresented = false
                                }
                        }
                        .listStyle(PlainListStyle())
                        .frame(maxHeight: 360)
                        .onChange(of: highlighted) { newValue in
                            if let id = newValue {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                        .onAppear {
                            if let id = selection {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                    Button("") {
                        if let id = highlighted,
                           let item = filtered.first(where: { $0.id == id }) {
                            selection = item.id
                            isPresented = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                }
            }
            .frame(width: 300)
            .onAppear {
                applyFilter()
                DispatchQueue.main.async { searchFocused = true }
            }
            .onExitCommand {
                if !searchText.isEmpty {
                    searchText = ""
                    applyFilter()
                } else {
                    isPresented = false
                }
            }
        }
    }

    private func applyFilter() {
        filtered = AssetSubClassPickerModel.filter(items, query: searchText)
        if let current = filtered.first(where: { $0.id == selection })?.id {
            highlighted = current
        } else {
            highlighted = filtered.first?.id
        }
        #if canImport(AppKit)
        NSAccessibility.post(
            element: nil,
            notification: .announcement,
            userInfo: [.announcement: "\(filtered.count) results"]
        )
        #endif
    }
}

struct AssetSubClassPickerModel {
    static func sort(_ items: [AssetSubClassPicker.Item]) -> [AssetSubClassPicker.Item] {
        items.sorted {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) <
                $1.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
    }

    static func filter(_ items: [AssetSubClassPicker.Item], query: String) -> [AssetSubClassPicker.Item] {
        guard !query.isEmpty else { return sort(items) }
        let q = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return sort(items).filter {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(q)
        }
    }
}
