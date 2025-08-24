import Foundation

// Sort utilities for PortfolioThemeAsset arrays.
enum ThemeAssetSortField {
    case instrument
    case researchPct
    case userPct
}

func sortThemeAssets(
    _ assets: inout [PortfolioThemeAsset],
    field: ThemeAssetSortField,
    ascending: Bool,
    instrumentName: (Int) -> String,
    locale: Locale = .current
) {
    assets.sort { a, b in
        switch field {
        case .instrument:
            let nameA = instrumentName(a.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
            let nameB = instrumentName(b.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
            let cmp = nameA.compare(nameB, options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], range: nil, locale: locale)
            if cmp == .orderedSame {
                if a.researchTargetPct == b.researchTargetPct {
                    return ascending ? a.instrumentId < b.instrumentId : a.instrumentId > b.instrumentId
                }
                return a.researchTargetPct > b.researchTargetPct
            }
            return ascending ? cmp == .orderedAscending : cmp == .orderedDescending
        case .researchPct:
            let l = a.researchTargetPct
            let r = b.researchTargetPct
            if l == r {
                let nameA = instrumentName(a.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let nameB = instrumentName(b.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let cmp = nameA.compare(nameB, options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], range: nil, locale: locale)
                if cmp == .orderedSame {
                    return a.instrumentId < b.instrumentId
                }
                return cmp == .orderedAscending
            }
            return ascending ? l < r : l > r
        case .userPct:
            let l = a.userTargetPct
            let r = b.userTargetPct
            if l == r {
                let nameA = instrumentName(a.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let nameB = instrumentName(b.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
                let cmp = nameA.compare(nameB, options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], range: nil, locale: locale)
                if cmp == .orderedSame {
                    return a.instrumentId < b.instrumentId
                }
                return cmp == .orderedAscending
            }
            return ascending ? l < r : l > r
        }
    }
}

