import SwiftUI

protocol DashboardTile: View {
    init()
    static var tileID: String { get }
    static var tileName: String { get }
    static var iconName: String { get }
}

struct DashboardCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
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
            VStack(alignment: .leading, spacing: 4) {
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
                guard let price = p.currentPrice else { continue }
                var value = p.quantity * price
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

    init() {}
    static let tileID = "top_positions"
    static let tileName = "Top 10 Positions by Asset Value (CHF)"
    static let iconName = "list.number"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.tileName)
                .font(.headline)
            if viewModel.calculating {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(viewModel.top10PositionsCHF.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.instrument)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    Text(String(format: "%.2f CHF", item.valueCHF))
                                        .font(.caption)
                                        .foregroundColor(Color(red: 30/255, green: 58/255, blue: 138/255))
                                }
                                Spacer()
                                Text(item.currency)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(4)
                            .background(index == 0 ? Color(red: 191/255, green: 219/255, blue: 254/255) : Color.clear)
                            .cornerRadius(6)
                        }
                    }
                }
                .frame(maxHeight: viewModel.top10PositionsCHF.count > 6 ? 220 : .infinity)
            }
        }
        .padding(16)
        .background(Color(red: 216/255, green: 236/255, blue: 248/255))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear { viewModel.calculateTop10Positions(db: dbManager) }
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

struct MapTile: DashboardTile {
    init() {}
    static let tileID = "map"
    static let tileName = "Position Value by Currency"
    static let iconName = "map"

    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = CurrencyMapViewModel()

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if viewModel.loading {
                ProgressView()
                    .frame(height: 140)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    CurrencyChoroplethMapView(viewModel: viewModel)
                        .frame(height: 140)
                    MapLegend(viewModel: viewModel)
                }
            }
        }
        .onAppear { viewModel.load(using: dbManager) }
        .accessibilityElement(children: .combine)
    }
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

        TileInfo(id: CurrencyExposureTile.tileID, name: CurrencyExposureTile.tileName, icon: CurrencyExposureTile.iconName) { AnyView(CurrencyExposureTile()) },
        TileInfo(id: RiskBucketsTile.tileID, name: RiskBucketsTile.tileName, icon: RiskBucketsTile.iconName) { AnyView(RiskBucketsTile()) },
        TileInfo(id: TextTile.tileID, name: TextTile.tileName, icon: TextTile.iconName) { AnyView(TextTile()) },
        TileInfo(id: ImageTile.tileID, name: ImageTile.tileName, icon: ImageTile.iconName) { AnyView(ImageTile()) },
        TileInfo(id: MapTile.tileID, name: MapTile.tileName, icon: MapTile.iconName) { AnyView(MapTile()) },
        TileInfo(id: AccountsNeedingUpdateTile.tileID, name: AccountsNeedingUpdateTile.tileName, icon: AccountsNeedingUpdateTile.iconName) { AnyView(AccountsNeedingUpdateTile()) }
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
