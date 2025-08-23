import XCTest
@testable import DragonShield

final class ThemeUpdateEditorViewAttachmentTests: XCTestCase {
    func testAttachmentsEnabledByDefault() {
        let view = ThemeUpdateEditorView(themeId: 1, themeName: "T", onSave: { _ in }, onCancel: {})
        XCTAssertTrue(view.attachmentsEnabled)
    }

    func testAttachmentsDisabledWhenFlagFalse() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        let view = ThemeUpdateEditorView(themeId: 1, themeName: "T", onSave: { _ in }, onCancel: {})
        XCTAssertFalse(view.attachmentsEnabled)
        defaults.removeObject(forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
    }
}
