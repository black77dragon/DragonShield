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
                        if let d = t.description, !d.isEmpty { Text(d).font(.footnote) }
                        HStack { Text("Instruments"); Spacer(); Text("\(t.instrumentCount)").foregroundColor(.secondary) }
                        HStack {
                            labelWithUnit("Portfolio Target Budget")
                            Spacer()
                            Text(kChf(t.theoreticalBudgetChf)).foregroundColor(.secondary)
                        }
                        HStack {
                            labelWithUnit("Set Target")
                            Spacer()
                            Text(kChf(totalSetTargetChf)).foregroundColor(.secondary)
                        }
                        HStack {
                            labelWithUnit("Actual Value")
                            Spacer()
                            Text(kChf(totalActualChf)).foregroundColor(.secondary).privacyBlur()
                        }
                    } else {
                        Text("Portfolio not found").foregroundColor(.secondary)
                    }
                }
                Section(header: Text("Holdings")) {
                    if holdings.isEmpty {
                        Text("No holdings or data unavailable for this snapshot").foregroundColor(.secondary)
                    } else {
                        HStack {
                            Text("Instrument").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("Targ (kCHF)").font(.caption).foregroundColor(.secondary).frame(width: 110, alignment: .trailing)
                            Text("Act (kCHF)").font(.caption).foregroundColor(.secondary).frame(width: 110, alignment: .trailing)
                        }
                        ForEach(sortedHoldings) { r in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.instrumentName)
                                    Text(r.instrumentCurrency).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(kChf(r.setTargetChf)).frame(width: 110, alignment: .trailing).foregroundColor(.secondary)
                                Text(kChf(r.valueChf)).frame(width: 110, alignment: .trailing).foregroundColor(r.valueChf == nil ? .orange : .secondary).privacyBlur()
                            }
                        }
                    }
                }
            }
            .navigationTitle(theme?.name ?? "Portfolio")
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

        private var totalSetTargetChf: Double? {
            let values = holdings.compactMap(\.setTargetChf)
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +)
        }

        private var totalActualChf: Double? {
            let values = holdings.compactMap(\.valueChf)
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +)
        }

        private func kChf(_ v: Double?) -> String {
            guard let value = v else { return "—" }
            return ValueFormatting.thousands(value)
        }

        private func labelWithUnit(_ text: String) -> some View {
            HStack(spacing: 4) {
                Text(text)
                Text("(kCHF)").font(.caption).foregroundColor(.secondary)
            }
        }
    }
#endif
