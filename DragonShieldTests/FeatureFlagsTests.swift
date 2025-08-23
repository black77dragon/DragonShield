import XCTest
@testable import DragonShield

final class FeatureFlagsTests: XCTestCase {
    func testInstrumentUpdatesEnabledByDefault() {
        XCTAssertTrue(FeatureFlags.portfolioInstrumentUpdatesEnabled(args: [], env: [:], defaults: .standard))
    }

    func testAttachmentsEnabledByDefault() {
        XCTAssertTrue(FeatureFlags.portfolioAttachmentsEnabled(args: [], env: [:], defaults: .standard))
    }

    func testAttachmentsCanBeDisabled() {
        let defaults = UserDefaults(suiteName: "attachmentsOff")!
        defaults.set(false, forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        XCTAssertFalse(FeatureFlags.portfolioAttachmentsEnabled(args: [], env: [:], defaults: defaults))
    }
}
