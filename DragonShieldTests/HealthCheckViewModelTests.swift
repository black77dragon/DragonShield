import XCTest
@testable import DragonShield

final class HealthCheckViewModelTests: XCTestCase {
    func testSummaryCounts() {
        let vm = HealthCheckViewModel()
        vm.runChecks()
        let summary = vm.summary
        XCTAssertEqual(summary.ok, 1)
        XCTAssertEqual(summary.warning, 1)
        XCTAssertEqual(summary.error, 1)
    }
}
