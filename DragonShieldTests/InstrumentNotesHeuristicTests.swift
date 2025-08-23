import XCTest
@testable import DragonShield

final class InstrumentNotesHeuristicTests: XCTestCase {
    func testCodeMentionMatch() {
        let update = PortfolioThemeUpdate(id: 1, themeId: 1, title: "ALAB surges", bodyMarkdown: "Great quarter", type: .General, author: "a", pinned: false, positionsAsOf: nil, totalValueChf: nil, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z", softDelete: false, deletedAt: nil, deletedBy: nil)
        XCTAssertTrue(InstrumentNotesView.mentionMatches(update: update, code: "ALAB", name: "Astera Labs Inc"))
    }

    func testNameMentionMatch() {
        let update = PortfolioThemeUpdate(id: 2, themeId: 1, title: "Note", bodyMarkdown: "Discussing Astera Labs Inc future", type: .Research, author: "a", pinned: false, positionsAsOf: nil, totalValueChf: nil, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z", softDelete: false, deletedAt: nil, deletedBy: nil)
        XCTAssertTrue(InstrumentNotesView.mentionMatches(update: update, code: "ALAB", name: "Astera Labs Inc"))
    }

    func testShortCodeIgnored() {
        let update = PortfolioThemeUpdate(id: 3, themeId: 1, title: "AI trends", bodyMarkdown: "AI is everywhere", type: .General, author: "a", pinned: false, positionsAsOf: nil, totalValueChf: nil, createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z", softDelete: false, deletedAt: nil, deletedBy: nil)
        XCTAssertFalse(InstrumentNotesView.mentionMatches(update: update, code: "AI", name: "AI"))
    }
}
