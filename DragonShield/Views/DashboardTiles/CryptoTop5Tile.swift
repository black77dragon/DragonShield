import SwiftUI

struct CryptoTop5Tile: DashboardTile {
    init() {}
    static let tileID = "crypto_top5"
    static let tileName = "Crypto Allocations"
    static let iconName = "bitcoinsign.circle"

    struct CryptoRow: Identifiable {
        let id = UUID()
        let symbol: String
        let valueCHF: Double
        let percentage: Double
    }

    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [CryptoRow] = []
    @State private var loading = false
    @Environment(\.colorScheme) private var colorScheme

    private static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Self.tileName)
                .font(.system(size: 17, weight: .semibold))

            HStack(alignment: .bottom) {
                Text("ASSET")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("VALUE (CHF)")
                    .frame(width: 80, alignment: .trailing)
                Text("WEIGHT")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.caption2)
            .foregroundColor(Color(red: 100/255, green: 116/255, blue: 139/255))
            .textCase(.uppercase)
            .padding(.bottom, 4)

            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                            rowView(item)
                            if index != rows.count - 1 {
                                Divider()
                                    .foregroundColor(Color(red: 226/255, green: 232/255, blue: 240/255))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: rows.count > 6 ? 200 : .infinity)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear(perform: calculate)
        .accessibilityElement(children: .combine)
    }

    private func rowView(_ item: CryptoRow) -> some View {
        HStack(alignment: .top) {
            Text(item.symbol)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(Self.chfFormatter.string(from: NSNumber(value: item.valueCHF)) ?? "\u2014")
                .font(.system(.body, design: .monospaced))
                .frame(width: 80, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f %%", item.percentage))
                    .font(.system(size: 13, weight: .bold))
                weightBar(item.percentage)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 13))
    }

    private func weightBar(_ percentage: Double) -> some View {
        GeometryReader { geometry in
            let fraction = CGFloat(percentage / 100)
            let width = max(fraction * geometry.size.width, 2)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(colorScheme == .dark ? Color(red: 46/255, green: 46/255, blue: 46/255)
                                              : Color(red: 241/255, green: 245/255, blue: 249/255))
                    .frame(height: 4)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 59/255, green: 130/255, blue: 246/255),
                                     Color(red: 6/255, green: 182/255, blue: 212/255)],
                            startPoint: .leading,
                            endPoint: .trailing)
                    )
                    .frame(width: width, height: 4)
            }
        }
        .frame(width: 60, height: 4)
        .accessibilityLabel(Text(String(format: "%.1f%% weight", percentage)))
    }

    private func calculate() {
        loading = true
        DispatchQueue.global().async {
            let positions = dbManager.fetchPositionReports()
            var totals: [String: Double] = [:]
            var rateCache: [String: Double] = [:]
            for p in positions {
                guard let price = p.currentPrice else { continue }
                guard (p.assetSubClass ?? "").lowercased().contains("crypto") ||
                      (p.assetClass ?? "").lowercased().contains("crypto") else { continue }
                var value = p.quantity * price
                let currency = p.instrumentCurrency.uppercased()
                if currency != "CHF" {
                    if rateCache[currency] == nil {
                        rateCache[currency] = dbManager.fetchExchangeRates(currencyCode: currency, upTo: nil).first?.rateToChf
                    }
                    if let rate = rateCache[currency] {
                        value *= rate
                    } else {
                        continue
                    }
                }
                totals[p.instrumentName, default: 0] += value
            }
            let totalValue = totals.values.reduce(0, +)
            let sorted = totals.sorted { $0.value > $1.value }
            let results = sorted.map { key, value in
                CryptoRow(symbol: key,
                          valueCHF: value,
                          percentage: totalValue > 0 ? value / totalValue * 100 : 0)
            }
            DispatchQueue.main.async {
                self.rows = results
                self.loading = false
            }
        }
    }
}

