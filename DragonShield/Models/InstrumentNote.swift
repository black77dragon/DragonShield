import Foundation

/// Represents a note captured for an instrument. Notes can exist at the instrument level
/// (no portfolio linkage) or be scoped to a specific portfolio theme.
public struct InstrumentNote: Identifiable, Codable {
    public let id: Int
    public let instrumentId: Int
    public var themeId: Int?
    public var title: String
    public var bodyMarkdown: String
    public var typeId: Int?
    public var typeCode: String
    public var typeDisplayName: String?
    public let author: String
    public var pinned: Bool
    public var positionsAsOf: String?
    public var valueChf: Double?
    public var actualPercent: Double?
    public let createdAt: String
    public var updatedAt: String

    /// True when the note applies to the instrument without any specific theme.
    public var isInstrumentOnly: Bool { themeId == nil }

    public static func isValidTitle(_ title: String) -> Bool {
        let count = title.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= 1 && count <= 120
    }

    public static func isValidBody(_ body: String) -> Bool {
        let count = body.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= 1 && count <= 5000
    }
}
