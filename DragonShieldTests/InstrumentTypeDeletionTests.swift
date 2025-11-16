@testable import DragonShield
import SQLite3
import XCTest

final class InstrumentTypeDeletionTests: XCTestCase {
    private func setupDb() -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let sql = """
            CREATE TABLE AssetSubClasses (sub_class_id INTEGER PRIMARY KEY, class_id INTEGER, code TEXT, name TEXT);
            CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY, instrument_name TEXT, sub_class_id INTEGER);
            CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, instrument_id INTEGER);
            CREATE TABLE SubClassTargets (asset_sub_class_id INTEGER);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    private func querySingleInt(db: OpaquePointer?, sql: String) -> Int {
        var stmt: OpaquePointer?
        var value = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                value = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return value
    }

    func testCanDeleteInstrumentTypeCountsPositionReports() {
        let dbm = setupDb()
        sqlite3_exec(dbm.db, "INSERT INTO AssetSubClasses VALUES (1,1,'SC1','sub1');", nil, nil, nil)
        sqlite3_exec(dbm.db, "INSERT INTO Instruments VALUES (1,'Inst',1);", nil, nil, nil)
        sqlite3_exec(dbm.db, "INSERT INTO PositionReports (instrument_id) VALUES (1);", nil, nil, nil)
        let info = dbm.canDeleteInstrumentType(id: 1)
        XCTAssertFalse(info.canDelete)
        XCTAssertEqual(info.instrumentCount, 1)
        XCTAssertEqual(info.positionReportCount, 1)
        XCTAssertEqual(info.allocationCount, 0)
        sqlite3_close(dbm.db)
    }

    func testPurgePositionReportsDeletesRows() {
        let dbm = setupDb()
        sqlite3_exec(dbm.db, "INSERT INTO AssetSubClasses VALUES (1,1,'SC1','sub1');", nil, nil, nil)
        sqlite3_exec(dbm.db, "INSERT INTO Instruments VALUES (1,'Inst',1);", nil, nil, nil)
        sqlite3_exec(dbm.db, "INSERT INTO PositionReports (instrument_id) VALUES (1);", nil, nil, nil)
        dbm.purgeInstrumentTypeData(subClassId: 1)
        let instrCount = querySingleInt(db: dbm.db, sql: "SELECT COUNT(*) FROM Instruments;")
        let posCount = querySingleInt(db: dbm.db, sql: "SELECT COUNT(*) FROM PositionReports;")
        XCTAssertEqual(instrCount, 0)
        XCTAssertEqual(posCount, 0)
        sqlite3_close(dbm.db)
    }

    func testDeleteInstrumentTypePurgesAndDeletes() {
        let dbm = setupDb()
        sqlite3_exec(dbm.db, "INSERT INTO AssetSubClasses VALUES (1,1,'SC1','sub1');", nil, nil, nil)
        sqlite3_exec(dbm.db, "INSERT INTO Instruments VALUES (1,'Inst',1);", nil, nil, nil)
        sqlite3_exec(dbm.db, "INSERT INTO PositionReports (instrument_id) VALUES (1);", nil, nil, nil)
        let result = dbm.deleteInstrumentType(id: 1)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.usage.isEmpty)
        let subCount = querySingleInt(db: dbm.db, sql: "SELECT COUNT(*) FROM AssetSubClasses;")
        XCTAssertEqual(subCount, 0)
        sqlite3_close(dbm.db)
    }

    func testDeleteInstrumentTypeReturnsUsageIfReferenced() {
        let dbm = setupDb()
        sqlite3_exec(dbm.db, "INSERT INTO AssetSubClasses VALUES (1,1,'SC1','sub1');", nil, nil, nil)
        sqlite3_exec(dbm.db, "INSERT INTO SubClassTargets VALUES (1);", nil, nil, nil)
        let result = dbm.deleteInstrumentType(id: 1)
        XCTAssertFalse(result.success)
        XCTAssertFalse(result.usage.isEmpty)
        XCTAssertEqual(result.usage.first?.table, "SubClassTargets")
        sqlite3_close(dbm.db)
    }
}
