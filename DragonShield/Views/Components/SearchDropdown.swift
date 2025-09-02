import SwiftUI

/// A reliable, pure-SwiftUI searchable dropdown that shows the full list on focus
/// and filters as you type. Designed to replace NSComboBox for consistent UX.
struct SearchDropdown: View {
    let items: [String]
    @Binding var text: String
    var placeholder: String = "Search…"
    var maxVisibleRows: Int = 12
    var onSelectIndex: (Int) -> Void

    @State private var isOpen: Bool = false
    @State private var hoverList: Bool = false
    @FocusState private var focused: Bool

    private var filteredIndexMap: [Int] {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return Array(items.indices) }
        return items.enumerated().compactMap { i, s in s.lowercased().contains(q) ? i : nil }
    }
    private var filteredItems: [String] { filteredIndexMap.map { items[$0] } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onChange(of: focused) { _, now in
                    // Open list when field gains focus, close when it loses focus and mouse not hovering list
                    withAnimation(.easeInOut(duration: 0.08)) {
                        isOpen = now || hoverList
                    }
                }
                .onChange(of: text) { _, _ in
                    // Keep list open while typing
                    if focused || hoverList { withAnimation(.easeInOut(duration: 0.08)) { isOpen = true } }
                }
                .onSubmit {
                    // Enter selects the first filtered item if available
                    if let first = filteredIndexMap.first { select(index: first) }
                }

            if isOpen {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filteredItems.enumerated()), id: \.0) { idx, label in
                            Button(action: {
                                let original = filteredIndexMap[idx]
                                select(index: original)
                            }) {
                                HStack {
                                    Text(label)
                                        .foregroundColor(.primary)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)
                            .background(idx % 2 == 0 ? Color.gray.opacity(0.03) : Color.clear)
                        }
                    }
                }
                .frame(maxHeight: CGFloat(max(1, min(maxVisibleRows, filteredItems.count))) * 24)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                .onHover { inside in
                    hoverList = inside
                    if !focused && !inside { withAnimation(.easeInOut(duration: 0.08)) { isOpen = false } }
                }
            }
        }
    }

    private func select(index: Int) {
        text = items[index]
        onSelectIndex(index)
        withAnimation(.easeInOut(duration: 0.08)) { isOpen = false }
    }
}

