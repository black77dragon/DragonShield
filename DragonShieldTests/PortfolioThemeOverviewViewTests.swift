import XCTest
import Foundation
@testable import DragonShield

final class PortfolioThemeOverviewViewTests: XCTestCase {
    func testDateFilterInclusive() {
        let tz = TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let now = cal.date(from: DateComponents(year: 2025, month: 8, day: 23, hour: 12))!
        let today = cal.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last1d.contains(today, in: tz, now: now))
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last1d.contains(yesterday, in: tz, now: now))
        let sixDaysAgo = cal.date(byAdding: .day, value: -6, to: today)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last7d.contains(sixDaysAgo, in: tz, now: now))
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: today)!
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last7d.contains(sevenDaysAgo, in: tz, now: now))
    }
}

