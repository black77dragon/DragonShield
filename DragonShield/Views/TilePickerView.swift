import SwiftUI

// NOTE: This version removes the incorrect, duplicate 'Tile' and 'TileRegistry' structs.
// It now correctly uses the 'TileInfo' and 'TileRegistry' that already exist in your project.

struct TilePickerView: View {
    @Binding var tileIDs: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Use a VStack for a simple, clean layout.
        VStack(spacing: 0) {
            // 1. A clear title for the window.
            Text("Configure Dashboard")
                .font(.title2)
                .fontWeight(.medium)
                .padding()

            Divider()

            // 2. A Form to present the list of toggles cleanly.
            Form {
                // The ForEach now correctly iterates over your existing 'TileRegistry.all'
                // and uses the 'id' property of 'TileInfo' for identification.
                // This resolves both compiler errors.
                List {
                    ForEach(TileRegistry.all, id: \.id) { tile in
                        Toggle(isOn: binding(for: tile.id)) {
                            Label(tile.name, systemImage: tile.icon)
                        }
                    }
                }
            }
            .padding([.leading, .trailing], 5)

            Divider()

            // 3. A single, clear "Done" button to close the window.
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction) // Allows pressing Enter to confirm.
            }
            .padding()
        }
        // 4. Set a proper frame size to fix the original layout issue.
        .frame(minWidth: 350, idealWidth: 400, minHeight: 400, idealHeight: 500)
    }

    /// Helper function to create a binding for each toggle from the tileIDs array.
    private func binding(for id: String) -> Binding<Bool> {
        Binding {
            tileIDs.contains(id)
        } set: { newValue in
            if newValue {
                if !tileIDs.contains(id) { tileIDs.append(id) }
            } else {
                tileIDs.removeAll { $0 == id }
            }
        }
    }
}
