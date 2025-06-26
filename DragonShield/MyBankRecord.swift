// DragonShield/MyBankRecord.swift
// MARK: - Version 1.0.0.0
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial creation of record model used for CSV imports.

import Foundation

struct MyBankRecord: Codable, Identifiable {
    let id: UUID
    let transactionDate: Date
    let description: String
    let amount: Double
    let currency: String
    let bankAccount: String

    init(id: UUID = UUID(), transactionDate: Date, description: String, amount: Double, currency: String, bankAccount: String) {
        self.id = id
        self.transactionDate = transactionDate
        self.description = description
        self.amount = amount
        self.currency = currency
        self.bankAccount = bankAccount
    }
}
