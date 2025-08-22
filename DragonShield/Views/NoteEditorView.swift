import SwiftUI

struct NoteEditorView: View {
    let title: String
    @Binding var note: String
    let isReadOnly: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    private let maxLength = 2000

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            TextEditor(text: $note)
                .frame(minHeight: 140)
                .disabled(isReadOnly)
            Text("\(note.count) / \(maxLength) characters")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundColor(note.count > maxLength ? .red : .secondary)
            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(isReadOnly || note.count > maxLength)
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 220)
    }
}
