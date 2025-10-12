import Foundation

enum TablePreferenceKind {
    case institutions
    case instruments
    case assetSubClasses
    case assetClasses
    case currencies
    case accounts
    case portfolioThemes
    case transactionTypes
    case accountTypes

    var logLabel: String {
        switch self {
        case .institutions: return "institutions"
        case .instruments: return "instruments"
        case .assetSubClasses: return "asset-subclasses"
        case .assetClasses: return "asset-classes"
        case .currencies: return "currencies"
        case .accounts: return "accounts"
        case .portfolioThemes: return "portfolio-themes"
        case .transactionTypes: return "transaction-types"
        case .accountTypes: return "account-types"
        }
    }

    var fractionsKeyPath: ReferenceWritableKeyPath<DatabaseManager, [String: Double]> {
        switch self {
        case .institutions: return \DatabaseManager.institutionsTableColumnFractions
        case .instruments: return \DatabaseManager.instrumentsTableColumnFractions
        case .assetSubClasses: return \DatabaseManager.assetSubClassesTableColumnFractions
        case .assetClasses: return \DatabaseManager.assetClassesTableColumnFractions
        case .currencies: return \DatabaseManager.currenciesTableColumnFractions
        case .accounts: return \DatabaseManager.accountsTableColumnFractions
        case .portfolioThemes: return \DatabaseManager.portfolioThemesTableColumnFractions
        case .transactionTypes: return \DatabaseManager.transactionTypesTableColumnFractions
        case .accountTypes: return \DatabaseManager.accountTypesTableColumnFractions
        }
    }

    var fontKeyPath: ReferenceWritableKeyPath<DatabaseManager, String> {
        switch self {
        case .institutions: return \DatabaseManager.institutionsTableFontSize
        case .instruments: return \DatabaseManager.instrumentsTableFontSize
        case .assetSubClasses: return \DatabaseManager.assetSubClassesTableFontSize
        case .assetClasses: return \DatabaseManager.assetClassesTableFontSize
        case .currencies: return \DatabaseManager.currenciesTableFontSize
        case .accounts: return \DatabaseManager.accountsTableFontSize
        case .portfolioThemes: return \DatabaseManager.portfolioThemesTableFontSize
        case .transactionTypes: return \DatabaseManager.transactionTypesTableFontSize
        case .accountTypes: return \DatabaseManager.accountTypesTableFontSize
        }
    }

    var legacyFractionsKey: String {
        switch self {
        case .institutions: return "InstitutionsView.columnFractions.v1"
        case .instruments: return "PortfolioView.instrumentColumnFractions.v2"
        case .assetSubClasses: return "AssetSubClassesView.columnFractions.v1"
        case .assetClasses: return "AssetClassesView.columnFractions.v1"
        case .currencies: return "CurrenciesView.columnFractions.v1"
        case .accounts: return "AccountsView.columnFractions.v1"
        case .portfolioThemes: return "NewPortfoliosView.columnFractions.v1"
        case .transactionTypes: return "TransactionTypesView.columnFractions.v1"
        case .accountTypes: return "AccountTypesView.columnFractions.v1"
        }
    }

    var legacyFontKey: String {
        switch self {
        case .institutions: return "InstitutionsView.tableFontSize.v1"
        case .instruments: return "PortfolioView.tableFontSize.v1"
        case .assetSubClasses: return "AssetSubClassesView.tableFontSize.v1"
        case .assetClasses: return "AssetClassesView.tableFontSize.v1"
        case .currencies: return "CurrenciesView.tableFontSize.v1"
        case .accounts: return "AccountsView.tableFontSize.v1"
        case .portfolioThemes: return "NewPortfoliosView.tableFontSize.v1"
        case .transactionTypes: return "TransactionTypesView.tableFontSize.v1"
        case .accountTypes: return "AccountTypesView.tableFontSize.v1"
        }
    }
}

extension DatabaseManager {
    func tableColumnFractions(for kind: TablePreferenceKind) -> [String: Double] {
        self[keyPath: kind.fractionsKeyPath]
    }

    func setTableColumnFractions(_ fractions: [String: Double], for kind: TablePreferenceKind) {
        switch kind {
        case .institutions: setInstitutionsTableColumnFractions(fractions)
        case .instruments: setInstrumentsTableColumnFractions(fractions)
        case .assetSubClasses: setAssetSubClassesTableColumnFractions(fractions)
        case .assetClasses: setAssetClassesTableColumnFractions(fractions)
        case .currencies: setCurrenciesTableColumnFractions(fractions)
        case .accounts: setAccountsTableColumnFractions(fractions)
        case .portfolioThemes: setPortfolioThemesTableColumnFractions(fractions)
        case .transactionTypes: setTransactionTypesTableColumnFractions(fractions)
        case .accountTypes: setAccountTypesTableColumnFractions(fractions)
        }
    }

    func tableFontSize(for kind: TablePreferenceKind) -> String {
        self[keyPath: kind.fontKeyPath]
    }

    func setTableFontSize(_ value: String, for kind: TablePreferenceKind) {
        switch kind {
        case .institutions: setInstitutionsTableFontSize(value)
        case .instruments: setInstrumentsTableFontSize(value)
        case .assetSubClasses: setAssetSubClassesTableFontSize(value)
        case .assetClasses: setAssetClassesTableFontSize(value)
        case .currencies: setCurrenciesTableFontSize(value)
        case .accounts: setAccountsTableFontSize(value)
        case .portfolioThemes: setPortfolioThemesTableFontSize(value)
        case .transactionTypes: setTransactionTypesTableFontSize(value)
        case .accountTypes: setAccountTypesTableFontSize(value)
        }
    }

    func legacyTableColumnFractions(for kind: TablePreferenceKind) -> [String: Double]? {
        let defaults = UserDefaults.standard
        var restored: [String: Double] = [:]

        if let dictionary = defaults.dictionary(forKey: kind.legacyFractionsKey) {
            for (key, value) in dictionary {
                if let parsed = DatabaseManager.parseFractionValue(value) {
                    restored[key] = parsed
                }
            }
        } else if let raw = defaults.string(forKey: kind.legacyFractionsKey) {
            for part in raw.split(separator: ",") {
                let pieces = part.split(separator: ":", maxSplits: 1)
                guard pieces.count == 2,
                      let parsed = DatabaseManager.parseFractionValue(String(pieces[1])) else { continue }
                restored[String(pieces[0])] = parsed
            }
        }

        return restored.isEmpty ? nil : restored
    }

    func clearLegacyTableColumnFractions(for kind: TablePreferenceKind) {
        UserDefaults.standard.removeObject(forKey: kind.legacyFractionsKey)
    }

    func legacyTableFontSize(for kind: TablePreferenceKind) -> String? {
        UserDefaults.standard.string(forKey: kind.legacyFontKey)
    }

    func clearLegacyTableFontSize(for kind: TablePreferenceKind) {
        UserDefaults.standard.removeObject(forKey: kind.legacyFontKey)
    }

    private static func parseFractionValue(_ value: Any) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        guard let stringValue = value as? String else { return nil }
        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = Double(trimmed) { return direct }

        let formatters: [NumberFormatter] = {
            let en = NumberFormatter()
            en.locale = Locale(identifier: "en_US_POSIX")
            en.numberStyle = .decimal

            let current = NumberFormatter()
            current.locale = Locale.current
            current.numberStyle = .decimal
            return [en, current]
        }()

        for formatter in formatters {
            if let number = formatter.number(from: trimmed) {
                return number.doubleValue
            }
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
