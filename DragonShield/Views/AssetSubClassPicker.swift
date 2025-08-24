import SwiftUI

struct AssetSubClassOption: Identifiable, Equatable {
    let id: Int
    let name: String
}

enum AssetSubClassPickerLogic {
    static func filteredOptions(from options: [AssetSubClassOption], query: String) -> [AssetSubClassOption] {
        let sorted = options.sorted { lhs, rhs in
            lhs.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) <
            rhs.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
        guard !query.isEmpty else { return sorted }
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return sorted.filter {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(needle)
        }
    }
}

struct AssetSubClassPicker: View {
    let options: [AssetSubClassOption]
    @Binding var selection: Int
    var placeholder = "Select Asset SubClass"
    var onSelect: () -> Void = {}

    @State private var isPresented = false
    @State private var search = ""
    @State private var debouncedSearch = ""
    @State private var highlighted: Int?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    var body: some View {
        Button(action: { isPresented = true }) {
            HStack {
                Text(options.first(where: { $0.id == selection })?.name ?? placeholder)
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
        .popover(isPresented: $isPresented) {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search…", text: $search)
                        .focused($searchFocused)
                        .onSubmit { selectHighlighted() }
                        .onExitCommand { handleEscape() }
                        .onMoveCommand { dir in handleMove(dir) }
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                    if !search.isEmpty {
                        Button(action: { search = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                Divider()
                content
            }
            .frame(width: 260, height: 360)
            .onAppear {
                search = ""
                debouncedSearch = ""
                searchFocused = true
                highlighted = selection
            }
            .onChange(of: search) { _, newValue in
                debounceSearch(newValue)
            }
        }
    }

    private var filtered: [AssetSubClassOption] {
        AssetSubClassPickerLogic.filteredOptions(from: options, query: debouncedSearch)
    }

    @ViewBuilder private var content: some View {
        if filtered.isEmpty {
            VStack {
                Spacer()
                Text("No matches found. Clear the search to see all.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
        } else {
            ScrollViewReader { proxy in
                List(selection: $highlighted) {
                    ForEach(filtered) { option in
                        Button(action: { select(option) }) {
                            Text(option.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .tag(option.id)
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    if let sel = highlighted {
                        proxy.scrollTo(sel, anchor: .center)
                    }
                }
                .onChange(of: highlighted) { _, newValue in
                    if let id = newValue {
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .onChange(of: filtered.count) { _, _ in
                    announceResults()
                    if let hi = highlighted, !filtered.contains(where: { $0.id == hi }) {
                        highlighted = filtered.first?.id
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func select(_ option: AssetSubClassOption) {
        selection = option.id
        onSelect()
        isPresented = false
    }

    private func selectHighlighted() {
        if let id = highlighted, let opt = filtered.first(where: { $0.id == id }) {
            select(opt)
        }
    }

    private func handleEscape() {
        if !search.isEmpty {
            search = ""
        } else {
            isPresented = false
        }
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        guard !filtered.isEmpty else { return }
        guard let current = highlighted, let idx = filtered.firstIndex(where: { $0.id == current }) else {
            highlighted = filtered.first?.id
            return
        }
        switch direction {
        case .down:
            let next = min(idx + 1, filtered.count - 1)
            highlighted = filtered[next].id
        case .up:
            let prev = max(idx - 1, 0)
            highlighted = filtered[prev].id
        case .pageDown:
            let next = min(idx + 10, filtered.count - 1)
            highlighted = filtered[next].id
        case .pageUp:
            let prev = max(idx - 10, 0)
            highlighted = filtered[prev].id
        default:
            break
        }
    }

    private func debounceSearch(_ text: String) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            debouncedSearch = text
            highlighted = filtered.first?.id
        }
    }

    private func announceResults() {
#if os(macOS)
        let message = "\(filtered.count) results"
        NSAccessibility.post(element: NSApp, notification: .announcementRequested, userInfo: [NSAccessibility.announcementKey: message])
#endif
    }
}
