import SwiftUI

struct NoteEditorView: View {
    let title: String
    @Binding var note: String
    let isReadOnly: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    static let maxLength = 2000

    var isOverLimit: Bool { note.count > Self.maxLength }
    var saveDisabled: Bool { isReadOnly || isOverLimit }
    var countColor: Color { isOverLimit ? .red : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            TextEditor(text: $note)
                .frame(minHeight: 140)
                .disabled(isReadOnly)
            Text("\(note.count) / \(Self.maxLength) characters")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(countColor)
            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(saveDisabled)
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 220)
    }
}
