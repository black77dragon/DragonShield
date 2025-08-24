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
        let twentyNineDaysAgo = calendar.date(byAdding: .day, value: -29, to: startToday)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last30d.contains(twentyNineDaysAgo, timeZone: tz))
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: startToday)!
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last30d.contains(thirtyDaysAgo, timeZone: tz))
    }

    func testDateFilterLast90d() {
        let tz = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let now = Date()
        let startToday = calendar.startOfDay(for: now)
        let eightyNineDaysAgo = calendar.date(byAdding: .day, value: -89, to: startToday)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last90d.contains(eightyNineDaysAgo, timeZone: tz))
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: startToday)!
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last90d.contains(ninetyDaysAgo, timeZone: tz))
    }

    func testDateFilterAllAlwaysTrue() {
        let tz = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let past = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1))!
        let future = calendar.date(from: DateComponents(year: 2100, month: 12, day: 31))!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.all.contains(past, timeZone: tz))
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.all.contains(future, timeZone: tz))
    }

    func testDateFilterLabelsMatchSpecification() {
        XCTAssertEqual(PortfolioThemeOverviewView.DateFilter.last7d.label, "Last 7d")
        XCTAssertEqual(PortfolioThemeOverviewView.DateFilter.last30d.label, "Last 30d")
        XCTAssertEqual(PortfolioThemeOverviewView.DateFilter.last90d.label, "Last 90d")
        XCTAssertEqual(PortfolioThemeOverviewView.DateFilter.all.label, "All")
    }

    func testTitleOrPlaceholder() {
        XCTAssertEqual(PortfolioThemeOverviewView.titleOrPlaceholder(""), "(No title)")
        XCTAssertEqual(PortfolioThemeOverviewView.titleOrPlaceholder("Alpha"), "Alpha")
    }
}
