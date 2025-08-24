import Foundation

/// Represents an Asset SubClass option in pickers.
struct AssetSubClassOption: Equatable {
    let id: Int
    let name: String
}

/// Utility methods for sorting and filtering AssetSubClass options.
enum AssetSubClassPickerModel {
    /// Returns options sorted alphabetically by display name.
    static func sort(_ options: [AssetSubClassOption]) -> [AssetSubClassOption] {
        options.sorted {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                <
            $1.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
    }

    /// Returns options filtered by query and sorted alphabetically.
    /// - Parameters:
    ///   - options: full list of options.
    ///   - query: search term; if empty, returns the full sorted list.
    static func filter(_ options: [AssetSubClassOption], query: String) -> [AssetSubClassOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = sort(options)
        guard !trimmed.isEmpty else { return sorted }
        let needle = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return sorted.filter {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle)
        }
    }
}

