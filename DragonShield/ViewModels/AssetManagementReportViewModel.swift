import Foundation

struct AssetManagementReportSummary {
    struct CashBreakdown: Identifiable {
        let id: Int
        let accountName: String
        let institutionName: String
        let currency: String
        let localAmount: Double
        let baseAmount: Double
    }

    struct NearCashHolding: Identifiable {
        let id: Int
        let name: String
        let accountName: String
        let category: String
        let currency: String
        let localValue: Double
        let baseValue: Double
    }

    struct AssetClassPosition: Identifiable {
        let id: Int
        let instrumentName: String
        let accountName: String
        let assetSubClass: String
        let currency: String
        let quantity: Double
        let localValue: Double
        let baseValue: Double
    }

    struct AssetClassBreakdown: Identifiable {
        let id: String
        let name: String
        let baseValue: Double
        let percentage: Double
        let positions: [AssetClassPosition]
    }

    struct CurrencyAllocation: Identifiable {
        let id: String
        let currency: String
        let baseValue: Double
        let percentage: Double
    }

    var reportDate: Date
    var baseCurrency: String
    var totalCashBase: Double
    var totalNearCashBase: Double
    var totalPortfolioBase: Double
    var cashBreakdown: [CashBreakdown]
    var nearCashHoldings: [NearCashHolding]
    var currencyAllocations: [CurrencyAllocation]
    var assetClassBreakdown: [AssetClassBreakdown]

    static func empty(baseCurrency: String = "CHF", reportDate: Date = Date()) -> AssetManagementReportSummary {
        AssetManagementReportSummary(
            reportDate: reportDate,
            baseCurrency: baseCurrency,
            totalCashBase: 0,
            totalNearCashBase: 0,
            totalPortfolioBase: 0,
            cashBreakdown: [],
            nearCashHoldings: [],
            currencyAllocations: [],
            assetClassBreakdown: []
        )
    }

    var hasData: Bool {
        !cashBreakdown.isEmpty || !nearCashHoldings.isEmpty || !currencyAllocations.isEmpty || !assetClassBreakdown.isEmpty
    }
}

final class AssetManagementReportViewModel: ObservableObject {
    private let nearCashSubClassCodes: Set<String> = ["GOV_BOND", "CORP_BOND", "MM_INST", "BOND_ETF", "BOND_FUND", "STRUCTURED"]
    @Published private(set) var summary: AssetManagementReportSummary = .empty()
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load(using dbManager: DatabaseManager) {
        if isLoading { return }
        let baseCurrency = normalizedBaseCurrency(dbManager.baseCurrency)
        let reportDate = dbManager.asOfDate
        let manager = dbManager
        isLoading = true
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let summary = self.composeSummary(dbManager: manager, baseCurrency: baseCurrency, reportDate: reportDate)
            DispatchQueue.main.async {
                self.summary = summary
                self.isLoading = false
                self.errorMessage = summary.hasData ? nil : "No holdings or cash balances available for reporting."
            }
        }
    }

    private func composeSummary(dbManager: DatabaseManager, baseCurrency: String, reportDate: Date) -> AssetManagementReportSummary {
        var summary = AssetManagementReportSummary.empty(baseCurrency: baseCurrency, reportDate: reportDate)
        let accounts = dbManager.fetchAccounts()
        let accountTypes = dbManager.fetchAccountTypes(activeOnly: false)
        let assetClassRecords = dbManager.fetchAssetClassesDetailed()
        let classCodeToName = Dictionary(uniqueKeysWithValues: assetClassRecords.map { ($0.code.uppercased(), $0.name) })
        let classDisplayOrder = assetClassRecords.map { $0.code.uppercased() }
        let cashTypeIds = Set(accountTypes.filter(isCashType).map(\.id))
        let accountTypeCodes = Dictionary(uniqueKeysWithValues: accountTypes.map { ($0.id, $0.code.uppercased()) })
        var cashRows: [AssetManagementReportSummary.CashBreakdown] = []
        var currencyTotals: [String: Double] = [:]
        struct AssetClassAggregate {
            var code: String?
            var name: String
            var value: Double
            var positions: [AssetManagementReportSummary.AssetClassPosition]
        }
        var assetClassTotals: [String: AssetClassAggregate] = [:]
        let today = Date()

        for account in accounts where isCashAccount(account, cashTypeIds: cashTypeIds, accountTypeCodes: accountTypeCodes) {
            let localAmount = dbManager.currentCashBalance(accountId: account.id, upTo: today)
            guard abs(localAmount) > 0.05 else { continue }
            let currency = account.currencyCode.uppercased()
            guard let conversion = dbManager.convertValueToBase(value: localAmount, from: currency, baseCurrency: baseCurrency) else { continue }
            let baseValue = conversion.value
            cashRows.append(
                .init(
                    id: account.id,
                    accountName: account.accountName,
                    institutionName: account.institutionName,
                    currency: currency,
                    localAmount: localAmount,
                    baseAmount: baseValue
                )
            )
            summary.totalCashBase += baseValue
            currencyTotals[currency, default: 0] += baseValue
        }
        let positions = dbManager.fetchPositionReports()
        var nearCashRows: [AssetManagementReportSummary.NearCashHolding] = []
        for position in positions {
            let localValue = localValue(for: position)
            guard abs(localValue) > 0.05 else { continue }
            let currency = position.instrumentCurrency.uppercased()
            guard let conversion = dbManager.convertValueToBase(value: localValue, from: currency, baseCurrency: baseCurrency) else { continue }
            let baseValue = conversion.value
            currencyTotals[currency, default: 0] += baseValue

            if abs(baseValue) > 0.01 {
                let classCode = position.assetClassCode?.uppercased()
                let className = classCode.flatMap { classCodeToName[$0] } ?? position.assetClass?.trimmedNonEmpty ?? "Unclassified"
                let entryPosition = AssetManagementReportSummary.AssetClassPosition(
                    id: position.id,
                    instrumentName: position.instrumentName,
                    accountName: position.accountName,
                    assetSubClass: position.assetSubClass?.trimmedNonEmpty ?? "—",
                    currency: currency,
                    quantity: position.quantity,
                    localValue: localValue,
                    baseValue: baseValue
                )
                let key = classCode ?? className
                var aggregate = assetClassTotals[key] ?? AssetClassAggregate(code: classCode, name: className, value: 0, positions: [])
                aggregate.value += baseValue
                aggregate.positions.append(entryPosition)
                assetClassTotals[key] = aggregate
            }

            if isCashPosition(subClass: position.assetSubClass, code: position.assetSubClassCode) {
                let identifier = -1 * (10_000_000 + max(position.id, 0))
                cashRows.append(
                    .init(
                        id: identifier,
                        accountName: position.accountName,
                        institutionName: position.instrumentName,
                        currency: currency,
                        localAmount: localValue,
                        baseAmount: baseValue
                    )
                )
                summary.totalCashBase += baseValue
            } else if isNearCash(subClassCode: position.assetSubClassCode) {
                let category = position.assetClass ?? "Near Cash"
                nearCashRows.append(
                    .init(
                        id: position.id,
                        name: position.instrumentName,
                        accountName: position.accountName,
                        category: category,
                        currency: currency,
                        localValue: localValue,
                        baseValue: baseValue
                    )
                )
                summary.totalNearCashBase += baseValue
            }
        }
        summary.cashBreakdown = cashRows.sorted { $0.baseAmount > $1.baseAmount }
        summary.nearCashHoldings = nearCashRows.sorted { $0.baseValue > $1.baseValue }

        let totalPortfolioBase = currencyTotals.values.reduce(0, +)
        summary.totalPortfolioBase = totalPortfolioBase
        if totalPortfolioBase > 0 {
            summary.currencyAllocations = currencyTotals
                .map { AssetManagementReportSummary.CurrencyAllocation(id: $0.key, currency: $0.key, baseValue: $0.value, percentage: ($0.value / totalPortfolioBase) * 100) }
                .sorted { $0.baseValue > $1.baseValue }
        } else {
            summary.currencyAllocations = []
        }
        var orderedKeys: [String] = []
        for code in classDisplayOrder {
            if assetClassTotals[code] != nil {
                orderedKeys.append(code)
            }
        }
        let remainingKeys = assetClassTotals.keys.filter { !orderedKeys.contains($0) }
            .sorted { lhs, rhs in
                let left = assetClassTotals[lhs]?.value ?? 0
                let right = assetClassTotals[rhs]?.value ?? 0
                return left > right
            }
        orderedKeys.append(contentsOf: remainingKeys)

        summary.assetClassBreakdown = orderedKeys.compactMap { key in
            guard let aggregate = assetClassTotals[key] else { return nil }
            return AssetManagementReportSummary.AssetClassBreakdown(
                id: aggregate.code ?? aggregate.name,
                name: aggregate.name,
                baseValue: aggregate.value,
                percentage: totalPortfolioBase > 0 ? (aggregate.value / totalPortfolioBase) * 100 : 0,
                positions: aggregate.positions.sorted { $0.baseValue > $1.baseValue }
            )
        }

        return summary
    }

    private func isCashAccount(
        _ account: DatabaseManager.AccountData,
        cashTypeIds: Set<Int>,
        accountTypeCodes: [Int: String]
    ) -> Bool {
        if let code = accountTypeCodes[account.accountTypeId], code == "BANK" {
            return true
        }
        if cashTypeIds.contains(account.accountTypeId) { return true }
        let normalizedType = account.accountType.lowercased()
        let normalizedName = account.accountName.lowercased()
        return normalizedType.contains("cash") || normalizedType.contains("liquid") || normalizedName.contains("cash")
    }

    private func isCashType(_ type: DatabaseManager.AccountTypeData) -> Bool {
        let code = type.code.uppercased()
        let name = type.name.lowercased()
        if code.contains("CASH") || code.contains("LIQ") { return true }
        return name.contains("cash") || name.contains("liquidity") || name.contains("liquid")
    }

    private func isCashPosition(subClass: String?, code: String?) -> Bool {
        if let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), code == "CASH" {
            return true
        }
        guard let subClass else { return false }
        return subClass.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("cash") == .orderedSame
    }

    private func isNearCash(subClassCode: String?) -> Bool {
        guard let code = subClassCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else {
            return false
        }
        return nearCashSubClassCodes.contains(code)
    }

    private func localValue(for report: PositionReportData) -> Double {
        if let price = report.currentPrice ?? report.purchasePrice {
            return report.quantity * price
        }
        return report.quantity
    }

    private func normalizedBaseCurrency(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercased = trimmed.isEmpty ? "CHF" : trimmed.uppercased()
        return uppercased
    }
}

private extension Optional where Wrapped == String {
    var trimmedNonEmpty: String? {
        guard let value = self else { return nil }
        return value.trimmedNonEmpty
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if DEBUG
extension AssetManagementReportSummary {
    static var preview: AssetManagementReportSummary {
        AssetManagementReportSummary(
            reportDate: Date(),
            baseCurrency: "CHF",
            totalCashBase: 200_000,
            totalNearCashBase: 120_000,
            totalPortfolioBase: 520_000,
            cashBreakdown: [
                .init(id: 1, accountName: "ZKB Private Account", institutionName: "Zürcher Kantonalbank", currency: "CHF", localAmount: 200_000, baseAmount: 200_000),
                .init(id: 2, accountName: "Credit Suisse USD", institutionName: "Credit Suisse", currency: "USD", localAmount: 70_000, baseAmount: 61_000)
            ],
            nearCashHoldings: [
                .init(id: 101, name: "Swiss Confederation 1.5% 2027", accountName: "ZKB Custody", category: "Bonds", currency: "CHF", localValue: 80_000, baseValue: 80_000),
                .init(id: 102, name: "iShares Ultra Short Bond ETF", accountName: "IBKR Custody", category: "Money Market", currency: "USD", localValue: 45_000, baseValue: 39_000)
            ],
            currencyAllocations: [
                .init(id: "CHF", currency: "CHF", baseValue: 320_000, percentage: 61.5),
                .init(id: "USD", currency: "USD", baseValue: 160_000, percentage: 30.7),
                .init(id: "EUR", currency: "EUR", baseValue: 40_000, percentage: 7.8)
            ],
            assetClassBreakdown: [
                .init(
                    id: "Equities",
                    name: "Equities",
                    baseValue: 280_000,
                    percentage: 53.8,
                    positions: [
                        .init(id: 9001, instrumentName: "Apple Inc.", accountName: "IBKR Custody", assetSubClass: "US Equity", currency: "USD", quantity: 120, localValue: 24_000, baseValue: 20_900),
                        .init(id: 9002, instrumentName: "Nestlé", accountName: "ZKB Custody", assetSubClass: "CH Equity", currency: "CHF", quantity: 180, localValue: 22_000, baseValue: 22_000)
                    ]
                ),
                .init(
                    id: "Bonds",
                    name: "Bonds",
                    baseValue: 140_000,
                    percentage: 26.9,
                    positions: [
                        .init(id: 9101, instrumentName: "Swiss Gov 2028", accountName: "ZKB Custody", assetSubClass: "GOV_BOND", currency: "CHF", quantity: 100_000, localValue: 100_000, baseValue: 100_000),
                        .init(id: 9102, instrumentName: "iShares Bond ETF", accountName: "IBKR Custody", assetSubClass: "BOND_ETF", currency: "USD", quantity: 1_500, localValue: 38_000, baseValue: 32_000)
                    ]
                ),
                .init(
                    id: "Alternatives",
                    name: "Alternatives",
                    baseValue: 100_000,
                    percentage: 19.2,
                    positions: [
                        .init(id: 9201, instrumentName: "Bitcoin ETP", accountName: "IBKR Custody", assetSubClass: "Crypto", currency: "USD", quantity: 5, localValue: 50_000, baseValue: 44_000),
                        .init(id: 9202, instrumentName: "Private Equity Fund", accountName: "Credit Suisse Custody", assetSubClass: "Private Equity", currency: "USD", quantity: 1, localValue: 60_000, baseValue: 56_000)
                    ]
                )
            ]
        )
    }
}

extension AssetManagementReportViewModel {
    func applyPreviewData(_ summary: AssetManagementReportSummary) {
        self.summary = summary
        self.errorMessage = nil
        self.isLoading = false
    }
}
#endif
