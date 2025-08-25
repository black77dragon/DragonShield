import XCTest
import SwiftUI
import SQLite3
@testable import DragonShield

final class UnusedInstrumentsReportViewTests: XCTestCase {
    func testReportViewInitializes() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let view = UnusedInstrumentsReportView().environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(db)
    }
}
