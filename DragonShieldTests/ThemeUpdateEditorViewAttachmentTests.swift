import XCTest
@testable import DragonShield

final class ThemeUpdateEditorViewAttachmentTests: XCTestCase {
    func testAttachmentsDisabledByDefault() {
        let view = ThemeUpdateEditorView(themeId: 1, themeName: "T", onSave: { _ in }, onCancel: {})
        XCTAssertFalse(view.attachmentsEnabled)
    }

    func testAttachmentsEnabledWhenFlagSet() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "portfolioAttachmentsEnabled")
        let view = ThemeUpdateEditorView(themeId: 1, themeName: "T", onSave: { _ in }, onCancel: {})
        XCTAssertTrue(view.attachmentsEnabled)
        defaults.removeObject(forKey: "portfolioAttachmentsEnabled")
    }
}

