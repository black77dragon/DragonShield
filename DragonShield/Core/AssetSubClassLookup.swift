import Foundation

struct AssetSubClassLookup {
    static func sort(_ groups: [(id: Int, name: String)], locale: Locale = .current) -> [(id: Int, name: String)] {
        groups.sorted { lhs, rhs in
            lhs.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
                < rhs.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
        }
    }

    static func filter(_ groups: [(id: Int, name: String)], query: String, locale: Locale = .current) -> [(id: Int, name: String)] {
        guard !query.isEmpty else { return sort(groups, locale: locale) }
        let foldedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
        return groups.filter { group in
            group.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
                .contains(foldedQuery)
        }.sorted { lhs, rhs in
            lhs.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
                < rhs.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
        }
    }
}
