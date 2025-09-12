import SwiftUI

struct InstrumentDashboardWindowView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    let instrumentId: Int

    @State private var details: DatabaseManager.InstrumentDetails?
    @State private var latestPrice: (price: Double, currency: String, asOf: String)?
    @State private var themes: [(themeId: Int, themeName: String, isArchived: Bool, updatesCount: Int, mentionsCount: Int)] = []
    @State private var allocations: [AllocationRow] = []
    @State private var accountHoldings: [AccountHolding] = []
    @State private var totalValueCHF: Double = 0
    @State private var totalUnits: Double = 0
    @State private var instrumentCode: String = ""
    @State private var instrumentName: String = ""
    @State private var actualChfByTheme: [Int: Double] = [:]
    @State private var editingInstrument: Bool = false

    // Layout constants
    private let minRowsToShow: Int = 4
    private let tileRowHeight: CGFloat = 28

    struct AllocationRow: Identifiable {
        let id = UUID()
        let themeId: Int
        let themeName: String
        let researchPct: Double
        let userPct: Double
        let isArchived: Bool
    }

    struct AccountHolding: Identifiable {
        let id = UUID()
        let accountName: String
        let institutionName: String
        let quantity: Double
        let valueCHF: Double
    }

    @State private var openThemeId: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            HStack {
                Spacer()
                Button(role: .cancel) { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut("w", modifiers: .command)
            }
            .padding(12)
        }
        .frame(minWidth: 980, minHeight: 680)
        .onAppear(perform: load)
        .sheet(isPresented: $editingInstrument) {
            InstrumentEditView(instrumentId: instrumentId)
                .environmentObject(dbManager)
        }
        .sheet(item: Binding(get: {
            openThemeId.map { Ident(value: $0) }
        }, set: { newVal in openThemeId = newVal?.value })) { ident in
            PortfolioThemeWorkspaceView(
                themeId: ident.value,
                origin: "instrument_dashboard",
                initialTab: .updates
            )
            .environmentObject(dbManager)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Instrument Dashboard")
                    .font(.title3).bold()
                if let d = details {
                    Text(d.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    HStack(spacing: 8) {
                        Tag("Currency: \(d.currency)")
                        if let t = d.tickerSymbol, !t.isEmpty { Tag("Ticker: \(t.uppercased())") }
                        if let i = d.isin, !i.isEmpty { Tag("ISIN: \(i.uppercased())") }
                        if let v = d.valorNr, !v.isEmpty { Tag("Valor: \(v)") }
                        if let s = d.sector, !s.isEmpty { Tag("Sector: \(s)") }
                        Button("Edit Instrument") { editingInstrument = true }
                            .buttonStyle(.link)
                    }
                } else {
                    EmptyView()
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                let bigFontSize: CGFloat = 36
                Text(formatCHFNoDecimalsPrefix(totalValueCHF))
                    .font(.system(size: bigFontSize, weight: .bold))
                    .foregroundColor(Theme.primaryAccent)
                Text("Total Position")
                    .font(.caption)
                    .foregroundColor(.secondary)
                // Total units displayed under the Total Position label
                Text(String(format: "%.2f units", totalUnits))
                    .font(.system(size: bigFontSize / 2, weight: .bold))
                    .foregroundColor(Theme.primaryAccent)
            }
        }
        .padding(16)
        .background(Theme.surface)
    }

    private var content: some View {
        TabView {
            overviewTab
                .tabItem { Text("Overview") }
            notesTab
                .tabItem { Text("Notes") }
        }
    }

    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                topCards
                holdingsSection
            }
            .padding(12)
        }
    }

    private var topCards: some View {
        HStack(alignment: .top, spacing: 16) {
            infoCard(title: "Price & Value") {
                VStack(alignment: .leading, spacing: 4) {
                    if let p = latestPrice {
                        rowKV("Latest Price", String(format: "%.2f %@", p.price, p.currency))
                        rowKV("As Of", DateFormatting.userFriendly(p.asOf))
                    } else {
                        rowKV("Latest Price", "—")
                        rowKV("As Of", "—")
                    }
                    Divider().padding(.vertical, 2)
                    rowKV("Total Position (\(dbManager.baseCurrency))", formatCHFNoDecimalsSuffix(totalValueCHF))
                }
            }
            infoCard(title: "Portfolios & Allocations") {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Portfolio Theme").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Research %").frame(width: 90, alignment: .trailing)
                        Text("User %").frame(width: 80, alignment: .trailing)
                        Text("Actual CHF").frame(width: 140, alignment: .trailing)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                    Divider()
                    if themes.isEmpty {
                        Text("Not included in any portfolios")
                            .foregroundColor(.secondary)
                            .padding(8)
                    } else {
                        ForEach(themes, id: \.themeId) { t in
                            HStack {
                                Text(t.themeName)
                                    .underline()
                                    .foregroundColor(Theme.primaryAccent)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .onTapGesture(count: 2) { openThemeId = t.themeId }
                                let alloc = allocations.first { $0.themeId == t.themeId }
                                Text(alloc.map { String(format: "%.1f%%", $0.researchPct) } ?? "—")
                                    .frame(width: 90, alignment: .trailing)
                                    .monospacedDigit()
                                Text(alloc.map { String(format: "%.1f%%", $0.userPct) } ?? "—")
                                    .frame(width: 80, alignment: .trailing)
                                    .monospacedDigit()
                                Text(formatCHFNoDecimalsSuffix(actualChfByTheme[t.themeId] ?? 0))
                                    .frame(width: 140, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            if t.themeId != themes.last?.themeId { Divider() }
                        }
                    }
                }
            }
        }
    }

    // Consolidated into Portfolios & Allocations card

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Holdings by Account").font(.headline)
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                .background(Color.white)
                .overlay(
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow()
                        Divider()
                        if accountHoldings.isEmpty {
                            Text("No holdings found in current positions snapshot.")
                                .foregroundColor(.secondary)
                                .padding(8)
                        } else {
                            ForEach(accountHoldings) { r in
                                HStack {
                                    Text(r.accountName)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(String(format: "%.2f", r.quantity))
                                        .frame(width: 120, alignment: .trailing)
                                        .monospacedDigit()
                                    Text(formatCHFNoDecimalsSuffix(r.valueCHF))
                                        .frame(width: 160, alignment: .trailing)
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 8)
                                .frame(height: 28)
                                if r.id != accountHoldings.last?.id { Divider() }
                            }
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(minHeight: tileRowHeight * CGFloat(minRowsToShow) + 40)
        }
    }

    private func headerRow() -> some View {
        HStack {
            Text("Account").frame(maxWidth: .infinity, alignment: .leading)
            Text("Amount").frame(width: 140, alignment: .trailing)
            Text("Value").frame(width: 180, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var notesTab: some View {
        VStack(spacing: 0) {
            if instrumentName.isEmpty {
                Text("Loading…").padding()
            } else {
                InstrumentNotesView(
                    instrumentId: instrumentId,
                    instrumentCode: instrumentCode,
                    instrumentName: instrumentName,
                    initialTab: .updates,
                    initialThemeId: nil,
                    onClose: {}
                )
                .environmentObject(dbManager)
            }
        }
    }

    private func infoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func rowKV(_ key: String, _ value: String?) -> some View {
        HStack {
            Text(key).foregroundColor(.secondary)
            Spacer()
            Text(value ?? "—")
        }
        .font(.system(size: 13))
    }

    private func load() {
        // Details
        details = dbManager.fetchInstrumentDetails(id: instrumentId)
        instrumentName = details?.name ?? (dbManager.getInstrumentName(id: instrumentId) ?? "#\(instrumentId)")
        // Prefer ticker as code; fallback to ISIN/Valor if needed
        if let t = details?.tickerSymbol, !t.isEmpty {
            instrumentCode = t
        } else if let i = details?.isin, !i.isEmpty {
            instrumentCode = i
        } else if let v = details?.valorNr, !v.isEmpty {
            instrumentCode = v
        } else {
            instrumentCode = ""
        }

        // Latest price
        latestPrice = dbManager.getLatestPrice(instrumentId: instrumentId)

        // Portfolios
        let trows = dbManager.listThemesForInstrumentWithUpdateCounts(
            instrumentId: instrumentId,
            instrumentCode: instrumentCode,
            instrumentName: instrumentName
        )
        themes = trows
        allocations = trows.compactMap { t in
            if let asset = dbManager.getThemeAsset(themeId: t.themeId, instrumentId: instrumentId) {
                return AllocationRow(themeId: t.themeId, themeName: t.themeName, researchPct: asset.researchTargetPct, userPct: asset.userTargetPct, isArchived: t.isArchived)
            }
            return nil
        }

        // Positions snapshot -> account holdings and total CHF
        computeHoldings()

        // Compute actual CHF per theme for this instrument
        computeActualChfPerTheme()
    }

    private func computeHoldings() {
        // Build per-account aggregation based on latest price and FX to CHF.
        let reports = dbManager.fetchPositionReports()
        let filtered = reports.filter { $0.instrumentId == instrumentId }
        guard !filtered.isEmpty else {
            self.accountHoldings = []
            self.totalValueCHF = 0
            self.totalUnits = 0
            return
        }
        // Determine price and currency
        let priceInfo = dbManager.getLatestPrice(instrumentId: instrumentId)
        // Group by (accountName, institutionName)
        var byAccount: [String: (qty: Double, valueCHF: Double, acc: String)] = [:]
        for p in filtered {
            let key = p.accountName
            let qty = p.quantity
            // Value in instrument currency
            var value = 0.0
            if let pi = priceInfo {
                value = qty * pi.price
                // FX to CHF if needed
                if pi.currency.uppercased() != dbManager.baseCurrency.uppercased() {
                    if let rate = dbManager.fetchExchangeRates(currencyCode: pi.currency, upTo: nil).first?.rateToChf {
                        value *= rate
                    } else {
                        // No rate, fallback to 0 for CHF value
                        value = 0
                    }
                }
            }
            let prev = byAccount[key] ?? (0, 0, p.accountName)
            byAccount[key] = (prev.qty + qty, prev.valueCHF + value, p.accountName)
        }
        let rows = byAccount.values.map { AccountHolding(accountName: $0.acc, institutionName: "", quantity: $0.qty, valueCHF: $0.valueCHF) }
        self.accountHoldings = rows.sorted { $0.valueCHF > $1.valueCHF }
        self.totalValueCHF = rows.reduce(0) { $0 + $1.valueCHF }
        self.totalUnits = rows.reduce(0) { $0 + $1.quantity }
    }

    private func computeActualChfPerTheme() {
        guard !themes.isEmpty else { actualChfByTheme = [:]; return }
        DispatchQueue.global(qos: .userInitiated).async {
            var map: [Int: Double] = [:]
            let fxService = FXConversionService(dbManager: dbManager)
            let valuationService = PortfolioValuationService(dbManager: dbManager, fxService: fxService)
            for t in themes {
                let snap = valuationService.snapshot(themeId: t.themeId)
                if let row = snap.rows.first(where: { $0.instrumentId == instrumentId }) {
                    map[t.themeId] = row.currentValueBase
                } else {
                    map[t.themeId] = 0
                }
            }
            DispatchQueue.main.async { actualChfByTheme = map }
        }
    }

    private func formatCHFNoDecimalsPrefix(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        let base = f.string(from: NSNumber(value: v)) ?? String(format: "%.0f", v)
        return "CHF " + base
    }

    private func formatCHFNoDecimalsSuffix(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        let base = f.string(from: NSNumber(value: v)) ?? String(format: "%.0f", v)
        return base + " CHF"
    }

    private struct Ident: Identifiable { let value: Int; var id: Int { value } }
}

private struct Tag: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.12))
            .cornerRadius(6)
    }
}
