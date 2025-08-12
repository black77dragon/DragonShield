import XCTest
@testable import DragonShield

final class LoggingServiceTests: XCTestCase {
    func testSuppressesKnownWarnings() {
        let svc = LoggingService.shared
        svc.clearLog()
        svc.log("/private/var/db/DetachedSignatures warning")
        svc.log("normal message")
        sleep(1)
        let content = svc.readLog()
        XCTAssertFalse(content.contains("DetachedSignatures"))
        XCTAssertTrue(content.contains("normal message"))
    }
}
