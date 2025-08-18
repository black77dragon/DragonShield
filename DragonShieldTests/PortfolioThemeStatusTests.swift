import XCTest
@testable import DragonShield

final class PortfolioThemeStatusTests: XCTestCase {
    func testColorValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidColor("#A1B2C3"))
        XCTAssertFalse(PortfolioThemeStatus.isValidColor("#1234"))
        XCTAssertFalse(PortfolioThemeStatus.isValidColor("blue"))
    }
}
