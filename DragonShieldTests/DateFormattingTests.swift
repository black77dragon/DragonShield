import XCTest
@testable import DragonShield

final class DateFormattingTests: XCTestCase {
    func testFriendlyFormat() {
        let iso = "2025-08-22T15:39:00Z"
        let friendly = DateFormatting.friendly(iso)
        XCTAssertTrue(friendly.hasPrefix("2025-08-22 15:39"))
    }
}
