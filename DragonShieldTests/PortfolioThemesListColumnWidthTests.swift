import XCTest
@testable import DragonShield

final class PortfolioThemesListColumnWidthTests: XCTestCase {
    @MainActor
    func testNameWidthPersists() {
        let defaults = UserDefaults.standard
        let key = UserDefaultsKeys.portfolioThemesNameWidth
        defaults.removeObject(forKey: key)
        defaults.set(210, forKey: key)
        let view = PortfolioThemesListView()
        let mirror = Mirror(reflecting: view)
        let width = mirror.descendant("nameWidthValue") as? Double
        XCTAssertEqual(width, 210)
        defaults.removeObject(forKey: key)
    }
}
