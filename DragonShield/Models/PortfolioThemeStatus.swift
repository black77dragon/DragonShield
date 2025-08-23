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

    static let defaultColorHex = "#10B981"
}

struct ThemeStatusColorPreset: Identifiable {
    let name: String
    let hex: String
    var id: String { hex }
}

extension PortfolioThemeStatus {
    static let colorPresets: [ThemeStatusColorPreset] = [
        ThemeStatusColorPreset(name: "Red", hex: "#EF4444"),
        ThemeStatusColorPreset(name: "Orange", hex: "#F97316"),
        ThemeStatusColorPreset(name: "Amber", hex: "#F59E0B"),
        ThemeStatusColorPreset(name: "Yellow", hex: "#EAB308"),
        ThemeStatusColorPreset(name: "Lime", hex: "#84CC16"),
        ThemeStatusColorPreset(name: "Green", hex: "#22C55E"),
        ThemeStatusColorPreset(name: "Emerald", hex: "#10B981"),
        ThemeStatusColorPreset(name: "Teal", hex: "#14B8A6"),
        ThemeStatusColorPreset(name: "Cyan", hex: "#06B6D4"),
        ThemeStatusColorPreset(name: "Sky", hex: "#0EA5E9"),
        ThemeStatusColorPreset(name: "Blue", hex: "#3B82F6"),
        ThemeStatusColorPreset(name: "Indigo", hex: "#6366F1"),
        ThemeStatusColorPreset(name: "Violet", hex: "#8B5CF6"),
        ThemeStatusColorPreset(name: "Purple", hex: "#A855F7"),
        ThemeStatusColorPreset(name: "Fuchsia", hex: "#D946EF"),
        ThemeStatusColorPreset(name: "Pink", hex: "#EC4899"),
        ThemeStatusColorPreset(name: "Rose", hex: "#F43F5E"),
        ThemeStatusColorPreset(name: "Slate", hex: "#64748B"),
        ThemeStatusColorPreset(name: "Gray", hex: "#6B7280"),
        ThemeStatusColorPreset(name: "Stone", hex: "#78716C")
    ]

    static func preset(for hex: String) -> ThemeStatusColorPreset? {
        colorPresets.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }
}

