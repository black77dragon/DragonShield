import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioThemeAssetSequentialUpdateTests: XCTestCase {
    private var manager: DatabaseManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        manager = DatabaseManager()
        manager.closeConnection()

        var mem: OpaquePointer?
        sqlite3_open(":memory:", &mem)
        manager.db = mem

        let sql = """
        CREATE TABLE PortfolioThemeStatus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            color_hex TEXT NOT NULL,
            is_default INTEGER NOT NULL,
            created_at TEXT DEFAULT '',
            updated_at TEXT DEFAULT ''
        );
        INSERT INTO PortfolioThemeStatus (code,name,color_hex,is_default) VALUES ('ACTIVE','Active','#FFFFFF',1);
        CREATE TABLE PortfolioTheme (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            status_id INTEGER NOT NULL,
            created_at TEXT DEFAULT '',
            updated_at TEXT DEFAULT '',
            archived_at TEXT,
            soft_delete INTEGER DEFAULT 0
        );
        CREATE TABLE Instruments (
            instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
            instrument_name TEXT NOT NULL,
            sub_class_id INTEGER NOT NULL,
            currency TEXT NOT NULL
        );
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
        manager.ensurePortfolioThemeAssetTable()
        _ = manager.createPortfolioTheme(name: "Growth", code: "GROWTH", statusId: 1)
        sqlite3_exec(manager.db, "INSERT INTO Instruments (instrument_name, sub_class_id, currency) VALUES ('Apple',1,'USD');", nil, nil, nil)
    }

    override func tearDownWithError() throws {
        if let db = manager.db {
            sqlite3_close(db)
            manager.db = nil
        }
        manager = nil
        try super.tearDownWithError()
    }

    func testSequentialUpdatesPersist() throws {
        guard let theme = manager.fetchPortfolioThemes().first else {
            XCTFail("Failed to fetch theme")
            return
        }
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 10.0, userPct: 10.0)

        let percentages = [20.0, 30.0, 40.0]
        for pct in percentages {
            let updated = manager.updateThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: pct, userPct: pct, notes: nil)
            XCTAssertEqual(updated?.researchTargetPct, pct)
            XCTAssertEqual(updated?.userTargetPct, pct)
        }

        let finalAsset = manager.getThemeAsset(themeId: theme.id, instrumentId: 1)
        XCTAssertNotNil(finalAsset)
        XCTAssertEqual(finalAsset?.researchTargetPct, percentages.last)
        XCTAssertEqual(finalAsset?.userTargetPct, percentages.last)
    }
}
