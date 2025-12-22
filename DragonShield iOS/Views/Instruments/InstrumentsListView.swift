import SwiftUI

struct InstrumentsListView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var preferences: AppPreferences
    @State private var rows: [DatabaseManager.InstrumentRow] = []
    @State private var search: String = ""

    var body: some View {
        List(filtered) { r in
            NavigationLink(destination: InstrumentDetailView(instrumentId: r.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.name).font(.headline)
                    HStack(spacing: 8) {
                        if let t = r.tickerSymbol, !t.isEmpty { Text(t).font(.caption).foregroundColor(.secondary) }
                        if let i = r.isin, !i.isEmpty { Text(i).font(.caption).foregroundColor(.secondary) }
                        Text(r.currency).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Instruments")
        .searchable(text: $search, placement: .navigationBarDrawer)
        .onAppear { rows = dbManager.fetchAssets() }
        .refreshable { rows = dbManager.fetchAssets() }
    }

    private var filtered: [DatabaseManager.InstrumentRow] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows }
        let needle = q.lowercased()
        return rows.filter { r in
            r.name.lowercased().contains(needle) ||
                (r.tickerSymbol?.lowercased().contains(needle) ?? false) ||
                (r.isin?.lowercased().contains(needle) ?? false)
        }
    }
}

struct InstrumentDetailView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var preferences: AppPreferences
    let instrumentId: Int
    @State private var details: DatabaseManager.InstrumentDetails?
    @State private var memberships: [(themeId: Int, themeName: String, isArchived: Bool, updatesCount: Int, mentionsCount: Int)] = []
    @State private var holdings: [DatabaseManager.InstrumentAccountHolding] = []
    @State private var asOfDate: Date? = nil
    @State private var totalQuantity: Double = 0
    @State private var totalValueChf: Double? = nil
    @State private var perAccountValuesChf: [Int: Double] = [:]
    @State private var priceMissing: Bool = false
    @State private var fxMissing: Bool = false

    private enum SortColumn { case account, qty, chf }
    @State private var sortColumn: SortColumn = .chf
    @State private var sortAscending: Bool = false // default CHF desc

    var body: some View {
        Form {
            Section(header: Text("Holdings")) {
                HStack {
                    Text("Total Position")
                    Spacer()
                    Text(quantityString(totalQuantity))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                HStack {
                    Text("Total Value (\(preferences.baseCurrency))")
                    Spacer()
                    Text(totalValueChf.map { ValueFormatting.large($0) } ?? "—")
                        .fontWeight(.bold)
                        .foregroundColor(totalValueChf == nil ? .orange : .blue)
                        .privacyBlur()
                }
                if priceMissing || fxMissing {
                    HStack(spacing: 8) {
                        if priceMissing { badge(text: "Price missing") }
                        if fxMissing { badge(text: "FX missing") }
                        Spacer()
                    }
                }
                if let asOf = asOfDate {
                    Text("Positions as of \(DateFormatter.iso8601DateOnly.string(from: asOf))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Section(header: Text("Details")) {
                if let d = details {
                    KeyValueRow("Name", d.name)
                    KeyValueRow("Currency", d.currency)
                    if let t = d.tickerSymbol, !t.isEmpty { KeyValueRow("Ticker", t) }
                    if let i = d.isin, !i.isEmpty { KeyValueRow("ISIN", i) }
                    if let v = d.valorNr, !v.isEmpty { KeyValueRow("Valor", v) }
                    if let s = d.sector, !s.isEmpty { KeyValueRow("Sector", s) }
                } else {
                    Text("No details found").foregroundColor(.secondary)
                }
            }
            Section(header: Text("Accounts")) {
                if holdings.isEmpty {
                    Text("No positions for this instrument").foregroundColor(.secondary)
                } else {
                    HStack {
                        headerButton(title: "Account", col: .account)
                        Spacer()
                        headerButton(title: "Qty", col: .qty)
                            .frame(width: 100, alignment: .trailing)
                        headerButton(title: preferences.baseCurrency, col: .chf)
                            .frame(width: 120, alignment: .trailing)
                    }
                    ForEach(sortedHoldings) { h in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.accountName)
                                Text(h.institutionName).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(quantityString(h.quantity))
                                .frame(width: 100, alignment: .trailing)
                                .foregroundColor(.secondary)
                            Text(perAccountValuesChf[h.accountId].map { formattedAmount($0) } ?? "—")
                                .frame(width: 120, alignment: .trailing)
                                .foregroundColor(perAccountValuesChf[h.accountId] == nil ? .orange : .secondary)
                                .privacyBlur()
                        }
                    }
                }
            }
            Section(header: Text("Portfolios")) {
                if memberships.isEmpty {
                    Text("Not a member of any portfolio").foregroundColor(.secondary)
                } else {
                    ForEach(memberships, id: \.themeId) { it in
                        NavigationLink(destination: ThemeDetailIOSView(themeId: it.themeId)) {
                            HStack {
                                Text(it.themeName)
                                Spacer()
                                if it.isArchived { Text("Archived").font(.caption2).foregroundColor(.orange) }
                                if it.updatesCount > 0 { Text("📝 \(it.updatesCount)").font(.caption) }
                                if it.mentionsCount > 0 { Text("🔎 \(it.mentionsCount)").font(.caption) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(details?.name ?? "Instrument")
        .onAppear { load() }
    }

    private var sortedHoldings: [DatabaseManager.InstrumentAccountHolding] {
        let rows = holdings
        switch sortColumn {
        case .account:
            return rows.sorted { a, b in
                let lhs = a.accountName.lowercased()
                let rhs = b.accountName.lowercased()
                return sortAscending ? (lhs < rhs) : (lhs > rhs)
            }
        case .qty:
            return rows.sorted { a, b in
                sortAscending ? (a.quantity < b.quantity) : (a.quantity > b.quantity)
            }
        case .chf:
            return rows.sorted { a, b in
                let av = perAccountValuesChf[a.accountId]
                let bv = perAccountValuesChf[b.accountId]
                // Always push missing values to bottom
                switch (av, bv) {
                case (nil, nil):
                    return a.accountName < b.accountName
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                case let (la?, lb?):
                    return sortAscending ? (la < lb) : (la > lb)
                }
            }
        }
    }

    @ViewBuilder private func headerButton(title: String, col: SortColumn) -> some View {
        Button(action: {
            if sortColumn == col {
                sortAscending.toggle()
            } else {
                sortColumn = col
                // sensible defaults per column
                switch col {
                case .account: sortAscending = true
                case .qty: sortAscending = false
                case .chf: sortAscending = false
                }
            }
        }) {
            HStack(spacing: 4) {
                Text(title).font(.caption).foregroundColor(.secondary)
                if sortColumn == col {
                    Text(sortAscending ? "▲" : "▼").font(.caption).foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("Sort by \(title)")
    }

    private func load() {
        details = dbManager.fetchInstrumentDetails(id: instrumentId)
        let code = details?.tickerSymbol ?? details?.isin ?? ""
        let name = details?.name ?? dbManager.getInstrumentName(id: instrumentId) ?? ""
        memberships = dbManager.listThemesForInstrumentWithUpdateCounts(instrumentId: instrumentId, instrumentCode: code, instrumentName: name)
        holdings = dbManager.fetchInstrumentHoldingsByAccount(instrumentId: instrumentId)
        asOfDate = dbManager.positionsAsOfDate()
        computeValuation()
    }

    private func computeValuation() {
        // Capture to avoid any property-wrapper ambiguities in closures
        let manager: DatabaseManager = dbManager
        totalQuantity = holdings.reduce(0) { $0 + $1.quantity }
        priceMissing = false
        fxMissing = false
        perAccountValuesChf = [:]

        guard let priceInfo = manager.getLatestPrice(instrumentId: instrumentId) else {
            priceMissing = true
            totalValueChf = nil
            return
        }
        let nativeTotal = totalQuantity * priceInfo.price
        let priceCurrency = priceInfo.currency.uppercased()
        if priceCurrency == "CHF" {
            totalValueChf = nativeTotal
            for h in holdings {
                let v = h.quantity * priceInfo.price
                perAccountValuesChf[h.accountId] = v
            }
        } else {
            // Try robust lookup using iOS helpers only (target-safe): price currency, then instrument currency
            var rate: Double? = nil
            var rateFrom = priceCurrency
            if let r = manager.latestRateToChf(currencyCode: priceCurrency)?.rate {
                rate = r
            } else if let instCur = details?.currency.uppercased(), instCur != priceCurrency, let r2 = manager.latestRateToChf(currencyCode: instCur)?.rate {
                rate = r2
                rateFrom = instCur
            }

            if let r = rate {
                totalValueChf = nativeTotal * r
                for h in holdings {
                    let v = h.quantity * priceInfo.price
                    perAccountValuesChf[h.accountId] = v * r
                }
                #if DEBUG
                    LoggingService.shared.log("[iOS Valuation] FX applied instrId=\(instrumentId) priceCurr=\(priceCurrency) usedRateFrom=\(rateFrom) rate=\(r)", type: .debug, logger: .database)
                #endif
            } else {
                totalValueChf = nil
                fxMissing = true
                #if DEBUG
                    LoggingService.shared.log("[iOS Valuation] FX missing instrId=\(instrumentId) priceCurr=\(priceCurrency)", type: .warning, logger: .database)
                #endif
            }
        }
    }

    private func quantityString(_ q: Double) -> String {
        let precision = max(0, min(8, preferences.decimalPrecision))
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = precision
        nf.minimumFractionDigits = 0
        nf.groupingSeparator = "'"
        nf.usesGroupingSeparator = true
        return nf.string(from: NSNumber(value: q)) ?? String(format: "%0.*f", precision, q)
    }

    private func currencyString(_ v: Double) -> String {
        if #available(iOS 15.0, *) {
            return v.formatted(.currency(code: preferences.baseCurrency).precision(.fractionLength(2)))
        } else {
            let nf = NumberFormatter()
            nf.numberStyle = .currency
            nf.currencyCode = preferences.baseCurrency
            nf.maximumFractionDigits = 2
            nf.minimumFractionDigits = 2
            return nf.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
        }
    }

    private func formattedAmount(_ v: Double) -> String {
        if abs(v) >= 1000 { return ValueFormatting.large(v) }
        return currencyString(v)
    }

    @ViewBuilder private func badge(text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .foregroundColor(.orange)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.5), lineWidth: 1))
            .cornerRadius(8)
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String
    init(_ k: String, _ v: String) { key = k; value = v }
    var body: some View {
        HStack { Text(key); Spacer(); Text(value).foregroundColor(.secondary) }
    }
}
