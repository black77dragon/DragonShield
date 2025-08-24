import XCTest
@testable import DragonShield

final class ThemeUpdateReaderViewFlagTests: XCTestCase {
    private let sample = PortfolioThemeUpdate(
        id: 1,
        themeId: 1,
        title: "",
        bodyMarkdown: "Note",
        type: .General,
        author: "A",
        pinned: false,
        positionsAsOf: nil,
        totalValueChf: nil,
        createdAt: "",
        updatedAt: "",
        softDelete: false,
        deletedAt: nil,
        deletedBy: nil
    )

    func testLinksDisabledByDefault() {
        let view = ThemeUpdateReaderView(update: sample, links: [], attachments: [], onEdit: { _ in }, onPin: { _ in }, onDelete: { _ in })
        XCTAssertFalse(view.linksEnabled)
    }

    func testLinksEnabledWhenFlagSet() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: UserDefaultsKeys.portfolioLinksEnabled)
        let view = ThemeUpdateReaderView(update: sample, links: [], attachments: [], onEdit: { _ in }, onPin: { _ in }, onDelete: { _ in })
        XCTAssertTrue(view.linksEnabled)
        defaults.removeObject(forKey: UserDefaultsKeys.portfolioLinksEnabled)
    }

    func testAttachmentsDisabledByDefault() {
        let view = ThemeUpdateReaderView(update: sample, links: [], attachments: [], onEdit: { _ in }, onPin: { _ in }, onDelete: { _ in })
        XCTAssertFalse(view.attachmentsEnabled)
    }

    func testAttachmentsEnabledWhenFlagSet() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        let view = ThemeUpdateReaderView(update: sample, links: [], attachments: [], onEdit: { _ in }, onPin: { _ in }, onDelete: { _ in })
        XCTAssertTrue(view.attachmentsEnabled)
        defaults.removeObject(forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
    }
}

