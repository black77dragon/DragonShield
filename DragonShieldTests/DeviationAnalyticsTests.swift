import XCTest
@testable import DragonShield

final class DeviationAnalyticsTests: XCTestCase {
    func testDeviationMathAndState() {
        let metrics = DeviationAnalytics.deviation(actual: 45.0, target: 30.0, tolerance: 2.0)
        XCTAssertEqual(metrics.delta, 15.0, accuracy: 0.0001)
        XCTAssertEqual(metrics.state, .overweight)
    }

    func testOnlyOutFilterHonorsVisibleColumns() {
        let row = (actual: 19.9, research: 25.0, user: 20.0, excluded: false)
        let include = DeviationAnalytics.shouldInclude(actual: row.actual, research: row.research, user: row.user, excluded: row.excluded, tolerance: 2.0, showResearch: true, showUser: true, onlyOut: true)
        XCTAssertTrue(include)
        let hideUser = DeviationAnalytics.shouldInclude(actual: row.actual, research: row.research, user: row.user, excluded: row.excluded, tolerance: 2.0, showResearch: true, showUser: false, onlyOut: true)
        XCTAssertTrue(hideUser)
        let within = DeviationAnalytics.shouldInclude(actual: row.actual, research: row.research, user: row.user, excluded: row.excluded, tolerance: 2.0, showResearch: false, showUser: true, onlyOut: true)
        XCTAssertFalse(within)
    }

    func testExcludedRowIgnoredWhenFiltering() {
        let include = DeviationAnalytics.shouldInclude(actual: 0, research: 10, user: 10, excluded: true, tolerance: 2.0, showResearch: true, showUser: true, onlyOut: false)
        XCTAssertTrue(include)
        let filterOn = DeviationAnalytics.shouldInclude(actual: 0, research: 10, user: 10, excluded: true, tolerance: 2.0, showResearch: true, showUser: true, onlyOut: true)
        XCTAssertFalse(filterOn)
    }
}
