import XCTest
import SQLite3
@testable import DragonShield

final class CascadeDeleteTests: XCTestCase {
    var db: OpaquePointer?

    override func setUp() {
        super.setUp()
        sqlite3_open(":memory:", &db)
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        let setup = """
        CREATE TABLE AssetClasses(
            class_id INTEGER PRIMARY KEY,
            class_code TEXT NOT NULL,
            class_name TEXT NOT NULL
        );
        CREATE TABLE AssetSubClasses(
            sub_class_id INTEGER PRIMARY KEY,
            class_id INTEGER NOT NULL,
            sub_class_code TEXT NOT NULL,
            sub_class_name TEXT NOT NULL,
            FOREIGN KEY(class_id) REFERENCES AssetClasses(class_id) ON DELETE CASCADE
        );
        CREATE TABLE Instruments(
            instrument_id INTEGER PRIMARY KEY,
            instrument_name TEXT NOT NULL,
            sub_class_id INTEGER NOT NULL,
            currency TEXT NOT NULL,
            FOREIGN KEY(sub_class_id) REFERENCES AssetSubClasses(sub_class_id) ON DELETE CASCADE
        );
        CREATE TABLE Accounts(account_id INTEGER PRIMARY KEY);
        CREATE TABLE Institutions(institution_id INTEGER PRIMARY KEY);
        CREATE TABLE ImportSessions(import_session_id INTEGER PRIMARY KEY);
        CREATE TABLE PositionReports(
            position_id INTEGER PRIMARY KEY,
            import_session_id INTEGER,
            account_id INTEGER NOT NULL,
            institution_id INTEGER NOT NULL,
            instrument_id INTEGER NOT NULL,
            quantity REAL NOT NULL,
            report_date DATE NOT NULL,
            FOREIGN KEY(import_session_id) REFERENCES ImportSessions(import_session_id),
            FOREIGN KEY(account_id) REFERENCES Accounts(account_id),
            FOREIGN KEY(institution_id) REFERENCES Institutions(institution_id),
            FOREIGN KEY(instrument_id) REFERENCES Instruments(instrument_id) ON DELETE CASCADE
        );
        INSERT INTO Accounts(account_id) VALUES(1);
        INSERT INTO Institutions(institution_id) VALUES(1);
        INSERT INTO ImportSessions(import_session_id) VALUES(1);
        """
        sqlite3_exec(db, setup, nil, nil, nil)
    }

    override func tearDown() {
        sqlite3_close(db)
        db = nil
        super.tearDown()
    }

    private func count(_ table: String) -> Int {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table);", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_step(stmt)
        return Int(sqlite3_column_int(stmt, 0))
    }

    func testCascadeDelete() {
        let insert = """
        INSERT INTO AssetClasses(class_id, class_code, class_name) VALUES (1,'C','Class');
        INSERT INTO AssetSubClasses(sub_class_id, class_id, sub_class_code, sub_class_name) VALUES (10,1,'SC','Sub');
        INSERT INTO Instruments(instrument_id, instrument_name, sub_class_id, currency) VALUES (100,'Inst',10,'CHF');
        INSERT INTO PositionReports(position_id, import_session_id, account_id, institution_id, instrument_id, quantity, report_date)
        VALUES (1000,1,1,1,100,1,'2024-01-01');
        """
        sqlite3_exec(db, insert, nil, nil, nil)
        sqlite3_exec(db, "DELETE FROM AssetClasses WHERE class_id=1;", nil, nil, nil)
        XCTAssertEqual(count("AssetSubClasses"), 0)
        XCTAssertEqual(count("Instruments"), 0)
        XCTAssertEqual(count("PositionReports"), 0)
    }
}
