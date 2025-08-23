import XCTest
import Foundation
@testable import DragonShield

final class PortfolioThemeOverviewViewTests: XCTestCase {
    func testDateFilterIncludesToday() {
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: start)!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: start)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last7d.contains(now))
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last7d.contains(sixDaysAgo))
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last7d.contains(sevenDaysAgo))
    }
}

