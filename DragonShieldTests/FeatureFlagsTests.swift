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

    func testThumbnailsOffByDefault() {
        XCTAssertFalse(FeatureFlags.portfolioAttachmentThumbnailsEnabled(args: [], env: [:], defaults: .standard))
    }

    func testThumbnailsOnWhenAttachmentsEnabled() {
        let defaults = UserDefaults(suiteName: "thumbsOn")!
        defaults.set(true, forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        XCTAssertTrue(FeatureFlags.portfolioAttachmentThumbnailsEnabled(args: [], env: [:], defaults: defaults))
    }

    func testThumbnailsCanBeDisabled() {
        let defaults = UserDefaults(suiteName: "thumbsOff")!
        defaults.set(true, forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        defaults.set(false, forKey: UserDefaultsKeys.portfolioAttachmentThumbnailsEnabled)
        XCTAssertFalse(FeatureFlags.portfolioAttachmentThumbnailsEnabled(args: [], env: [:], defaults: defaults))
    }
}
