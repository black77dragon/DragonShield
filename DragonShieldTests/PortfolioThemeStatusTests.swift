import XCTest
@testable import DragonShield

final class PortfolioThemeStatusTests: XCTestCase {
    func testColorValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidColor("#A1B2C3"))
        XCTAssertFalse(PortfolioThemeStatus.isValidColor("#1234"))
        XCTAssertFalse(PortfolioThemeStatus.isValidColor("blue"))
    }

    func testCodeValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidCode("VALID1"))
        XCTAssertFalse(PortfolioThemeStatus.isValidCode("invalid"))
    }

    func testNameValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidName("Valid Name"))
        XCTAssertFalse(PortfolioThemeStatus.isValidName(""))
        XCTAssertFalse(PortfolioThemeStatus.isValidName(String(repeating: "a", count: 65)))
    }
}
