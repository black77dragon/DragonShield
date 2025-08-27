// DragonShield/Models/PortfolioThemeUpdate.swift
// MARK: - Version 1.3
// MARK: - History
// - 1.0 -> 1.1: Add Markdown body and pin flag for Phase 6B updates.
// - 1.1 -> 1.2: Track soft deletion metadata for Phase 6C.
// - 1.2 -> 1.3: Replace enum type with UpdateType reference.

import Foundation

struct PortfolioThemeUpdate: Identifiable, Codable {
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
    var softDelete: Bool
    var deletedAt: String?
    var deletedBy: String?

    static func isValidTitle(_ title: String) -> Bool {
        let count = title.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= 1 && count <= 120
    }

    static func isValidBody(_ body: String) -> Bool {
        let count = body.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= 1 && count <= 5000
    }
}
