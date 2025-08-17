import SwiftUI

// Local model definitions to ensure this view is self-contained and doesn't affect other files.
fileprivate struct Tile: Identifiable {
    let id: String
    let name: String
    let icon: String
}

fileprivate struct TileRegistry {
    static let all: [Tile] = [
        Tile(id: "total_value", name: "Total Asset Value", icon: "dollarsign.circle"),
        Tile(id: "top_positions", name: "Top Positions", icon: "list.number"),
        Tile(id: "riskBuckets", name: "Risk Buckets", icon: "shield.lefthalf.filled"),
        Tile(id: "currencyExposure", name: "Currency Exposure", icon: "chart.pie"),
        Tile(id: "staleAccounts", name: "Accounts Needing Update", icon: "hourglass.bottomhalf.fill"),
        Tile(id: "cryptoTop5", name: "Top 5 Crypto", icon: "bitcoinsign.circle"),
        Tile(id: "institutionsAUM", name: "Institutions AUM", icon: "building.columns"),
        Tile(id: "allocationHeatMap", name: "Allocation Heat Map", icon: "square.stack.3d.up")
    ]
}

// The updated view
struct TilePickerView: View {
    @Binding var tileIDs: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Use a VStack for a simple, clean layout instead of NavigationView
        VStack(spacing: 0) {
            // 1. A clear title for the window
            Text("Configure Dashboard")
                .font(.title2)
                .fontWeight(.medium)
                .padding()

            Divider()

            // 2. A Form to present the list of toggles cleanly
            Form {
                List {
                    ForEach(TileRegistry.all) { tile in
                        Toggle(isOn: binding(for: tile.id)) {
                            Label(tile.name, systemImage: tile.icon)
                        }
                    }
                }
            }
            .padding([.leading, .trailing], 5)


            Divider()

            // 3. A single, clear "Done" button to close the window
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction) // Allows pressing Enter to confirm
            }
            .padding()
        }
        // 4. Set a proper frame size to fix the original issue
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
