import XCTest
import Foundation
@testable import DragonShield

final class PortfolioThemeOverviewViewTests: XCTestCase {
    func testDateFilterInclusive() {
        let tz = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let now = Date()
        let startToday = calendar.startOfDay(for: now)
        let endToday = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startToday)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last7d.contains(startToday, timeZone: tz))
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last7d.contains(endToday, timeZone: tz))
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: startToday)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last7d.contains(sixDaysAgo, timeZone: tz))
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: startToday)!
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last7d.contains(eightDaysAgo, timeZone: tz))
    }

    func testTitleOrPlaceholder() {
        XCTAssertEqual(PortfolioThemeOverviewView.titleOrPlaceholder(""), "(No title)")
        XCTAssertEqual(PortfolioThemeOverviewView.titleOrPlaceholder("Alpha"), "Alpha")
    }
}
