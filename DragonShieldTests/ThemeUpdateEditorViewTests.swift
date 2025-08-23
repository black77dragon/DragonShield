import XCTest
@testable import DragonShield

final class ThemeUpdateEditorViewTests: XCTestCase {
    func testAttachmentsVisibleWithFlag() {
        let defaults = UserDefaults()
        defaults.set(true, forKey: "portfolioAttachmentsEnabled")
        let view = ThemeUpdateEditorView(themeId: 1, themeName: "Test", onSave: { _ in }, onCancel: {})
        XCTAssertTrue(view.attachmentsEnabled(defaults: defaults))
    }
}
