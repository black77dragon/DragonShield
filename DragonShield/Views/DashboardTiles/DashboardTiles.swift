import SwiftUI

protocol DashboardTile: View {
    init()
    static var tileID: String { get }
    static var tileName: String { get }
    static var iconName: String { get }
}

struct DashboardCard<Content: View>: View {
    let title: String
    let headerIcon: Image?
    let content: Content

    init(title: String, headerIcon: Image? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.headerIcon = headerIcon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let icon = headerIcon {
                    icon
                        .resizable()
                        .frame(width: 24, height: 24)
                }
            }
            content
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

struct ChartTile: DashboardTile {
    init() {}
    static let tileID = "chart"
    static let tileName = "Chart Tile"
    static let iconName = "chart.bar"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Color.gray.opacity(0.3)
                .frame(height: 120)
                .cornerRadius(4)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ListTile: DashboardTile {
    init() {}
    static let tileID = "list"
    static let tileName = "List Tile"
    static let iconName = "list.bullet"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            VStack(alignment: .leading, spacing: DashboardTileLayout.rowSpacing) {
                Text("First item")
                Text("Second item")
                Text("Third item")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricTile: DashboardTile {
    init() {}
    static let tileID = "metric"
    static let tileName = "Metric Tile"
    static let iconName = "number"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Text("123")
                .font(.system(size: 48, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(Theme.primaryAccent)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TotalValueTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var total: Double = 0
    @State private var loading = false

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        return f
    }()

    init() {}
    static let tileID = "total_value"
    static let tileName = "Total Asset Value (CHF)"
    static let iconName = "francsign.circle"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text(Self.formatter.string(from: NSNumber(value: total)) ?? "0")
                    .font(.system(size: 48, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(Theme.primaryAccent)
            }
        }
        .onAppear(perform: calculate)
        .accessibilityElement(children: .combine)
    }

    private func calculate() {
        loading = true
        DispatchQueue.global().async {
            let positions = dbManager.fetchPositionReports()
            var sum: Double = 0
            for p in positions {
                guard let iid = p.instrumentId, let lp = dbManager.getLatestPrice(instrumentId: iid) else { continue }
                var value = p.quantity * lp.price
                if p.instrumentCurrency.uppercased() != "CHF" {
                    let rates = dbManager.fetchExchangeRates(currencyCode: p.instrumentCurrency, upTo: nil)
                    guard let rate = rates.first?.rateToChf else { continue }
                    value *= rate
                }
                sum += value
            }
            DispatchQueue.main.async {
                total = sum
                loading = false
            }
        }
    }
}

struct TopPositionsTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = PositionsViewModel()
    @Environment(\.colorScheme) private var colorScheme

    init() {}
    static let tileID = "top_positions"
    static let tileName = "Top Positions"
    static let iconName = "list.number"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.tileName)
                .font(.system(size: 18, weight: .bold))
            if viewModel.calculating {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DashboardTileLayout.rowSpacing) {
                        ForEach(Array(viewModel.topPositions.enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .top) {
                                Text(item.instrument)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.2f", item.valueCHF))
                                        .font(.system(.body, design: .monospaced).bold())
                                    Text(item.currency)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(height: DashboardTileLayout.rowHeight)
                            if index != viewModel.topPositions.count - 1 {
                                Divider().foregroundColor(Color(red: 226/255, green: 232/255, blue: 240/255))
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .background(
            Group {
                if colorScheme == .dark {
                    Color(red: 30/255, green: 30/255, blue: 30/255)
                } else {
                    Color.white
                }
            }
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear { viewModel.calculateTopPositions(db: dbManager) }
        .accessibilityElement(children: .combine)
    }
}

struct TextTile: DashboardTile {
    init() {}
    static let tileID = "text"
    static let tileName = "Text Tile"
    static let iconName = "text.alignleft"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla ut nulla sit amet massa volutpat accumsan.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Themes Overview Tile

struct ThemesOverviewTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [Row] = []
    @State private var loading = false
    @State private var openThemeId: Int? = nil

    init() {}
    static let tileID = "themes_overview"
    static let tileName = "Portfolio Themes"
    static let iconName = "square.grid.2x2"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if rows.isEmpty {
                Text("No themes found").foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: DashboardTileLayout.rowSpacing) {
                        header
                        ForEach(rows) { r in
                            HStack {
                                Button(r.name) { openThemeId = r.id }
                                    .buttonStyle(.link)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(r.instrumentCount)")
                                    .frame(width: 80, alignment: .trailing)
                                Text(currency(r.totalValue))
                                    .frame(width: 140, alignment: .trailing)
                            }
                            .font(.system(size: 13))
                            .frame(height: DashboardTileLayout.rowHeight)
                        }
                    }
                    .padding(.vertical, DashboardTileLayout.rowSpacing)
                }
                .frame(maxHeight: 320)
            }
        }
        .onAppear(perform: load)
        .sheet(item: Binding(get: {
            openThemeId.map { Ident(value: $0) }
        }, set: { newVal in openThemeId = newVal?.value })) { ident in
            PortfolioThemeWorkspaceView(themeId: ident.value, origin: "Dashboard")
                .environmentObject(dbManager)
        }
    }

    private var header: some View {
        HStack {
            Text("Theme").frame(maxWidth: .infinity, alignment: .leading)
            Text("Instruments").frame(width: 80, alignment: .trailing)
            Text("Total Value").frame(width: 140, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func load() {
        loading = true
        DispatchQueue.global().async {
            let themes = dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false)
            var result: [Row] = []
            let fx = FXConversionService(dbManager: dbManager)
            let service = PortfolioValuationService(dbManager: dbManager, fxService: fx)
            for t in themes {
                let snap = service.snapshot(themeId: t.id)
                let total = snap.totalValueBase
                result.append(Row(id: t.id, name: t.name, instrumentCount: t.instrumentCount, totalValue: total))
            }
            result.sort { $0.totalValue > $1.totalValue }
            DispatchQueue.main.async { rows = result; loading = false }
        }
    }

    private struct Ident: Identifiable { let value: Int; var id: Int { value } }

    private func currency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = dbManager.baseCurrency
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }

    private struct Row: Identifiable {
        let id: Int
        let name: String
        let instrumentCount: Int
        let totalValue: Double
    }
}

struct ImageTile: DashboardTile {
    init() {}
    static let tileID = "image"
    static let tileName = "Image Tile"
    static let iconName = "photo"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Color.gray.opacity(0.3)
                .frame(height: 100)
                .overlay(Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray))
                .cornerRadius(4)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - All Notes Tile

struct AllNotesTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var totalCount: Int = 0
    @State private var recent: [Row] = []
    @State private var loading = false
    @State private var openAll = false
    @State private var search: String = ""
    @State private var pinnedFirst: Bool = true
    @State private var editingTheme: PortfolioThemeUpdate?
    @State private var editingInstrument: PortfolioThemeAssetUpdate?
    @State private var themeNames: [Int: String] = [:]
    @State private var instrumentNames: [Int: String] = [:]

    init() {}
    static let tileID = "all_notes"
    static let tileName = "All Notes"
    static let iconName = "note.text"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Open All") { openAll = true }
                Text(loading ? "—" : String(totalCount))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.primaryAccent)
            }
            HStack(spacing: 8) {
                TextField("Search notes", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { load() }
                if !search.isEmpty {
                    Button("Clear") { search = ""; load() }.buttonStyle(.link)
                }
                Toggle("Pinned first", isOn: $pinnedFirst)
                    .toggleStyle(.checkbox)
                    .onChange(of: pinnedFirst) { _, _ in load() }
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                if recent.isEmpty {
                    Text("No recent notes")
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: DashboardTileLayout.rowSpacing) {
                        ForEach(recent) { r in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    Text(r.title)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .help(r.title)
                                    Spacer()
                                    Text(r.when)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Text(r.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .help(r.subtitle)
                                    Spacer()
                                    Text(r.type)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { openEditor(r) }
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear(perform: load)
        .sheet(isPresented: $openAll) {
            AllNotesView().environmentObject(dbManager)
        }
        .sheet(item: $editingTheme) { upd in
            ThemeUpdateEditorView(themeId: upd.themeId, themeName: themeNames[upd.themeId] ?? "", existing: upd, onSave: { _ in editingTheme = nil; load() }, onCancel: { editingTheme = nil })
                .environmentObject(dbManager)
        }
        .sheet(item: $editingInstrument) { upd in
            InstrumentUpdateEditorView(themeId: upd.themeId, instrumentId: upd.instrumentId, instrumentName: instrumentNames[upd.instrumentId] ?? "#\(upd.instrumentId)", themeName: themeNames[upd.themeId] ?? "", existing: upd, onSave: { _ in editingInstrument = nil; load() }, onCancel: { editingInstrument = nil })
                .environmentObject(dbManager)
        }
    }

    private func load() {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let q = search.isEmpty ? nil : search
            let theme = dbManager.listAllThemeUpdates(view: .active, typeId: nil, searchQuery: q, pinnedFirst: pinnedFirst)
            let instr = dbManager.listAllInstrumentUpdates(pinnedFirst: pinnedFirst, searchQuery: q, typeId: nil)
            let themes = dbManager.fetchPortfolioThemes(includeArchived: true)
            let themeNameMap = Dictionary(uniqueKeysWithValues: themes.map { ($0.id, $0.name) })
            let instrumentNameMap = Dictionary(uniqueKeysWithValues: dbManager.fetchAssets().map { ($0.id, $0.name) })
            let combined: [Row] = Array(theme.prefix(3)).map { t in
                Row(id: "t-\(t.id)", title: t.title, subtitle: "Theme: \(themeNameMap[t.themeId] ?? "#\(t.themeId)")", type: t.typeDisplayName ?? t.typeCode, when: DateFormatting.userFriendly(t.createdAt))
            } + Array(instr.prefix(3)).map { u in
                Row(id: "i-\(u.id)", title: u.title, subtitle: "Instr: \(instrumentNameMap[u.instrumentId] ?? "#\(u.instrumentId)") · Theme: \(themeNameMap[u.themeId] ?? "#\(u.themeId)")", type: u.typeDisplayName ?? u.typeCode, when: DateFormatting.userFriendly(u.createdAt))
            }
            DispatchQueue.main.async {
                self.totalCount = theme.count + instr.count
                self.recent = combined
                self.loading = false
            }
        }
    }

    
    private func openEditor(_ row: Row) {
        if row.id.hasPrefix("t-") {
            if let id = Int(row.id.dropFirst(2)), let upd = dbManager.getThemeUpdate(id: id) {
                editingTheme = upd
            }
        } else if row.id.hasPrefix("i-") {
            if let id = Int(row.id.dropFirst(2)), let upd = dbManager.getInstrumentUpdate(id: id) {
                editingInstrument = upd
            }
        }
    }

private struct Row: Identifiable { let id: String; let title: String; let subtitle: String; let type: String; let when: String }
}

struct MapTile: DashboardTile {
    init() {}
    static let tileID = "map"
    static let tileName = "Map Tile"
    static let iconName = "map"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Color.gray.opacity(0.3)
                .frame(height: 120)
                .overlay(Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundColor(.gray))
                .cornerRadius(4)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MissingPricesTile: DashboardTile {
    init() {}
    static let tileID = "missing_prices"
    static let tileName = "Missing Prices"
    static let iconName = "exclamationmark.triangle"

    @EnvironmentObject var dbManager: DatabaseManager
    struct MissingPriceItem: Identifiable { let id: Int; let name: String; let currency: String }
    @State private var items: [MissingPriceItem] = []
    @State private var loading = false
    @State private var editingInstrumentId: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Self.tileName)
                    .font(.system(size: 17, weight: .semibold))
                Text("Warning")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.paleRed)
                    .foregroundColor(.numberRed)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.numberRed.opacity(0.6), lineWidth: 1))
                    .cornerRadius(10)
                Spacer()
                Text(items.isEmpty ? "—" : String(items.count))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.primaryAccent)
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if items.isEmpty {
                Text("All instruments have a latest price.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: DashboardTileLayout.rowSpacing) {
                        ForEach(items) { item in
                            HStack {
                                Text(item.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(item.currency)
                                    .foregroundColor(.secondary)
                                Button("Edit Price") { editingInstrumentId = item.id }
                                    .buttonStyle(.link)
                            }
                            .font(.system(size: 13))
                            .frame(height: DashboardTileLayout.rowHeight)
                        }
                    }
                    .padding(.vertical, DashboardTileLayout.rowSpacing)
                }
                .frame(maxHeight: items.count > 6 ? 200 : .infinity)
            }
        }
        .padding(DashboardTileLayout.tilePadding)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .overlay(alignment: .leading) { Rectangle().fill(Color.numberRed).frame(width: 4).cornerRadius(2) }
        .onAppear(perform: load)
        .sheet(item: Binding(get: {
            editingInstrumentId.map { Ident(value: $0) }
        }, set: { newVal in
            editingInstrumentId = newVal?.value
        })) { ident in
            InstrumentEditView(instrumentId: ident.value)
                .environmentObject(dbManager)
        }
    }

    private func load() {
        loading = true
        DispatchQueue.global().async {
            var res: [MissingPriceItem] = []
            let assets = dbManager.fetchAssets()
            for a in assets {
                if dbManager.getLatestPrice(instrumentId: a.id) == nil {
                    res.append(MissingPriceItem(id: a.id, name: a.name, currency: a.currency))
                }
            }
            DispatchQueue.main.async {
                self.items = res
                self.loading = false
            }
        }
    }

    private struct Ident: Identifiable { let value: Int; var id: Int { value } }
}

struct TileInfo {
    let id: String
    let name: String
    let icon: String
    let viewBuilder: () -> AnyView
}

enum TileRegistry {
    static let all: [TileInfo] = [
        TileInfo(id: ChartTile.tileID, name: ChartTile.tileName, icon: ChartTile.iconName) { AnyView(ChartTile()) },
        TileInfo(id: ListTile.tileID, name: ListTile.tileName, icon: ListTile.iconName) { AnyView(ListTile()) },
        TileInfo(id: MetricTile.tileID, name: MetricTile.tileName, icon: MetricTile.iconName) { AnyView(MetricTile()) },
        TileInfo(id: TotalValueTile.tileID, name: TotalValueTile.tileName, icon: TotalValueTile.iconName) { AnyView(TotalValueTile()) },
        TileInfo(id: TopPositionsTile.tileID, name: TopPositionsTile.tileName, icon: TopPositionsTile.iconName) { AnyView(TopPositionsTile()) },
        TileInfo(id: CryptoTop5Tile.tileID, name: CryptoTop5Tile.tileName, icon: CryptoTop5Tile.iconName) { AnyView(CryptoTop5Tile()) },
        TileInfo(id: InstitutionsAUMTile.tileID, name: InstitutionsAUMTile.tileName, icon: InstitutionsAUMTile.iconName) { AnyView(InstitutionsAUMTile()) },
        TileInfo(id: UnusedInstrumentsTile.tileID, name: UnusedInstrumentsTile.tileName, icon: UnusedInstrumentsTile.iconName) { AnyView(UnusedInstrumentsTile()) },
        TileInfo(id: ThemesOverviewTile.tileID, name: ThemesOverviewTile.tileName, icon: ThemesOverviewTile.iconName) { AnyView(ThemesOverviewTile()) },

        TileInfo(id: CurrencyExposureTile.tileID, name: CurrencyExposureTile.tileName, icon: CurrencyExposureTile.iconName) { AnyView(CurrencyExposureTile()) },
        TileInfo(id: RiskBucketsTile.tileID, name: RiskBucketsTile.tileName, icon: RiskBucketsTile.iconName) { AnyView(RiskBucketsTile()) },
        TileInfo(id: TextTile.tileID, name: TextTile.tileName, icon: TextTile.iconName) { AnyView(TextTile()) },
        TileInfo(id: ImageTile.tileID, name: ImageTile.tileName, icon: ImageTile.iconName) { AnyView(ImageTile()) },
        TileInfo(id: MapTile.tileID, name: MapTile.tileName, icon: MapTile.iconName) { AnyView(MapTile()) },
        TileInfo(id: AccountsNeedingUpdateTile.tileID, name: AccountsNeedingUpdateTile.tileName, icon: AccountsNeedingUpdateTile.iconName) { AnyView(AccountsNeedingUpdateTile()) },
        TileInfo(id: MissingPricesTile.tileID, name: MissingPricesTile.tileName, icon: MissingPricesTile.iconName) { AnyView(MissingPricesTile()) },
        TileInfo(id: AllNotesTile.tileID, name: AllNotesTile.tileName, icon: AllNotesTile.iconName) { AnyView(AllNotesTile()) }
    ]

    static func view(for id: String) -> AnyView? {
        all.first(where: { $0.id == id })?.viewBuilder()
    }

    static func info(for id: String) -> (name: String, icon: String) {
        if let tile = all.first(where: { $0.id == id }) {
            return (tile.name, tile.icon)
        }
        return ("", "")
    }
}
