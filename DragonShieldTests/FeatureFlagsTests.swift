import XCTest
@testable import DragonShield

final class FeatureFlagsTests: XCTestCase {
    func testInstrumentUpdatesEnabledByDefault() {
        XCTAssertTrue(FeatureFlags.portfolioInstrumentUpdatesEnabled(args: [], env: [:], defaults: .standard))
    }

    func testAttachmentsDisabledByDefault() {
        XCTAssertFalse(FeatureFlags.portfolioAttachmentsEnabled(args: [], env: [:], defaults: .standard))
    }

    func testAttachmentsEnabledWhenDefaultsTrue() {
        let defaults = UserDefaults(suiteName: "testAttachmentsEnabled")!
        defaults.set(true, forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        XCTAssertTrue(FeatureFlags.portfolioAttachmentsEnabled(args: [], env: [:], defaults: defaults))
    }

    func testLinksEnabledByDefault() {
        XCTAssertTrue(FeatureFlags.portfolioLinksEnabled(args: [], env: [:], defaults: .standard))
    }

    func testLinksDisabledWhenDefaultsFalse() {
        let defaults = UserDefaults(suiteName: "testLinksDisabled")!
        defaults.set(false, forKey: UserDefaultsKeys.portfolioLinksEnabled)
        XCTAssertFalse(FeatureFlags.portfolioLinksEnabled(args: [], env: [:], defaults: defaults))
    }

}
