#if os(iOS)
import SwiftUI

struct IOSDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @AppStorage("tile.totalValue") private var showTotalValue: Bool = true
    @AppStorage("tile.missingPrices") private var showMissingPrices: Bool = true
    @AppStorage("tile.cryptoAlloc") private var showCryptoAlloc: Bool = true
    @AppStorage("tile.currencyExposure") private var showCurrencyExposure: Bool = true
    @AppStorage("tile.upcomingAlerts") private var showUpcomingAlerts: Bool = true
    @AppStorage("ios.dashboard.tileOrder") private var tileOrderRaw: String = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(currentTileOrder(), id: \.self) { id in
                    switch id {
                    case "totalValue":
                        if showTotalValue { TotalValueTileIOS().environmentObject(dbManager) }
                    case "missingPrices":
                        if showMissingPrices { MissingPricesTileIOS().environmentObject(dbManager) }
                    case "cryptoAlloc":
                        if showCryptoAlloc { CryptoAllocationsTileIOS().environmentObject(dbManager) }
                    case "currencyExposure":
                        if showCurrencyExposure { CurrencyExposureTileIOS().environmentObject(dbManager) }
                    case "upcomingAlerts":
                        if showUpcomingAlerts { UpcomingAlertsTileIOS().environmentObject(dbManager) }
                    default:
                        EmptyView()
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Dashboard")
    }
}

// MARK: - Tile order helpers
private extension IOSDashboardView {
    func defaultOrder() -> [String] { ["totalValue", "missingPrices", "cryptoAlloc", "currencyExposure", "upcomingAlerts"] }
    func currentTileOrder() -> [String] {
        let saved = tileOrderRaw.split(separator: ",").map { String($0) }
        var set = Set(saved)
        var order: [String] = saved
        // Append any new tiles not yet saved
        for id in defaultOrder() where !set.contains(id) {
            order.append(id); set.insert(id)
        }
        // Filter unknown ids
        let known = Set(defaultOrder())
        let filtered = order.filter { known.contains($0) }
        if tileOrderRaw.isEmpty { tileOrderRaw = filtered.joined(separator: ",") }
        return filtered
    }
}

private struct TotalValueTileIOS: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var total: Double = 0
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "francsign.circle"); Text("Total Asset Value (") + Text(dbManager.baseCurrency).bold() + Text(")") }
                .font(.headline)
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text(ValueFormatting.large(total))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.blue)
                    .privacyBlur()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear(perform: calculate)
        .onChange(of: dbManager.dbFilePath) { _ in calculate() }
        .accessibilityElement(children: .combine)
    }

    private func calculate() {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let positions = dbManager.fetchPositionReportsSafe()
            var sum: Double = 0
            var rateCache: [String: Double] = [:]
            for p in positions {
                guard let iid = p.instrumentId, let lp = dbManager.getLatestPrice(instrumentId: iid) else { continue }
                var value = p.quantity * lp.price
                let curr = lp.currency.uppercased()
                if curr != dbManager.baseCurrency.uppercased() {
                    if let cached = rateCache[curr] {
                        value *= cached
                    } else if let r = dbManager.latestRateToChf(currencyCode: curr)?.rate {
                        rateCache[curr] = r
                        value *= r
                    } else {
                        continue
                    }
                }
                sum += value
            }
            DispatchQueue.main.async { total = sum; loading = false }
        }
    }
}

private struct MissingPricesTileIOS: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var items: [(id: Int, name: String, currency: String)] = []
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text("Missing Prices").font(.headline)
                Spacer()
                Text(items.isEmpty ? "—" : String(items.count))
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if items.isEmpty {
                Text("All instruments have a latest price.").font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(items.prefix(10), id: \.id) { it in
                    HStack {
                        Text(it.name)
                        Spacer()
                        Text(it.currency).foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
                if items.count > 10 { Text("+ \(items.count - 10) more …").font(.caption).foregroundColor(.secondary) }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear(perform: load)
        .onChange(of: dbManager.dbFilePath) { _ in load() }
    }

    private func load() {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            var res: [(Int, String, String)] = []
            let assets = dbManager.fetchAssets()
            for a in assets {
                if dbManager.getLatestPrice(instrumentId: a.id) == nil {
                    res.append((a.id, a.name, a.currency))
                }
            }
            DispatchQueue.main.async { items = res; loading = false }
        }
    }
}

private struct CryptoAllocationsTileIOS: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [(name: String, value: Double, pct: Double)] = []
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "bitcoinsign.circle"); Text("Crypto Allocations").font(.headline) }
            if loading { ProgressView().frame(maxWidth: .infinity) } else if rows.isEmpty {
                Text("No crypto holdings").font(.caption).foregroundColor(.secondary)
            } else {
                HStack { Text("Asset").font(.caption).foregroundColor(.secondary); Spacer(); Text("CHF").font(.caption).foregroundColor(.secondary).frame(width: 120, alignment: .trailing); Text("Weight").font(.caption).foregroundColor(.secondary).frame(width: 60, alignment: .trailing) }
                ForEach(0..<rows.count, id: \.self) { i in
                    let r = rows[i]
                    HStack {
                        Text(r.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(ValueFormatting.large(r.value)).frame(width: 120, alignment: .trailing).privacyBlur()
                        Text(String(format: "%.1f%%", r.pct)).frame(width: 60, alignment: .trailing)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear(perform: calculate)
        .onChange(of: dbManager.dbFilePath) { _ in calculate() }
    }

    private func calculate() {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let positions = dbManager.fetchPositionReportsSafe()
            var sums: [String: Double] = [:]
            var rateCache: [String: Double] = [:]
            for p in positions {
                guard let iid = p.instrumentId, let lp = dbManager.getLatestPrice(instrumentId: iid) else { continue }
                // Identify crypto by asset class/subclass name
                let isCrypto = (p.assetSubClass ?? "").localizedCaseInsensitiveContains("crypto") || (p.assetClass ?? "").localizedCaseInsensitiveContains("crypto")
                guard isCrypto else { continue }
                var value = p.quantity * lp.price
                let curr = lp.currency.uppercased()
                if curr != dbManager.baseCurrency.uppercased() {
                    if let cached = rateCache[curr] {
                        value *= cached
                    } else if let r = dbManager.latestRateToChf(currencyCode: curr)?.rate {
                        rateCache[curr] = r
                        value *= r
                    } else { continue }
                }
                sums[p.instrumentName, default: 0] += value
            }
            let total = sums.values.reduce(0, +)
            let list = sums.sorted { $0.value > $1.value }.map { (k, v) in (k, v, total > 0 ? v/total*100 : 0) }
            DispatchQueue.main.async { rows = list; loading = false }
        }
    }
}

private struct CurrencyExposureTileIOS: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var rows: [(currency: String, chf: Double, pct: Double)] = []
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "globe"); Text("Portfolio by Currency").font(.headline) }
            if loading { ProgressView().frame(maxWidth: .infinity) } else if rows.isEmpty {
                Text("No holdings").font(.caption).foregroundColor(.secondary)
            } else {
                HStack { Text("Currency").font(.caption).foregroundColor(.secondary); Spacer(); Text("CHF").font(.caption).foregroundColor(.secondary).frame(width: 120, alignment: .trailing); Text("Weight").font(.caption).foregroundColor(.secondary).frame(width: 60, alignment: .trailing) }
                ForEach(0..<rows.count, id: \.self) { i in
                    let r = rows[i]
                    HStack {
                        Text(r.currency).frame(maxWidth: .infinity, alignment: .leading)
                        Text(ValueFormatting.large(r.chf)).frame(width: 120, alignment: .trailing).privacyBlur()
                        Text(String(format: "%.1f%%", r.pct)).frame(width: 60, alignment: .trailing)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear(perform: calculate)
        .onChange(of: dbManager.dbFilePath) { _ in calculate() }
    }

    private func calculate() {
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let positions = dbManager.fetchPositionReportsSafe()
            var sums: [String: Double] = [:]
            var rateCache: [String: Double] = [:]
            for p in positions {
                guard let iid = p.instrumentId, let lp = dbManager.getLatestPrice(instrumentId: iid) else { continue }
                var value = p.quantity * lp.price
                let curr = lp.currency.uppercased()
                if curr != dbManager.baseCurrency.uppercased() {
                    if let cached = rateCache[curr] { value *= cached }
                    else if let r = dbManager.latestRateToChf(currencyCode: curr)?.rate { rateCache[curr] = r; value *= r }
                    else { continue }
                }
                sums[p.instrumentCurrency.uppercased(), default: 0] += value
            }
            let total = sums.values.reduce(0, +)
            let list = sums.sorted { $0.value > $1.value }.map { (k, v) in (k, v, total > 0 ? v/total*100 : 0) }
            DispatchQueue.main.async { rows = list; loading = false }
        }
    }
}

// Tile visibility is controlled via @AppStorage in this view and in Settings
#endif
