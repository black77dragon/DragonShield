// DragonShield/Models/PortfolioThemeAssetUpdate.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.1: Add Markdown body and pin flag for Step 7B.
// - 1.0: Initial instrument-level update model for Step 7A.

import Foundation

struct PortfolioThemeAssetUpdate: Identifiable, Codable {
    enum UpdateType: String, CaseIterable, Codable {
        case General
        case Research
        case Rebalance
        case Risk
    }

    let id: Int
    let themeId: Int
    let instrumentId: Int
    var title: String
    var bodyMarkdown: String
    var type: UpdateType
    let author: String
    var positionsAsOf: String?
    var valueChf: Double?
    var actualPercent: Double?
    var pinned: Bool
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
