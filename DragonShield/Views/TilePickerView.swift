import SwiftUI

// NOTE: This version removes the incorrect, duplicate 'Tile' and 'TileRegistry' structs.
// It now correctly uses the 'TileInfo' and 'TileRegistry' that already exist in your project.

struct TilePickerView: View {
    @Binding var tileIDs: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var categoryOverrides: [String: DashboardCategory] = DashboardTileCategories.currentOverrides()

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
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Toggle(isOn: binding(for: tile.id)) {
                                    Label(tile.name, systemImage: tile.icon)
                                }
                                Spacer()
                                Menu {
                                    ForEach(DashboardCategory.allCases.filter { $0 != .all }) { category in
                                        Button {
                                            setCategory(category, for: tile.id)
                                        } label: {
                                            Label(category.displayName, systemImage: categoryIcon(for: category))
                                        }
                                    }
                                } label: {
                                    Label("Assign Category", systemImage: "tag")
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .help("Assign this tile to a category")
                            }
                            Text("Category: \(categoryLabel(for: tile.id))")
                                .font(.caption)
                                .foregroundColor(.secondary)
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

    private func categoryLabel(for id: String) -> String {
        let override = categoryOverrides[id]
        let base = DashboardTileCategories.baseCategory(for: id)
        let category = override ?? base
        return override == nil ? category.displayName : "\(category.displayName) (custom)"
    }

    private func categoryIcon(for category: DashboardCategory) -> String {
        switch category {
        case .overview: return "rectangle.grid.2x2"
        case .allocation: return "chart.pie"
        case .risk: return "shield.lefthalf.filled"
        case .warningsAlerts: return "exclamationmark.triangle"
        case .general: return "square.grid.3x3"
        case .all: return "asterisk"
        }
    }

    private func setCategory(_ category: DashboardCategory, for id: String) {
        categoryOverrides[id] = category
        DashboardTileCategories.setOverride(tileID: id, category: category)
    }
}
