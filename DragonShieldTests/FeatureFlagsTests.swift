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

    func testInstrumentNotesDisabledByDefault() {
        XCTAssertFalse(FeatureFlags.instrumentNotesEnabled(args: [], env: [:], defaults: .standard))
    }

    func testInstrumentNotesEnabledWhenDefaultsTrue() {
        let defaults = UserDefaults(suiteName: "testInstrumentNotesEnabled")!
        defaults.set(true, forKey: UserDefaultsKeys.instrumentNotesEnabled)
        XCTAssertTrue(FeatureFlags.instrumentNotesEnabled(args: [], env: [:], defaults: defaults))
    }

}
