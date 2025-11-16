@testable import DragonShield
import XCTest

final class UpdateDateFilterTests: XCTestCase {
    func testTodayRange() {
        let tz = TimeZone(secondsFromGMT: 0)!
        let now = Date()
        XCTAssertTrue(UpdateDateFilter.today.contains(now, timeZone: tz))
        let yesterday = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: now)!
        XCTAssertFalse(UpdateDateFilter.today.contains(yesterday, timeZone: tz))
    }

    func testLast7DaysRange() {
        let tz = TimeZone(secondsFromGMT: 0)!
        let now = Date()
        let sixDaysAgo = Calendar(identifier: .gregorian).date(byAdding: .day, value: -6, to: now)!
        XCTAssertTrue(UpdateDateFilter.last7d.contains(sixDaysAgo, timeZone: tz))
        let eightDaysAgo = Calendar(identifier: .gregorian).date(byAdding: .day, value: -8, to: now)!
        XCTAssertFalse(UpdateDateFilter.last7d.contains(eightDaysAgo, timeZone: tz))
    }
}
