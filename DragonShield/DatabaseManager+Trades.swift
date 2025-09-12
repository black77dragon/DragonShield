import Foundation
import SQLite3

extension DatabaseManager {

    // MARK: - Ensure schema
    func ensureTradeSchema() {
        guard let db else { return }
        let tradeSQL = """
            CREATE TABLE IF NOT EXISTS Trade (
                trade_id INTEGER PRIMARY KEY AUTOINCREMENT,
                type_code TEXT NOT NULL CHECK(type_code IN('BUY','SELL')),
                trade_date DATE NOT NULL,
                instrument_id INTEGER NOT NULL,
                quantity REAL NOT NULL,
                price_txn REAL NOT NULL,
                currency_code TEXT NOT NULL,
                fees_chf REAL DEFAULT 0,
                commission_chf REAL DEFAULT 0,
                fx_chf_to_txn REAL,
                notes TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id),
                FOREIGN KEY (currency_code) REFERENCES Currencies(currency_code)
            );
        """
        let legSQL = """
            CREATE TABLE IF NOT EXISTS TradeLeg (
                leg_id INTEGER PRIMARY KEY AUTOINCREMENT,
                trade_id INTEGER NOT NULL,
                leg_type TEXT NOT NULL CHECK(leg_type IN('CASH','INSTRUMENT')),
                account_id INTEGER NOT NULL,
                instrument_id INTEGER NOT NULL,
                delta_quantity REAL NOT NULL,
                fx_to_chf REAL,
                amount_chf REAL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(trade_id, leg_type),
                FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE,
                FOREIGN KEY (account_id) REFERENCES Accounts(account_id),
                FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id)
            );
        """
        sqlite3_exec(db, tradeSQL, nil, nil, nil)
        sqlite3_exec(db, legSQL, nil, nil, nil)
        sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_trade_date ON Trade(trade_date);", nil, nil, nil)
        sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_trade_instr ON Trade(instrument_id);", nil, nil, nil)
        sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_tradeleg_account ON TradeLeg(account_id);", nil, nil, nil)
        sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_tradeleg_instr ON TradeLeg(instrument_id);", nil, nil, nil)
    }

    // MARK: - Helpers
    /// Rounds to 4 decimals (half up behavior via formatting then parsing)
    private func round4(_ v: Double) -> Double {
        let f = NumberFormatter(); f.maximumFractionDigits = 4; f.minimumFractionDigits = 0; f.numberStyle = .decimal
        return Double(f.string(from: NSNumber(value: v)) ?? String(format: "%.4f", v)) ?? (v * 10000).rounded() / 10000
    }

    private func cashInstrumentId(for currency: String) -> Int? {
        let sql = """
            SELECT i.instrument_id
              FROM Instruments i
              JOIN AssetSubClasses s ON s.sub_class_id = i.sub_class_id
             WHERE s.sub_class_code = 'CASH' AND i.currency = ?
             LIMIT 1;
        """
        var stmt: OpaquePointer?
        var result: Int? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, currency, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - Create trade (buy/sell)
    struct NewTradeInput {
        var typeCode: String // BUY or SELL
        var date: Date
        var instrumentId: Int
        var quantity: Double
        var priceTxn: Double
        var feesChf: Double
        var commissionChf: Double
        var custodyAccountId: Int
        var cashAccountId: Int
        var notes: String?
    }

    @discardableResult
    func createTrade(_ input: NewTradeInput) -> Int? {
        guard let db else { return nil }
        // Currency from instrument
        guard let instr = fetchInstrumentDetails(id: input.instrumentId) else { return nil }
        let currency = instr.currency.uppercased()
        // Cash account must match currency
        guard let cashAcc = fetchAccountDetails(id: input.cashAccountId), cashAcc.currencyCode.uppercased() == currency else { return nil }
        // FX for CHF fees
        let fx = fetchExchangeRates(currencyCode: currency, upTo: input.date).first?.rateToChf
        let fxChfToTxn: Double = (fx != nil && fx! > 0) ? (1.0 / fx!) : 1.0 // ExchangeRates likely stores rate_to_chf; invert to CHF->txn
        // Round values
        let qty = round4(input.quantity)
        let price = round4(input.priceTxn)
        let tradeValue = round4(qty * price)
        let feesTxn = round4(input.feesChf * fxChfToTxn)
        let commTxn = round4(input.commissionChf * fxChfToTxn)
        let isBuy = input.typeCode.uppercased() == "BUY"
        let cashDelta = isBuy ? -round4(tradeValue + feesTxn + commTxn) : +round4(tradeValue - feesTxn - commTxn)
        let instrDelta = isBuy ? +qty : -qty

        // Atomic write
        sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil)
        // Insert trade
        let insertTrade = """
            INSERT INTO Trade (type_code, trade_date, instrument_id, quantity, price_txn, currency_code, fees_chf, commission_chf, fx_chf_to_txn, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertTrade, -1, &stmt, nil) == SQLITE_OK else { sqlite3_exec(db, "ROLLBACK;", nil, nil, nil); return nil }
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, input.typeCode.uppercased(), -1, T)
        sqlite3_bind_text(stmt, 2, DateFormatter.iso8601DateOnly.string(from: input.date), -1, T)
        sqlite3_bind_int(stmt, 3, Int32(input.instrumentId))
        sqlite3_bind_double(stmt, 4, qty)
        sqlite3_bind_double(stmt, 5, price)
        sqlite3_bind_text(stmt, 6, currency, -1, T)
        sqlite3_bind_double(stmt, 7, round4(input.feesChf))
        sqlite3_bind_double(stmt, 8, round4(input.commissionChf))
        sqlite3_bind_double(stmt, 9, fxChfToTxn)
        if let n = input.notes, !n.isEmpty { sqlite3_bind_text(stmt, 10, n, -1, T) } else { sqlite3_bind_null(stmt, 10) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { sqlite3_finalize(stmt); sqlite3_exec(db, "ROLLBACK;", nil, nil, nil); return nil }
        sqlite3_finalize(stmt)
        let tradeId = Int(sqlite3_last_insert_rowid(db))

        // Insert legs
        func insertLeg(type: String, accountId: Int, instrumentId: Int, delta: Double) -> Bool {
            let sql = """
                INSERT INTO TradeLeg (trade_id, leg_type, account_id, instrument_id, delta_quantity)
                VALUES (?, ?, ?, ?, ?);
            """
            var s: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK else { return false }
            sqlite3_bind_int(s, 1, Int32(tradeId))
            sqlite3_bind_text(s, 2, type, -1, T)
            sqlite3_bind_int(s, 3, Int32(accountId))
            sqlite3_bind_int(s, 4, Int32(instrumentId))
            sqlite3_bind_double(s, 5, delta)
            let ok = sqlite3_step(s) == SQLITE_DONE
            sqlite3_finalize(s)
            return ok
        }

        // Cash leg
        guard let cashInstrId = cashInstrumentId(for: currency) else { sqlite3_exec(db, "ROLLBACK;", nil, nil, nil); return nil }
        guard insertLeg(type: "CASH", accountId: input.cashAccountId, instrumentId: cashInstrId, delta: cashDelta) else { sqlite3_exec(db, "ROLLBACK;", nil, nil, nil); return nil }
        // Instrument leg
        guard insertLeg(type: "INSTRUMENT", accountId: input.custodyAccountId, instrumentId: input.instrumentId, delta: instrDelta) else { sqlite3_exec(db, "ROLLBACK;", nil, nil, nil); return nil }

        sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        return tradeId
    }

    // MARK: - Delete / Rewind
    func deleteTrade(tradeId: Int) -> Bool {
        guard let db else { return false }
        sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil)
        var ok = (sqlite3_exec(db, "DELETE FROM TradeLeg WHERE trade_id = \(tradeId);", nil, nil, nil) == SQLITE_OK)
        ok = ok && (sqlite3_exec(db, "DELETE FROM Trade WHERE trade_id = \(tradeId);", nil, nil, nil) == SQLITE_OK)
        sqlite3_exec(db, ok ? "COMMIT;" : "ROLLBACK;", nil, nil, nil)
        return ok
    }

    /// Rewind by creating a reversing trade with same fields but opposite type and deltas.
    func rewindTrade(tradeId: Int, notesPrefix: String = "Reversal of ") -> Int? {
        // Fetch original header
        let sql = "SELECT type_code, trade_date, instrument_id, quantity, price_txn, currency_code, fees_chf, commission_chf, notes FROM Trade WHERE trade_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_int(stmt, 1, Int32(tradeId))
        guard sqlite3_step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return nil }
        let type = String(cString: sqlite3_column_text(stmt, 0))
        let dateStr = String(cString: sqlite3_column_text(stmt, 1))
        let date = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? Date()
        let instrumentId = Int(sqlite3_column_int(stmt, 2))
        let qty = sqlite3_column_double(stmt, 3)
        let price = sqlite3_column_double(stmt, 4)
        let feesChf = sqlite3_column_double(stmt, 6)
        let commChf = sqlite3_column_double(stmt, 7)
        let oldNotes = sqlite3_column_text(stmt, 8).map { String(cString: $0) } ?? ""
        sqlite3_finalize(stmt)
        let reversedType = (type.uppercased() == "BUY") ? "SELL" : "BUY"

        // Fetch legs to get accounts
        let sqlLegs = "SELECT leg_type, account_id FROM TradeLeg WHERE trade_id = ?"
        var s: OpaquePointer?
        var cashAccId: Int? = nil
        var custodyAccId: Int? = nil
        if sqlite3_prepare_v2(db, sqlLegs, -1, &s, nil) == SQLITE_OK {
            sqlite3_bind_int(s, 1, Int32(tradeId))
            while sqlite3_step(s) == SQLITE_ROW {
                let legType = String(cString: sqlite3_column_text(s, 0))
                let accId = Int(sqlite3_column_int(s, 1))
                if legType == "CASH" { cashAccId = accId } else if legType == "INSTRUMENT" { custodyAccId = accId }
            }
        }
        sqlite3_finalize(s)
        guard let cash = cashAccId, let custody = custodyAccId else { return nil }

        let input = NewTradeInput(typeCode: reversedType, date: date, instrumentId: instrumentId, quantity: qty, priceTxn: price, feesChf: feesChf, commissionChf: commChf, custodyAccountId: custody, cashAccountId: cash, notes: notesPrefix + "#\(tradeId) " + oldNotes)
        return createTrade(input)
    }

    // MARK: - Query for History
    struct TradeWithLegs: Identifiable {
        var id: Int { tradeId }
        let tradeId: Int
        let typeCode: String
        let date: Date
        let instrumentId: Int
        let instrumentName: String
        let currency: String
        let quantity: Double
        let price: Double
        let feesChf: Double
        let commissionChf: Double
        let custodyAccountName: String
        let cashAccountName: String
        let cashDelta: Double
        let instrumentDelta: Double
    }

    func fetchTradesWithLegs(limit: Int = 200) -> [TradeWithLegs] {
        var rows: [TradeWithLegs] = []
        let sql = """
            SELECT t.trade_id, t.type_code, t.trade_date, t.instrument_id, i.instrument_name, t.currency_code,
                   t.quantity, t.price_txn, t.fees_chf, t.commission_chf,
                   (SELECT a.account_name FROM TradeLeg l JOIN Accounts a ON a.account_id = l.account_id WHERE l.trade_id = t.trade_id AND l.leg_type='INSTRUMENT') AS custody_name,
                   (SELECT a.account_name FROM TradeLeg l JOIN Accounts a ON a.account_id = l.account_id WHERE l.trade_id = t.trade_id AND l.leg_type='CASH') AS cash_name,
                   (SELECT delta_quantity FROM TradeLeg l WHERE l.trade_id = t.trade_id AND l.leg_type='CASH') AS cash_delta,
                   (SELECT delta_quantity FROM TradeLeg l WHERE l.trade_id = t.trade_id AND l.leg_type='INSTRUMENT') AS instr_delta
              FROM Trade t
              JOIN Instruments i ON i.instrument_id = t.instrument_id
             ORDER BY t.trade_date DESC, t.trade_id DESC
             LIMIT ?
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let type = String(cString: sqlite3_column_text(stmt, 1))
                let dstr = String(cString: sqlite3_column_text(stmt, 2))
                let date = DateFormatter.iso8601DateOnly.date(from: dstr) ?? Date()
                let instrId = Int(sqlite3_column_int(stmt, 3))
                let instrName = String(cString: sqlite3_column_text(stmt, 4))
                let curr = String(cString: sqlite3_column_text(stmt, 5))
                let qty = sqlite3_column_double(stmt, 6)
                let price = sqlite3_column_double(stmt, 7)
                let fees = sqlite3_column_double(stmt, 8)
                let comm = sqlite3_column_double(stmt, 9)
                let custody = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? ""
                let cash = sqlite3_column_text(stmt, 11).map { String(cString: $0) } ?? ""
                let cashDelta = sqlite3_column_double(stmt, 12)
                let instrDelta = sqlite3_column_double(stmt, 13)
                rows.append(TradeWithLegs(tradeId: id, typeCode: type, date: date, instrumentId: instrId, instrumentName: instrName, currency: curr, quantity: qty, price: price, feesChf: fees, commissionChf: comm, custodyAccountName: custody, cashAccountName: cash, cashDelta: cashDelta, instrumentDelta: instrDelta))
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }
}

