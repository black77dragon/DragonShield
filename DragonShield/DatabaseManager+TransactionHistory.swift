// DragonShield/DatabaseManager+TransactionHistory.swift

// MARK: - Version 1.1

// MARK: - History

// - 1.0 -> 1.1: Implemented database query to fetch transaction history items.

import Foundation
import SQLite3

extension DatabaseManager {
    func fetchTransactionHistoryItems() -> [TransactionRowData] {
        var transactions: [TransactionRowData] = []

        let query = """
            SELECT
                t.transaction_id,
                t.transaction_date,
                a.account_name,
                i.instrument_name,
                tt.type_name,
                t.description,
                t.quantity,
                t.price,
                t.net_amount,
                t.transaction_currency,
                p.portfolio_name
            FROM Transactions t
            JOIN Accounts a ON t.account_id = a.account_id
            JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
            LEFT JOIN Instruments i ON t.instrument_id = i.instrument_id
            LEFT JOIN Portfolios p ON t.portfolio_id = p.portfolio_id
            ORDER BY t.transaction_date DESC, t.transaction_id DESC;
        """
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            print("✅ Successfully prepared fetchTransactionHistoryItems query.")
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))

                let dateStr = String(cString: sqlite3_column_text(statement, 1))
                let date = DateFormatter.iso8601DateOnly.date(from: dateStr) ?? Date() // Fallback to current date if parsing fails

                let accountName = String(cString: sqlite3_column_text(statement, 2))

                let instrumentName: String?
                if sqlite3_column_type(statement, 3) != SQLITE_NULL {
                    instrumentName = String(cString: sqlite3_column_text(statement, 3))
                } else {
                    instrumentName = nil
                }

                let typeName = String(cString: sqlite3_column_text(statement, 4))

                let description: String?
                if sqlite3_column_type(statement, 5) != SQLITE_NULL {
                    description = String(cString: sqlite3_column_text(statement, 5))
                } else {
                    description = nil
                }

                let quantity: Double?
                if sqlite3_column_type(statement, 6) != SQLITE_NULL {
                    quantity = sqlite3_column_double(statement, 6)
                } else {
                    quantity = nil
                }

                let price: Double?
                if sqlite3_column_type(statement, 7) != SQLITE_NULL {
                    price = sqlite3_column_double(statement, 7)
                } else {
                    price = nil
                }

                let netAmount = sqlite3_column_double(statement, 8)
                let currency = String(cString: sqlite3_column_text(statement, 9))

                let portfolioName: String?
                if sqlite3_column_type(statement, 10) != SQLITE_NULL {
                    portfolioName = String(cString: sqlite3_column_text(statement, 10))
                } else {
                    portfolioName = nil
                }

                transactions.append(TransactionRowData(
                    id: id,
                    date: date,
                    accountName: accountName,
                    instrumentName: instrumentName,
                    typeName: typeName,
                    description: description,
                    quantity: quantity,
                    price: price,
                    netAmount: netAmount,
                    currency: currency,
                    portfolioName: portfolioName
                ))
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to prepare fetchTransactionHistoryItems: \(errmsg)")
        }
        sqlite3_finalize(statement)

        print("ℹ️ fetchTransactionHistoryItems() retrieved \(transactions.count) items.")
        return transactions
    }
}
