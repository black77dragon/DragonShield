import XCTest
import SwiftUI
import SQLite3
@testable import DragonShield

final class PortfolioThemeUpdateAccessTests: XCTestCase {
    func testEditorViewInitializes() {
        let manager = DatabaseManager()
        var mem: OpaquePointer?
        sqlite3_open(":memory:", &mem)
        manager.db = mem
        let view = ThemeUpdateEditorView(themeId: 1, themeName: "Test", onSave: { _ in }, onCancel: {})
            .environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(mem)
    }
}
