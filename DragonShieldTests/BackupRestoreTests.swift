import XCTest
@testable import DragonShield

final class BackupRestoreTests: XCTestCase {
    func testRestoreDeltaDeltaComputation() {
        let delta = RestoreDelta(table: "T", backupCount: 5, postCount: 3)
        XCTAssertEqual(delta.delta, -2)
    }
}
