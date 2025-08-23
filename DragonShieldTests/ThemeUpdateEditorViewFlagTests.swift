import XCTest
@testable import DragonShield

final class ThemeUpdateEditorViewFlagTests: XCTestCase {
    func testAttachmentsFlagControlsVisibility() {
        let viewOn = ThemeUpdateEditorView(themeId: 1, themeName: "T", attachmentsFlag: true, onSave: { _ in }, onCancel: {})
        XCTAssertTrue(viewOn.attachmentsFlag)
        let viewOff = ThemeUpdateEditorView(themeId: 1, themeName: "T", attachmentsFlag: false, onSave: { _ in }, onCancel: {})
        XCTAssertFalse(viewOff.attachmentsFlag)
    }
}
