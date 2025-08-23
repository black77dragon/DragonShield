import XCTest
@testable import DragonShield

final class ThemeUpdateEditorViewFlagTests: XCTestCase {
    func testAttachmentsFlagPropagates() {
        let view = ThemeUpdateEditorView(themeId: 1, themeName: "T", attachmentsEnabled: true, onSave: { _ in }, onCancel: {})
        XCTAssertTrue(view.attachmentsEnabled)
    }
}
