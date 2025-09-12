import Foundation
import SQLite3

extension DatabaseManager {

    struct TransactionData: Identifiable {
        var id: Int
        var accountId: Int
        var instrumentId: Int?
        var transactionTypeId: Int
        var portfolioId: Int?
        var transactionDate: Date
        var valueDate: Date?
        var bookingDate: Date?
        var quantity: Double?
        var price: Double?
        var grossAmount: Double?
        var fee: Double?
        var tax: Double?
        var netAmount: Double
        var transactionCurrency: String
        var exchangeRateToChf: Double
        var amountChf: Double
        var importSource: String
        var importSessionId: Int?
        var externalReference: String?
        var orderReference: String?
        var description: String?
        var notes: String?
    }

    // MARK: - Helpers
    private func findTransactionTypeId(code: String) -> Int? {
        let sql = "SELECT transaction_type_id FROM TransactionTypes WHERE type_code = ? COLLATE NOCASE LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, code, -1, nil)
        if sqlite3_step(stmt) == SQLITE_ROW { return Int(sqlite3_column_int(stmt, 0)) }
        return nil
    }

    private func latestFxRateToChf(code: String, on date: Date) -> Double? {
        return fetchExchangeRates(currencyCode: code, upTo: date).first?.rateToChf
    }

    /// Current quantity for given account+instrument up to and including date.
    private func currentQuantity(accountId: Int, instrumentId: Int, upTo date: Date) -> Double {
        let dateStr = DateFormatter.iso8601DateOnly.string(from: date)
        let sql = """
            SELECT COALESCE(SUM(CASE
                       WHEN tt.type_code IN ('BUY','TRANSFER_IN') THEN t.quantity
                       WHEN tt.type_code IN ('SELL','TRANSFER_OUT') THEN -t.quantity
                       ELSE 0 END), 0)
              FROM Transactions t
              JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
             WHERE t.account_id = ? AND t.instrument_id = ? AND t.transaction_date <= ?;
        """
        var stmt: OpaquePointer?
        var qty: Double = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(accountId))
            sqlite3_bind_int(stmt, 2, Int32(instrumentId))
            sqlite3_bind_text(stmt, 3, dateStr, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { qty = sqlite3_column_double(stmt, 0) }
        }
        sqlite3_finalize(stmt)
        return qty
    }

    // MARK: - CRUD
    func addTransaction(
        accountId: Int,
        instrumentId: Int?,
        transactionTypeId: Int,
        transactionDate: Date,
        quantity: Double?,
        price: Double?,
        grossAmount: Double?,
        fee: Double?,
        tax: Double?,
        netAmount: Double,
        transactionCurrency: String,
        portfolioId: Int? = nil,
        valueDate: Date? = nil,
        bookingDate: Date? = nil,
        importSource: String = "manual",
        importSessionId: Int? = nil,
        externalReference: String? = nil,
        orderReference: String? = nil,
        description: String? = nil,
        notes: String? = nil
    ) -> Int? {
        guard let rate = latestFxRateToChf(code: transactionCurrency, on: transactionDate) ?? (transactionCurrency.uppercased() == "CHF" ? 1.0 : nil) else {
            print("❌ No FX rate for \(transactionCurrency) on/before \(transactionDate)")
            return nil
        }
        let amountChf = netAmount * rate
        let sql = """
            INSERT INTO Transactions (
                account_id, instrument_id, transaction_type_id, portfolio_id,
                transaction_date, value_date, booking_date,
                quantity, price, gross_amount, fee, tax, net_amount,
                transaction_currency, exchange_rate_to_chf, amount_chf,
                import_source, import_session_id, external_reference, order_reference,
                description, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare addTransaction: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(accountId))
        if let iid = instrumentId { sqlite3_bind_int(stmt, 2, Int32(iid)) } else { sqlite3_bind_null(stmt, 2) }
        sqlite3_bind_int(stmt, 3, Int32(transactionTypeId))
        if let pid = portfolioId { sqlite3_bind_int(stmt, 4, Int32(pid)) } else { sqlite3_bind_null(stmt, 4) }
        sqlite3_bind_text(stmt, 5, DateFormatter.iso8601DateOnly.string(from: transactionDate), -1, T)
        if let d = valueDate { sqlite3_bind_text(stmt, 6, DateFormatter.iso8601DateOnly.string(from: d), -1, T) } else { sqlite3_bind_null(stmt, 6) }
        if let d = bookingDate { sqlite3_bind_text(stmt, 7, DateFormatter.iso8601DateOnly.string(from: d), -1, T) } else { sqlite3_bind_null(stmt, 7) }
        if let q = quantity { sqlite3_bind_double(stmt, 8, q) } else { sqlite3_bind_null(stmt, 8) }
        if let p = price { sqlite3_bind_double(stmt, 9, p) } else { sqlite3_bind_null(stmt, 9) }
        if let g = grossAmount { sqlite3_bind_double(stmt, 10, g) } else { sqlite3_bind_null(stmt, 10) }
        if let f = fee { sqlite3_bind_double(stmt, 11, f) } else { sqlite3_bind_null(stmt, 11) }
        if let t = tax { sqlite3_bind_double(stmt, 12, t) } else { sqlite3_bind_null(stmt, 12) }
        sqlite3_bind_double(stmt, 13, netAmount)
        sqlite3_bind_text(stmt, 14, transactionCurrency, -1, T)
        sqlite3_bind_double(stmt, 15, rate)
        sqlite3_bind_double(stmt, 16, amountChf)
        sqlite3_bind_text(stmt, 17, importSource, -1, T)
        if let sid = importSessionId { sqlite3_bind_int(stmt, 18, Int32(sid)) } else { sqlite3_bind_null(stmt, 18) }
        if let ext = externalReference { sqlite3_bind_text(stmt, 19, ext, -1, T) } else { sqlite3_bind_null(stmt, 19) }
        if let ord = orderReference { sqlite3_bind_text(stmt, 20, ord, -1, T) } else { sqlite3_bind_null(stmt, 20) }
        if let desc = description { sqlite3_bind_text(stmt, 21, desc, -1, T) } else { sqlite3_bind_null(stmt, 21) }
        if let n = notes { sqlite3_bind_text(stmt, 22, n, -1, T) } else { sqlite3_bind_null(stmt, 22) }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ addTransaction step failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        return Int(sqlite3_last_insert_rowid(db))
    }

    func deleteTransaction(id: Int) -> Bool {
        let sql = "DELETE FROM Transactions WHERE transaction_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    /// Create a paired BUY/SELL trade: (position leg + cash leg) atomically.
    /// Enforces currency match and non-negative holdings.
    func createPairedTrade(
        typeCode: String, // "BUY" or "SELL"
        instrumentId: Int,
        securitiesAccountId: Int,
        cashAccountId: Int,
        date: Date,
        quantity: Double,
        price: Double,
        fee: Double?,
        tax: Double?,
        description: String?
    ) -> Bool {
        guard let instrument = fetchInstrumentDetails(id: instrumentId) else { return false }
        guard let sec = fetchAccountDetails(id: securitiesAccountId), let cash = fetchAccountDetails(id: cashAccountId) else { return false }
        let currency = instrument.currency.uppercased()
        guard sec.currencyCode.uppercased() == currency && cash.currencyCode.uppercased() == currency else {
            print("❌ Currency mismatch: instrument/account/cash must be \(currency)")
            return false
        }
        // Negative holdings guard for SELL
        if typeCode.uppercased() == "SELL" {
            let cur = currentQuantity(accountId: securitiesAccountId, instrumentId: instrumentId, upTo: date)
            if cur - quantity < -1e-8 { // allow tiny epsilon
                print("❌ Would create negative holding: have \(cur), trying to sell \(quantity)")
                return false
            }
        }
        let orderRef = UUID().uuidString
        let gross = quantity * price
        let f = fee ?? 0
        let tx = tax ?? 0
        let posTypeId = findTransactionTypeId(code: typeCode)!
        let cashTypeCode = (typeCode.uppercased() == "BUY") ? "WITHDRAWAL" : "DEPOSIT"
        guard let cashTypeId = findTransactionTypeId(code: cashTypeCode) else {
            print("❌ Missing cash type id for \(cashTypeCode)")
            return false
        }
        // Net amounts from account perspective
        // BUY: net negative; SELL: net positive; include fees/taxes on position leg only
        let posNet: Double
        switch typeCode.uppercased() {
        case "BUY": posNet = -(gross + f + tx)
        case "SELL": posNet = +(gross - f - tx)
        default: return false
        }
        // Cash leg mirrors the cash movement
        let cashNet = -posNet

        // Begin atomic insert
        sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil)
        let posId = addTransaction(
            accountId: securitiesAccountId,
            instrumentId: instrumentId,
            transactionTypeId: posTypeId,
            transactionDate: date,
            quantity: quantity,
            price: price,
            grossAmount: gross,
            fee: fee,
            tax: tax,
            netAmount: posNet,
            transactionCurrency: currency,
            orderReference: orderRef,
            description: description
        )
        let cashId = addTransaction(
            accountId: cashAccountId,
            instrumentId: nil,
            transactionTypeId: cashTypeId,
            transactionDate: date,
            quantity: nil,
            price: nil,
            grossAmount: nil,
            fee: nil,
            tax: nil,
            netAmount: cashNet,
            transactionCurrency: currency,
            orderReference: orderRef,
            description: description
        )
        if posId != nil && cashId != nil {
            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
            return true
        } else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return false
        }
    }
    // MARK: - Order reference helpers and paired trade fetch
    func fetchTransactionOrderReference(id: Int) -> String? {
        let sql = "SELECT order_reference FROM Transactions WHERE transaction_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        if sqlite3_step(stmt) == SQLITE_ROW, sqlite3_column_type(stmt, 0) != SQLITE_NULL, let c = sqlite3_column_text(stmt, 0) {
            return String(cString: c)
        }
        return nil
    }

    @discardableResult
    func deleteTransactions(orderReference: String) -> Int {
        let sql = "DELETE FROM Transactions WHERE order_reference = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, orderReference, -1, nil)
        let step = sqlite3_step(stmt)
        if step == SQLITE_DONE { return Int(sqlite3_changes(db)) }
        return 0
    }

    struct PairedTradeDetails {
        var typeCode: String // BUY or SELL
        var instrumentId: Int
        var securitiesAccountId: Int
        var cashAccountId: Int
        var date: Date
        var quantity: Double
        var price: Double
        var fee: Double?
        var tax: Double?
        var description: String?
        var currency: String
        var orderReference: String
    }

    func fetchPairedTradeDetails(transactionId: Int) -> PairedTradeDetails? {
        let sql = """
            SELECT t.transaction_id, t.account_id, t.instrument_id, tt.type_code, t.transaction_date,
                   t.quantity, t.price, t.fee, t.tax, t.net_amount, t.transaction_currency, t.order_reference, t.description
              FROM Transactions t
              JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
             WHERE t.transaction_id = ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(transactionId))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let thisAccountId = Int(sqlite3_column_int(stmt, 1))
        let thisInstrumentId: Int? = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 2)) : nil
        let _ = String(cString: sqlite3_column_text(stmt, 3)) // not used directly
        let dateStr = String(cString: sqlite3_column_text(stmt, 4))
        let thisDate = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? Date()
        let thisQty: Double? = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? sqlite3_column_double(stmt, 5) : nil
        let thisPrice: Double? = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? sqlite3_column_double(stmt, 6) : nil
        let thisFee: Double? = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? sqlite3_column_double(stmt, 7) : nil
        let thisTax: Double? = sqlite3_column_type(stmt, 8) != SQLITE_NULL ? sqlite3_column_double(stmt, 8) : nil
        let thisCurrency = String(cString: sqlite3_column_text(stmt, 10))
        let orderRef = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        let thisDesc = sqlite3_column_text(stmt, 12).map { String(cString: $0) }

        guard let ord = orderRef else { return nil }

        // Fetch both legs by order reference
        let sql2 = """
            SELECT t.transaction_id, t.account_id, t.instrument_id, tt.type_code, t.quantity, t.price
              FROM Transactions t
              JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
             WHERE t.order_reference = ?
        """
        var stmt2: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql2, -1, &stmt2, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt2) }
        sqlite3_bind_text(stmt2, 1, ord, -1, nil)
        var posLeg: (accountId: Int, instrumentId: Int, type: String, qty: Double, price: Double)?
        var cashLegAccount: Int?
        while sqlite3_step(stmt2) == SQLITE_ROW {
            let accId = Int(sqlite3_column_int(stmt2, 1))
            let instr: Int? = sqlite3_column_type(stmt2, 2) != SQLITE_NULL ? Int(sqlite3_column_int(stmt2, 2)) : nil
            let tcode = String(cString: sqlite3_column_text(stmt2, 3))
            let q: Double = sqlite3_column_type(stmt2, 4) != SQLITE_NULL ? sqlite3_column_double(stmt2, 4) : 0
            let p: Double = sqlite3_column_type(stmt2, 5) != SQLITE_NULL ? sqlite3_column_double(stmt2, 5) : 0
            if let iid = instr { posLeg = (accId, iid, tcode, q, p) } else { cashLegAccount = accId }
        }
        guard let pos = posLeg, let cashAcc = cashLegAccount else { return nil }
        let normalizedType = pos.type.uppercased() == "SELL" ? "SELL" : "BUY"
        return PairedTradeDetails(
            typeCode: normalizedType,
            instrumentId: pos.instrumentId,
            securitiesAccountId: pos.accountId,
            cashAccountId: cashAcc,
            date: thisDate,
            quantity: thisQty ?? pos.qty,
            price: thisPrice ?? pos.price,
            fee: thisFee,
            tax: thisTax,
            description: thisDesc,
            currency: thisCurrency,
            orderReference: ord
        )
    }
}
