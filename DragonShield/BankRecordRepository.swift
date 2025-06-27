// DragonShield/BankRecordRepository.swift
// MARK: - Version 1.0.0.2
// - 1.0.0.1 -> 1.0.0.2: Provide detailed insert/prepare error information.
enum BankRecordRepositoryError: LocalizedError {
    case prepareFailed(String)
    case insertFailed(String)

    var errorDescription: String? {
        switch self {
        case .prepareFailed(let msg):
            return "Failed to prepare INSERT statement: \(msg)"
        case .insertFailed(let msg):
            return "Failed to insert record: \(msg)"
        }
    }
}

            throw BankRecordRepositoryError.prepareFailed(msg)
                throw BankRecordRepositoryError.insertFailed(msg)
// - 0.0.0.0 -> 1.0.0.0: Initial repository for saving records using SQLite.
// - 1.0.0.0 -> 1.0.0.1: Create table if missing and surface SQLite errors.

import Foundation
import SQLite3

class BankRecordRepository {
    private let db: OpaquePointer

    init(db: OpaquePointer) {
        self.db = db
        createTableIfNeeded()
    }

    private func createTableIfNeeded() {
        let createSQL = """
            CREATE TABLE IF NOT EXISTS bankRecord (
                id TEXT PRIMARY KEY,
                transactionDate TEXT NOT NULL,
                description TEXT NOT NULL,
                amount REAL NOT NULL,
                currency TEXT NOT NULL,
                bankAccount TEXT NOT NULL
            );
            """
        if sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ Failed to create bankRecord table: \(String(cString: sqlite3_errmsg(db)))")
        }

    }

    func saveRecords(_ records: [MyBankRecord]) throws {
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let sql = "INSERT INTO bankRecord (id, transactionDate, description, amount, currency, bankAccount) VALUES (?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {

            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "BankRecordRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare INSERT statement: \(msg)"])

        }
        defer { sqlite3_finalize(stmt) }
        let formatter = ISO8601DateFormatter()
        for record in records {
            sqlite3_bind_text(stmt, 1, record.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, formatter.string(from: record.transactionDate), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, record.description, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 4, record.amount)
            sqlite3_bind_text(stmt, 5, record.currency, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 6, record.bankAccount, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_DONE {

                let msg = String(cString: sqlite3_errmsg(db))
                throw NSError(domain: "BankRecordRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to insert record: \(msg)"])

            }
            sqlite3_reset(stmt)
        }
    }
}
