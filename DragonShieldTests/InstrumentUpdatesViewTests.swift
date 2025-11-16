@testable import DragonShield
import SQLite3
import SwiftUI
import XCTest

final class InstrumentUpdatesViewTests: XCTestCase {
    func testEditorViewInitializes() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let view = InstrumentUpdateEditorView(themeId: 1, instrumentId: 1, instrumentName: "Test", themeName: "Theme", onSave: { _ in }, onCancel: {})
            .environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(db)
    }

    func testListViewInitializes() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let view = InstrumentUpdatesView(themeId: 1, instrumentId: 1, instrumentName: "Test", themeName: "Theme", onClose: {})
            .environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(db)
    }
}
