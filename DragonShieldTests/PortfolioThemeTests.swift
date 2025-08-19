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

    func testCreateThemePersists() {
        let manager = DatabaseManager()
        let before = manager.fetchPortfolioThemes().count
        let theme = manager.createPortfolioTheme(name: "Test Theme", code: "TEST_THEME")
        XCTAssertNotNil(theme)
        let after = manager.fetchPortfolioThemes().count
        XCTAssertEqual(after, before + 1)
        if let id = theme?.id {
            _ = manager.softDeletePortfolioTheme(id: id)
        }
    }
}
