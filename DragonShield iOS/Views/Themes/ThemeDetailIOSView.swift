#if os(iOS)
import SwiftUI

struct ThemeDetailIOSView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    @State private var theme: PortfolioTheme? = nil
    @State private var holdings: [DatabaseManager.ThemeHoldingRow] = []

    var body: some View {
        Form {
            Section(header: Text("Overview")) {
                if let t = theme {
                    HStack { Text("Name"); Spacer(); Text(t.name).foregroundColor(.secondary) }
                    HStack { Text("Code"); Spacer(); Text(t.code).foregroundColor(.secondary) }
                    if let d = t.description, !d.isEmpty { Text(d).font(.footnote) }
                    HStack { Text("Instruments"); Spacer(); Text("\(t.instrumentCount)").foregroundColor(.secondary) }
                } else {
                    Text("Theme not found").foregroundColor(.secondary)
                }
            }
            Section(header: Text("Holdings")) {
                if holdings.isEmpty {
                    Text("No holdings or data unavailable for this snapshot").foregroundColor(.secondary)
                } else {
                    HStack {
                        Text("Instrument").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text("Qty").font(.caption).foregroundColor(.secondary).frame(width: 90, alignment: .trailing)
                        Text(dbManager.baseCurrency).font(.caption).foregroundColor(.secondary).frame(width: 120, alignment: .trailing)
                    }
                    ForEach(sortedHoldings) { r in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.instrumentName)
                                Text(r.instrumentCurrency).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(qty(r.quantity)).frame(width: 90, alignment: .trailing).foregroundColor(.secondary)
                            Text(chf(r.valueChf)).frame(width: 120, alignment: .trailing).foregroundColor(r.valueChf == nil ? .orange : .secondary).privacyBlur()
                        }
                    }
                }
            }
        }
        .navigationTitle(theme?.name ?? "Theme")
        .onAppear { reload() }
    }

    private func reload() {
        theme = dbManager.getPortfolioTheme(id: themeId)
        holdings = dbManager.fetchThemeHoldings(themeId: themeId)
    }

    private var sortedHoldings: [DatabaseManager.ThemeHoldingRow] {
        holdings.sorted {
            switch ($0.valueChf, $1.valueChf) {
            case (nil, nil): return $0.instrumentName < $1.instrumentName
            case (nil, _): return false
            case (_, nil): return true
            case let (a?, b?): return a > b
            }
        }
    }

    private func qty(_ v: Double) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.groupingSeparator = "'"; nf.usesGroupingSeparator = true
        nf.maximumFractionDigits = 4; nf.minimumFractionDigits = 0
        return nf.string(from: NSNumber(value: v)) ?? String(format: "%.4f", v)
    }

    private func chf(_ v: Double?) -> String {
        guard let val = v else { return "—" }
        if abs(val) >= 1_000 { return ValueFormatting.large(val) }
        let nf = NumberFormatter(); nf.numberStyle = .currency; nf.currencyCode = dbManager.baseCurrency
        nf.maximumFractionDigits = 2; nf.minimumFractionDigits = 2
        return nf.string(from: NSNumber(value: val)) ?? String(format: "%.2f", val)
    }
}
#endif
