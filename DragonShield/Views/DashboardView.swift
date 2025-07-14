import SwiftUI

private let layoutKey = "dashboardTileLayout"

struct DashboardView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    @State private var tileIDs: [String] = []
    @State private var showingPicker = false
    @State private var draggedID: String?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(tileIDs, id: \.self) { id in
                    if let tile = TileRegistry.view(for: id) {
                        tile
                            .onDrag {
                                draggedID = id
                                return NSItemProvider(object: id as NSString)
                            }
                            .onDrop(of: [.text], delegate: TileDropDelegate(item: id, tiles: $tileIDs, dragged: $draggedID))
                            .accessibilityLabel(TileRegistry.info(for: id).name)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Configure") { showingPicker = true }
            }
        }
        .sheet(isPresented: $showingPicker) {
            TilePickerView(tileIDs: $tileIDs)
                .onDisappear { saveLayout() }
        }
        .onAppear(perform: loadLayout)
        .onChange(of: tileIDs) { _ in saveLayout() }
    }

    private func loadLayout() {
        if let saved = UserDefaults.standard.array(forKey: layoutKey) as? [String], !saved.isEmpty {
            tileIDs = saved.filter { id in TileRegistry.all.contains { $0.tileID == id } }
        } else {
            tileIDs = TileRegistry.all.map { $0.tileID }
        }
    }

    private func saveLayout() {
        UserDefaults.standard.set(tileIDs, forKey: layoutKey)
    }
}

struct TileDropDelegate: DropDelegate {
    let item: String
    @Binding var tiles: [String]
    @Binding var dragged: String?

    func dropEntered(info: DropInfo) {
        guard let dragged = dragged, dragged != item,
              let from = tiles.firstIndex(of: dragged),
              let to = tiles.firstIndex(of: item) else { return }
        if tiles[to] != dragged {
            tiles.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        return true
    }
}
