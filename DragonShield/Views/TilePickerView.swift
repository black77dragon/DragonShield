import SwiftUI

struct TilePickerView: View {
    @Binding var tileIDs: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(TileRegistry.all, id: \.id) { tile in
                    Toggle(isOn: binding(for: tile.id)) {
                        Label(tile.name, systemImage: tile.icon)
                    }
                }
            }
            .navigationTitle("Configure Dashboard")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 400)
    }

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
