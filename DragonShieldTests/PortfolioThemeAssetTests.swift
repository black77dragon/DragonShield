import XCTest
import SQLite3
@testable import DragonShield

final class PortfolioThemeAssetTests: XCTestCase {
    private func setupDb(_ manager: DatabaseManager) {
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

    func testCreateDefaultsUserPct() {
        let manager = DatabaseManager()
        setupDb(manager)
        guard let theme = manager.fetchPortfolioThemes().first else { XCTFail(); return }
        let asset = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 25.0)
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset?.userTargetPct, 25.0)
        sqlite3_close(manager.db)
    }

    func testDuplicateInstrumentRejected() {
        let manager = DatabaseManager()
        setupDb(manager)
        guard let theme = manager.fetchPortfolioThemes().first else { XCTFail(); return }
        let first = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 10.0)
        XCTAssertNotNil(first)
        let second = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 5.0)
        XCTAssertNil(second)
        sqlite3_close(manager.db)
    }

    func testUpdateTargets() {
        let manager = DatabaseManager()
        setupDb(manager)
        guard let theme = manager.fetchPortfolioThemes().first else { XCTFail(); return }
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 10.0, userPct: 10.0)
        let updated = manager.updateThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 20.0, userPct: 30.0, notes: nil)
        XCTAssertEqual(updated?.researchTargetPct, 20.0)
        XCTAssertEqual(updated?.userTargetPct, 30.0)
        sqlite3_close(manager.db)
    }

    func testUpdateNotesPersists() {
        let manager = DatabaseManager()
        setupDb(manager)
        guard let theme = manager.fetchPortfolioThemes().first else { XCTFail(); return }
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 10.0, userPct: 10.0, notes: "Old")
        let updated = manager.updateThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 10.0, userPct: 10.0, notes: "New note")
        XCTAssertEqual(updated?.notes, "New note")
        sqlite3_close(manager.db)
    }

    func testNotesPreservedWhenNil() {
        let manager = DatabaseManager()
        setupDb(manager)
        guard let theme = manager.fetchPortfolioThemes().first else { XCTFail(); return }
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 10.0, userPct: 10.0, notes: "Keep")
        let updated = manager.updateThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 20.0, userPct: 20.0, notes: nil)
        XCTAssertEqual(updated?.notes, "Keep")
        sqlite3_close(manager.db)
    }

    func testThemeAssetCount() {
        let manager = DatabaseManager()
        setupDb(manager)
        guard let theme = manager.fetchPortfolioThemes().first else { XCTFail(); return }
        XCTAssertEqual(manager.themeAssetCount(themeId: theme.id), 0)
        _ = manager.createThemeAsset(themeId: theme.id, instrumentId: 1, researchPct: 25.0)
        XCTAssertEqual(manager.themeAssetCount(themeId: theme.id), 1)
        sqlite3_close(manager.db)
    }
}
