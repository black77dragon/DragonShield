import XCTest
import SQLite3
@testable import DragonShield

final class FetchInstrumentsWithoutThemesTests: XCTestCase {
    private func makeManager() -> DatabaseManager {
        let manager = DatabaseManager()
        var mem: OpaquePointer?
        sqlite3_open(":memory:", &mem)
        manager.db = mem
        let sql = """
        CREATE TABLE Instruments (
            instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
            instrument_name TEXT NOT NULL,
            currency TEXT NOT NULL,
            sub_class_id INTEGER NOT NULL,
            ticker_symbol TEXT,
            isin TEXT,
            valor_nr TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1
        );
        CREATE TABLE PortfolioThemeAsset (
            theme_id INTEGER NOT NULL,
            instrument_id INTEGER NOT NULL,
            rwk_set_target_chf REAL
        );
        """
        XCTAssertEqual(sqlite3_exec(manager.db, sql, nil, nil, nil), SQLITE_OK)
        return manager
    }

    private func insertInstrument(_ manager: DatabaseManager, name: String, isActive: Int = 1, isDeleted: Int = 0) {
        let sql = "INSERT INTO Instruments (instrument_name, currency, sub_class_id, is_active, is_deleted) VALUES ('\(name)', 'CHF', 1, \(isActive), \(isDeleted));"
        XCTAssertEqual(sqlite3_exec(manager.db, sql, nil, nil, nil), SQLITE_OK)
    }

    func testDefaultFiltersExcludeAssignedInactiveAndDeleted() {
        let manager = makeManager()
        insertInstrument(manager, name: "Alpha Fund")
        insertInstrument(manager, name: "Beta Fund")
        insertInstrument(manager, name: "Gamma Fund", isActive: 0)
        insertInstrument(manager, name: "Delta Fund", isDeleted: 1)
        XCTAssertEqual(sqlite3_exec(manager.db, "INSERT INTO PortfolioThemeAsset (theme_id, instrument_id) VALUES (1, 2);", nil, nil, nil), SQLITE_OK)

        let results = manager.fetchInstrumentsWithoutThemes()
        XCTAssertEqual(results.map { $0.name }, ["Alpha Fund"])
        sqlite3_close(manager.db)
    }

    func testIncludeFlagsExtendResultSet() {
        let manager = makeManager()
        insertInstrument(manager, name: "Alpha Fund")
        insertInstrument(manager, name: "Beta Fund", isActive: 0)
        insertInstrument(manager, name: "Gamma Fund", isDeleted: 1)

        let onlyActive = manager.fetchInstrumentsWithoutThemes()
        XCTAssertEqual(onlyActive.map { $0.name }, ["Alpha Fund"])

        let includingInactive = manager.fetchInstrumentsWithoutThemes(includeInactive: true)
        XCTAssertEqual(includingInactive.map { $0.name }, ["Alpha Fund", "Beta Fund"])

        let includingAll = manager.fetchInstrumentsWithoutThemes(includeDeleted: true, includeInactive: true)
        XCTAssertEqual(includingAll.map { $0.name }, ["Alpha Fund", "Beta Fund", "Gamma Fund"])
        sqlite3_close(manager.db)
    }
}
