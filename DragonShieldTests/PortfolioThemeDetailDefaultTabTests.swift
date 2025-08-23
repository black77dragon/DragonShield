import XCTest
@testable import DragonShield

final class PortfolioThemeDetailDefaultTabTests: XCTestCase {
    func testDefaultInitialTabIsOverview() {
        let view = PortfolioThemeDetailView(themeId: 1, origin: "test")
        XCTAssertEqual(view.initialTab, .overview)
    }
}

