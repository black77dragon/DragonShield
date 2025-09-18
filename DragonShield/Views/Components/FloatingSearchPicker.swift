import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A reusable floating picker that mimics a Spotlight-style search experience.
/// The picker opens on focus, filters as you type, and lets callers customise how each
/// item is displayed while binding the selection to a generic identifier.
struct FloatingSearchPicker: View {
    struct Item: Identifiable {
        var id: AnyHashable
        var title: String
        var subtitle: String?
        var searchText: String
    }

    var title: String?
    var placeholder: String
    var items: [Item]
    @Binding var selectedId: AnyHashable?
    var showsClearButton: Bool
    var emptyStateText: String
    var coordinateSpace: CoordinateSpace
    var externalQuery: Binding<String>?
    var maxDropdownHeight: CGFloat?
    var onFieldFrameChange: ((CGRect) -> Void)?
    var onSelection: ((Item) -> Void)?
    var onClear: (() -> Void)?
    var onSubmit: ((String) -> Void)?
    var selectsFirstOnSubmit: Bool

    @State private var internalQuery: String = ""
    @State private var isDropdownVisible = false
    @State private var fieldSize: CGSize = .zero
    @State private var cachedFieldFrame: CGRect = .zero
    @State private var isHoveringDropdown = false
    @FocusState private var isFocused: Bool

    init(
        title: String? = nil,
        placeholder: String = "Search",
        items: [Item],
        selectedId: Binding<AnyHashable?>,
        showsClearButton: Bool = true,
        emptyStateText: String = "No results",
        coordinateSpace: CoordinateSpace = .global,
        query: Binding<String>? = nil,
        maxDropdownHeight: CGFloat? = nil,
        onFieldFrameChange: ((CGRect) -> Void)? = nil,
        onSelection: ((Item) -> Void)? = nil,
        onClear: (() -> Void)? = nil,
        onSubmit: ((String) -> Void)? = nil,
        selectsFirstOnSubmit: Bool = true
    ) {
        self.title = title
        self.placeholder = placeholder
        self.items = items
        self._selectedId = selectedId
        self.showsClearButton = showsClearButton
        self.emptyStateText = emptyStateText
        self.coordinateSpace = coordinateSpace
        self.externalQuery = query
        self.maxDropdownHeight = maxDropdownHeight
        self.onFieldFrameChange = onFieldFrameChange
        self.onSelection = onSelection
        self.onClear = onClear
        self.onSubmit = onSubmit
        self.selectsFirstOnSubmit = selectsFirstOnSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            ZStack(alignment: .topLeading) {
                searchField
                    .background(fieldGeometryReader)
                    .zIndex(0)
                if isDropdownVisible {
                    dropdown
                        .frame(width: fieldSize.width == .zero ? nil : fieldSize.width)
                        .offset(y: dropdownVerticalOffset)
                        .transition(
                            .opacity
                                .combined(with: .move(edge: .top))
                                .animation(.easeInOut(duration: 0.12))
                        )
                        .zIndex(10)
                }
            }
        }
        .onAppear {
            isDropdownVisible = false
            syncQueryWithSelection()
        }
        .onChange(of: selectedId) { _, _ in
            guard !isFocused else { return }
            syncQueryWithSelection()
        }
        .onChange(of: items.map { $0.id }) { _, _ in
            if !isFocused { syncQueryWithSelection() }
        }
        .onChange(of: isFocused) { _, now in
            withAnimation(.easeInOut(duration: 0.12)) {
                isDropdownVisible = now || isHoveringDropdown
            }
            if now && selectedId == nil && currentQuery.isEmpty {
                withAnimation(.easeInOut(duration: 0.12)) {
                    isDropdownVisible = true
                }
            }
        }
        .onChange(of: currentQuery) { _, _ in
            guard isFocused || isHoveringDropdown else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                isDropdownVisible = true
            }
        }
    }

    private var queryBinding: Binding<String> {
        externalQuery ?? $internalQuery
    }

    private var currentQuery: String { queryBinding.wrappedValue }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: queryBinding)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(handleSubmit)
            if showsClearButton && clearButtonVisible {
                Button(action: clearSelection) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                        .accessibilityLabel("Clear selection")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(fieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var dropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text(emptyStateText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredItems) { item in
                            let isSelected = selectedId == item.id
                            Button {
                                select(item)
                            } label: {
                                row(for: item, isSelected: isSelected)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowBackground(isSelected: isSelected))
                        }
                    }
                }
                .frame(maxHeight: dropdownHeight)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(fieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 10)
    #if os(macOS)
        .onHover { hovering in
            isHoveringDropdown = hovering
            withAnimation(.easeInOut(duration: 0.12)) {
                isDropdownVisible = hovering || isFocused
            }
        }
    #endif
    }

    private func row(for item: Item, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            if let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func rowBackground(isSelected: Bool) -> some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.18))
                    .padding(.horizontal, 6)
            } else {
                Color.clear
            }
        }
    }

    private var dropdownHeight: CGFloat {
        let rowHeight: CGFloat = 36
        let minHeight: CGFloat = 180
        let maxHeight: CGFloat = 320
        let natural = min(
            max(CGFloat(filteredItems.count) * rowHeight, minHeight),
            maxHeight
        )
        if let override = maxDropdownHeight {
            return min(natural, max(0, override))
        }
        return natural
    }

    private var dropdownVerticalOffset: CGFloat {
        let defaultFieldHeight: CGFloat = 44
        let gap: CGFloat = 6
        let baseline = fieldSize.height > 0 ? fieldSize.height : defaultFieldHeight
        return baseline + gap
    }

    private var filteredItems: [Item] {
        let trimmed = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let needle = normalize(trimmed)
        return items.filter { item in
            normalize(item.searchText).contains(needle)
        }
    }

    private func normalize(_ string: String) -> String {
        string
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private var fieldBackground: Color {
        #if os(macOS)
        return Color(nsColor: NSColor.textBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }

    private var clearButtonVisible: Bool {
        !currentQuery.isEmpty || selectedId != nil
    }

    private func clearSelection() {
        queryBinding.wrappedValue = ""
        selectedId = nil
        withAnimation(.easeInOut(duration: 0.12)) {
            isDropdownVisible = true
        }
        onClear?()
        isFocused = true
    }

    private func select(_ item: Item) {
        selectedId = item.id
        queryBinding.wrappedValue = item.title
        isFocused = false
        withAnimation(.easeInOut(duration: 0.12)) {
            isDropdownVisible = false
        }
        onSelection?(item)
    }

    private func handleSubmit() {
        if selectsFirstOnSubmit {
            selectFirstResultIfPossible()
        }
        onSubmit?(currentQuery)
    }

    private func selectFirstResultIfPossible() {
        guard let first = filteredItems.first else { return }
        select(first)
    }

    private func syncQueryWithSelection() {
        guard let id = selectedId,
              let match = items.first(where: { $0.id == id }) else {
            queryBinding.wrappedValue = ""
            return
        }
        queryBinding.wrappedValue = match.title
    }

    private var fieldGeometryReader: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let frame = proxy.frame(in: coordinateSpace)
            DispatchQueue.main.async {
                updateFieldGeometry(size: size, frame: frame)
            }
            return Color.clear
        }
        .frame(width: 0, height: 0)
    }

    private func updateFieldGeometry(size: CGSize, frame: CGRect) {
        if fieldSize != size {
            fieldSize = size
        }
        if cachedFieldFrame != frame {
            cachedFieldFrame = frame
            onFieldFrameChange?(frame)
        }
    }
}
