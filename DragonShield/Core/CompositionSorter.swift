import Foundation

enum CompositionSortField {
    case instrument
    case researchPct
    case userPct
}

struct CompositionSorter {
    static func sort(_ assets: [PortfolioThemeAsset], field: CompositionSortField, ascending: Bool, nameProvider: (Int) -> String) -> [PortfolioThemeAsset] {
        assets.sorted { a, b in
            let nameA = nameProvider(a.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
            let nameB = nameProvider(b.instrumentId).trimmingCharacters(in: .whitespacesAndNewlines)
            switch field {
            case .instrument:
                let cmp = nameA.localizedCaseInsensitiveCompare(nameB)
                if cmp == .orderedSame {
                    if a.researchTargetPct == b.researchTargetPct {
                        return a.instrumentId < b.instrumentId
                    }
                    return a.researchTargetPct > b.researchTargetPct
                }
                return ascending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .researchPct:
                if a.researchTargetPct == b.researchTargetPct {
                    let cmp = nameA.localizedCaseInsensitiveCompare(nameB)
                    if cmp == .orderedSame {
                        return a.instrumentId < b.instrumentId
                    }
                    return cmp == .orderedAscending
                }
                return ascending ? (a.researchTargetPct < b.researchTargetPct) : (a.researchTargetPct > b.researchTargetPct)
            case .userPct:
                if a.userTargetPct == b.userTargetPct {
                    let cmp = nameA.localizedCaseInsensitiveCompare(nameB)
                    if cmp == .orderedSame {
                        return a.instrumentId < b.instrumentId
                    }
                    return cmp == .orderedAscending
                }
                return ascending ? (a.userTargetPct < b.userTargetPct) : (a.userTargetPct > b.userTargetPct)
            }
        }
    }
}

