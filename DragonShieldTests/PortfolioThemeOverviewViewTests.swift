import XCTest
import Foundation
@testable import DragonShield

final class PortfolioThemeOverviewViewTests: XCTestCase {
    func testDateFilterRangeIncludesToday() {
        let tz = TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let now = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let sixDaysAgo = cal.date(byAdding: .day, value: -6, to: now)!
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: now)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last7d.contains(now, timeZone: tz))
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last7d.contains(sixDaysAgo, timeZone: tz))
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last7d.contains(sevenDaysAgo, timeZone: tz))
    }
}
