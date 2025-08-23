import XCTest
@testable import DragonShield

final class InstrumentUpdateEditorViewAttachmentTests: XCTestCase {
    func testAttachmentsDisabledByDefault() {
        let view = InstrumentUpdateEditorView(themeId: 1, instrumentId: 1, instrumentName: "I", themeName: "T", onSave: { _ in }, onCancel: {})
        XCTAssertFalse(view.attachmentsEnabled)
    }

    func testAttachmentsEnabledWhenFlagSet() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "portfolioAttachmentsEnabled")
        let view = InstrumentUpdateEditorView(themeId: 1, instrumentId: 1, instrumentName: "I", themeName: "T", onSave: { _ in }, onCancel: {})
        XCTAssertTrue(view.attachmentsEnabled)
        defaults.removeObject(forKey: "portfolioAttachmentsEnabled")
    }
}
