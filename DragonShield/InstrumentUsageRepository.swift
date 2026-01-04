// DragonShield/InstrumentUsageRepository.swift

// MARK: - Version 1.0.0

// Repository providing queries for unused instruments under strict criteria.

import Foundation
import OSLog
import SQLite3

struct UnusedInstrument: Identifiable {
    let instrumentId: Int
    let name: String
    let type: String
    let currency: String
    let lastActivity: Date?
    let themesCount: Int
    let refsCount: Int

    var id: Int { instrumentId }
}

enum InstrumentUsageRepositoryError: LocalizedError {
    case noSnapshot

    var errorDescription: String? {
        switch self {
        case .noSnapshot:
            return "No positions snapshot available"
        }
    }
}

/// Provides queries for analysing instrument usage across the database.
final class InstrumentUsageRepository {
    private let dbManager: DatabaseManager
    private static let epsilon = 1e-9

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    /// Returns all instruments that satisfy U1∧U2∧U3 from the specification.
    /// - Parameter excludeCash: When true (default) excludes instruments of the cash subclass.
    func unusedStrict(excludeCash: Bool = true) throws -> [UnusedInstrument] {
        guard let db = dbManager.db else { return [] }

        // Ensure at least one positions snapshot exists.
        var checkStmt: OpaquePointer?
        var hasSnapshot = false
        if sqlite3_prepare_v2(db, "SELECT 1 FROM PositionReports LIMIT 1", -1, &checkStmt, nil) == SQLITE_OK {
            hasSnapshot = sqlite3_step(checkStmt) == SQLITE_ROW
        }
        sqlite3_finalize(checkStmt)

        guard hasSnapshot else {
            throw InstrumentUsageRepositoryError.noSnapshot
        }

        // Build refs_count expression based on existing tables.
        let referenceTables = ["Transactions", "PortfolioInstruments"].filter { tableExists($0, db: db) }
        let refsExpression: String
        if referenceTables.isEmpty {
            refsExpression = "0"
        } else {
            let components = referenceTables.map {
                "CASE WHEN EXISTS(SELECT 1 FROM \($0) r WHERE r.instrument_id = i.instrument_id) THEN 1 ELSE 0 END"
            }
            refsExpression = components.joined(separator: " + ")
        }

        let cashFilter = excludeCash ? "AND i.sub_class_id != 1" : ""

        let sql = """
        WITH position_activity AS (
            SELECT instrument_id, MAX(ABS(quantity)) AS max_qty
            FROM PositionReports
            GROUP BY instrument_id
        ),
        last_activity AS (
            SELECT instrument_id, MAX(report_date) AS last_date
            FROM PositionReports
            GROUP BY instrument_id
        ),
        theme_counts AS (
            SELECT instrument_id, COUNT(*) AS cnt
            FROM PortfolioThemeAsset
            GROUP BY instrument_id
        )
        SELECT i.instrument_id, i.instrument_name, asc.sub_class_name, i.currency,
               la.last_date,
               COALESCE(tc.cnt,0) AS themes_count,
               \(refsExpression) AS refs_count
        FROM Instruments i
        LEFT JOIN position_activity pa ON pa.instrument_id = i.instrument_id
        LEFT JOIN last_activity la ON la.instrument_id = i.instrument_id
        LEFT JOIN theme_counts tc ON tc.instrument_id = i.instrument_id
        LEFT JOIN AssetSubClasses asc ON asc.sub_class_id = i.sub_class_id
        WHERE (pa.instrument_id IS NULL OR pa.max_qty < \(Self.epsilon))
          AND COALESCE(tc.cnt,0) = 0
          AND \(refsExpression) = 0
          AND i.is_active = 1
          \(cashFilter)
        ORDER BY i.instrument_name
        """

        var stmt: OpaquePointer?
        var results: [UnusedInstrument] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let formatter = DateFormatter.iso8601DateOnly
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let type = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let currency = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                let lastDateStr = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                let lastDate = lastDateStr.flatMap { formatter.date(from: $0) }
                let themesCount = Int(sqlite3_column_int(stmt, 5))
                let refsCount = Int(sqlite3_column_int(stmt, 6))
                results.append(UnusedInstrument(
                    instrumentId: id,
                    name: name,
                    type: type,
                    currency: currency,
                    lastActivity: lastDate,
                    themesCount: themesCount,
                    refsCount: refsCount
                ))
            }
        } else {
            LoggingService.shared.log("unusedStrict prepare failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return results
    }

    private func tableExists(_ name: String, db: OpaquePointer) -> Bool {
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1"
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, name, -1, nil)
            exists = sqlite3_step(stmt) == SQLITE_ROW
        }
        sqlite3_finalize(stmt)
        return exists
    }
}
