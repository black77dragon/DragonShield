import XCTest
@testable import DragonShield

final class DeviationTests: XCTestCase {
    func testDeltaMathAndFiltering() {
        let tolerance = 2.0
        // AC2
        let actual1 = 45.0
        let research1 = 30.0
        let user1 = 35.0
        XCTAssertEqual(computeDelta(actual: actual1, target: research1), 15.0, accuracy: 0.0001)
        XCTAssertEqual(computeDelta(actual: actual1, target: user1), 10.0, accuracy: 0.0001)
        XCTAssertTrue(rowOutOfTolerance(actual: actual1, research: research1, user: user1, status: "OK", tolerance: tolerance, showResearch: true, showUser: true))

        // AC3 - appears due to research delta only
        let actual2 = 19.9
        let research2 = 25.0
        let user2 = 20.0
        XCTAssertTrue(rowOutOfTolerance(actual: actual2, research: research2, user: user2, status: "OK", tolerance: tolerance, showResearch: true, showUser: true))
        XCTAssertFalse(rowOutOfTolerance(actual: actual2, research: research2, user: user2, status: "OK", tolerance: tolerance, showResearch: false, showUser: true))

        // AC4 - hide user column
        let actual3 = 10.0
        let research3 = 10.0
        let user3 = 6.0
        XCTAssertTrue(rowOutOfTolerance(actual: actual3, research: research3, user: user3, status: "OK", tolerance: tolerance, showResearch: true, showUser: true))
        XCTAssertFalse(rowOutOfTolerance(actual: actual3, research: research3, user: user3, status: "OK", tolerance: tolerance, showResearch: true, showUser: false))

        // AC5 - excluded row
        XCTAssertFalse(rowOutOfTolerance(actual: 0.0, research: 50.0, user: 50.0, status: "FX missing — excluded", tolerance: tolerance, showResearch: true, showUser: true))
    }
}
