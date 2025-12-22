// DragonShield/DatabaseManager+Currencies.swift

// MARK: - Version 1.1

// MARK: - History

// - 1.0 -> 1.1: Corrected string binding in fetchCurrencyDetails to fix data loading bug.
// - Initial creation: Refactored from DatabaseManager.swift.

import Foundation

extension DatabaseManager {
    func fetchActiveCurrencies() -> [(code: String, name: String, symbol: String)] {
        CurrencyRepository(connection: databaseConnection).fetchActiveCurrencies()
    }

    func fetchCurrencies() -> [(code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)] {
        CurrencyRepository(connection: databaseConnection).fetchCurrencies()
    }

    func debugListAllCurrencies() {
        CurrencyRepository(connection: databaseConnection).debugListAllCurrencies()
    }

    func fetchCurrencyDetails(code: String) -> (code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)? {
        CurrencyRepository(connection: databaseConnection).fetchCurrencyDetails(code: code)
    }

    func addCurrency(code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool) -> Bool {
        CurrencyRepository(connection: databaseConnection).addCurrency(
            code: code,
            name: name,
            symbol: symbol,
            isActive: isActive,
            apiSupported: apiSupported
        )
    }

    func updateCurrency(code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool) -> Bool {
        CurrencyRepository(connection: databaseConnection).updateCurrency(
            code: code,
            name: name,
            symbol: symbol,
            isActive: isActive,
            apiSupported: apiSupported
        )
    }

    func deleteCurrency(code: String) -> Bool { // Soft delete
        CurrencyRepository(connection: databaseConnection).deleteCurrency(code: code)
    }
}
