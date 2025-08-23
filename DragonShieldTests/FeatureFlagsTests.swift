import XCTest
@testable import DragonShield

final class FeatureFlagsTests: XCTestCase {
    func testInstrumentUpdatesEnabledByDefault() {
        XCTAssertTrue(FeatureFlags.portfolioInstrumentUpdatesEnabled(args: [], env: [:], defaults: .standard))
    }

    func testAttachmentsDisabledByDefault() {
        XCTAssertFalse(FeatureFlags.portfolioAttachmentsEnabled(args: [], env: [:], defaults: .standard))
    }
}
