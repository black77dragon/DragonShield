import XCTest
import SwiftUI
@testable import DragonShield

final class NoteEditorViewTests: XCTestCase {
    func testViewInitializes() {
        let view = NoteEditorView(
            title: "Edit Note — Test",
            note: .constant("sample"),
            isReadOnly: false,
            onSave: {},
            onCancel: {}
        )
        XCTAssertNotNil(view.body)
    }
}
