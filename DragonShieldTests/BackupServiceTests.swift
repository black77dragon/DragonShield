import XCTest
@testable import DragonShield

final class BackupServiceTests: XCTestCase {
    func testShouldDisplayLogFiltersNoise() {
        let service = BackupService()
        XCTAssertFalse(service.shouldDisplayLog("warning: /private/var/db/DetachedSignatures"))
        XCTAssertFalse(service.shouldDisplayLog("error default.metallib missing"))
        XCTAssertTrue(service.shouldDisplayLog("[2024-01-01] Backup test.db Success"))
    }
}
