import XCTest
import SwiftUI
@testable import DragonShield

final class PortfolioThemesListColumnWidthTests: XCTestCase {
    @MainActor
    func testNameWidthPersists() {
        let defaults = UserDefaults.standard
        let key = UserDefaultsKeys.portfolioThemesNameWidth
        defaults.removeObject(forKey: key)
        defaults.set(210.0, forKey: key)

        let view = PortfolioThemesListView()
        let mirror = Mirror(reflecting: view)
        let storage = mirror.descendant("_nameWidth") as? AppStorage<Double>
        XCTAssertEqual(storage?.wrappedValue, 210.0)

        defaults.removeObject(forKey: key)
    }
}
