import XCTest
@testable import DragonShield

final class InstitutionsColumnWidthTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKeys.institutionsNameColWidth)
        defaults.removeObject(forKey: UserDefaultsKeys.institutionsBicColWidth)
        defaults.removeObject(forKey: UserDefaultsKeys.institutionsTypeColWidth)
        defaults.removeObject(forKey: UserDefaultsKeys.institutionsCurColWidth)
        defaults.removeObject(forKey: UserDefaultsKeys.institutionsCountryColWidth)
        defaults.removeObject(forKey: UserDefaultsKeys.institutionsStatusColWidth)
    }

    func testWidthsRestoredFromDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(310.0, forKey: UserDefaultsKeys.institutionsNameColWidth)
        defaults.set(111.0, forKey: UserDefaultsKeys.institutionsBicColWidth)
        defaults.set(133.0, forKey: UserDefaultsKeys.institutionsTypeColWidth)
        defaults.set(44.0, forKey: UserDefaultsKeys.institutionsCurColWidth)
        defaults.set(88.0, forKey: UserDefaultsKeys.institutionsCountryColWidth)
        defaults.set(99.0, forKey: UserDefaultsKeys.institutionsStatusColWidth)

        let view = InstitutionsView()
        let mirror = Mirror(reflecting: view)

        XCTAssertEqual(mirror.descendant("nameColWidth") as? Double, 310.0)
        XCTAssertEqual(mirror.descendant("bicColWidth") as? Double, 111.0)
        XCTAssertEqual(mirror.descendant("typeColWidth") as? Double, 133.0)
        XCTAssertEqual(mirror.descendant("curColWidth") as? Double, 44.0)
        XCTAssertEqual(mirror.descendant("countryColWidth") as? Double, 88.0)
        XCTAssertEqual(mirror.descendant("statusColWidth") as? Double, 99.0)
    }
}
