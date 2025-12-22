// DragonShield/Repositories/TransactionTypeRepository.swift

import Foundation
import SQLite3

typealias TransactionTypeRow = (
    id: Int,
    code: String,
    name: String,
    description: String,
    affectsPosition: Bool,
    affectsCash: Bool,
    isIncome: Bool,
    sortOrder: Int
)

final class TransactionTypeRepository {
    private let connection: DatabaseConnection
    private var db: OpaquePointer? { connection.db }

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    convenience init(dbManager: DatabaseManager) {
        self.init(connection: dbManager.databaseConnection)
    }

    func fetchTransactionTypes() -> [TransactionTypeRow] {
        var types: [TransactionTypeRow] = []
        guard let db else { return types }
        let query = """
            SELECT transaction_type_id, type_code, type_name, type_description, affects_position, affects_cash, is_income, sort_order
            FROM TransactionTypes
            ORDER BY sort_order, type_name
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))
                let description = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                let affectsPosition = sqlite3_column_int(statement, 4) == 1
                let affectsCash = sqlite3_column_int(statement, 5) == 1
                let isIncome = sqlite3_column_int(statement, 6) == 1
                let sortOrder = Int(sqlite3_column_int(statement, 7))

                types.append((
                    id: id,
                    code: code,
                    name: name,
                    description: description,
                    affectsPosition: affectsPosition,
                    affectsCash: affectsCash,
                    isIncome: isIncome,
                    sortOrder: sortOrder
                ))
            }
        } else {
            print("❌ Failed to prepare fetchTransactionTypes: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return types
    }

    func fetchTransactionTypeDetails(id: Int) -> TransactionTypeRow? {
        guard let db else { return nil }
        let query = """
            SELECT transaction_type_id, type_code, type_name, type_description, affects_position, affects_cash, is_income, sort_order
            FROM TransactionTypes
            WHERE transaction_type_id = ?
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(id))

            if sqlite3_step(statement) == SQLITE_ROW {
                let typeId = Int(sqlite3_column_int(statement, 0))
                let code = String(cString: sqlite3_column_text(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))
                let description = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                let affectsPosition = sqlite3_column_int(statement, 4) == 1
                let affectsCash = sqlite3_column_int(statement, 5) == 1
                let isIncome = sqlite3_column_int(statement, 6) == 1
                let sortOrder = Int(sqlite3_column_int(statement, 7))

                sqlite3_finalize(statement)
                return (
                    id: typeId,
                    code: code,
                    name: name,
                    description: description,
                    affectsPosition: affectsPosition,
                    affectsCash: affectsCash,
                    isIncome: isIncome,
                    sortOrder: sortOrder
                )
            } else {
                print("ℹ️ No transaction type details found for ID: \(id)")
            }
        } else {
            print("❌ Failed to prepare fetchTransactionTypeDetails (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        return nil
    }

    func addTransactionType(code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int) -> Bool {
        guard let db else { return false }
        let query = """
            INSERT INTO TransactionTypes (type_code, type_name, type_description, affects_position, affects_cash, is_income, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare addTransactionType: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        _ = code.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        if !description.isEmpty {
            _ = description.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, affectsPosition ? 1 : 0)
        sqlite3_bind_int(statement, 5, affectsCash ? 1 : 0)
        sqlite3_bind_int(statement, 6, isIncome ? 1 : 0)
        sqlite3_bind_int(statement, 7, Int32(sortOrder))

        let result = sqlite3_step(statement) == SQLITE_DONE
        let newId = result ? Int(sqlite3_last_insert_rowid(db)) : nil
        sqlite3_finalize(statement)

        if result {
            let idLog = newId ?? Int(sqlite3_last_insert_rowid(db))
            print("✅ Inserted transaction type '\(name)' with ID: \(idLog)")
        } else {
            print("❌ Insert transaction type '\(name)' failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        if let newId, result, !reorderTransactionTypes(movingId: newId, desiredOrder: sortOrder) {
            print("⚠️ Failed to normalize transaction type order after insert.")
        }
        return result
    }

    func updateTransactionType(id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int) -> Bool {
        guard let db else { return false }
        let query = """
            UPDATE TransactionTypes
            SET type_code = ?, type_name = ?, type_description = ?, affects_position = ?, affects_cash = ?, is_income = ?, sort_order = ?
            WHERE transaction_type_id = ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare updateTransactionType (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        _ = code.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        _ = name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        if !description.isEmpty {
            _ = description.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_int(statement, 4, affectsPosition ? 1 : 0)
        sqlite3_bind_int(statement, 5, affectsCash ? 1 : 0)
        sqlite3_bind_int(statement, 6, isIncome ? 1 : 0)
        sqlite3_bind_int(statement, 7, Int32(sortOrder))
        sqlite3_bind_int(statement, 8, Int32(id))

        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if result {
            print("✅ Updated transaction type (ID: \(id))")
        } else {
            print("❌ Update transaction type failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        if result, !reorderTransactionTypes(movingId: id, desiredOrder: sortOrder) {
            print("⚠️ Failed to normalize transaction type order after update.")
        }
        return result
    }

    func deleteTransactionType(id: Int) -> Bool {
        guard let db else { return false }
        let deleteQuery = "DELETE FROM TransactionTypes WHERE transaction_type_id = ?"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare deleteTransactionType (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        sqlite3_bind_int(statement, 1, Int32(id))
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)

        if result {
            print("✅ Deleted transaction type (ID: \(id))")
        } else {
            print("❌ Delete transaction type failed (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    func canDeleteTransactionType(id: Int) -> (canDelete: Bool, transactionCount: Int) {
        guard let db else { return (canDelete: false, transactionCount: 0) }
        let checkQuery = "SELECT COUNT(*) FROM Transactions WHERE transaction_type_id = ?"
        var checkStatement: OpaquePointer?
        var count = 0

        if sqlite3_prepare_v2(db, checkQuery, -1, &checkStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(checkStatement, 1, Int32(id))
            if sqlite3_step(checkStatement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(checkStatement, 0))
            }
            sqlite3_finalize(checkStatement)
        } else {
            print("❌ Failed to prepare canDeleteTransactionType check (ID: \(id)): \(String(cString: sqlite3_errmsg(db)))")
        }
        return (canDelete: count == 0, transactionCount: count)
    }

    private func reorderTransactionTypes(movingId: Int, desiredOrder: Int) -> Bool {
        var ids = orderedTransactionTypeIds()
        ids.removeAll { $0 == movingId }
        let insertionIndex: Int
        if desiredOrder <= 0 {
            insertionIndex = ids.count
        } else {
            insertionIndex = min(max(0, desiredOrder - 1), ids.count)
        }
        ids.insert(movingId, at: insertionIndex)
        return persistOrder(idsInOrder: ids)
    }

    private func orderedTransactionTypeIds() -> [Int] {
        guard let db else { return [] }
        var ids: [Int] = []
        let sql = """
            SELECT transaction_type_id
            FROM TransactionTypes
            ORDER BY sort_order, type_name, transaction_type_id
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                ids.append(Int(sqlite3_column_int(stmt, 0)))
            }
        } else {
            print("❌ Failed to prepare orderedTransactionTypeIds: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
        return ids
    }

    private func persistOrder(idsInOrder: [Int]) -> Bool {
        guard let db else { return false }
        guard sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else {
            print("❌ Failed to begin reorder transaction: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        let sql = "UPDATE TransactionTypes SET sort_order = ? WHERE transaction_type_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ Failed to prepare reorder update: \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }
        defer { sqlite3_finalize(stmt) }

        var ok = true
        for (index, id) in idsInOrder.enumerated() {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_int(stmt, 1, Int32(index + 1))
            sqlite3_bind_int(stmt, 2, Int32(id))
            if sqlite3_step(stmt) != SQLITE_DONE {
                ok = false
                break
            }
        }

        if ok {
            if sqlite3_exec(db, "COMMIT", nil, nil, nil) != SQLITE_OK {
                print("❌ Failed to commit reorder: \(String(cString: sqlite3_errmsg(db)))")
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                return false
            }
            return true
        } else {
            print("❌ Failed to reorder transaction types: \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            return false
        }
    }
}
