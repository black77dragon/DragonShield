// DragonShield/PositionReportRepository.swift
// MARK: - Version 1.0.0
// Repository for inserting position reports into the database.

import Foundation
import SQLite3

struct PositionReport {
    let importSessionId: Int?
    let accountId: Int
    let institutionId: Int
    let instrumentId: Int
    let quantity: Double
    let purchasePrice: Double?
    let currentPrice: Double?
    let reportDate: Date
    let instrumentUpdatedAt: Date?
}

enum PositionReportRepositoryError: LocalizedError {
    case prepareFailed(String)
    case insertFailed(String)
    case connectionUnavailable

    var errorDescription: String? {
        switch self {
        case .prepareFailed(let msg):
            return "Failed to prepare INSERT statement: \(msg)"
        case .insertFailed(let msg):
            return "Failed to insert position: \(msg)"
        case .connectionUnavailable:
            return "Database connection unavailable"
        }
    }
}

final class PositionReportRepository {
    private let dbManager: DatabaseManager
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
        createTableIfNeeded()
    }

    private func createTableIfNeeded() {
        let sql = """
            CREATE TABLE IF NOT EXISTS PositionReports (
                position_id INTEGER PRIMARY KEY AUTOINCREMENT,
                import_session_id INTEGER,
                account_id INTEGER NOT NULL,
                institution_id INTEGER NOT NULL,
                instrument_id INTEGER NOT NULL,
                quantity REAL NOT NULL,
                purchase_price REAL,
                current_price REAL,
                instrument_updated_at DATE,
                report_date DATE NOT NULL,
                uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (account_id) REFERENCES Accounts(account_id),
                FOREIGN KEY (institution_id) REFERENCES Institutions(institution_id),
                FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id)
            );
            """
        guard let db = dbManager.db else { return }
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            print("❌ Failed to create PositionReports table: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    func saveReports(_ reports: [PositionReport]) throws {
        let sql = "INSERT INTO PositionReports (import_session_id, account_id, institution_id, instrument_id, quantity, purchase_price, current_price, instrument_updated_at, report_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard let db = dbManager.db else {
            throw PositionReportRepositoryError.connectionUnavailable
        }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw PositionReportRepositoryError.prepareFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }
        let dateFormatter = DateFormatter.iso8601DateOnly
        for rpt in reports {
            if let sessId = rpt.importSessionId {
                sqlite3_bind_int(stmt, 1, Int32(sessId))
            } else {
                sqlite3_bind_null(stmt, 1)
            }
            sqlite3_bind_int(stmt, 2, Int32(rpt.accountId))
            sqlite3_bind_int(stmt, 3, Int32(rpt.institutionId))
            sqlite3_bind_int(stmt, 4, Int32(rpt.instrumentId))
            sqlite3_bind_double(stmt, 5, rpt.quantity)
            if let pPrice = rpt.purchasePrice {
                sqlite3_bind_double(stmt, 6, pPrice)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            if let cPrice = rpt.currentPrice {
                sqlite3_bind_double(stmt, 7, cPrice)
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            if let updated = rpt.instrumentUpdatedAt {
                sqlite3_bind_text(stmt, 8, dateFormatter.string(from: updated), -1, Self.sqliteTransient)
            } else {
                sqlite3_bind_null(stmt, 8)
            }
            sqlite3_bind_text(stmt, 9, dateFormatter.string(from: rpt.reportDate), -1, Self.sqliteTransient)
            if sqlite3_step(stmt) != SQLITE_DONE {
                let msg = String(cString: sqlite3_errmsg(db))
                throw PositionReportRepositoryError.insertFailed(msg)
            }
            sqlite3_reset(stmt)
        }
    }
}
