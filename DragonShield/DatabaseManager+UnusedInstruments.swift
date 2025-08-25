import Foundation
import SQLite3

extension DatabaseManager {
    func fetchUnusedInstruments(excludingCash: Bool = true) -> [UnusedInstrument] {
        var unused: [UnusedInstrument] = []
        guard let db = db else { return unused }

        var stmt: OpaquePointer?
        var latest: String?
        if sqlite3_prepare_v2(db, "SELECT MAX(report_date) FROM PositionReports", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW, let cstr = sqlite3_column_text(stmt, 0) {
                latest = String(cString: cstr)
            }
        }
        sqlite3_finalize(stmt)
        guard let latestDate = latest else { return [] }

        var sql = """
            SELECT i.instrument_id, i.instrument_name, asc.sub_class_name, i.currency,
                   MAX(pr.report_date) AS last_activity,
                   COUNT(DISTINCT pta.theme_id) AS theme_count
              FROM Instruments i
              JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
              LEFT JOIN (
                    SELECT instrument_id, SUM(quantity) AS qty
                      FROM PositionReports
                     WHERE report_date = ?
                     GROUP BY instrument_id
              ) cur ON cur.instrument_id = i.instrument_id
              LEFT JOIN PositionReports pr ON pr.instrument_id = i.instrument_id
              LEFT JOIN PortfolioThemeAsset pta ON pta.instrument_id = i.instrument_id
             WHERE IFNULL(cur.qty, 0) = 0
            """
        if excludingCash {
            sql += " AND asc.sub_class_code <> 'CASH'"
        }
        sql += """
             GROUP BY i.instrument_id, i.instrument_name, asc.sub_class_name, i.currency
             ORDER BY last_activity ASC NULLS FIRST, i.instrument_name;
            """
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            return unused
        }
        sqlite3_bind_text(stmt, 1, latestDate, -1, nil)
        let formatter = DateFormatter.iso8601DateOnly
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            guard let namePtr = sqlite3_column_text(stmt, 1),
                  let typePtr = sqlite3_column_text(stmt, 2),
                  let currencyPtr = sqlite3_column_text(stmt, 3) else { continue }
            let name = String(cString: namePtr)
            let type = String(cString: typePtr)
            let currency = String(cString: currencyPtr)
            var last: Date? = nil
            if sqlite3_column_type(stmt, 4) != SQLITE_NULL {
                let str = String(cString: sqlite3_column_text(stmt, 4))
                last = formatter.date(from: str)
            }
            let themes = Int(sqlite3_column_int(stmt, 5))
            unused.append(UnusedInstrument(id: id, name: name, type: type, currency: currency, lastActivity: last, themeCount: themes))
        }
        sqlite3_finalize(stmt)
        return unused
    }
}

