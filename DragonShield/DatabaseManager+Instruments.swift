import Foundation
import SQLite3

extension DatabaseManager {
    struct InstrumentRow: Identifiable {
        var id: Int
        var name: String
        var currency: String
        var subClassId: Int
        var tickerSymbol: String?
        var isin: String?
        var valorNr: String?
    }

    func fetchAssets() -> [InstrumentRow] {
        var rows: [InstrumentRow] = []
        let sql = """
            SELECT instrument_id,
                   instrument_name,
                   currency,
                   sub_class_id,
                   ticker_symbol,
                   isin,
                   valor_nr
              FROM Instruments
             WHERE is_active = 1
             ORDER BY instrument_name COLLATE NOCASE
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let currency = String(cString: sqlite3_column_text(stmt, 2))
            let subClassId = Int(sqlite3_column_int(stmt, 3))
            let ticker = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let isin = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let valor = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            rows.append(InstrumentRow(id: id, name: name, currency: currency, subClassId: subClassId, tickerSymbol: ticker, isin: isin, valorNr: valor))
        }
        return rows
    }
    func getInstrumentName(id: Int) -> String? {
        let sql = "SELECT instrument_name FROM Instruments WHERE instrument_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        if sqlite3_step(stmt) == SQLITE_ROW, let cstr = sqlite3_column_text(stmt, 0) {
            return String(cString: cstr)
        }
        return nil
    }

    struct InstrumentDetails {
        var id: Int
        var name: String
        var subClassId: Int
        var currency: String
        var valorNr: String?
        var tickerSymbol: String?
        var isin: String?
        var sector: String?
    }

    func fetchInstrumentDetails(id: Int) -> InstrumentDetails? {
        let sql = """
            SELECT instrument_id, instrument_name, sub_class_id, currency, valor_nr, ticker_symbol, isin, sector
              FROM Instruments
             WHERE instrument_id = ?
             LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        if sqlite3_step(stmt) == SQLITE_ROW {
            let iid = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let subClassId = Int(sqlite3_column_int(stmt, 2))
            let currency = String(cString: sqlite3_column_text(stmt, 3))
            let valor = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let ticker = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let isin = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let sector = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            return InstrumentDetails(id: iid, name: name, subClassId: subClassId, currency: currency, valorNr: valor, tickerSymbol: ticker, isin: isin, sector: sector)
        }
        return nil
    }

    @discardableResult
    func addInstrument(
        name: String,
        subClassId: Int,
        currency: String,
        valorNr: String?,
        tickerSymbol: String?,
        isin: String?,
        countryCode: String?,
        exchangeCode: String?,
        sector: String?
    ) -> Bool {
        let sql = """
            INSERT INTO Instruments (
                instrument_name, sub_class_id, currency, valor_nr, ticker_symbol, isin, country_code, exchange_code, sector, include_in_portfolio, is_active, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(subClassId))
        sqlite3_bind_text(stmt, 3, currency, -1, SQLITE_TRANSIENT)
        if let v = valorNr { sqlite3_bind_text(stmt, 4, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        if let v = tickerSymbol { sqlite3_bind_text(stmt, 5, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 5) }
        if let v = isin { sqlite3_bind_text(stmt, 6, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 6) }
        if let v = countryCode { sqlite3_bind_text(stmt, 7, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 7) }
        if let v = exchangeCode { sqlite3_bind_text(stmt, 8, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 8) }
        if let v = sector { sqlite3_bind_text(stmt, 9, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 9) }
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    @discardableResult
    func updateInstrument(
        id: Int,
        name: String,
        subClassId: Int,
        currency: String,
        valorNr: String?,
        tickerSymbol: String?,
        isin: String?,
        sector: String?
    ) -> Bool {
        let sql = """
            UPDATE Instruments
               SET instrument_name = ?,
                   sub_class_id = ?,
                   currency = ?,
                   valor_nr = ?,
                   ticker_symbol = ?,
                   isin = ?,
                   sector = ?,
                   updated_at = CURRENT_TIMESTAMP
             WHERE instrument_id = ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(subClassId))
        sqlite3_bind_text(stmt, 3, currency, -1, SQLITE_TRANSIENT)
        if let v = valorNr { sqlite3_bind_text(stmt, 4, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        if let v = tickerSymbol { sqlite3_bind_text(stmt, 5, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 5) }
        if let v = isin { sqlite3_bind_text(stmt, 6, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 6) }
        if let v = sector { sqlite3_bind_text(stmt, 7, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 7) }
        sqlite3_bind_int(stmt, 8, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    @discardableResult
    func deleteInstrument(id: Int) -> Bool {
        let sql = "DELETE FROM Instruments WHERE instrument_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    // MARK: - Lookups
    func findInstrumentId(valorNr: String) -> Int? {
        let sql = "SELECT instrument_id FROM Instruments WHERE valor_nr = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, valorNr, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW { return Int(sqlite3_column_int(stmt, 0)) }
        return nil
    }

    func findInstrumentId(isin: String) -> Int? {
        let sql = "SELECT instrument_id FROM Instruments WHERE isin = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, isin, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW { return Int(sqlite3_column_int(stmt, 0)) }
        return nil
    }

    func findInstrumentId(ticker: String) -> Int? {
        let sql = "SELECT instrument_id FROM Instruments WHERE UPPER(ticker_symbol) = UPPER(?) LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, ticker, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_ROW { return Int(sqlite3_column_int(stmt, 0)) }
        return nil
    }
}
