// DragonShield/Models/PortfolioThemeAssetUpdate.swift

// MARK: - Version 1.1

// MARK: - History

// - 1.0: Initial instrument-level update model for Step 7A.
// - 1.0 -> 1.1: Add Markdown body and pin flag for Phase 7B.

import Foundation

struct PortfolioThemeAssetUpdate: Identifiable, Codable {
    let id: Int
    let themeId: Int
    let instrumentId: Int
    var title: String
    var bodyMarkdown: String
    var typeId: Int?
    var typeCode: String
    var typeDisplayName: String?
    let author: String
    var pinned: Bool
    var positionsAsOf: String?
    var valueChf: Double?
    var actualPercent: Double?
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
