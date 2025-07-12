// DragonShield/DatabaseManager+Dashboard.swift
// MARK: - Version 1.0 (2025-06-01)
// MARK: - History
// - Initial creation: Placeholder methods for fetching dashboard data.

import Foundation

// Data Structures for Dashboard Components
struct LargestPositionItem: Identifiable {
    let id: String // Could be instrument ISIN or a unique generated ID
    let name: String
    let valueInBaseCurrency: Double
    let assetClass: String
    // Later: P&L, deltaToTarget, etc.
}

struct AssetClassAllocationItem: Identifiable {
    let id: String // Asset class name or ID
    let assetClassName: String
    let valueInBaseCurrency: Double
    let actualPercentage: Double
    // Later: targetPercentage
}

struct OptionHoldingItem: Identifiable {
    let id: String // Could be instrument ISIN or a unique generated ID
    let name: String // e.g., "AAPL 2025-12-31 C150"
    let quantity: Double
    let currentPrice: Double?
    let expiryDate: Date
    let strikePrice: Double
    let underlyingAsset: String?
    let type: String // Call or Put
}

struct AssetAllocationVarianceItem: Identifiable {
    let id: String
    let assetClassName: String
    let currentPercent: Double
    let targetPercent: Double
    let currentValue: Double
    let lastRebalance: Date?
}

struct AssetDashboardClass: Identifiable {
    let id = UUID()
    let name: String
    let assets: [AssetDashboardItem]
}

struct AssetDashboardItem: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
}

extension DatabaseManager {

    func fetchLargestPositions(count: Int = 5) -> [LargestPositionItem] {
        // Placeholder: Returns sample data.
        // Actual implementation will query holdings, get current prices, convert to base currency, and rank.
        print("ℹ️ fetchLargestPositions() called - returning sample data.")
        return [
            LargestPositionItem(id: "AAPL", name: "Apple Inc.", valueInBaseCurrency: 15000.00, assetClass: "Equity"),
            LargestPositionItem(id: "MSFT", name: "Microsoft Corp.", valueInBaseCurrency: 12500.00, assetClass: "Equity"),
            LargestPositionItem(id: "IWDA", name: "iShares MSCI World ETF", valueInBaseCurrency: 11000.00, assetClass: "ETF"),
            LargestPositionItem(id: "BTC", name: "Bitcoin", valueInBaseCurrency: 9500.00, assetClass: "Crypto"),
            LargestPositionItem(id: "ROG", name: "Roche Holding AG", valueInBaseCurrency: 8000.00, assetClass: "Equity")
        ].prefix(count).map { $0 }
    }

    func fetchAssetClassAllocation() -> [AssetClassAllocationItem] {
        // Placeholder: Returns sample data.
        // Actual implementation will aggregate values by asset class.
        print("ℹ️ fetchAssetClassAllocation() called - returning sample data.")
        let totalValue = 56000.0 // Sample total portfolio value for percentage calculation
        return [
            AssetClassAllocationItem(id: "Equity", assetClassName: "Equities", valueInBaseCurrency: 35500.00, actualPercentage: (35500/totalValue)*100),
            AssetClassAllocationItem(id: "ETF", assetClassName: "ETFs", valueInBaseCurrency: 11000.00, actualPercentage: (11000/totalValue)*100),
            AssetClassAllocationItem(id: "Crypto", assetClassName: "Cryptocurrencies", valueInBaseCurrency: 9500.00, actualPercentage: (9500/totalValue)*100),
            // Add other classes like Bonds, Cash, Real Estate as needed
        ]
    }

    func fetchOptionHoldings() -> [OptionHoldingItem] {
        // Placeholder: Returns sample data.
        // Actual implementation will query instruments identified as options and their current holdings.
        // Assuming 'Options' is an InstrumentGroup or identified by some other means.
        print("ℹ️ fetchOptionHoldings() called - returning sample data.")
        
        let calendar = Calendar.current
        let oneMonthFromNow = calendar.date(byAdding: .month, value: 1, to: Date())!
        let threeMonthsFromNow = calendar.date(byAdding: .month, value: 3, to: Date())!
        
        return [
            OptionHoldingItem(id: "AAPL2512C150", name: "AAPL DEC 2025 150C", quantity: 10, currentPrice: 5.50, expiryDate: oneMonthFromNow, strikePrice: 150.00, underlyingAsset: "AAPL", type: "Call"),
            OptionHoldingItem(id: "SPY2509P400", name: "SPY SEP 2025 400P", quantity: 5, currentPrice: 8.20, expiryDate: threeMonthsFromNow, strikePrice: 400.00, underlyingAsset: "SPY", type: "Put"),
        ]
    }

    func fetchAssetAllocationVariance() -> (items: [AssetAllocationVarianceItem], portfolioValue: Double) {
        print("ℹ️ fetchAssetAllocationVariance() called - returning sample data.")

        let portfolioValue = 56000.0
        let allocations = [
            AssetAllocationVarianceItem(id: "Equity", assetClassName: "Equities", currentPercent: (35500/portfolioValue)*100, targetPercent: 60, currentValue: 35500, lastRebalance: Date(timeIntervalSinceNow: -60*60*24*30)),
            AssetAllocationVarianceItem(id: "ETF", assetClassName: "ETFs", currentPercent: (11000/portfolioValue)*100, targetPercent: 25, currentValue: 11000, lastRebalance: Date(timeIntervalSinceNow: -60*60*24*60)),
            AssetAllocationVarianceItem(id: "Crypto", assetClassName: "Cryptocurrencies", currentPercent: (9500/portfolioValue)*100, targetPercent: 10, currentValue: 9500, lastRebalance: Date(timeIntervalSinceNow: -60*60*24*10))
        ]

        return (allocations, portfolioValue)
    }

    func fetchAssetDashboardData() -> [AssetDashboardClass] {
        // Placeholder groups ordered by total value
        return [
            AssetDashboardClass(name: "Equities", assets: [
                AssetDashboardItem(name: "Apple Inc.", value: 15000),
                AssetDashboardItem(name: "Microsoft Corp.", value: 12500),
                AssetDashboardItem(name: "Roche Holding AG", value: 8000)
            ]),
            AssetDashboardClass(name: "ETFs", assets: [
                AssetDashboardItem(name: "iShares MSCI World", value: 11000)
            ]),
            AssetDashboardClass(name: "Crypto", assets: [
                AssetDashboardItem(name: "Bitcoin", value: 9500)
            ])
        ]
    }
}
