// DragonShield/Models/PortfolioTheme.swift

// MARK: - Version 1.3

// MARK: - History

// - Added description and optional institutionId for richer metadata.
// - Added optional totalValueBase and instrumentCount for list overview metrics.
// - Conformed to Hashable for SwiftUI List selection compatibility.
// - Initial creation: Represents user-defined portfolio themes.

import Foundation

// Hashable conformance is synthesized; equality must reflect valuation updates.
struct PortfolioTheme: Identifiable, Hashable {
    let id: Int
    var name: String
    let code: String
    var description: String?
    var institutionId: Int?
    var statusId: Int
    var timelineId: Int? = nil
    var timeHorizonEndDate: String? = nil
    var createdAt: String
    var updatedAt: String
    var archivedAt: String?
    var softDelete: Bool
    var weeklyChecklistEnabled: Bool = true
    var theoreticalBudgetChf: Double? = nil
    var totalValueBase: Double? = nil
    var instrumentCount: Int = 0
    var riskScore: Double? = nil
    var riskCategory: String? = nil

    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 64
    }

    static func isValidCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^[A-Z][A-Z0-9_]{1,30}$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
