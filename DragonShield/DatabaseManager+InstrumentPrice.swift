import Foundation
import SQLite3

extension DatabaseManager {
    struct InstrumentLatestPriceRow: Identifiable {
        var id: Int
        var name: String
        var currency: String
        var latestPrice: Double?
        var asOf: String?
        var source: String?
        var ticker: String?
        var isin: String?
        var valorNr: String?
        var className: String?
        var subClassName: String?
    }

    /// Lists instruments with their latest price (if any), with optional filters.
    /// - Parameters:
    ///   - search: Case-insensitive filter across name, ticker, ISIN, valor.
    ///   - currencies: Restrict to these currency codes (uppercased).
    ///   - missingOnly: If true, only instruments without a latest price.
    ///   - staleDays: If provided, include instruments with latest price older than N days.
    func listInstrumentLatestPrices(
        search: String? = nil,
        currencies: [String]? = nil,
        missingOnly: Bool = false,
        staleDays: Int? = nil
    ) -> [InstrumentLatestPriceRow] {
        var rows: [InstrumentLatestPriceRow] = []
        var clauses: [String] = ["i.is_active = 1"]
        var binds: [Any] = []
        if let s = search?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            clauses.append("(LOWER(i.instrument_name) LIKE ? OR LOWER(i.ticker_symbol) LIKE ? OR LOWER(i.isin) LIKE ? OR LOWER(i.valor_nr) LIKE ?)")
            let pat = "%" + s.lowercased() + "%"
            binds.append(pat); binds.append(pat); binds.append(pat); binds.append(pat)
        }
        if let cur = currencies, !cur.isEmpty {
            let place = Array(repeating: "?", count: cur.count).joined(separator: ", ")
            clauses.append("UPPER(i.currency) IN (\(place))")
            for c in cur { binds.append(c.uppercased()) }
        }
        if missingOnly {
            clauses.append("ipl.instrument_id IS NULL")
        }
        if let days = staleDays, days > 0 {
            clauses.append("(ipl.as_of IS NULL OR DATE(ipl.as_of) <= DATE('now', ?))")
            binds.append("-\(days) days")
        }
        let whereSql = clauses.isEmpty ? "" : ("WHERE " + clauses.joined(separator: " AND "))
        let sql = """
            SELECT i.instrument_id,
                   i.instrument_name,
                   i.currency,
                   ipl.price,
                   ipl.as_of,
                   ipl.source,
                   i.ticker_symbol,
                   i.isin,
                   i.valor_nr,
                   ac.class_name,
                   asc.sub_class_name
              FROM Instruments i
              LEFT JOIN InstrumentPriceLatest ipl ON ipl.instrument_id = i.instrument_id
              JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
              JOIN AssetClasses ac ON asc.class_id = ac.class_id
            \(whereSql)
             ORDER BY i.instrument_name COLLATE NOCASE
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var idx: Int32 = 1
        for b in binds {
            if let s = b as? String {
                sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            } else if let i = b as? Int {
                sqlite3_bind_int(stmt, idx, Int32(i))
            } else {
                sqlite3_bind_null(stmt, idx)
            }
            idx += 1
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let cur = String(cString: sqlite3_column_text(stmt, 2))
            let price: Double? = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil
            let asOf: String? = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let source: String? = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let ticker = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            let isin = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
            let valor = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
            let className = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
            let subClassName = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
            rows.append(InstrumentLatestPriceRow(id: id, name: name, currency: cur, latestPrice: price, asOf: asOf, source: source, ticker: ticker, isin: isin, valorNr: valor, className: className, subClassName: subClassName))
        }
        return rows
    }
    func getLatestPrice(instrumentId: Int) -> (price: Double, currency: String, asOf: String)? {
        let sql = "SELECT price, currency, as_of FROM InstrumentPriceLatest WHERE instrument_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        if sqlite3_step(stmt) == SQLITE_ROW {
            let price = sqlite3_column_double(stmt, 0)
            let curr = String(cString: sqlite3_column_text(stmt, 1))
            let asof = String(cString: sqlite3_column_text(stmt, 2))
            return (price, curr, asof)
        }
        return nil
    }

    func upsertPrice(instrumentId: Int, price: Double, currency: String, asOf: String, source: String? = nil) -> Bool {
        let sql = "INSERT OR REPLACE INTO InstrumentPrice(instrument_id, price, currency, source, as_of) VALUES (?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(instrumentId))
        sqlite3_bind_double(stmt, 2, price)
        sqlite3_bind_text(stmt, 3, currency, -1, SQLITE_TRANSIENT)
        if let s = source { sqlite3_bind_text(stmt, 4, s, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        sqlite3_bind_text(stmt, 5, asOf, -1, SQLITE_TRANSIENT)
        return sqlite3_step(stmt) == SQLITE_DONE
    }
}
