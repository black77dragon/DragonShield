import XCTest
@testable import DragonShield

final class LoggingServiceTests: XCTestCase {
    func testFiltersNoisyMessages() {
        let service = LoggingService.shared
        service.clearLog()
        service.log("/private/var/db/DetachedSignatures warning")
        service.log("default.metallib missing")
        service.log("useful info")
        let log = service.readLog()
        XCTAssertFalse(log.contains("DetachedSignatures"))
        XCTAssertFalse(log.contains("default.metallib"))
        XCTAssertTrue(log.contains("useful info"))
    }
}
