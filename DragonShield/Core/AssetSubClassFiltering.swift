import Foundation

struct AssetSubClassFilter {
    static func sort(_ items: [(id: Int, name: String)]) -> [(id: Int, name: String)] {
        items.sorted {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) <
            $1.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
    }

    static func filter(_ items: [(id: Int, name: String)], query: String) -> [(id: Int, name: String)] {
        guard !query.isEmpty else { return sort(items) }
        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return sort(items).filter { item in
            item.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(normalizedQuery)
        }
    }
}

