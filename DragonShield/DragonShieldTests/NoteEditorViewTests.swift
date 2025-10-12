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
    func testSaveDisabledWhenOverLimit() {
        let longNote = String(repeating: "a", count: NoteEditorView.maxLength + 1)
        let view = NoteEditorView(
            title: "Edit Note — Test",
            note: .constant(longNote),
            isReadOnly: false,
            onSave: {},
            onCancel: {}
        )
        XCTAssertTrue(view.saveDisabled)
        XCTAssertTrue(view.isOverLimit)
    }

    func testSaveDisabledWhenReadOnly() {
        let view = NoteEditorView(
            title: "Edit Note — Test",
            note: .constant("sample"),
            isReadOnly: true,
            onSave: {},
            onCancel: {}
        )
        XCTAssertTrue(view.saveDisabled)
    }

    func testCountColorTurnsRedWhenOverLimit() {
        let longNote = String(repeating: "a", count: NoteEditorView.maxLength + 1)
        let view = NoteEditorView(
            title: "Edit Note — Test",
            note: .constant(longNote),
            isReadOnly: false,
            onSave: {},
            onCancel: {}
        )
        XCTAssertEqual(view.countColor, .red)
    }
}
