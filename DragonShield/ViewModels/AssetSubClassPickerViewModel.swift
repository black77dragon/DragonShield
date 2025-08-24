import SwiftUI
import Combine

@MainActor
final class AssetSubClassPickerViewModel: ObservableObject {
    struct SubClass: Identifiable, Equatable {
        let id: Int
        let name: String
    }

    @Published var searchText: String = ""
    @Published private(set) var filtered: [SubClass] = []
    @Published var highlightedIndex: Int = 0

    private let all: [SubClass]
    private var cancellables: Set<AnyCancellable> = []

    init(subClasses: [SubClass]) {
        self.all = subClasses
        filtered = Self.sort(subClasses)
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] term in
                self?.applyFilter(term: term)
            }
            .store(in: &cancellables)
    }

    func displayName(for id: Int) -> String? {
        all.first { $0.id == id }?.name
    }

    func indexOf(id: Int) -> Int? {
        filtered.firstIndex { $0.id == id }
    }

    func ensureHighlightWithinBounds() {
        if highlightedIndex >= filtered.count {
            highlightedIndex = max(filtered.count - 1, 0)
        }
    }

    private func applyFilter(term: String) {
        if term.isEmpty {
            filtered = Self.sort(all)
        } else {
            let folded = term.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            filtered = Self.sort(
                all.filter {
                    $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        .contains(folded)
                }
            )
        }
        highlightedIndex = 0
    }

    private static func sort(_ list: [SubClass]) -> [SubClass] {
        list.sorted {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                < $1.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
    }
}

