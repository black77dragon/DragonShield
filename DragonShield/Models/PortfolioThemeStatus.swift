// DragonShield/Models/PortfolioThemeStatus.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: Represents status codes for portfolio themes.

import Foundation

struct PortfolioThemeStatus: Identifiable {
    static let archivedCode = "ARCHIVED"
    let id: Int
    let code: String
    var name: String
    var colorHex: String
    var isDefault: Bool

    static func isValidCode(_ code: String) -> Bool {
        let pattern = "^[A-Z][A-Z0-9_]{1,30}$"
        return code.range(of: pattern, options: .regularExpression) != nil
    }

    static func isValidName(_ name: String) -> Bool {
        return !name.isEmpty && name.count <= 64
    }

    static func isValidColor(_ hex: String) -> Bool {
        let pattern = "^#[0-9A-Fa-f]{6}$"
        return hex.range(of: pattern, options: .regularExpression) != nil
    }
}
