import XCTest
import SQLite3
@testable import DragonShield

final class InstrumentUsageRepositoryTests: XCTestCase {
    var manager: DatabaseManager!
    var db: OpaquePointer?
    var repo: InstrumentUsageRepository!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &db)
        manager.db = db
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        // Minimal schema
        sqlite3_exec(db, "CREATE TABLE AssetSubClasses(sub_class_id INTEGER PRIMARY KEY, sub_class_name TEXT);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO AssetSubClasses(sub_class_id, sub_class_name) VALUES(1,'Cash'),(2,'Single Stock');", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE Instruments(instrument_id INTEGER PRIMARY KEY, instrument_name TEXT NOT NULL, sub_class_id INTEGER NOT NULL, currency TEXT NOT NULL, is_active INTEGER DEFAULT 1);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE PortfolioThemeAsset(theme_id INTEGER, instrument_id INTEGER, rwk_set_target_chf REAL);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE PositionReports(instrument_id INTEGER, quantity REAL, report_date TEXT);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE Transactions(tx_id INTEGER PRIMARY KEY, instrument_id INTEGER);", nil, nil, nil)
        // Instrument with position to establish snapshot
        sqlite3_exec(db, "INSERT INTO Instruments(instrument_id, instrument_name, sub_class_id, currency) VALUES(1,'Used',2,'USD');", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO PositionReports(instrument_id, quantity, report_date) VALUES(1,10,'2024-11-03');", nil, nil, nil)
        // Unused instrument
        sqlite3_exec(db, "INSERT INTO Instruments(instrument_id, instrument_name, sub_class_id, currency) VALUES(2,'Unused',2,'USD');", nil, nil, nil)
        repo = InstrumentUsageRepository(dbManager: manager)
    }

    override func tearDown() {
        sqlite3_close(db)
        db = nil
        manager = nil
        repo = nil
        super.tearDown()
    }

    func testReturnsInstrumentWithoutUsage() throws {
        let list = try repo.unusedStrict()
        XCTAssertEqual(list.map { $0.instrumentId }, [2])
    }

    func testInstrumentRemovedWhenThemeAdded() throws {
        _ = try repo.unusedStrict()
        sqlite3_exec(db, "INSERT INTO PortfolioThemeAsset(theme_id, instrument_id) VALUES(1,2);", nil, nil, nil)
        let list = try repo.unusedStrict()
        XCTAssertTrue(list.isEmpty)
    }

    func testInstrumentRemovedWhenTransactionAdded() throws {
        _ = try repo.unusedStrict()
        sqlite3_exec(db, "INSERT INTO Transactions(instrument_id) VALUES(2);", nil, nil, nil)
        let list = try repo.unusedStrict()
        XCTAssertTrue(list.isEmpty)
    }

    func testInstrumentWithOnlyOlderPositionsExcluded() throws {
        sqlite3_exec(db, "INSERT INTO PositionReports(instrument_id, quantity, report_date) VALUES(2,5,'2024-10-01');", nil, nil, nil)
        let list = try repo.unusedStrict()
        XCTAssertTrue(list.isEmpty)
    }
}
