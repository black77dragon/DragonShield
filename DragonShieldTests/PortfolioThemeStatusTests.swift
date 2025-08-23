import XCTest
@testable import DragonShield

final class PortfolioThemeStatusTests: XCTestCase {
    func testColorValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidColor("#A1B2C3"))
        XCTAssertFalse(PortfolioThemeStatus.isValidColor("#1234"))
        XCTAssertFalse(PortfolioThemeStatus.isValidColor("blue"))
    }

    func testCodeValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidCode("AA"))
        XCTAssertTrue(PortfolioThemeStatus.isValidCode("CODE_1"))
        XCTAssertFalse(PortfolioThemeStatus.isValidCode("A"))
        XCTAssertFalse(PortfolioThemeStatus.isValidCode("invalid"))
    }

    func testNameValidation() {
        XCTAssertTrue(PortfolioThemeStatus.isValidName("Valid Name"))
        XCTAssertFalse(PortfolioThemeStatus.isValidName("A"))
        XCTAssertFalse(PortfolioThemeStatus.isValidName(String(repeating: "a", count: 41)))
    }
}
