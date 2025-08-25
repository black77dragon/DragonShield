import XCTest
import SwiftUI
import SQLite3
@testable import DragonShield

final class UnusedInstrumentsViewTests: XCTestCase {
    func testViewInitializes() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let view = UnusedInstrumentsView().environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(db)
    }
}
