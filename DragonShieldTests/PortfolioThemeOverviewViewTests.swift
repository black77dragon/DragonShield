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

    func testDateFilterLast30d() {
        let tz = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let now = Date()
        let startToday = calendar.startOfDay(for: now)
        let twentyDaysAgo = calendar.date(byAdding: .day, value: -20, to: startToday)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last30d.contains(twentyDaysAgo, timeZone: tz))
        let thirtyOneDaysAgo = calendar.date(byAdding: .day, value: -31, to: startToday)!
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last30d.contains(thirtyOneDaysAgo, timeZone: tz))
    }

    func testDateFilterLast90d() {
        let tz = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let now = Date()
        let startToday = calendar.startOfDay(for: now)
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: startToday)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last90d.contains(sixtyDaysAgo, timeZone: tz))
        let ninetyOneDaysAgo = calendar.date(byAdding: .day, value: -91, to: startToday)!
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last90d.contains(ninetyOneDaysAgo, timeZone: tz))
    }

    func testTitleOrPlaceholder() {
        XCTAssertEqual(PortfolioThemeOverviewView.titleOrPlaceholder(""), "(No title)")
        XCTAssertEqual(PortfolioThemeOverviewView.titleOrPlaceholder("Alpha"), "Alpha")
    }
}
