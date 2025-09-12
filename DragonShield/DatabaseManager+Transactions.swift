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
        let sql = "SELECT transaction_type_id FROM TransactionTypes WHERE UPPER(TRIM(type_code)) = UPPER(TRIM(?)) LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let cstr = (code as NSString).utf8String {
            sqlite3_bind_text(stmt, 1, cstr, -1, SQLITE_TRANSIENT)
        }
        if sqlite3_step(stmt) == SQLITE_ROW { return Int(sqlite3_column_int(stmt, 0)) }
        return nil
    }

    private func latestFxRateToChf(code: String, on date: Date) -> Double? {
        return fetchExchangeRates(currencyCode: code, upTo: date).first?.rateToChf
    }

    private func accountTypeCode(for id: Int) -> String? {
        let sql = "SELECT type_code FROM AccountTypes WHERE account_type_id = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
            return String(cString: c)
        }
        return nil
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

    /// Public: Holding quantity for an account+instrument up to a date (inclusive).
    func getHoldingQuantity(accountId: Int, instrumentId: Int, upTo date: Date) -> Double {
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

    /// Public: Cash balance for an account up to a date (inclusive).
    func getCashBalance(accountId: Int, upTo date: Date) -> Double {
        let dateStr = DateFormatter.iso8601DateOnly.string(from: date)
        let sql = "SELECT COALESCE(SUM(net_amount),0) FROM Transactions WHERE account_id = ? AND transaction_date <= ?;"
        var stmt: OpaquePointer?
        var total: Double = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(accountId))
            sqlite3_bind_text(stmt, 2, dateStr, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { total = sqlite3_column_double(stmt, 0) }
        }
        sqlite3_finalize(stmt)
        return total
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
            let msg = "No FX rate for \(transactionCurrency) on or before \(DateFormatter.iso8601DateOnly.string(from: transactionDate))."
            print("❌ \(msg)")
            self.lastTransactionErrorMessage = msg
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
            let msg = "Failed to prepare addTransaction: \(String(cString: sqlite3_errmsg(db)))"
            print("❌ \(msg)")
            self.lastTransactionErrorMessage = msg
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
            let msg = "addTransaction step failed: \(String(cString: sqlite3_errmsg(db)))"
            print("❌ \(msg)")
            self.lastTransactionErrorMessage = msg
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

    private func ensureCoreTransactionTypes() {
        // Ensure required core types exist (idempotent)
        func ensure(_ code: String, _ name: String, _ desc: String, _ affectsPosition: Bool, _ affectsCash: Bool, _ isIncome: Bool, _ sort: Int) {
            if findTransactionTypeId(code: code) == nil {
                _ = updateTransactionType // no-op to silence unused warning if signature changes
                // Use TransactionTypes helper via extension defined elsewhere
                _ = self.addTransactionType(code: code, name: name, description: desc, affectsPosition: affectsPosition, affectsCash: affectsCash, isIncome: isIncome, sortOrder: sort)
            }
        }
        ensure("BUY", "Purchase", "Buy securities or assets", true, true, false, 1)
        ensure("SELL", "Sale", "Sell securities or assets", true, true, false, 2)
        ensure("DIVIDEND", "Dividend", "Dividend payment received", false, true, true, 3)
        ensure("INTEREST", "Interest", "Interest payment received", false, true, true, 4)
        ensure("FEE", "Fee", "Transaction or management fee", false, true, false, 5)
        ensure("TAX", "Tax", "Withholding or other taxes", false, true, false, 6)
        ensure("DEPOSIT", "Cash Deposit", "Cash deposit to account", false, true, false, 7)
        ensure("WITHDRAWAL", "Cash Withdrawal", "Cash withdrawal from account", false, true, false, 8)
        ensure("TRANSFER_IN", "Transfer In", "Securities transferred into account", true, false, false, 9)
        ensure("TRANSFER_OUT", "Transfer Out", "Securities transferred out of account", true, false, false, 10)
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
        // Allow custody account as securities account to ignore currency, but enforce cash account currency match
        let secType = accountTypeCode(for: sec.accountTypeId)?.uppercased()
        let secCurrencyOk = (secType == "CUSTODY") || (sec.currencyCode.uppercased() == currency)
        let cashCurrencyOk = (cash.currencyCode.uppercased() == currency)
        guard secCurrencyOk && cashCurrencyOk else {
            let msg = !cashCurrencyOk
                ? "Cash account currency must be \(currency)."
                : "Securities account currency must be \(currency) unless account type is CUSTODY."
            print("❌ \(msg)")
            self.lastTransactionErrorMessage = msg
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
        // Be defensive: core types might be missing in some DBs; seed if needed
        ensureCoreTransactionTypes()
        let orderRef = UUID().uuidString
        let gross = quantity * price
        let f = fee ?? 0
        let tx = tax ?? 0
        guard let posTypeId = findTransactionTypeId(code: typeCode) else {
            let msg = "Missing Transaction Type with code \(typeCode). Add it in Configuration → Transaction Types."
            print("❌ \(msg)")
            self.lastTransactionErrorMessage = msg
            return false
        }
        let cashTypeCode = (typeCode.uppercased() == "BUY") ? "WITHDRAWAL" : "DEPOSIT"
        guard let cashTypeId = findTransactionTypeId(code: cashTypeCode) else {
            let msg = "Missing cash Transaction Type with code \(cashTypeCode). Add it in Configuration → Transaction Types."
            print("❌ \(msg)")
            self.lastTransactionErrorMessage = msg
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
            if self.lastTransactionErrorMessage == nil {
                self.lastTransactionErrorMessage = "Failed to save trade. See Console for details."
            }
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
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let cstr = (orderReference as NSString).utf8String {
            sqlite3_bind_text(stmt, 1, cstr, -1, SQLITE_TRANSIENT)
        }
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
        var orderReference: String?
        var posTransactionId: Int?
        var cashTransactionId: Int?
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
        let thisType = String(cString: sqlite3_column_text(stmt, 3))
        let dateStr = String(cString: sqlite3_column_text(stmt, 4))
        let thisDate = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? Date()
        let thisQty: Double? = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? sqlite3_column_double(stmt, 5) : nil
        let thisPrice: Double? = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? sqlite3_column_double(stmt, 6) : nil
        let thisFee: Double? = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? sqlite3_column_double(stmt, 7) : nil
        let thisTax: Double? = sqlite3_column_type(stmt, 8) != SQLITE_NULL ? sqlite3_column_double(stmt, 8) : nil
        let thisNet = sqlite3_column_double(stmt, 9)
        let thisCurrency = String(cString: sqlite3_column_text(stmt, 10))
        let orderRef = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        let thisDesc = sqlite3_column_text(stmt, 12).map { String(cString: $0) }
        if let ord = orderRef {
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
            var posLeg: (txId: Int, accountId: Int, instrumentId: Int, type: String, qty: Double, price: Double)?
            var cashLeg: (txId: Int, accountId: Int)?
            while sqlite3_step(stmt2) == SQLITE_ROW {
                let txid = Int(sqlite3_column_int(stmt2, 0))
                let accId = Int(sqlite3_column_int(stmt2, 1))
                let instr: Int? = sqlite3_column_type(stmt2, 2) != SQLITE_NULL ? Int(sqlite3_column_int(stmt2, 2)) : nil
                let tcode = String(cString: sqlite3_column_text(stmt2, 3))
                let q: Double = sqlite3_column_type(stmt2, 4) != SQLITE_NULL ? sqlite3_column_double(stmt2, 4) : 0
                let p: Double = sqlite3_column_type(stmt2, 5) != SQLITE_NULL ? sqlite3_column_double(stmt2, 5) : 0
                if let iid = instr { posLeg = (txid, accId, iid, tcode, q, p) } else { cashLeg = (txid, accId) }
            }
            guard let pos = posLeg, let cashAcc = cashLeg?.accountId else { return nil }
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
                orderReference: ord,
                posTransactionId: pos.txId,
                cashTransactionId: cashLeg?.txId
            )
        }

        // Fallback inference without order_reference
        let tol = 0.01
        let sqlOppCash = """
            SELECT t.account_id
              FROM Transactions t
              JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
             WHERE t.transaction_id != ?
               AND t.transaction_date = ?
               AND t.transaction_currency = ?
               AND t.instrument_id IS NULL
               AND ABS(t.net_amount + ?) < ?
             LIMIT 1;
        """
        let sqlOppPos = """
            SELECT t.account_id, t.instrument_id, t.quantity, t.price, t.transaction_id
              FROM Transactions t
              JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
             WHERE t.transaction_id != ?
               AND t.transaction_date = ?
               AND t.transaction_currency = ?
               AND t.instrument_id IS NOT NULL
               AND ABS(t.net_amount + ?) < ?
             LIMIT 1;
        """
        if thisInstrumentId != nil {
            var stmt3: OpaquePointer?
            if sqlite3_prepare_v2(db, sqlOppCash, -1, &stmt3, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt3, 1, Int32(transactionId))
                sqlite3_bind_text(stmt3, 2, dateStr, -1, nil)
                sqlite3_bind_text(stmt3, 3, thisCurrency, -1, nil)
                sqlite3_bind_double(stmt3, 4, thisNet)
                sqlite3_bind_double(stmt3, 5, tol)
                var cashAcc: Int?
                if sqlite3_step(stmt3) == SQLITE_ROW { cashAcc = Int(sqlite3_column_int(stmt3, 0)) }
                sqlite3_finalize(stmt3)
                if let cashAcc = cashAcc, let iid = thisInstrumentId {
                    let normalizedType = thisType.uppercased() == "SELL" ? "SELL" : "BUY"
                    return PairedTradeDetails(typeCode: normalizedType, instrumentId: iid, securitiesAccountId: thisAccountId, cashAccountId: cashAcc, date: thisDate, quantity: thisQty ?? 0, price: thisPrice ?? 0, fee: thisFee, tax: thisTax, description: thisDesc, currency: thisCurrency, orderReference: nil, posTransactionId: transactionId, cashTransactionId: nil)
                }
            }
        } else {
            var stmt4: OpaquePointer?
            if sqlite3_prepare_v2(db, sqlOppPos, -1, &stmt4, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt4, 1, Int32(transactionId))
                sqlite3_bind_text(stmt4, 2, dateStr, -1, nil)
                sqlite3_bind_text(stmt4, 3, thisCurrency, -1, nil)
                sqlite3_bind_double(stmt4, 4, thisNet)
                sqlite3_bind_double(stmt4, 5, tol)
                var secAcc: Int?
                var iid: Int?
                var q: Double = 0
                var p: Double = 0
                var posTxId: Int?
                if sqlite3_step(stmt4) == SQLITE_ROW {
                    secAcc = Int(sqlite3_column_int(stmt4, 0))
                    iid = Int(sqlite3_column_int(stmt4, 1))
                    if sqlite3_column_type(stmt4, 2) != SQLITE_NULL { q = sqlite3_column_double(stmt4, 2) }
                    if sqlite3_column_type(stmt4, 3) != SQLITE_NULL { p = sqlite3_column_double(stmt4, 3) }
                    posTxId = Int(sqlite3_column_int(stmt4, 4))
                }
                sqlite3_finalize(stmt4)
                if let secAcc = secAcc, let iid = iid {
                    let normalizedType = thisType.uppercased() == "DEPOSIT" ? "SELL" : "BUY"
                    return PairedTradeDetails(typeCode: normalizedType, instrumentId: iid, securitiesAccountId: secAcc, cashAccountId: thisAccountId, date: thisDate, quantity: thisQty ?? q, price: thisPrice ?? p, fee: thisFee, tax: thisTax, description: thisDesc, currency: thisCurrency, orderReference: nil, posTransactionId: posTxId, cashTransactionId: transactionId)
                }
            }
        }
        return nil
    }

    struct BasicTransactionDetails {
        var transactionId: Int
        var accountId: Int
        var instrumentId: Int?
        var typeCode: String
        var date: Date
        var quantity: Double?
        var price: Double?
        var fee: Double?
        var tax: Double?
        var currency: String
        var orderReference: String?
        var description: String?
    }

    func fetchTransactionDetails(id: Int) -> BasicTransactionDetails? {
        let sql = """
            SELECT t.transaction_id, t.account_id, t.instrument_id, tt.type_code, t.transaction_date,
                   t.quantity, t.price, t.fee, t.tax, t.transaction_currency, t.order_reference, t.description
              FROM Transactions t
              JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
             WHERE t.transaction_id = ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let txId = Int(sqlite3_column_int(stmt, 0))
        let accId = Int(sqlite3_column_int(stmt, 1))
        let instrId: Int? = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 2)) : nil
        let tcode = String(cString: sqlite3_column_text(stmt, 3))
        let dateStr = String(cString: sqlite3_column_text(stmt, 4))
        let d = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? Date()
        let qty: Double? = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? sqlite3_column_double(stmt, 5) : nil
        let pr: Double? = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? sqlite3_column_double(stmt, 6) : nil
        let f: Double? = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? sqlite3_column_double(stmt, 7) : nil
        let t: Double? = sqlite3_column_type(stmt, 8) != SQLITE_NULL ? sqlite3_column_double(stmt, 8) : nil
        let cur = String(cString: sqlite3_column_text(stmt, 9))
        let ord = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
        let desc = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        return BasicTransactionDetails(
            transactionId: txId, accountId: accId, instrumentId: instrId, typeCode: tcode,
            date: d, quantity: qty, price: pr, fee: f, tax: t, currency: cur, orderReference: ord, description: desc)
    }
}
