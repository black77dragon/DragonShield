// DragonShield/Models/PortfolioTheme.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: Represents user-defined portfolio themes.

import Foundation

struct PortfolioTheme: Identifiable {
    let id: Int
    var name: String
    let code: String
    var statusId: Int
    var createdAt: String
    var updatedAt: String
    var archivedAt: String?
    var softDelete: Bool

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
