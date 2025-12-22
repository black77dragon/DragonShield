#if os(iOS)
    import SQLite3
    import SwiftUI

    struct IOSDashboardView: View {
        @EnvironmentObject var dbManager: DatabaseManager
        @AppStorage("tile.totalValue") private var showTotalValue: Bool = true
        @AppStorage("tile.missingPrices") private var showMissingPrices: Bool = true
        @AppStorage("tile.cryptoAlloc") private var showCryptoAlloc: Bool = true
        @AppStorage("tile.currencyExposure") private var showCurrencyExposure: Bool = true
        @AppStorage("tile.upcomingAlerts") private var showUpcomingAlerts: Bool = true
        @AppStorage("ios.dashboard.tileOrder") private var tileOrderRaw: String = ""
        @AppStorage(UserDefaultsKeys.dashboardShowIncomingDeadlinesEveryVisit) private var showIncomingDeadlinesEveryVisit: Bool = true
        @AppStorage(UserDefaultsKeys.dashboardIncomingPopupShownThisLaunch) private var incomingDeadlinesPopupShownThisLaunch: Bool = false
        @State private var showUpcomingWeekPopup = false
        @State private var startupChecked = false
        @State private var upcomingWeek: [(name: String, date: String)] = []

        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(currentTileOrder(), id: \.self) { id in
                        switch id {
                        case "totalValue":
                            if showTotalValue {
                                if supportsPositions() { TotalValueTileIOS().environmentObject(dbManager) }
                                else { MissingPositionsTileIOS(title: "Total Asset Value") }
                            }
                        case "missingPrices":
                            if showMissingPrices { MissingPricesTileIOS().environmentObject(dbManager) }
                        case "cryptoAlloc":
                            if showCryptoAlloc {
                                if supportsPositions() { CryptoAllocationsTileIOS().environmentObject(dbManager) }
                                else { MissingPositionsTileIOS(title: "Crypto Allocations") }
                            }
                        case "currencyExposure":
                            if showCurrencyExposure {
                                if supportsPositions() { CurrencyExposureTileIOS().environmentObject(dbManager) }
                                else { MissingPositionsTileIOS(title: "Portfolio by Currency") }
                            }
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
            .sheet(isPresented: $showUpcomingWeekPopup) {
                IOSStartupAlertsPopup(items: upcomingWeek)
            }
            .onAppear {
                if !startupChecked {
                    startupChecked = true
                    loadUpcomingWeekAlerts()
                }
            }
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

        // MARK: Startup alerts check (next 7 days)

        func loadUpcomingWeekAlerts() {
            let rows = fetchUpcomingDateAlertsForIOS(db: dbManager.db, limit: 200)
            // filter to <= 7 days from today
            let inDf = DateFormatter(); inDf.locale = Locale(identifier: "en_US_POSIX"); inDf.timeZone = TimeZone(secondsFromGMT: 0); inDf.dateFormat = "yyyy-MM-dd"
            guard let today = inDf.date(from: inDf.string(from: Date())),
                  let week = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return }
            let nextWeek = rows.filter { inDf.date(from: $0.date).map { $0 <= week } ?? false }
            if !nextWeek.isEmpty {
                upcomingWeek = nextWeek.map { ($0.name, $0.date) }

                let shouldShowPopup: Bool
                if !incomingDeadlinesPopupShownThisLaunch {
                    incomingDeadlinesPopupShownThisLaunch = true
                    shouldShowPopup = true
                } else {
                    shouldShowPopup = showIncomingDeadlinesEveryVisit
                }

                if shouldShowPopup {
                    showUpcomingWeekPopup = true
                }
            }
        }

        func supportsPositions() -> Bool {
            dbManager.tableExistsIOS("PositionReports")
        }
    }

    // MARK: - Startup popup (iOS)

    private struct IOSStartupAlertsPopup: View {
        let items: [(name: String, date: String)]
        private static let inDf: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f }()
        private static let outDf: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "de_CH"); f.dateFormat = "dd.MM.yy"; return f }()
        private func format(_ s: String) -> String { if let d = Self.inDf.date(from: s) { return Self.outDf.string(from: d) }; return s }

        @Environment(\.dismiss) private var dismiss
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image("dragonshieldAppLogo")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityHidden(true)
                    Text("Incoming Deadlines Detected")
                        .font(.title2).bold()
                    Spacer()
                }
                Text("A long time ago in a galaxy not so far away… upcoming alerts began to stir. Use the Force to stay on target!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.0) { _, it in
                        HStack {
                            Text(it.name).lineLimit(1).truncationMode(.tail)
                            Spacer()
                            Text(format(it.date)).foregroundColor(.secondary)
                        }
                    }
                }
                Divider()
                HStack { Spacer(); Button("Dismiss") { dismiss() } }
            }
            .padding(20)
        }
    }

    // MARK: - Minimal fetch (read-only snapshot)

    private func fetchUpcomingDateAlertsForIOS(db: OpaquePointer?, limit: Int) -> [(name: String, date: String)] {
        guard let db else { return [] }
        // Ensure Alert table exists
        var check: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND name='Alert' LIMIT 1", -1, &check, nil) != SQLITE_OK { return [] }
        let exists = sqlite3_step(check) == SQLITE_ROW
        sqlite3_finalize(check)
        guard exists else { return [] }
        // Load enabled date alerts
        var stmt: OpaquePointer?
        var out: [(String, String)] = []
        if sqlite3_prepare_v2(db, "SELECT name, params_json FROM Alert WHERE enabled = 1 AND trigger_type_code = 'date' ORDER BY id DESC", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(stmt, 0))
                let params = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "{}"
                if let data = params.data(using: .utf8),
                   let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                {
                    let dateStr = (obj["date"] as? String) ?? (obj["trigger_date"] as? String) ?? ""
                    if !dateStr.isEmpty { out.append((name, dateStr)) }
                    if out.count >= limit { break }
                }
            }
        }
        return out
    }

    private struct TotalValueTileIOS: View {
        @EnvironmentObject var dbManager: DatabaseManager
        @EnvironmentObject var preferences: AppPreferences
        @State private var total: Double = 0
        @State private var loading = false

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Image(systemName: "francsign.circle"); Text("Total Asset Value (") + Text(preferences.baseCurrency).bold() + Text(")") }
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
                    if curr != preferences.baseCurrency.uppercased() {
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
        @EnvironmentObject var preferences: AppPreferences
        @State private var rows: [(name: String, value: Double, pct: Double)] = []
        @State private var loading = false

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Image(systemName: "bitcoinsign.circle"); Text("Crypto Allocations").font(.headline) }
                if loading { ProgressView().frame(maxWidth: .infinity) } else if rows.isEmpty {
                    Text("No crypto holdings").font(.caption).foregroundColor(.secondary)
                } else {
                    HStack { Text("Asset").font(.caption).foregroundColor(.secondary); Spacer(); Text("CHF").font(.caption).foregroundColor(.secondary).frame(width: 120, alignment: .trailing); Text("Weight").font(.caption).foregroundColor(.secondary).frame(width: 60, alignment: .trailing) }
                    ForEach(0 ..< rows.count, id: \.self) { i in
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
                    if curr != preferences.baseCurrency.uppercased() {
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
                let list = sums.sorted { $0.value > $1.value }.map { k, v in (k, v, total > 0 ? v / total * 100 : 0) }
                DispatchQueue.main.async { rows = list; loading = false }
            }
        }
    }

    private struct CurrencyExposureTileIOS: View {
        @EnvironmentObject var dbManager: DatabaseManager
        @EnvironmentObject var preferences: AppPreferences
        @State private var rows: [(currency: String, chf: Double, pct: Double)] = []
        @State private var loading = false

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Image(systemName: "globe"); Text("Portfolio by Currency").font(.headline) }
                if loading { ProgressView().frame(maxWidth: .infinity) } else if rows.isEmpty {
                    Text("No holdings").font(.caption).foregroundColor(.secondary)
                } else {
                    HStack { Text("Currency").font(.caption).foregroundColor(.secondary); Spacer(); Text("CHF").font(.caption).foregroundColor(.secondary).frame(width: 120, alignment: .trailing); Text("Weight").font(.caption).foregroundColor(.secondary).frame(width: 60, alignment: .trailing) }
                    ForEach(0 ..< rows.count, id: \.self) { i in
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
                    if curr != preferences.baseCurrency.uppercased() {
                        if let cached = rateCache[curr] { value *= cached }
                        else if let r = dbManager.latestRateToChf(currencyCode: curr)?.rate { rateCache[curr] = r; value *= r }
                        else { continue }
                    }
                    sums[p.instrumentCurrency.uppercased(), default: 0] += value
                }
                let total = sums.values.reduce(0, +)
                let list = sums.sorted { $0.value > $1.value }.map { k, v in (k, v, total > 0 ? v / total * 100 : 0) }
                DispatchQueue.main.async { rows = list; loading = false }
            }
        }
    }

    // Fallback tile shown if the snapshot lacks PositionReports table
    private struct MissingPositionsTileIOS: View {
        let title: String
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(title).font(.headline)
                }
                Text("Positions are not available in this snapshot. Export a full snapshot from the Mac app and import it here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // Tile visibility is controlled via @AppStorage in this view and in Settings
#endif
