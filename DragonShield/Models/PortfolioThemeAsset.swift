import Foundation

// Represents a link between a portfolio theme and an instrument with target allocations.
struct PortfolioThemeAsset: Identifiable, Hashable {
    let themeId: Int
    let instrumentId: Int
    var researchTargetPct: Double
    var userTargetPct: Double
    var setTargetChf: Double?
    var notes: String?
    var createdAt: String
    var updatedAt: String

    var id: Int { instrumentId }

    static func isValidPercentage(_ value: Double) -> Bool {
        value >= 0.0 && value <= 100.0
    }
}
