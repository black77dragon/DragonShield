import Foundation
import SwiftUI

struct AssetSubClassItem: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
}

@MainActor
final class AssetSubClassPickerViewModel: ObservableObject {
    @Published private(set) var items: [AssetSubClassItem]
    @Published var searchText: String = ""
    @Published private(set) var filteredItems: [AssetSubClassItem] = []
    @Published var highlightedItem: AssetSubClassItem?

    private var debounceTask: Task<Void, Never>? = nil

    init(items: [AssetSubClassItem]) {
        self.items = items.sorted {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) <
            $1.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        self.filteredItems = self.items
        self.highlightedItem = self.filteredItems.first
    }

    func updateSearch(_ text: String) {
        searchText = text
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            await applyFilter()
        }
    }

    private func applyFilter() {
        let query = searchText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if query.isEmpty {
            filteredItems = items
        } else {
            filteredItems = items.filter {
                $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(query)
            }
        }
        highlightedItem = filteredItems.first
    }
}
