// DragonShield/Models/ThemeStatusColorPresets.swift

// MARK: - Version 1.0

// MARK: - History

// - Initial creation: Defines preset colors for Theme Status picker.

import Foundation

struct ThemeStatusColorPreset: Identifiable, Equatable {
    let name: String
    let hex: String
    var id: String { hex.lowercased() }
}

let themeStatusColorPresets: [ThemeStatusColorPreset] = [
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
    ThemeStatusColorPreset(name: "Stone", hex: "#78716C"),
]

extension ThemeStatusColorPreset {
    static var `default`: ThemeStatusColorPreset {
        themeStatusColorPresets.first { $0.name == "Emerald" }!
    }

    static func matching(hex: String) -> ThemeStatusColorPreset? {
        themeStatusColorPresets.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }
}
