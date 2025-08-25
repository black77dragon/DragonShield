import XCTest
import SQLite3
@testable import DragonShield

final class UnusedInstrumentsTests: XCTestCase {
    func makeManager(withPositions: Bool) -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(db, """
            CREATE TABLE AssetSubClasses(
                sub_class_id INTEGER PRIMARY KEY,
                class_id INTEGER,
                sub_class_code TEXT,
                sub_class_name TEXT
            );
            CREATE TABLE Instruments(
                instrument_id INTEGER PRIMARY KEY,
                instrument_name TEXT,
                sub_class_id INTEGER,
                currency TEXT,
                is_active INTEGER DEFAULT 1
            );
            CREATE TABLE PositionReports(
                position_id INTEGER PRIMARY KEY,
                instrument_id INTEGER,
                quantity REAL,
                report_date TEXT
            );
            CREATE TABLE PortfolioTheme(
                id INTEGER PRIMARY KEY
            );
            CREATE TABLE PortfolioThemeAsset(
                theme_id INTEGER,
                instrument_id INTEGER
            );
        """, nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO AssetSubClasses VALUES (1,1,'CASH','Cash');", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO AssetSubClasses VALUES (2,1,'EQT','Equity');", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO Instruments VALUES (1,'Stock A',2,'USD',1);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO Instruments VALUES (2,'Stock B',2,'EUR',1);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO Instruments VALUES (3,'Cash CHF',1,'CHF',1);", nil, nil, nil)
        if withPositions {
            sqlite3_exec(db, "INSERT INTO PositionReports VALUES (1,1,5,'2025-01-01');", nil, nil, nil)
            sqlite3_exec(db, "INSERT INTO PositionReports VALUES (2,2,1,'2024-12-01');", nil, nil, nil)
        }
        sqlite3_exec(db, "INSERT INTO PortfolioTheme VALUES (1);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO PortfolioThemeAsset VALUES (1,2);", nil, nil, nil)
        return manager
    }

    func testFetchUnusedInstrumentsExcludingCash() {
        let manager = makeManager(withPositions: true)
        let list = manager.fetchUnusedInstruments()
        XCTAssertEqual(list.count, 1)
        let item = list[0]
        XCTAssertEqual(item.name, "Stock B")
        XCTAssertEqual(item.themeCount, 1)
        XCTAssertEqual(DateFormatter.iso8601DateOnly.string(from: item.lastActivity!), "2024-12-01")
        sqlite3_close(manager.db)
    }

    func testFetchUnusedInstrumentsIncludingCashAndNoSnapshot() {
        let manager = makeManager(withPositions: true)
        let list = manager.fetchUnusedInstruments(excludingCash: false)
        XCTAssertEqual(list.map { $0.name }.sorted(), ["Cash CHF", "Stock B"])
        sqlite3_close(manager.db)

        let manager2 = makeManager(withPositions: false)
        let empty = manager2.fetchUnusedInstruments()
        XCTAssertTrue(empty.isEmpty)
        sqlite3_close(manager2.db)
    }
}

