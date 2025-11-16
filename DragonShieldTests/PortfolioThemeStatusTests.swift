@testable import DragonShield
import XCTest

final class PortfolioThemeStatusTests: XCTestCase {
    func testColorValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidColor("#A1B2C3"))
        XCTAssertFalse(PortfolioThemeStatus.isValidColor("#1234"))
        XCTAssertFalse(PortfolioThemeStatus.isValidColor("blue"))
    }

    func testCodeValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidCode("CODE1"))
        XCTAssertTrue(PortfolioThemeStatus.isValidCode("CODE_1"))
        XCTAssertFalse(PortfolioThemeStatus.isValidCode("T"))
        XCTAssertFalse(PortfolioThemeStatus.isValidCode("TOO_LONG_CODE"))
        XCTAssertFalse(PortfolioThemeStatus.isValidCode("invalid"))
    }

    func testNameValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidName("Valid Name"))
        XCTAssertFalse(PortfolioThemeStatus.isValidName(""))
        XCTAssertFalse(PortfolioThemeStatus.isValidName("A"))
        XCTAssertFalse(PortfolioThemeStatus.isValidName(String(repeating: "a", count: 41)))
    }
}
