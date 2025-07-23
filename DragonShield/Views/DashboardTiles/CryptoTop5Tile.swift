import SwiftUI

struct CryptoTop5Tile: DashboardTile {
    init() {}
    static let tileID = "crypto_top5"
    static let tileName = "Crypto Top 5"
    static let iconName = "bitcoinsign.circle"

    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = CryptoTop5ViewModel()

    private static let valueFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        return f
    }()

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if viewModel.loading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<5, id: \.self) { idx in
                        rowView(index: idx)
                    }
                }
            }
        }
        .onAppear { viewModel.load(db: dbManager) }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func rowView(index: Int) -> some View {
        if index < viewModel.holdings.count {
            let item = viewModel.holdings[index]
            HStack {
                Text(item.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Self.valueFormatter.string(from: NSNumber(value: item.valueCHF)) ?? "0") + Text(" CHF")
                    .frame(width: 80, alignment: .trailing)
                Text(String(format: "%.1f%%", item.percentage))
                    .frame(width: 50, alignment: .trailing)
            }
            .font(.system(size: 13))
            .frame(minHeight: 44)
        } else {
            HStack {
                Text("–")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("–")
                    .frame(width: 80, alignment: .trailing)
                Text("–")
                    .frame(width: 50, alignment: .trailing)
            }
            .font(.system(size: 13))
            .frame(minHeight: 44)
        }
    }
}

