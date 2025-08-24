import XCTest
import AppKit
@testable import DragonShield

final class ImportReportWindowTests: XCTestCase {
    func testResolveImportReportFrameDefaultsCentered() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = ImportManager.resolveImportReportFrame(savedFrameString: nil, screenFrame: screen)
        XCTAssertEqual(rect.size.width, 1000, accuracy: 0.1)
        XCTAssertEqual(rect.size.height, 700, accuracy: 0.1)
        XCTAssertEqual(rect.origin.x, (screen.width - 1000) / 2, accuracy: 0.1)
        XCTAssertEqual(rect.origin.y, (screen.height - 700) / 2, accuracy: 0.1)
    }

    func testResolveImportReportFrameClampsToMinAndCenters() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let saved = NSStringFromRect(NSRect(x: -5000, y: -5000, width: 100, height: 100))
        let rect = ImportManager.resolveImportReportFrame(savedFrameString: saved, screenFrame: screen)
        XCTAssertEqual(rect.size.width, 800, accuracy: 0.1)
        XCTAssertEqual(rect.size.height, 560, accuracy: 0.1)
        XCTAssertEqual(rect.origin.x, (screen.width - 800) / 2, accuracy: 0.1)
        XCTAssertEqual(rect.origin.y, (screen.height - 560) / 2, accuracy: 0.1)
    }
}
