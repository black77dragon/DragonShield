import Foundation

/// Represents an asset sub-class item used by pickers.
struct AssetSubClassItem: Identifiable, Equatable {
    let id: Int
    let name: String
}

/// Provides sorting and filtering utilities for asset sub-classes.
enum AssetSubClassFilter {
    /// Returns items sorted alphabetically by display name using case- and diacritic-insensitive compare.
    static func sort(_ items: [AssetSubClassItem]) -> [AssetSubClassItem] {
        items.sorted {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                < $1.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
    }

    /// Filters items whose names contain the query, applying the same normalization as sorting.
    static func filter(_ items: [AssetSubClassItem], query: String) -> [AssetSubClassItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sort(items) }
        let foldedQuery = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return sort(items).filter {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(foldedQuery)
        }
    }
}

