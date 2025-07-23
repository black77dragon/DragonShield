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

    private static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.tileName)
                .font(.system(size: 17, weight: .semibold))
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(rows) { item in
                            rowView(item)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: rows.count > 6 ? 200 : .infinity)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onAppear(perform: calculate)
        .accessibilityElement(children: .combine)
    }

    private func rowView(_ item: CryptoRow) -> some View {
        HStack {
            Text(item.symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Self.chfFormatter.string(from: NSNumber(value: item.valueCHF)) ?? "0")
                .frame(width: 80, alignment: .trailing)
            Text(String(format: "%.1f%%", item.percentage))
                .frame(width: 50, alignment: .trailing)
        }
        .font(.system(size: 13))
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

