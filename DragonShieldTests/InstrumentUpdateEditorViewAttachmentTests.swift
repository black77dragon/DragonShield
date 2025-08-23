import XCTest
@testable import DragonShield

final class InstrumentUpdateEditorViewAttachmentTests: XCTestCase {
    func testAttachmentsEnabledByDefault() {
        let view = InstrumentUpdateEditorView(themeId: 1, instrumentId: 1, instrumentName: "I", themeName: "T", onSave: { _ in }, onCancel: {})
        XCTAssertTrue(view.attachmentsEnabled)
    }

    func testAttachmentsDisabledWhenFlagFalse() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        let view = InstrumentUpdateEditorView(themeId: 1, instrumentId: 1, instrumentName: "I", themeName: "T", onSave: { _ in }, onCancel: {})
        XCTAssertFalse(view.attachmentsEnabled)
        defaults.removeObject(forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
    }
}
