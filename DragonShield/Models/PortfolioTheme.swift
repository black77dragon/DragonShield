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
        return !name.isEmpty && name.count <= 64
    }

    static func isValidCode(_ code: String) -> Bool {
        let pattern = "^[A-Z][A-Z0-9_]{1,30}$"
        return code.range(of: pattern, options: .regularExpression) != nil
    }
}
