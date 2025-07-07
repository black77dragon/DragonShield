// DragonShield/DatabaseManager+Instruments.swift
// MARK: - Version 1.0 (2025-05-30)
// MARK: - History
// - Initial creation: Refactored from DatabaseManager.swift.

import SQLite3
import Foundation

extension DatabaseManager {
    
    func fetchAssets() -> [(id: Int, name: String, subClassId: Int, currency: String, tickerSymbol: String?, isin: String?)] {
        var instruments: [(id: Int, name: String, subClassId: Int, currency: String, tickerSymbol: String?, isin: String?)] = []
        
        let query = """
            SELECT instrument_id, instrument_name, sub_class_id, currency, ticker_symbol, isin
            FROM Instruments
            WHERE is_active = 1 AND instrument_name IS NOT NULL AND instrument_name != ''
            ORDER BY instrument_name
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                
                guard let namePtr = sqlite3_column_text(statement, 1) else { continue }
                let name = String(cString: namePtr)
                
                let subClassId = Int(sqlite3_column_int(statement, 2))
                
                guard let currencyPtr = sqlite3_column_text(statement, 3) else { continue }
                let currency = String(cString: currencyPtr)
                
                let tickerSymbol: String?
                if let tickerPtr = sqlite3_column_text(statement, 4) {
                    let tickerValue = String(cString: tickerPtr)
                    tickerSymbol = tickerValue.isEmpty ? nil : tickerValue
                } else {
                    tickerSymbol = nil
                }
                
                let isin: String?
                if let isinPtr = sqlite3_column_text(statement, 5) {
                    let isinValue = String(cString: isinPtr)
                    isin = isinValue.isEmpty ? nil : isinValue
                } else {
                    isin = nil
                }
                
                instruments.append((id: id, name: name, subClassId: subClassId, currency: currency, tickerSymbol: tickerSymbol, isin: isin))
            }
        } else {
            print("❌ Failed to prepare fetchAssets: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return instruments
    }
    
    func addInstrument(name: String, subClassId: Int, currency: String, tickerSymbol: String?, isin: String?, countryCode: String?, exchangeCode: String?, sector: String?) -> Bool {
        let query = """
            INSERT INTO Instruments (instrument_name, sub_class_id, currency, ticker_symbol, isin, sector, is_active)
            VALUES (?, ?, ?, ?, ?, ?, 1)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare insert instrument: \(error)")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        _ = name.withCString { namePtr in
            sqlite3_bind_text(statement, 1, namePtr, -1, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int(statement, 2, Int32(subClassId))
        _ = currency.withCString { currencyPtr in
            sqlite3_bind_text(statement, 3, currencyPtr, -1, SQLITE_TRANSIENT)
        }
        
        if let ticker = tickerSymbol, !ticker.isEmpty {
            _ = ticker.withCString { tickerPtr in
                sqlite3_bind_text(statement, 4, tickerPtr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 4)
        }
        
        if let isinCode = isin, !isinCode.isEmpty {
            _ = isinCode.withCString { isinPtr in
                sqlite3_bind_text(statement, 5, isinPtr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 5)
        }
        
        if let sectorName = sector, !sectorName.isEmpty {
            _ = sectorName.withCString { sectorPtr in
                sqlite3_bind_text(statement, 6, sectorPtr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 6)
        }
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            let lastId = sqlite3_last_insert_rowid(db)
            print("✅ Inserted instrument with ID: \(lastId)")
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ Insert instrument failed: \(error)")
        }
        
        return result
    }
    
    func updateInstrument(id: Int, name: String, subClassId: Int, currency: String, tickerSymbol: String?, isin: String?, sector: String?) -> Bool {
        let query = """
            UPDATE Instruments
            SET instrument_name = ?, sub_class_id = ?, currency = ?, ticker_symbol = ?, isin = ?, sector = ?, updated_at = CURRENT_TIMESTAMP
            WHERE instrument_id = ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare update instrument: \(error)")
            return false
        }
        
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        
        _ = name.withCString { namePtr in sqlite3_bind_text(statement, 1, namePtr, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 2, Int32(subClassId))
        _ = currency.withCString { currencyPtr in sqlite3_bind_text(statement, 3, currencyPtr, -1, SQLITE_TRANSIENT) }
        
        if let ticker = tickerSymbol, !ticker.isEmpty {
            _ = ticker.withCString { tickerPtr in sqlite3_bind_text(statement, 4, tickerPtr, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 4)
        }
        
        if let isinCode = isin, !isinCode.isEmpty {
            _ = isinCode.withCString { isinPtr in sqlite3_bind_text(statement, 5, isinPtr, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 5)
        }
        
        if let sectorName = sector, !sectorName.isEmpty {
            _ = sectorName.withCString { sectorPtr in sqlite3_bind_text(statement, 6, sectorPtr, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 6)
        }
        
        sqlite3_bind_int(statement, 7, Int32(id))
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Updated instrument successfully (ID: \(id))")
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ Update instrument failed (ID: \(id)): \(error)")
        }
        
        return result
    }
    
    func deleteInstrument(id: Int) -> Bool {
        let query = "UPDATE Instruments SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE instrument_id = ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare delete instrument (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            print("✅ Soft deleted instrument (ID: \(id))")
        } else {
            print("❌ Soft delete instrument failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }
    
    func fetchInstrumentDetails(id: Int) -> (id: Int, name: String, subClassId: Int, currency: String, tickerSymbol: String?, isin: String?, countryCode: String?, exchangeCode: String?, sector: String?)? {
        let query = """
            SELECT instrument_id, instrument_name, sub_class_id, currency, ticker_symbol, isin, sector
            FROM Instruments
            WHERE instrument_id = ?
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let instrumentId = Int(sqlite3_column_int(statement, 0))
                let instrumentName = String(cString: sqlite3_column_text(statement, 1))
                let subClassId = Int(sqlite3_column_int(statement, 2))
                let currency = String(cString: sqlite3_column_text(statement, 3))
                
                let tickerSymbol: String? = sqlite3_column_text(statement, 4).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
                let isin: String? = sqlite3_column_text(statement, 5).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
                let sector: String? = sqlite3_column_text(statement, 6).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
                
                sqlite3_finalize(statement)
                return (id: instrumentId, name: instrumentName, subClassId: subClassId, currency: currency, tickerSymbol: tickerSymbol, isin: isin, countryCode: nil, exchangeCode: nil, sector: sector)
            } else {
                 print("ℹ️ No instrument details found for ID: \(id)")
            }
        } else {
            print("❌ Failed to prepare fetchInstrumentDetails (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return nil
    }

    /// Finds the instrument_id for the given ISIN if present.
    /// Finds the instrument_id for the given ISIN. The lookup ignores
    /// case and non-alphanumeric characters to better match data coming
    /// from spreadsheets that may use different formatting.
    func findInstrumentId(isin: String) -> Int? {
        let sanitizedSearch = isin.uppercased().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { String($0) }
            .joined()
        let query = "SELECT instrument_id, isin FROM Instruments WHERE isin IS NOT NULL;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare findInstrumentId: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            guard let isinPtr = sqlite3_column_text(statement, 1) else { continue }
            let dbIsin = String(cString: isinPtr)
            let sanitizedDb = dbIsin.uppercased().unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .map { String($0) }
                .joined()
            if sanitizedDb == sanitizedSearch {
                return id
            }
        }
        return nil
    }

    /// Finds the instrument_id for the given ticker symbol, ignoring case.
    func findInstrumentId(ticker: String) -> Int? {
        let query = "SELECT instrument_id FROM Instruments WHERE ticker_symbol = ? COLLATE NOCASE LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare findInstrumentId(ticker): \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, ticker, -1, nil)
        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        return nil
    }
}
