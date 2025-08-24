import SwiftUI
import Combine

@MainActor
final class AssetSubClassPickerViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var results: [(id: Int, name: String)]
    private(set) var allGroups: [(id: Int, name: String)]
    private var cancellables: Set<AnyCancellable> = []

    init(groups: [(id: Int, name: String)]) {
        allGroups = Self.sort(groups)
        results = allGroups
        $searchText
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] term in
                guard let self = self else { return }
                self.results = Self.filter(self.allGroups, query: term)
            }
            .store(in: &cancellables)
    }

    func updateGroups(_ groups: [(id: Int, name: String)]) {
        allGroups = Self.sort(groups)
        results = Self.filter(allGroups, query: searchText)
    }

    func name(for id: Int) -> String? {
        allGroups.first { $0.id == id }?.name
    }

    func clearSearch() {
        searchText = ""
    }

    static func sort(_ groups: [(id: Int, name: String)]) -> [(id: Int, name: String)] {
        groups.sorted {
            $0.name.compare($1.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedAscending
        }
    }

    static func filter(_ groups: [(id: Int, name: String)], query: String) -> [(id: Int, name: String)] {
        guard !query.isEmpty else { return groups }
        return groups.filter {
            $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
