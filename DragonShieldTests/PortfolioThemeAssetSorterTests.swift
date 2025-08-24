import XCTest
@testable import DragonShield

final class PortfolioThemeAssetSorterTests: XCTestCase {
    private func makeAsset(id: Int, research: Double, user: Double) -> PortfolioThemeAsset {
        PortfolioThemeAsset(themeId: 1, instrumentId: id, researchTargetPct: research, userTargetPct: user, notes: nil, createdAt: "", updatedAt: "")
    }

    func testInstrumentSortIsCaseInsensitive() {
        var assets = [
            makeAsset(id: 1, research: 10, user: 10),
            makeAsset(id: 2, research: 20, user: 20),
            makeAsset(id: 3, research: 15, user: 15)
        ]
        let names = [1: "bitcoin", 2: "Astera Labs", 3: "ethereum"]
        sortThemeAssets(&assets, field: .instrument, ascending: true) { names[$0] ?? "" }
        XCTAssertEqual(assets.map { $0.instrumentId }, [2,1,3])
    }

    func testResearchSortDescendingThenInstrument() {
        var assets = [
            makeAsset(id: 1, research: 10, user: 10),
            makeAsset(id: 2, research: 10, user: 20),
            makeAsset(id: 3, research: 30, user: 15)
        ]
        let names = [1: "Bitcoin", 2: "Astera", 3: "Ethereum"]
        sortThemeAssets(&assets, field: .researchPct, ascending: false) { names[$0] ?? "" }
        XCTAssertEqual(assets.map { $0.instrumentId }, [3,2,1])
    }

    func testUserSortAscending() {
        var assets = [
            makeAsset(id: 1, research: 5, user: 5),
            makeAsset(id: 2, research: 5, user: 2),
            makeAsset(id: 3, research: 5, user: 8)
        ]
        let names = [1: "A", 2: "B", 3: "C"]
        sortThemeAssets(&assets, field: .userPct, ascending: true) { names[$0] ?? "" }
        XCTAssertEqual(assets.map { $0.instrumentId }, [2,1,3])
    }

    func testInstrumentTieBreakByResearch() {
        var assets = [
            makeAsset(id: 1, research: 20, user: 10),
            makeAsset(id: 2, research: 10, user: 10)
        ]
        let names = [1: "Alpha", 2: "Alpha"]
        sortThemeAssets(&assets, field: .instrument, ascending: true) { names[$0] ?? "" }
        XCTAssertEqual(assets.map { $0.instrumentId }, [1,2])
    }
}
