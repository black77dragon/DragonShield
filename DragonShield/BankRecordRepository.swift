// DragonShield/BankRecordRepository.swift
// MARK: - Version 1.0.0.0
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial repository for saving records using SQLite.

import Foundation
import SQLite3

class BankRecordRepository {
    private let db: OpaquePointer

    init(db: OpaquePointer) {
        self.db = db
    }

    func saveRecords(_ records: [MyBankRecord]) throws {
        let sql = "INSERT INTO bankRecord (id, transactionDate, description, amount, currency, bankAccount) VALUES (?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw NSError(domain: "BankRecordRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Prepare failed"])
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
                throw NSError(domain: "BankRecordRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Insert failed"])
            }
            sqlite3_reset(stmt)
        }
    }
}
