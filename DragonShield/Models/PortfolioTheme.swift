// DragonShield/Models/PortfolioTheme.swift
// MARK: - Version 1.2
// MARK: - History
// - Added optional totalValueBase and instrumentCount for list overview metrics.
// - Conformed to Hashable for SwiftUI List selection compatibility.
// - Initial creation: Represents user-defined portfolio themes.

import Foundation

// Add Hashable conformance
struct PortfolioTheme: Identifiable, Hashable {
    let id: Int
    var name: String
    let code: String
    // This property does not exist in the database table or creation method,
    // so it should be removed from the main struct if not used elsewhere.
    // For now, we will assume it might be used in other contexts.
    // var description: String? 
    var statusId: Int
    var createdAt: String
    var updatedAt: String
    var archivedAt: String?
    var softDelete: Bool
    var totalValueBase: Double? = nil
    var instrumentCount: Int = 0

    // Required for Hashable
    static func == (lhs: PortfolioTheme, rhs: PortfolioTheme) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

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
