import XCTest
@testable import DragonShield

final class PortfolioThemeTests: XCTestCase {
    func testCodeValidation() {
        XCTAssertTrue(PortfolioTheme.isValidCode("THEME_1"))
        XCTAssertFalse(PortfolioTheme.isValidCode("theme"))
    }

    func testNameValidation() {
        XCTAssertTrue(PortfolioTheme.isValidName("Core Growth"))
        XCTAssertFalse(PortfolioTheme.isValidName(""))
    }
}
