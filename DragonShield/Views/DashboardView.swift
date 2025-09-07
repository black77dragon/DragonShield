import SwiftUI

private let layoutKey = "dashboardTileLayout"

struct DashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    private enum Layout {
        static let spacing: CGFloat = 24
        static let minWidth: CGFloat = 260
        static let maxWidth: CGFloat = 400
    }


    @State private var tileIDs: [String] = []
    @State private var showingPicker = false
    @State private var draggedID: String?
    @State private var columnCount = 3

    @State private var showUpcomingWeekPopup = false
    @State private var startupChecked = false
    @State private var upcomingWeek: [(id: Int, name: String, date: String)] = []

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                MasonryLayout(columns: columnCount, spacing: Layout.spacing) {
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
                .frame(maxWidth: gridWidth(for: columnCount), alignment: .topLeading)
                .padding(Layout.spacing)
                .animation(.easeInOut(duration: 0.2), value: columnCount)
            }
            .onAppear { updateColumns(width: geo.size.width) }
            .onChange(of: geo.size.width) { _, newValue in updateColumns(width: newValue) }
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
        .onChange(of: tileIDs) { _, _ in
            saveLayout()
        }
        .sheet(isPresented: $showUpcomingWeekPopup) {
            StartupAlertsPopupView(items: upcomingWeek)
        }
        .onAppear {
            // Run once on initial dashboard appearance
            if !startupChecked {
                startupChecked = true
                loadUpcomingWeekAlerts()
            }
        }
    }

    private func loadLayout() {
        if let saved = UserDefaults.standard.array(forKey: layoutKey) as? [String], !saved.isEmpty {
            tileIDs = saved.filter { id in TileRegistry.all.contains { $0.id == id } }
            if !tileIDs.contains(CryptoTop5Tile.tileID) {
                tileIDs.insert(CryptoTop5Tile.tileID, at: 0)
            }
            if !tileIDs.contains(InstitutionsAUMTile.tileID) {
                tileIDs.append(InstitutionsAUMTile.tileID)
            }
        } else {
            tileIDs = TileRegistry.all.map { $0.id }
        }
    }

    private func saveLayout() {
        UserDefaults.standard.set(tileIDs, forKey: layoutKey)
    }

    private func updateColumns(width: CGFloat) {
        let available = width - Layout.spacing * 2
        let fitByMax = Int(available / (Layout.maxWidth + Layout.spacing))
        switch fitByMax {
        case 4...:
            columnCount = 4
        case 3:
            columnCount = 3
        case 2:
            columnCount = 2
        default:
            columnCount = 1
        }
    }

    private func gridWidth(for columns: Int) -> CGFloat {
        Layout.maxWidth * CGFloat(columns) + Layout.spacing * CGFloat(columns - 1)
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

// MARK: - Startup Alerts Popup
private struct StartupAlertsPopupView: View {
    let items: [(id: Int, name: String, date: String)]
    private static let inDf: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let outDf: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_CH"); f.dateFormat = "dd.MM.yy"; return f
    }()
    private func format(_ s: String) -> String { if let d = Self.inDf.date(from: s) { return Self.outDf.string(from: d) }; return s }

    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "shield.fill").font(.system(size: 34)).foregroundColor(.blue)
                Text("Incoming Deadlines Detected")
                    .font(.title2).bold()
                Spacer()
            }
            .padding(.top, 8)
            Text("A long time ago in a galaxy not so far away… upcoming alerts began to stir. Use the Force to stay on target!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.0) { _, it in
                    HStack {
                        Text(it.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Text(format(it.date))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Divider()
            HStack {
                Spacer()
                Button("Dismiss") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

private extension DashboardView {
    func loadUpcomingWeekAlerts() {
        // Fetch upcoming and filter to next 7 days
        var rows = dbManager.listUpcomingDateAlerts(limit: 200)
        rows.sort { $0.upcomingDate < $1.upcomingDate }
        let inDf = DateFormatter(); inDf.locale = Locale(identifier: "en_US_POSIX"); inDf.timeZone = TimeZone(secondsFromGMT: 0); inDf.dateFormat = "yyyy-MM-dd"
        guard let today = inDf.date(from: inDf.string(from: Date())),
              let week = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return }
        let nextWeek = rows.filter { inDf.date(from: $0.upcomingDate).map { $0 <= week } ?? false }
        if !nextWeek.isEmpty {
            upcomingWeek = nextWeek.map { (id: $0.alertId, name: $0.alertName, date: $0.upcomingDate) }
            showUpcomingWeekPopup = true
        }
    }
}
