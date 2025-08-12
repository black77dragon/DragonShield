import XCTest
@testable import DragonShield

final class LoggingServiceTests: XCTestCase {
    func testSuppressesKnownWarnings() {
        let service = LoggingService.shared
        service.clearLog()
        service.log("path /private/var/db/DetachedSignatures warning")
        service.log("default.metallib not found")
        service.log("hello world")
        let contents = service.readLog()
        XCTAssertFalse(contents.contains("DetachedSignatures"))
        XCTAssertFalse(contents.contains("default.metallib"))
        XCTAssertTrue(contents.contains("hello world"))
    }
}
