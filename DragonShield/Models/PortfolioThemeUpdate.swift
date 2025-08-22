// DragonShield/Models/PortfolioThemeUpdate.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0 -> 1.1: Add Markdown body and pin flag for Phase 6B updates.

import Foundation

struct PortfolioThemeUpdate: Identifiable, Codable {
    enum UpdateType: String, CaseIterable, Codable {
        case General
        case Research
        case Rebalance
        case Risk
    }

    let id: Int
    let themeId: Int
    var title: String
    var bodyMarkdown: String
    var type: UpdateType
    let author: String
    var pinned: Bool
    var positionsAsOf: String?
    var totalValueChf: Double?
    let createdAt: String
    var updatedAt: String

    static func isValidTitle(_ title: String) -> Bool {
        let count = title.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= 1 && count <= 120
    }

    static func isValidBody(_ body: String) -> Bool {
        let count = body.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= 1 && count <= 5000
    }
}
