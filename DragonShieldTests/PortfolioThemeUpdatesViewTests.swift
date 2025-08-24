import XCTest
import SwiftUI
import SQLite3
@testable import DragonShield

final class PortfolioThemeUpdatesViewTests: XCTestCase {
    func testViewInitializes() {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let view = PortfolioThemeUpdatesView(themeId: 1, initialSearchText: nil, searchHint: nil)
            .environmentObject(manager)
        XCTAssertNotNil(view.body)
        sqlite3_close(db)
    }
}

