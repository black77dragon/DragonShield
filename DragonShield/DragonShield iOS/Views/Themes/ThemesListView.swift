import SwiftUI

struct ThemesListView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var themes: [PortfolioTheme] = []
    @State private var search: String = ""
    @State private var loading = false

    var body: some View {
        List {
            if !search.isEmpty {
                Section { Text("Searching: \(search)").font(.caption).foregroundColor(.secondary) }
            }
            if themes.isEmpty {
                Section {
                    Text(dbManager.tableExistsIOS("PortfolioTheme") ? "No themes found" : "This snapshot has no PortfolioTheme table. Import a full snapshot in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            ForEach(themes) { t in
                NavigationLink(destination: ThemeSummaryView(theme: t)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(t.name).font(.headline)
                            if t.archivedAt != nil { Text("Archived").font(.caption2).foregroundColor(.orange).padding(4).background(Color.orange.opacity(0.1)).clipShape(Capsule()) }
                        }
                        HStack(spacing: 12) {
                            Text(t.code).font(.caption).foregroundColor(.secondary)
                            if t.instrumentCount > 0 { Text("\(t.instrumentCount) instruments").font(.caption).foregroundColor(.secondary) }
                            if let b = t.theoreticalBudgetChf, b >= 1_000 {
                                Text("Budget: \(ValueFormatting.large(b))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Themes")
        .searchable(text: $search, placement: .navigationBarDrawer)
        // iOS 16-compatible onChange signature
        .onChange(of: search) { _ in reload() }
        .refreshable { reload() }
        .onAppear { reload() }
    }

    private func reload() {
        loading = true
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = self.dbManager.fetchPortfolioThemes(includeArchived: true, includeSoftDeleted: false, search: query.isEmpty ? nil : query)
        themes = result
        loading = false
    }
}

struct ThemeSummaryView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let theme: PortfolioTheme
    @State private var holdings: [DatabaseManager.ThemeHoldingRow] = []

    var body: some View {
        Form {
            Section(header: Text("Overview")) {
                HStack { Text("Name"); Spacer(); Text(theme.name).foregroundColor(.secondary) }
                HStack { Text("Code"); Spacer(); Text(theme.code).foregroundColor(.secondary) }
                if let d = theme.description, !d.isEmpty { Text(d).font(.footnote) }
                HStack { Text("Instruments"); Spacer(); Text("\(theme.instrumentCount)").foregroundColor(.secondary) }
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
        .navigationTitle(theme.name)
        .onAppear { reload() }
    }

    private func reload() { holdings = dbManager.fetchThemeHoldings(themeId: theme.id) }

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
