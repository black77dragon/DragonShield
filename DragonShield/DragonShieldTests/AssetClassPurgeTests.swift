import XCTest
import SQLite3
@testable import DragonShield

final class AssetClassPurgeTests: XCTestCase {
    private func setup(_ manager: DatabaseManager) {
        var mem: OpaquePointer?
        sqlite3_open(":memory:", &mem)
        manager.db = mem
        let sql = """
        CREATE TABLE AssetClasses (class_id INTEGER PRIMARY KEY AUTOINCREMENT, class_code TEXT, class_name TEXT);
        CREATE TABLE AssetSubClasses (sub_class_id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER NOT NULL, sub_class_code TEXT, sub_class_name TEXT, sort_order INTEGER);
        CREATE TABLE Instruments (instrument_id INTEGER PRIMARY KEY AUTOINCREMENT, instrument_name TEXT NOT NULL, sub_class_id INTEGER NOT NULL);
        CREATE TABLE PositionReports (position_id INTEGER PRIMARY KEY AUTOINCREMENT, instrument_id INTEGER NOT NULL, quantity REAL, report_date TEXT);
        INSERT INTO AssetClasses (class_code, class_name) VALUES ('EQ','Equity');
        INSERT INTO AssetSubClasses (class_id, sub_class_code, sub_class_name, sort_order) VALUES (1,'STOCK','Stock',1),(1,'ETF','ETF',2);
        INSERT INTO Instruments (instrument_name, sub_class_id) VALUES ('A',1),('B',2);
        INSERT INTO PositionReports (instrument_id, quantity, report_date) VALUES (1,10,'2025-01-01'),(2,20,'2025-01-01');
        """
        sqlite3_exec(manager.db, sql, nil, nil, nil)
    }

    func testPurgeAssetClassRemovesDependencies() {
        let manager = DatabaseManager()
        setup(manager)

        var info = manager.canDeleteAssetClass(id: 1)
        XCTAssertFalse(info.canDelete)
        XCTAssertEqual(info.subClassCount, 2)
        XCTAssertEqual(info.instrumentCount, 2)
        XCTAssertEqual(info.positionReportCount, 2)

        XCTAssertTrue(manager.purgeAssetClass(id: 1))

        info = manager.canDeleteAssetClass(id: 1)
        XCTAssertTrue(info.canDelete)
        XCTAssertEqual(info.subClassCount, 0)
        XCTAssertEqual(info.instrumentCount, 0)
        XCTAssertEqual(info.positionReportCount, 0)

        XCTAssertTrue(manager.deleteAssetClass(id: 1))
        sqlite3_close(manager.db)
    }
}
