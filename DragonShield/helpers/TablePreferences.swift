import Foundation

enum TablePreferenceKind {
    case institutions
    case instruments
    case assetSubClasses
    case assetClasses
    case currencies
    case accounts
    case positions
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
        case .positions: return "positions"
        case .portfolioThemes: return "portfolio-themes"
        case .transactionTypes: return "transaction-types"
        case .accountTypes: return "account-types"
        }
    }

    var preferencesFractionsKeyPath: ReferenceWritableKeyPath<AppPreferences, [String: Double]> {
        switch self {
        case .institutions: return \AppPreferences.institutionsTableColumnFractions
        case .instruments: return \AppPreferences.instrumentsTableColumnFractions
        case .assetSubClasses: return \AppPreferences.assetSubClassesTableColumnFractions
        case .assetClasses: return \AppPreferences.assetClassesTableColumnFractions
        case .currencies: return \AppPreferences.currenciesTableColumnFractions
        case .accounts: return \AppPreferences.accountsTableColumnFractions
        case .positions: return \AppPreferences.positionsTableColumnFractions
        case .portfolioThemes: return \AppPreferences.portfolioThemesTableColumnFractions
        case .transactionTypes: return \AppPreferences.transactionTypesTableColumnFractions
        case .accountTypes: return \AppPreferences.accountTypesTableColumnFractions
        }
    }

    var preferencesFontKeyPath: ReferenceWritableKeyPath<AppPreferences, String> {
        switch self {
        case .institutions: return \AppPreferences.institutionsTableFontSize
        case .instruments: return \AppPreferences.instrumentsTableFontSize
        case .assetSubClasses: return \AppPreferences.assetSubClassesTableFontSize
        case .assetClasses: return \AppPreferences.assetClassesTableFontSize
        case .currencies: return \AppPreferences.currenciesTableFontSize
        case .accounts: return \AppPreferences.accountsTableFontSize
        case .positions: return \AppPreferences.positionsTableFontSize
        case .portfolioThemes: return \AppPreferences.portfolioThemesTableFontSize
        case .transactionTypes: return \AppPreferences.transactionTypesTableFontSize
        case .accountTypes: return \AppPreferences.accountTypesTableFontSize
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
        case .positions: return "PositionsView.columnFractions.v1"
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
        case .positions: return "PositionsView.tableFontSize.v1"
        case .portfolioThemes: return "NewPortfoliosView.tableFontSize.v1"
        case .transactionTypes: return "TransactionTypesView.tableFontSize.v1"
        case .accountTypes: return "AccountTypesView.tableFontSize.v1"
        }
    }
}

extension DatabaseManager {
    func tableColumnFractions(for kind: TablePreferenceKind) -> [String: Double] {
        preferences.tableColumnFractions(for: kind)
    }

    func setTableColumnFractions(_ fractions: [String: Double], for kind: TablePreferenceKind) {
        switch kind {
        case .institutions: setInstitutionsTableColumnFractions(fractions)
        case .instruments: setInstrumentsTableColumnFractions(fractions)
        case .assetSubClasses: setAssetSubClassesTableColumnFractions(fractions)
        case .assetClasses: setAssetClassesTableColumnFractions(fractions)
        case .currencies: setCurrenciesTableColumnFractions(fractions)
        case .accounts: setAccountsTableColumnFractions(fractions)
        case .positions: setPositionsTableColumnFractions(fractions)
        case .portfolioThemes: setPortfolioThemesTableColumnFractions(fractions)
        case .transactionTypes: setTransactionTypesTableColumnFractions(fractions)
        case .accountTypes: setAccountTypesTableColumnFractions(fractions)
        }
    }

    func tableFontSize(for kind: TablePreferenceKind) -> String {
        preferences.tableFontSize(for: kind)
    }

    func setTableFontSize(_ value: String, for kind: TablePreferenceKind) {
        switch kind {
        case .institutions: setInstitutionsTableFontSize(value)
        case .instruments: setInstrumentsTableFontSize(value)
        case .assetSubClasses: setAssetSubClassesTableFontSize(value)
        case .assetClasses: setAssetClassesTableFontSize(value)
        case .currencies: setCurrenciesTableFontSize(value)
        case .accounts: setAccountsTableFontSize(value)
        case .positions: setPositionsTableFontSize(value)
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

extension AppPreferences {
    func tableColumnFractions(for kind: TablePreferenceKind) -> [String: Double] {
        self[keyPath: kind.preferencesFractionsKeyPath]
    }

    func tableFontSize(for kind: TablePreferenceKind) -> String {
        self[keyPath: kind.preferencesFontKeyPath]
    }
}
