import Foundation

/// Represents a note captured for an instrument. Notes can exist at the instrument level
/// (no portfolio linkage) or be scoped to a specific portfolio theme.
struct InstrumentNote: Identifiable, Codable {
    let id: Int
    let instrumentId: Int
    var themeId: Int?
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

    /// True when the note applies to the instrument without any specific theme.
    var isInstrumentOnly: Bool { themeId == nil }

    static func isValidTitle(_ title: String) -> Bool {
        let count = title.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= 1 && count <= 120
    }

    static func isValidBody(_ body: String) -> Bool {
        let count = body.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= 1 && count <= 5000
    }
}
