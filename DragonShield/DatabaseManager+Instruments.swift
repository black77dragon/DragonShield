import Foundation
import SQLite3

extension DatabaseManager {
    private func tableExists(_ name: String) -> Bool {
        guard let db = db else { return false }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND LOWER(name)=LOWER(?) LIMIT 1", -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    struct InstrumentRow: Identifiable {
        var id: Int
        var name: String
        var currency: String
        var subClassId: Int
        var tickerSymbol: String?
        var isin: String?
        var valorNr: String?
        var isDeleted: Bool
        var isActive: Bool
    }

    func fetchAssets(includeDeleted: Bool = false, includeInactive: Bool = false) -> [InstrumentRow] {
        var rows: [InstrumentRow] = []
        var clauses: [String] = []
        if !includeDeleted { clauses.append("is_deleted = 0") }
        if !includeInactive { clauses.append("is_active = 1") }
        let whereSql = clauses.isEmpty ? "" : ("WHERE " + clauses.joined(separator: " AND "))
        let sql = """
            SELECT instrument_id,
                   instrument_name,
                   currency,
                   sub_class_id,
                   ticker_symbol,
                   isin,
                   valor_nr,
                   is_deleted,
                   is_active
              FROM Instruments
              \(whereSql)
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
            let isDeleted = sqlite3_column_int(stmt, 7) == 1
            let isActive = sqlite3_column_int(stmt, 8) == 1
            rows.append(InstrumentRow(id: id, name: name, currency: currency, subClassId: subClassId, tickerSymbol: ticker, isin: isin, valorNr: valor, isDeleted: isDeleted, isActive: isActive))
        }
        return rows
    }

    func fetchInstrumentsWithoutThemes(includeDeleted: Bool = false, includeInactive: Bool = false) -> [InstrumentRow] {
        var rows: [InstrumentRow] = []
        var filters: [String] = []
        if !includeDeleted { filters.append("i.is_deleted = 0") }
        if !includeInactive { filters.append("i.is_active = 1") }
        if tableExists("PortfolioThemeAsset") {
            filters.append("NOT EXISTS (SELECT 1 FROM PortfolioThemeAsset a WHERE a.instrument_id = i.instrument_id)")
        }
        let whereSql = filters.isEmpty ? "" : ("WHERE " + filters.joined(separator: " AND "))
        let sql = """
            SELECT i.instrument_id,
                   i.instrument_name,
                   i.currency,
                   i.sub_class_id,
                   i.ticker_symbol,
                   i.isin,
                   i.valor_nr,
                   i.is_deleted,
                   i.is_active
              FROM Instruments i
              \(whereSql)
             ORDER BY i.instrument_name COLLATE NOCASE
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
            let isDeleted = sqlite3_column_int(stmt, 7) == 1
            let isActive = sqlite3_column_int(stmt, 8) == 1
            rows.append(InstrumentRow(id: id, name: name, currency: currency, subClassId: subClassId, tickerSymbol: ticker, isin: isin, valorNr: valor, isDeleted: isDeleted, isActive: isActive))
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
        var isActive: Bool
        var isDeleted: Bool
    }

    func fetchInstrumentDetails(id: Int) -> InstrumentDetails? {
        let sql = """
            SELECT instrument_id, instrument_name, sub_class_id, currency, valor_nr, ticker_symbol, isin, sector, is_active, is_deleted
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
            let isActive = sqlite3_column_int(stmt, 8) == 1
            let isDeleted = sqlite3_column_int(stmt, 9) == 1
            return InstrumentDetails(id: iid, name: name, subClassId: subClassId, currency: currency, valorNr: valor, tickerSymbol: ticker, isin: isin, sector: sector, isActive: isActive, isDeleted: isDeleted)
        }
        return nil
    }

    // MARK: - Soft Delete / Restore
    func countPositionsForInstrument(id: Int) -> Int {
        let sql = "SELECT COUNT(*) FROM PositionReports WHERE instrument_id = ?"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    func countPortfolioMembershipsForInstrument(id: Int) -> Int {
        let sql = "SELECT COUNT(*) FROM PortfolioThemeAsset WHERE instrument_id = ?"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        return count
    }

    struct InstrumentPortfolioMembershipRow: Identifiable {
        let id: Int
        let name: String
        let status: String?
        let isArchived: Bool
        let isSoftDeleted: Bool
        let researchTargetPct: Double?
        let userTargetPct: Double?
    }

    func listPortfolioMembershipsForInstrument(id: Int) -> [InstrumentPortfolioMembershipRow] {
        guard let db else { return [] }

        var rows: [InstrumentPortfolioMembershipRow] = []
        let hasArchivedAt = tableHasColumn("PortfolioTheme", column: "archived_at")
        let hasSoftDelete = tableHasColumn("PortfolioTheme", column: "soft_delete")
        let selectArchived = hasArchivedAt ? "pt.archived_at" : "NULL"
        let selectSoftDelete = hasSoftDelete ? "pt.soft_delete" : "0"
        let selectResearch = tableHasColumn("PortfolioThemeAsset", column: "research_target_pct") ? "pta.research_target_pct" : "NULL"
        let selectUser = tableHasColumn("PortfolioThemeAsset", column: "user_target_pct") ? "pta.user_target_pct" : "NULL"

        let sql = """
            SELECT pt.id,
                   pt.name,
                   pts.name,
                   \(selectArchived) AS archived_at,
                   \(selectSoftDelete) AS soft_delete,
                   \(selectResearch) AS research_target_pct,
                   \(selectUser) AS user_target_pct
              FROM PortfolioThemeAsset pta
              JOIN PortfolioTheme pt ON pt.id = pta.theme_id
              LEFT JOIN PortfolioThemeStatus pts ON pts.id = pt.status_id
             WHERE pta.instrument_id = ?
             ORDER BY LOWER(pt.name)
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let themeId = Int(sqlite3_column_int(stmt, 0))
                let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "Theme #\(themeId)"
                let statusName = sqlite3_column_text(stmt, 2).map { String(cString: $0) }

                let archived: Bool
                if hasArchivedAt {
                    if sqlite3_column_type(stmt, 3) == SQLITE_NULL {
                        archived = false
                    } else if let text = sqlite3_column_text(stmt, 3) {
                        archived = !String(cString: text).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    } else {
                        archived = false
                    }
                } else {
                    archived = false
                }

                let softDeleted = hasSoftDelete ? (sqlite3_column_int(stmt, 4) == 1) : false
                let researchPct = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 5)
                let userPct = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 6)

                rows.append(
                    InstrumentPortfolioMembershipRow(
                        id: themeId,
                        name: name,
                        status: statusName,
                        isArchived: archived,
                        isSoftDeleted: softDeleted,
                        researchTargetPct: researchPct,
                        userTargetPct: userPct
                    )
                )
            }
        } else {
            let err = String(cString: sqlite3_errmsg(db))
            LoggingService.shared.log("listPortfolioMembershipsForInstrument prepare failed: \(err)", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return rows
    }

    func softDeleteInstrument(id: Int, reason: String?, note: String?) -> Bool {
        // Guard: prevent soft delete if still referenced
        if countPositionsForInstrument(id: id) > 0 { return false }
        if countPortfolioMembershipsForInstrument(id: id) > 0 { return false }
        let sql = """
            UPDATE Instruments
               SET is_deleted = 1,
                   is_active = 0,
                   deleted_at = CURRENT_TIMESTAMP,
                   deleted_reason = COALESCE(?, deleted_reason),
                   user_note = COALESCE(?, user_note)
             WHERE instrument_id = ? AND is_deleted = 0
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        if let r = reason { sqlite3_bind_text(stmt, 1, r, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 1) }
        if let n = note { sqlite3_bind_text(stmt, 2, n, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 2) }
        sqlite3_bind_int(stmt, 3, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    func restoreInstrument(id: Int) -> Bool {
        let sql = """
            UPDATE Instruments
               SET is_deleted = 0,
                   is_active = 1,
                   deleted_at = NULL,
                   deleted_reason = NULL
             WHERE instrument_id = ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE
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
