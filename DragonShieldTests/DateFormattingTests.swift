import XCTest
@testable import DragonShield

final class DateFormattingTests: XCTestCase {
    func testUserFriendly() {
        let prev = NSTimeZone.default
        NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
        defer { NSTimeZone.default = prev }
        let iso = "2025-08-22T15:39:00Z"
        XCTAssertEqual(DateFormatting.userFriendly(iso), "2025-08-22 15:39")
        XCTAssertEqual(DateFormatting.userFriendly(nil), "—")
    }
}
