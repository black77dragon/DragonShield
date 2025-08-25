// DragonShield/DatabaseManager+Instruments.swift
// MARK: - Version 1.0 (2025-05-30)
// MARK: - History
// - Initial creation: Refactored from DatabaseManager.swift.

import SQLite3
import Foundation

extension DatabaseManager {
    
    func fetchAssets() -> [(id: Int, name: String, subClassId: Int, currency: String, valorNr: String?, tickerSymbol: String?, isin: String?, notes: String?)] {
        var instruments: [(id: Int, name: String, subClassId: Int, currency: String, valorNr: String?, tickerSymbol: String?, isin: String?, notes: String?)] = []

        let query = """
            SELECT instrument_id, instrument_name, sub_class_id, currency, valor_nr, ticker_symbol, isin, notes
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
                
                let valorNr: String?
                if let valorPtr = sqlite3_column_text(statement, 4) {
                    let valorValue = String(cString: valorPtr)
                    valorNr = valorValue.isEmpty ? nil : valorValue
                } else {
                    valorNr = nil
                }

                let tickerSymbol: String?
                if let tickerPtr = sqlite3_column_text(statement, 5) {
                    let tickerValue = String(cString: tickerPtr)
                    tickerSymbol = tickerValue.isEmpty ? nil : tickerValue
                } else {
                    tickerSymbol = nil
                }

                let isin: String?
                if let isinPtr = sqlite3_column_text(statement, 6) {
                    let isinValue = String(cString: isinPtr)
                    isin = isinValue.isEmpty ? nil : isinValue
                } else {
                    isin = nil
                }

                let notes: String?
                if let notesPtr = sqlite3_column_text(statement, 7) {
                    let notesValue = String(cString: notesPtr)
                    notes = notesValue.isEmpty ? nil : notesValue
                } else {
                    notes = nil
                }

                instruments.append((id: id, name: name, subClassId: subClassId, currency: currency, valorNr: valorNr, tickerSymbol: tickerSymbol, isin: isin, notes: notes))
            }
        } else {
            print("❌ Failed to prepare fetchAssets: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return instruments
    }
    
    func addInstrument(name: String, subClassId: Int, currency: String, valorNr: String?, tickerSymbol: String?, isin: String?, countryCode: String?, exchangeCode: String?, sector: String?, notes: String?) -> Bool {
        let query = """
            INSERT INTO Instruments (instrument_name, sub_class_id, currency, valor_nr, ticker_symbol, isin, sector, notes, is_active)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
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

        if let valor = valorNr, !valor.isEmpty {
            _ = valor.withCString { valorPtr in
                sqlite3_bind_text(statement, 4, valorPtr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 4)
        }

        if let ticker = tickerSymbol, !ticker.isEmpty {
            _ = ticker.withCString { tickerPtr in
                sqlite3_bind_text(statement, 5, tickerPtr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let isinCode = isin, !isinCode.isEmpty {
            _ = isinCode.withCString { isinPtr in
                sqlite3_bind_text(statement, 6, isinPtr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 6)
        }

        if let sectorName = sector, !sectorName.isEmpty {
            _ = sectorName.withCString { sectorPtr in
                sqlite3_bind_text(statement, 7, sectorPtr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if let n = notes, !n.isEmpty {
            _ = n.withCString { sqlite3_bind_text(statement, 8, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 8)
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

    /// Inserts a new instrument and returns the generated row ID on success.
    func addInstrumentReturningId(name: String, subClassId: Int, currency: String, valorNr: String?, tickerSymbol: String?, isin: String?, countryCode: String?, exchangeCode: String?, sector: String?, notes: String?) -> Int? {
        let query = """
            INSERT INTO Instruments (instrument_name, sub_class_id, currency, valor_nr, ticker_symbol, isin, sector, notes, is_active)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("Failed to prepare insert instrument: \(error)", type: .error, logger: .database)
            return nil
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        _ = name.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 2, Int32(subClassId))
        _ = currency.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }

        if let valor = valorNr, !valor.isEmpty {
            _ = valor.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 4)
        }

        if let ticker = tickerSymbol, !ticker.isEmpty {
            _ = ticker.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let isinCode = isin, !isinCode.isEmpty {
            _ = isinCode.withCString { sqlite3_bind_text(statement, 6, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 6)
        }

        if let sectorName = sector, !sectorName.isEmpty {
            _ = sectorName.withCString { sqlite3_bind_text(statement, 7, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if let n = notes, !n.isEmpty {
            _ = n.withCString { sqlite3_bind_text(statement, 8, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 8)
        }

        let success = sqlite3_step(statement) == SQLITE_DONE
        let insertedId = success ? Int(sqlite3_last_insert_rowid(db)) : nil
        sqlite3_finalize(statement)

        if let id = insertedId {
            LoggingService.shared.log("Inserted instrument \(name) with ID \(id)", type: .info, logger: .database)
        } else {
            LoggingService.shared.log("Insert instrument \(name) failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }

        return insertedId
    }
    
    func updateInstrument(id: Int, name: String, subClassId: Int, currency: String, valorNr: String?, tickerSymbol: String?, isin: String?, sector: String?, notes: String?) -> Bool {
        let query = """
            UPDATE Instruments
            SET instrument_name = ?, sub_class_id = ?, currency = ?, valor_nr = ?, ticker_symbol = ?, isin = ?, sector = ?, notes = ?, updated_at = CURRENT_TIMESTAMP
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

        if let valor = valorNr, !valor.isEmpty {
            _ = valor.withCString { valorPtr in sqlite3_bind_text(statement, 4, valorPtr, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 4)
        }

        if let ticker = tickerSymbol, !ticker.isEmpty {
            _ = ticker.withCString { tickerPtr in sqlite3_bind_text(statement, 5, tickerPtr, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let isinCode = isin, !isinCode.isEmpty {
            _ = isinCode.withCString { isinPtr in sqlite3_bind_text(statement, 6, isinPtr, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 6)
        }

        if let sectorName = sector, !sectorName.isEmpty {
            _ = sectorName.withCString { sectorPtr in sqlite3_bind_text(statement, 7, sectorPtr, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if let n = notes, !n.isEmpty {
            _ = n.withCString { notesPtr in sqlite3_bind_text(statement, 8, notesPtr, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 8)
        }

        sqlite3_bind_int(statement, 9, Int32(id))
        
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
    
    func fetchInstrumentDetails(id: Int) -> (id: Int, name: String, subClassId: Int, currency: String, valorNr: String?, tickerSymbol: String?, isin: String?, countryCode: String?, exchangeCode: String?, sector: String?, notes: String?)? {
        let query = """
            SELECT instrument_id, instrument_name, sub_class_id, currency, valor_nr, ticker_symbol, isin, sector, notes
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

                let valorNr: String? = sqlite3_column_text(statement, 4).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
                let tickerSymbol: String? = sqlite3_column_text(statement, 5).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
                let isin: String? = sqlite3_column_text(statement, 6).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
                let sector: String? = sqlite3_column_text(statement, 7).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }
                let notes: String? = sqlite3_column_text(statement, 8).map { String(cString: $0) }.flatMap { $0.isEmpty ? nil : $0 }

                sqlite3_finalize(statement)
                return (id: instrumentId, name: instrumentName, subClassId: subClassId, currency: currency, valorNr: valorNr, tickerSymbol: tickerSymbol, isin: isin, countryCode: nil, exchangeCode: nil, sector: sector, notes: notes)
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

    /// Finds the instrument_id for the given Valoren number.
    /// The lookup strips non-alphanumeric characters for resilience.
    func findInstrumentId(valorNr: String) -> Int? {
        let sanitizedSearch = valorNr.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { String($0) }
            .joined()
        let query = "SELECT instrument_id, valor_nr FROM Instruments WHERE valor_nr IS NOT NULL;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            LoggingService.shared.log("Failed to prepare findInstrumentId(valorNr): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            guard let valPtr = sqlite3_column_text(statement, 1) else { continue }
            let dbValor = String(cString: valPtr)
            let sanitizedDb = dbValor.unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .map { String($0) }
                .joined()
            if sanitizedDb.uppercased() == sanitizedSearch.uppercased() {
                LoggingService.shared.log("findInstrumentId(valorNr) found id=\(id) for sanitized=\(sanitizedSearch)", type: .debug, logger: .database)
                return id
            }
        }
        LoggingService.shared.log("findInstrumentId(valorNr) no match for sanitized=\(sanitizedSearch)", type: .debug, logger: .database)
        return nil
    }

    /// Finds the `instrument_id` for the given ticker symbol.
    /// The lookup strips non-alphanumeric characters and ignores case so
    /// variations like `CASH_CHF` or `cashchf` still match `CASHCHF`.
    func findInstrumentId(ticker: String) -> Int? {
        let sanitizedSearch = ticker.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { String($0) }
            .joined()
            .lowercased()

        let query = "SELECT instrument_id, ticker_symbol FROM Instruments WHERE ticker_symbol IS NOT NULL;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            LoggingService.shared.log("Failed to prepare findInstrumentId(ticker): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            guard let tickerPtr = sqlite3_column_text(statement, 1) else { continue }
            let dbTicker = String(cString: tickerPtr)
            let sanitizedDb = dbTicker.unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
                .map { String($0) }
                .joined()
                .lowercased()
            LoggingService.shared.log(
                "findInstrumentId(ticker) check id=\(id) ticker=\(dbTicker) sanitized=\(sanitizedDb)",
                type: .debug, logger: .database
            )
            if sanitizedDb == sanitizedSearch {
                LoggingService.shared.log("findInstrumentId(ticker) found id=\(id) for sanitized=\(sanitizedSearch)", type: .debug, logger: .database)
                return id
            }
        }
        LoggingService.shared.log("findInstrumentId(ticker) no match for sanitized=\(sanitizedSearch)", type: .debug, logger: .database)
        return nil
    }
}
