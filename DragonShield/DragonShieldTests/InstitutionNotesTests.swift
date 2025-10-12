import XCTest
import SQLite3
@testable import DragonShield

final class InstitutionNotesTests: XCTestCase {
    var db: OpaquePointer?

    override func setUp() {
        super.setUp()
        sqlite3_open(":memory:", &db)
    }

    override func tearDown() {
        sqlite3_close(db)
        db = nil
        super.tearDown()
    }

    func testNotesPersistence() {
        let setup = """
        CREATE TABLE Institutions(
            institution_id INTEGER PRIMARY KEY,
            institution_name TEXT NOT NULL,
            notes TEXT
        );
        INSERT INTO Institutions(institution_name, notes) VALUES('BankOne', 'First note');
        INSERT INTO Institutions(institution_name) VALUES('BankTwo');
        """
        sqlite3_exec(db, setup, nil, nil, nil)

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT notes FROM Institutions WHERE institution_name='BankOne';", -1, &stmt, nil)
        sqlite3_step(stmt)
        let note1 = String(cString: sqlite3_column_text(stmt, 0))
        sqlite3_finalize(stmt)
        XCTAssertEqual(note1, "First note")

        sqlite3_prepare_v2(db, "SELECT notes FROM Institutions WHERE institution_name='BankTwo';", -1, &stmt, nil)
        sqlite3_step(stmt)
        XCTAssertNil(sqlite3_column_text(stmt, 0))
        sqlite3_finalize(stmt)
    }
}
