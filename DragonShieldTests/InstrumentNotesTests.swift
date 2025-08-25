import XCTest
import SQLite3
@testable import DragonShield

final class InstrumentNotesTests: XCTestCase {
    var manager: DatabaseManager!
    var db: OpaquePointer?

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &db)
        manager.db = db
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE AssetSubClasses(sub_class_id INTEGER PRIMARY KEY, sub_class_name TEXT);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO AssetSubClasses(sub_class_id, sub_class_name) VALUES(1,'Stock');", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE Instruments(\n            instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,\n            instrument_name TEXT NOT NULL,\n            sub_class_id INTEGER NOT NULL,\n            currency TEXT NOT NULL,\n            valor_nr TEXT,\n            ticker_symbol TEXT,\n            isin TEXT,\n            sector TEXT,\n            notes TEXT,\n            is_active INTEGER DEFAULT 1\n        );", nil, nil, nil)
    }

    override func tearDown() {
        sqlite3_close(db)
        db = nil
        manager = nil
        super.tearDown()
    }

    func testInsertFetchAndUpdateNotes() {
        let id = manager.addInstrumentReturningId(name: "Test", subClassId: 1, currency: "USD", valorNr: nil, tickerSymbol: nil, isin: nil, countryCode: nil, exchangeCode: nil, sector: nil, notes: "Initial")
        XCTAssertNotNil(id)
        var details = manager.fetchInstrumentDetails(id: id!)
        XCTAssertEqual(details?.notes, "Initial")
        let updated = manager.updateInstrument(id: id!, name: "Test", subClassId: 1, currency: "USD", valorNr: nil, tickerSymbol: nil, isin: nil, sector: nil, notes: "Changed")
        XCTAssertTrue(updated)
        details = manager.fetchInstrumentDetails(id: id!)
        XCTAssertEqual(details?.notes, "Changed")
    }
}
