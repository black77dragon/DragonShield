@testable import DragonShield
import SQLite3
import SwiftUI
import XCTest

final class DataImportExportViewTests: XCTestCase {
    func testViewInitializes() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let view = DataImportExportView()
            .environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(db)
    }
}
