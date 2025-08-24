import Foundation

enum AssetSubClassSearch {
    static func sort(_ items: [(id: Int, name: String)]) -> [(id: Int, name: String)] {
        items.sorted {
            $0.name.compare(
                $1.name,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ) == .orderedAscending
        }
    }

    static func filter(_ items: [(id: Int, name: String)], query: String) -> [(id: Int, name: String)] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }
}
