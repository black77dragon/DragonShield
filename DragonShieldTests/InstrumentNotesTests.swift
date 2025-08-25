import XCTest
import SQLite3
@testable import DragonShield

final class InstrumentNotesTests: XCTestCase {
    private func setupDb() -> DatabaseManager {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        let sql = """
            CREATE TABLE Instruments (
                instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
                instrument_name TEXT,
                sub_class_id INTEGER,
                currency TEXT,
                valor_nr TEXT,
                ticker_symbol TEXT,
                isin TEXT,
                sector TEXT,
                notes TEXT,
                is_active BOOLEAN
            );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        return manager
    }

    func testAddAndFetchInstrumentNotes() {
        let dbm = setupDb()
        let added = dbm.addInstrument(name: "Test", subClassId: 1, currency: "USD", valorNr: nil, tickerSymbol: nil, isin: nil, countryCode: nil, exchangeCode: nil, sector: nil, notes: "hello")
        XCTAssertTrue(added)
        let details = dbm.fetchInstrumentDetails(id: 1)
        XCTAssertEqual(details?.notes, "hello")
        sqlite3_close(dbm.db)
    }
}
