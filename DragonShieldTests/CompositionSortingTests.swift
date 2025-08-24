import XCTest
@testable import DragonShield

final class CompositionSortingTests: XCTestCase {
    private func nameMap(_ id: Int) -> String {
        let map: [Int: String] = [1: "bitcoin", 2: "Ethereum", 3: "Bitcoin", 4: "Astera"]
        return map[id]!
    }

    func testInstrumentSortUsesCaseInsensitiveOrderAndResearchTiebreaker() {
        let assets = [
            PortfolioThemeAsset(themeId: 1, instrumentId: 1, researchTargetPct: 10, userTargetPct: 10, notes: nil, createdAt: "", updatedAt: ""),
            PortfolioThemeAsset(themeId: 1, instrumentId: 2, researchTargetPct: 20, userTargetPct: 20, notes: nil, createdAt: "", updatedAt: ""),
            PortfolioThemeAsset(themeId: 1, instrumentId: 3, researchTargetPct: 15, userTargetPct: 15, notes: nil, createdAt: "", updatedAt: "")
        ]
        let sorted = CompositionSorter.sort(assets, field: .instrument, ascending: true, nameProvider: nameMap)
        XCTAssertEqual(sorted.map { $0.instrumentId }, [3,1,2])
    }

    func testResearchSortDescendingTiebreaksByInstrument() {
        func names(_ id: Int) -> String {
            [1: "Beta", 2: "alpha", 3: "Gamma"][id]!
        }
        let assets = [
            PortfolioThemeAsset(themeId: 1, instrumentId: 1, researchTargetPct: 20, userTargetPct: 0, notes: nil, createdAt: "", updatedAt: ""),
            PortfolioThemeAsset(themeId: 1, instrumentId: 2, researchTargetPct: 20, userTargetPct: 0, notes: nil, createdAt: "", updatedAt: ""),
            PortfolioThemeAsset(themeId: 1, instrumentId: 3, researchTargetPct: 10, userTargetPct: 0, notes: nil, createdAt: "", updatedAt: "")
        ]
        let sorted = CompositionSorter.sort(assets, field: .researchPct, ascending: false, nameProvider: names)
        XCTAssertEqual(sorted.map { $0.instrumentId }, [2,1,3])
    }

    func testUserSortAscendingTiebreaksByInstrument() {
        func names(_ id: Int) -> String {
            [1: "Charlie", 2: "Bravo", 3: "Alpha"][id]!
        }
        let assets = [
            PortfolioThemeAsset(themeId: 1, instrumentId: 1, researchTargetPct: 0, userTargetPct: 30, notes: nil, createdAt: "", updatedAt: ""),
            PortfolioThemeAsset(themeId: 1, instrumentId: 2, researchTargetPct: 0, userTargetPct: 20, notes: nil, createdAt: "", updatedAt: ""),
            PortfolioThemeAsset(themeId: 1, instrumentId: 3, researchTargetPct: 0, userTargetPct: 20, notes: nil, createdAt: "", updatedAt: "")
        ]
        let sorted = CompositionSorter.sort(assets, field: .userPct, ascending: true, nameProvider: names)
        XCTAssertEqual(sorted.map { $0.instrumentId }, [3,2,1])
    }
}
