import XCTest
import Foundation
@testable import DragonShield

final class PortfolioThemeOverviewViewTests: XCTestCase {
    func testDateFilterContains() {
        let now = Date()
        let seven = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let ninety = Calendar.current.date(byAdding: .day, value: -90, to: now)!
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last7d.contains(seven))
        XCTAssertFalse(PortfolioThemeOverviewView.DateFilter.last7d.contains(ninety))
        XCTAssertTrue(PortfolioThemeOverviewView.DateFilter.last90d.contains(ninety))
    }
}

