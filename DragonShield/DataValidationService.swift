// DragonShield/DataValidationService.swift
// MARK: - Version 1.0.0.0
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial validation logic for parsed CSV rows.

import Foundation

enum ValidationError: Error {
    case missingField(String)
    case invalidDate(String)
    case invalidNumber(String)
}

struct DataValidationService {
    private let dateFormatter: DateFormatter

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }

    func validate(rawRecord: [String: String]) throws -> MyBankRecord {
        guard let dateString = rawRecord["Date"], let date = dateFormatter.date(from: dateString) else {
            throw ValidationError.invalidDate(rawRecord["Date"] ?? "")
        }
        guard let amountString = rawRecord["Amount"], let amount = Double(amountString) else {
            throw ValidationError.invalidNumber(rawRecord["Amount"] ?? "")
        }
        guard let description = rawRecord["Description"] else {
            throw ValidationError.missingField("Description")
        }
        let currency = rawRecord["Currency"] ?? "CHF"
        let account = rawRecord["Account"] ?? ""
        return MyBankRecord(transactionDate: date, description: description, amount: amount, currency: currency, bankAccount: account)
    }
}
