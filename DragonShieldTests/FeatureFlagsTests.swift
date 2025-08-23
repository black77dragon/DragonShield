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

    func testThumbnailsEnabledByDefault() {
        let defaults = UserDefaults(suiteName: "thumbDefault")!
        defaults.set(true, forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        XCTAssertTrue(FeatureFlags.portfolioAttachmentThumbnailsEnabled(args: [], env: [:], defaults: defaults))
    }

    func testThumbnailsCanBeDisabled() {
        let defaults = UserDefaults(suiteName: "thumbDisabled")!
        defaults.set(true, forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        XCTAssertFalse(FeatureFlags.portfolioAttachmentThumbnailsEnabled(args: [], env: ["PORTFOLIO_ATTACHMENT_THUMBNAILS_ENABLED": "false"], defaults: defaults))
    }
}
