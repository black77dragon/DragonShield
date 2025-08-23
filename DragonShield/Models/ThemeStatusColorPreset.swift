// DragonShield/Models/ThemeStatusColorPreset.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: 20-color presets for Theme Status picker.

import Foundation

struct ThemeStatusColorPreset: Identifiable, Hashable {
    let name: String
    let hex: String
    var id: String { hex.lowercased() }

    static let all: [ThemeStatusColorPreset] = [
        .init(name: "Red", hex: "#EF4444"),
        .init(name: "Orange", hex: "#F97316"),
        .init(name: "Amber", hex: "#F59E0B"),
        .init(name: "Yellow", hex: "#EAB308"),
        .init(name: "Lime", hex: "#84CC16"),
        .init(name: "Green", hex: "#22C55E"),
        .init(name: "Emerald", hex: "#10B981"),
        .init(name: "Teal", hex: "#14B8A6"),
        .init(name: "Cyan", hex: "#06B6D4"),
        .init(name: "Sky", hex: "#0EA5E9"),
        .init(name: "Blue", hex: "#3B82F6"),
        .init(name: "Indigo", hex: "#6366F1"),
        .init(name: "Violet", hex: "#8B5CF6"),
        .init(name: "Purple", hex: "#A855F7"),
        .init(name: "Fuchsia", hex: "#D946EF"),
        .init(name: "Pink", hex: "#EC4899"),
        .init(name: "Rose", hex: "#F43F5E"),
        .init(name: "Slate", hex: "#64748B"),
        .init(name: "Gray", hex: "#6B7280"),
        .init(name: "Stone", hex: "#78716C"),
    ]

    static let defaultPreset = all[6]

    static func preset(for hex: String) -> ThemeStatusColorPreset? {
        all.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }
}
