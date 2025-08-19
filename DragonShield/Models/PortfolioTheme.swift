// DragonShield/Models/PortfolioTheme.swift
// MARK: - Version 1.1
// MARK: - History
// - Conformed to Hashable and Equatable for SwiftUI compatibility.
// - Initial creation: Represents user-defined portfolio themes.

import Foundation

// Add Hashable conformance here
struct PortfolioTheme: Identifiable, Hashable {
    let id: Int
    var name: String
    let code: String
    var statusId: Int
    var createdAt: String
    var updatedAt: String
    var archivedAt: String?
    var softDelete: Bool

    // Add Equatable conformance (required for Hashable)
    static func == (lhs: PortfolioTheme, rhs: PortfolioTheme) -> Bool {
        return lhs.id == rhs.id
    }

    // Implement the hash(into:) method
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
