// DragonShield/DatabaseManager+TransactionTypes.swift

// MARK: - Version 1.0 (2025-05-30)

// MARK: - History

// - Initial creation: Refactored from DatabaseManager.swift.

import Foundation

extension DatabaseManager {
    func fetchTransactionTypes() -> [(id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int)] {
        TransactionTypeRepository(connection: databaseConnection).fetchTransactionTypes()
    }

    func fetchTransactionTypeDetails(id: Int) -> (id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int)? {
        TransactionTypeRepository(connection: databaseConnection).fetchTransactionTypeDetails(id: id)
    }

    func addTransactionType(code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int) -> Bool {
        TransactionTypeRepository(connection: databaseConnection).addTransactionType(
            code: code,
            name: name,
            description: description,
            affectsPosition: affectsPosition,
            affectsCash: affectsCash,
            isIncome: isIncome,
            sortOrder: sortOrder
        )
    }

    func updateTransactionType(id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int) -> Bool {
        TransactionTypeRepository(connection: databaseConnection).updateTransactionType(
            id: id,
            code: code,
            name: name,
            description: description,
            affectsPosition: affectsPosition,
            affectsCash: affectsCash,
            isIncome: isIncome,
            sortOrder: sortOrder
        )
    }

    func deleteTransactionType(id: Int) -> Bool { // Hard delete
        TransactionTypeRepository(connection: databaseConnection).deleteTransactionType(id: id)
    }

    func canDeleteTransactionType(id: Int) -> (canDelete: Bool, transactionCount: Int) {
        TransactionTypeRepository(connection: databaseConnection).canDeleteTransactionType(id: id)
    }
}
