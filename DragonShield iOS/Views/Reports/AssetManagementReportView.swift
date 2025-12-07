#if os(iOS)
import SwiftUI

// iOS version of the Asset Management Report. Mirrors the desktop report structure
// (cash, near cash, currency, asset class, crypto, custody) using snapshot data.
struct AssetManagementReportView: View {
    @EnvironmentObject private var dbManager: DatabaseManager
    @StateObject private var viewModel: AssetManagementReportViewModel = .init()
    @State private var showCash = false
    @State private var showNearCash = false
    @State private var showCurrency = false
    @State private var showAssetClass = false
    @State private var showCrypto = false
    @State private var showCustody = false
    @State private var expandedCustodyAccounts: Set<String> = []
    @State private var selectedAssetClass: AssetManagementReportSummary.AssetClassBreakdown?

    private var summary: AssetManagementReportSummary { viewModel.summary }
    private var sortedAssetClasses: [AssetManagementReportSummary.AssetClassBreakdown] {
        summary.assetClassBreakdown.sorted { $0.baseValue > $1.baseValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if viewModel.isLoading {
                    loadingState
                } else {
                    cashSection
                    nearCashSection
                    currencySection
                    assetClassSection
                    cryptoSection
                    custodySection
                }
                if let message = viewModel.errorMessage {
                    placeholder(message)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Asset Management Report")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.load(using: dbManager)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .onAppear {
            viewModel.load(using: dbManager)
        }
        .sheet(item: $selectedAssetClass) { breakdown in
            AssetClassSubClassSheet(
                breakdown: breakdown,
                baseCurrency: summary.baseCurrency,
                formatCurrency: { value, currency, decimals in
                    self.formatCurrency(value, currency: currency, decimals: decimals)
                },
                formatNumber: { value, decimals in
                    self.formatNumber(value, decimals: decimals)
                }
            )
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Asset Management Report")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            HStack(spacing: 12) {
                Label("As of \(reportDateText)", systemImage: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Base: \(summary.baseCurrency.uppercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reportDateText: String {
        DateFormatter.assetReport.string(from: summary.reportDate)
    }

    // MARK: Sections

    private var cashSection: some View {
        ReportSectionCard(
            letter: "A",
            header: {
                sectionHeader(
                    title: Text("How much ") + highlight("cash") + Text(" do I have?"),
                    summaryTitle: "Total cash",
                    amount: summary.totalCashBase
                )
            }
        ) {
            if summary.cashBreakdown.isEmpty {
                placeholder("No cash accounts matched the configured filters.")
            } else {
                DisclosureGroup(isExpanded: $showCash) {
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
                            tableHeader(columns: ["Account", "Local", summary.baseCurrency], boldColumnIndices: [2])
                                .padding(.bottom, 6)
                            ForEach(summary.cashBreakdown) { row in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.accountName)
                                                .font(.headline)
                                            Text(row.institutionName)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(minWidth: 260, alignment: .leading)
                                        Spacer(minLength: 12)
                                        Text("\(row.currency) \(formatNumber(row.localAmount, decimals: 0))")
                                            .font(.body.monospacedDigit())
                                            .frame(width: 160, alignment: .trailing)
                                        Text(formatCurrency(row.baseAmount, currency: summary.baseCurrency))
                                            .font(.body.monospacedDigit().weight(.semibold))
                                            .frame(width: 160, alignment: .trailing)
                                    }
                                    Divider()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(minWidth: 720, alignment: .leading)
                    }
                } label: { detailDisclosureLabel("Tap for account level detail") }
            }
        }
    }

    private var nearCashSection: some View {
        ReportSectionCard(
            letter: "B",
            header: {
                sectionHeader(
                    title: Text("What can I ") + highlight("convert into cash") + Text(" early?"),
                    summaryTitle: "Total near cash",
                    amount: summary.totalNearCashBase
                )
            }
        ) {
            if summary.nearCashHoldings.isEmpty {
                placeholder("No fixed income or money market holdings detected.")
            } else {
                DisclosureGroup(isExpanded: $showNearCash) {
                    ScrollView(.horizontal, showsIndicators: true) {
                        nearCashDetailTable(rows: summary.nearCashHoldings)
                            .frame(minWidth: 720, alignment: .leading)
                    }
                } label: { detailDisclosureLabel("Tap for near-cash detail") }
            }
        }
    }

    private func nearCashDetailTable(rows: [AssetManagementReportSummary.NearCashHolding]) -> some View {
        VStack(spacing: 6) {
            tableHeader(columns: ["Instrument", "Currency", summary.baseCurrency])
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .font(.headline)
                            Text("\(row.category) • \(row.accountName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(minWidth: 260, alignment: .leading)
                        Spacer(minLength: 12)
                        Text("\(row.currency) \(formatNumber(row.localValue, decimals: 0))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                        Text(formatCurrency(row.baseValue, currency: summary.baseCurrency))
                            .font(.caption.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                    }
                    Divider()
                }
            }
        }
    }

    private var currencySection: some View {
        ReportSectionCard(
            letter: "C",
            header: {
                sectionHeader(
                    title: Text("In which ") + highlight("currencies") + Text(" am I allocated?"),
                    summaryTitle: "Invested assets",
                    amount: summary.totalPortfolioBase
                )
            }
        ) {
            if summary.currencyAllocations.isEmpty {
                placeholder("No currency exposure available yet.")
            } else {
                DisclosureGroup(isExpanded: $showCurrency) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(summary.currencyAllocations) { allocation in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(allocation.currency).font(.headline)
                                    Spacer()
                                    Text(formatCurrency(allocation.baseValue, currency: summary.baseCurrency))
                                        .font(.body.monospacedDigit())
                                }
                                ProgressView(value: clampedPercentage(allocation.percentage), total: 100)
                                    .tint(currencyColor(for: allocation.currency))
                                Text(String(format: "%.1f%% of invested assets", allocation.percentage))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } label: { detailDisclosureLabel("Tap for currency exposure detail") }
            }
        }
    }

    private var assetClassSection: some View {
        ReportSectionCard(
            letter: "D",
            header: {
                sectionHeader(
                    title: Text("How am I ") + highlight("allocated by asset class") + Text("?"),
                    summaryTitle: "Total assets",
                    amount: summary.totalPortfolioBase
                )
            }
        ) {
            if sortedAssetClasses.isEmpty {
                placeholder("No asset class data available yet.")
            } else {
                DisclosureGroup(isExpanded: $showAssetClass) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedAssetClasses) { item in
                            Button {
                                selectedAssetClass = item
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.name).font(.headline)
                                        Spacer()
                                        Text(formatCurrency(item.baseValue, currency: summary.baseCurrency))
                                            .font(.subheadline.monospacedDigit())
                                    }
                                    ProgressView(value: clampedPercentage(item.percentage), total: 100)
                                        .tint(item.displayColor)
                                    Text(String(format: "%.1f%%", item.percentage))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                } label: { detailDisclosureLabel("Tap for asset class detail") }
            }
        }
    }

    private var cryptoSection: some View {
        ReportSectionCard(
            letter: "E",
            header: {
                sectionHeader(
                    title: Text("What is my ") + highlight("crypto currency") + Text(" exposure?"),
                    summaryTitle: "Total crypto",
                    amount: summary.totalCryptoBase
                )
            }
        ) {
            if summary.cryptoHoldings.isEmpty {
                placeholder("No crypto holdings detected.")
            } else {
                DisclosureGroup(isExpanded: $showCrypto) {
                    VStack(spacing: 0) {
                        tableHeader(columns: ["Instrument", "orig. curr", summary.baseCurrency, "% in crypto", "% of total assets"])
                            .padding(.bottom, 2)
                        ForEach(summary.cryptoHoldings) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(row.instrumentName)
                                            .font(.headline)
                                        Text("Units: \(formatCryptoQuantity(row.totalQuantity))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(formatCryptoQuantity(row.totalQuantity)) \(row.currency)")
                                        .font(.body.monospacedDigit())
                                        .frame(width: 140, alignment: .trailing)
                                    Text(formatCurrency(row.baseValue, currency: summary.baseCurrency))
                                        .font(.body.monospacedDigit())
                                        .frame(width: 140, alignment: .trailing)
                                    Text(formatPercentage(percentageShare(of: row.baseValue, total: summary.totalCryptoBase)))
                                        .font(.body.monospacedDigit())
                                        .frame(width: 120, alignment: .trailing)
                                    Text(formatPercentage(percentageShare(of: row.baseValue, total: summary.totalPortfolioBase)))
                                        .font(.body.monospacedDigit())
                                        .frame(width: 140, alignment: .trailing)
                                }
                                Divider()
                                    .padding(.top, 1)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } label: { detailDisclosureLabel("Tap for crypto detail") }
            }
        }
    }

    private var custodySection: some View {
        ReportSectionCard(
            letter: "F",
            header: {
                sectionHeader(
                    title: Text("Custody exposure: ") + highlight("ZKB") + Text(" vs ") + highlight("UBS"),
                    summaryTitle: "Tracked custody",
                    amount: summary.totalTrackedCustodyBase
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                custodySummaryGrid
                if summary.custodySummaries.filter({ !$0.accounts.isEmpty }).isEmpty {
                    placeholder("No custody positions recorded for ZKB or UBS / Credit-Suisse.")
                } else {
                    DisclosureGroup(isExpanded: $showCustody) {
                        custodyDetailList
                    } label: { detailDisclosureLabel("Tap for custody account detail") }
                }
            }
        }
    }

    private var custodySummaryGrid: some View {
        let totals = summary.custodySummaries.reduce(into: [String: Double]()) { $0[$1.id] = $1.totalBaseValue }
        let cards: [(id: String, title: String)] = [
            (id: "ZKB", title: "Zürcher Kantonalbank"),
            (id: "UBS", title: "UBS (Credit-Suisse)"),
        ]
        let totalTrackedAmount = totals.values.reduce(0, +)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(cards, id: \.id) { card in
                let amount = totals[card.id] ?? 0
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formatCurrency(amount, currency: summary.baseCurrency))
                            .font(.title3.weight(.semibold).monospacedDigit())
                        Text(formatPercentage(percentageShare(of: amount, total: totalTrackedAmount)))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }

    private var custodyDetailList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(summary.custodySummaries.filter { !$0.accounts.isEmpty }) { institution in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(institution.displayName)
                            .font(.headline)
                        Spacer()
                        Text(formatCurrency(institution.totalBaseValue, currency: summary.baseCurrency))
                            .font(.headline.monospacedDigit())
                    }
                    VStack(spacing: 8) {
                        ForEach(institution.accounts) { account in
                            custodyAccountBlock(account: account)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    @ViewBuilder
    private func custodyAccountBlock(account: AssetManagementReportSummary.CustodyInstitutionSummary.AccountBreakdown) -> some View {
        DisclosureGroup(isExpanded: bindingForCustodyAccount(account.id)) {
            custodyPositionsList(for: account)
        } label: {
            custodyAccountHeader(account)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
    }

    private func custodyAccountHeader(_ account: AssetManagementReportSummary.CustodyInstitutionSummary.AccountBreakdown) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(account.positions.count) positions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(account.totalBaseValue, currency: summary.baseCurrency))
                .font(.body.monospacedDigit())
        }
    }

    private func custodyPositionsList(for account: AssetManagementReportSummary.CustodyInstitutionSummary.AccountBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(account.positions) { position in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(position.instrumentName)
                                .font(.subheadline.weight(.semibold))
                            Text("\(position.assetSubClass) • \(position.accountName)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 12)
                        Text(formatCurrency(position.baseValue, currency: summary.baseCurrency))
                            .font(.caption.monospacedDigit())
                            .frame(width: 140, alignment: .trailing)
                    }
                    Divider()
                }
            }
        }
    }

    private func bindingForCustodyAccount(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedCustodyAccounts.contains(id) },
            set: { newValue in
                if newValue {
                    expandedCustodyAccounts.insert(id)
                } else {
                    expandedCustodyAccounts.remove(id)
                }
            }
        )
    }

    // MARK: Helpers

    private func sectionHeader(title: Text, summaryTitle: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title
                .font(.title3.weight(.semibold))
            Text("\(summaryTitle): \(formatCurrency(amount, currency: summary.baseCurrency))")
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Building report with live data…")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func highlight(_ text: String) -> Text {
        Text(text).foregroundColor(.accentColor).fontWeight(.semibold)
    }

    private func tableHeader(columns: [String], boldColumnIndices: Set<Int> = []) -> some View {
        HStack {
            ForEach(Array(columns.enumerated()), id: \.0) { idx, col in
                Text(col)
                    .font(.caption.weight(boldColumnIndices.contains(idx) ? .semibold : .regular))
                    .foregroundColor(.secondary)
                    .frame(
                        minWidth: idx == 0 ? 260 : 160,
                        maxWidth: idx == 0 ? .infinity : nil,
                        alignment: idx == 0 ? .leading : .trailing
                    )
            }
        }
    }

    private func detailDisclosureLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func formatCurrency(_ value: Double, currency: String, decimals: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = decimals == 0 ? 0 : decimals
        formatter.minimumFractionDigits = decimals == 0 ? 0 : decimals
        formatter.locale = Locale(identifier: "de_CH")
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency) \(value)"
    }

    private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private func formatPercentage(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func formatCryptoQuantity(_ value: Double) -> String {
        if abs(value) >= 1 {
            return String(format: "%.3f", value)
        }
        return String(format: "%.6f", value)
    }

    private func percentageShare(of part: Double, total: Double) -> Double {
        guard total > 0 else { return 0 }
        return (part / total) * 100
    }

    private func currencyColor(for currency: String) -> Color {
        switch currency.uppercased() {
        case "CHF": return .blue
        case "USD": return .green
        case "EUR": return .orange
        case "GBP": return .purple
        default: return .accentColor
        }
    }

    private func clampedPercentage(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

// MARK: - Supporting views

private struct ReportSectionCard<Header: View, Content: View>: View {
    let letter: String
    let header: Header
    let content: Content

    init(letter: String, @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.letter = letter
        self.header = header()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(letter)
                    .font(.title2.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(.systemGray6)))
                header
            }
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

private struct AssetClassSubClassSheet: View {
    let breakdown: AssetManagementReportSummary.AssetClassBreakdown
    let baseCurrency: String
    let formatCurrency: (Double, String, Int) -> String
    let formatNumber: (Double, Int) -> String

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Subclasses")) {
                    ForEach(subclassRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.name)
                                Spacer()
                                Text(formatCurrency(row.value, baseCurrency, 0))
                                    .font(.subheadline.monospacedDigit())
                            }
                            Text("\(row.positions.count) positions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Positions")) {
                    ForEach(breakdown.positions) { position in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(position.instrumentName)
                                Spacer()
                                Text(formatCurrency(position.baseValue, baseCurrency, 0))
                                    .font(.subheadline.monospacedDigit())
                            }
                            Text("\(position.assetSubClass) • \(position.accountName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(formatNumber(position.quantity, 2)) @ \(position.currency)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(breakdown.name)
        }
    }

    private var subclassRows: [SubclassRow] {
        let grouped = Dictionary(grouping: breakdown.positions, by: \.assetSubClass)
        return grouped.map { key, positions in
            let total = positions.reduce(0) { $0 + $1.baseValue }
            return SubclassRow(id: key, name: key, value: total, positions: positions)
        }.sorted { $0.value > $1.value }
    }

    private struct SubclassRow: Identifiable {
        let id: String
        let name: String
        let value: Double
        let positions: [AssetManagementReportSummary.AssetClassPosition]
    }
}

// MARK: - ViewModel + Summary

struct AssetManagementReportSummary {
    struct CashBreakdown: Identifiable {
        let id: Int
        let accountName: String
        let institutionName: String
        let currency: String
        let localAmount: Double
        let baseAmount: Double
    }

    struct CryptoHolding: Identifiable {
        let id: Int
        let instrumentName: String
        let currency: String
        let totalQuantity: Double
        let baseValue: Double
    }

    struct NearCashHolding: Identifiable {
        let id: Int
        let name: String
        let accountName: String
        let category: String
        let currency: String
        let localValue: Double
        let baseValue: Double
    }

    struct AssetClassPosition: Identifiable {
        let id: Int
        let instrumentName: String
        let accountName: String
        let assetSubClass: String
        let currency: String
        let quantity: Double
        let localValue: Double
        let baseValue: Double
    }

    struct AssetClassBreakdown: Identifiable {
        let id: String
        let code: String?
        let name: String
        let baseValue: Double
        let percentage: Double
        let positions: [AssetClassPosition]

        var displayColor: Color {
            switch code?.uppercased() {
            case "EQ": return .blue
            case "FI": return .green
            case "ALT": return .orange
            default: return .accentColor
            }
        }
    }

    struct CurrencyAllocation: Identifiable {
        let id: String
        let currency: String
        let baseValue: Double
        let percentage: Double
    }

    struct CustodyInstitutionSummary: Identifiable {
        struct AccountBreakdown: Identifiable {
            let id: String
            let name: String
            let totalBaseValue: Double
            let positions: [AssetClassPosition]
        }

        let id: String
        let displayName: String
        let totalBaseValue: Double
        let accounts: [AccountBreakdown]
    }

    var reportDate: Date
    var baseCurrency: String
    var totalCashBase: Double
    var totalNearCashBase: Double
    var totalPortfolioBase: Double
    var totalCryptoBase: Double
    var totalTrackedCustodyBase: Double
    var cashBreakdown: [CashBreakdown]
    var nearCashHoldings: [NearCashHolding]
    var cryptoHoldings: [CryptoHolding]
    var currencyAllocations: [CurrencyAllocation]
    var assetClassBreakdown: [AssetClassBreakdown]
    var custodySummaries: [CustodyInstitutionSummary]

    static func empty(baseCurrency: String = "CHF", reportDate: Date = Date()) -> AssetManagementReportSummary {
        AssetManagementReportSummary(
            reportDate: reportDate,
            baseCurrency: baseCurrency,
            totalCashBase: 0,
            totalNearCashBase: 0,
            totalPortfolioBase: 0,
            totalCryptoBase: 0,
            totalTrackedCustodyBase: 0,
            cashBreakdown: [],
            nearCashHoldings: [],
            cryptoHoldings: [],
            currencyAllocations: [],
            assetClassBreakdown: [],
            custodySummaries: []
        )
    }

    var hasData: Bool {
        !cashBreakdown.isEmpty ||
        !nearCashHoldings.isEmpty ||
        !cryptoHoldings.isEmpty ||
        !currencyAllocations.isEmpty ||
        !assetClassBreakdown.isEmpty ||
        custodySummaries.contains { !$0.accounts.isEmpty }
    }
}

final class AssetManagementReportViewModel: ObservableObject {
    private enum CustodyInstitution: String, CaseIterable {
        case zkb = "ZKB"
        case ubs = "UBS"

        var displayName: String {
            switch self {
            case .zkb: return "Zürcher Kantonalbank"
            case .ubs: return "UBS (Credit-Suisse)"
            }
        }

        static func match(from institutionName: String) -> CustodyInstitution? {
            let normalized = institutionName
                .folding(options: .diacriticInsensitive, locale: .current)
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "’", with: "'")
                .lowercased()
            if normalized.contains("zkb") || normalized.contains("kantonalbank") {
                return .zkb
            }
            if normalized.contains("ubs") || (normalized.contains("credit") && normalized.contains("suisse")) {
                return .ubs
            }
            return nil
        }
    }

    private let nearCashSubClassCodes: Set<String> = ["GOV_BOND", "CORP_BOND", "MM_INST", "BOND_ETF", "BOND_FUND", "STRUCTURED"]
    @Published private(set) var summary: AssetManagementReportSummary = .empty()
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load(using dbManager: DatabaseManager) {
        if isLoading { return }
        let baseCurrency = normalizedBaseCurrency(dbManager.baseCurrency)
        let reportDate = dbManager.asOfDate
        isLoading = true
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let summary = self.composeSummary(dbManager: dbManager, baseCurrency: baseCurrency, reportDate: reportDate)
            DispatchQueue.main.async {
                self.summary = summary
                self.isLoading = false
                self.errorMessage = summary.hasData ? nil : "No holdings or cash balances available for reporting."
            }
        }
    }

    private func composeSummary(dbManager: DatabaseManager, baseCurrency: String, reportDate: Date) -> AssetManagementReportSummary {
        var summary = AssetManagementReportSummary.empty(baseCurrency: baseCurrency, reportDate: reportDate)
        let positions = dbManager.fetchPositionReportsSafe()
        var rateCache: [String: Double] = ["CHF": 1.0]
        var currencyTotals: [String: Double] = [:]
        var assetClassTotals: [String: (code: String?, name: String, value: Double, positions: [AssetManagementReportSummary.AssetClassPosition])] = [:]
        var cryptoAggregates: [Int: (instrumentName: String, currency: String, totalQuantity: Double, baseValue: Double)] = [:]
        var custodyAggregates: [CustodyInstitution: (totalBaseValue: Double, accounts: [String: (id: String, name: String, totalBaseValue: Double, positions: [AssetManagementReportSummary.AssetClassPosition])])] = [:]

        func convertToBase(_ value: Double, currency: String) -> Double? {
            let code = currency.uppercased()
            if baseCurrency == code { return value }

            if let cached = rateCache[code] {
                return baseCurrency == "CHF" ? value * cached : (rateCache[baseCurrency].map { value * cached / $0 })
            }
            guard let rate = dbManager.latestRateToChf(currencyCode: code)?.rate else { return nil }
            rateCache[code] = rate
            if baseCurrency == "CHF" { return value * rate }
            guard let baseRate = rateCache[baseCurrency] ?? dbManager.latestRateToChf(currencyCode: baseCurrency)?.rate else { return nil }
            rateCache[baseCurrency] = baseRate
            return value * rate / baseRate
        }

        for position in positions {
            guard let instrumentId = position.instrumentId,
                  let latest = dbManager.getLatestPrice(instrumentId: instrumentId)
            else { continue }
            let localValue = position.quantity * latest.price
            guard abs(localValue) > 0.01 else { continue }
            guard let baseValue = convertToBase(localValue, currency: latest.currency) else { continue }

            summary.totalPortfolioBase += baseValue
            currencyTotals[position.instrumentCurrency.uppercased(), default: 0] += baseValue

            let entryPosition = AssetManagementReportSummary.AssetClassPosition(
                id: position.id,
                instrumentName: position.instrumentName,
                accountName: position.accountName,
                assetSubClass: position.assetSubClass?.trimmedNonEmpty ?? "—",
                currency: latest.currency.uppercased(),
                quantity: position.quantity,
                localValue: localValue,
                baseValue: baseValue
            )

            let classCode = position.assetClassCode?.uppercased()
            let className = position.assetClass?.trimmedNonEmpty ?? "Unclassified"
            let key = classCode ?? className
            var aggregate = assetClassTotals[key] ?? (code: classCode, name: className, value: 0, positions: [])
            aggregate.value += baseValue
            aggregate.positions.append(entryPosition)
            assetClassTotals[key] = aggregate

            if isCryptoPosition(position) {
                let keyId = position.instrumentId ?? position.id
                var aggregateCrypto = cryptoAggregates[keyId] ?? (instrumentName: position.instrumentName, currency: latest.currency, totalQuantity: 0, baseValue: 0)
                aggregateCrypto.totalQuantity += position.quantity
                aggregateCrypto.baseValue += baseValue
                cryptoAggregates[keyId] = aggregateCrypto
                summary.totalCryptoBase += baseValue
            }

            if isCashPosition(subClass: position.assetSubClass, code: position.assetSubClassCode) {
                summary.cashBreakdown.append(
                    .init(
                        id: position.id,
                        accountName: position.accountName,
                        institutionName: position.institutionName,
                        currency: latest.currency.uppercased(),
                        localAmount: localValue,
                        baseAmount: baseValue
                    )
                )
                summary.totalCashBase += baseValue
            } else if isNearCash(subClassCode: position.assetSubClassCode) {
                summary.nearCashHoldings.append(
                    .init(
                        id: position.id,
                        name: position.instrumentName,
                        accountName: position.accountName,
                        category: position.assetClass ?? "Near Cash",
                        currency: latest.currency.uppercased(),
                        localValue: localValue,
                        baseValue: baseValue
                    )
                )
                summary.totalNearCashBase += baseValue
            }

            if let institution = CustodyInstitution.match(from: position.institutionName) {
                var institutionAggregate = custodyAggregates[institution] ?? (totalBaseValue: 0, accounts: [:])
                let accountKey = normalizedAccountIdentifier(position.accountName)
                var accountAggregate = institutionAggregate.accounts[accountKey] ?? (id: accountKey, name: position.accountName, totalBaseValue: 0, positions: [])
                accountAggregate.totalBaseValue += baseValue
                accountAggregate.positions.append(entryPosition)
                institutionAggregate.accounts[accountKey] = accountAggregate
                institutionAggregate.totalBaseValue += baseValue
                custodyAggregates[institution] = institutionAggregate
                summary.totalTrackedCustodyBase += baseValue
            }
        }

        summary.cashBreakdown.sort { $0.baseAmount > $1.baseAmount }
        summary.nearCashHoldings.sort { $0.baseValue > $1.baseValue }

        summary.cryptoHoldings = cryptoAggregates.values
            .map {
                AssetManagementReportSummary.CryptoHolding(
                    id: $0.instrumentName.hashValue,
                    instrumentName: $0.instrumentName,
                    currency: $0.currency,
                    totalQuantity: $0.totalQuantity,
                    baseValue: $0.baseValue
                )
            }
            .sorted { $0.baseValue > $1.baseValue }

        let totalPortfolioBase = summary.totalPortfolioBase
        summary.currencyAllocations = currencyTotals
            .map { AssetManagementReportSummary.CurrencyAllocation(id: $0.key, currency: $0.key, baseValue: $0.value, percentage: totalPortfolioBase > 0 ? ($0.value / totalPortfolioBase) * 100 : 0) }
            .sorted { $0.baseValue > $1.baseValue }

        summary.assetClassBreakdown = assetClassTotals.values
            .map { aggregate in
                AssetManagementReportSummary.AssetClassBreakdown(
                    id: aggregate.code ?? aggregate.name,
                    code: aggregate.code,
                    name: aggregate.name,
                    baseValue: aggregate.value,
                    percentage: totalPortfolioBase > 0 ? (aggregate.value / totalPortfolioBase) * 100 : 0,
                    positions: aggregate.positions.sorted { $0.baseValue > $1.baseValue }
                )
            }
            .sorted { $0.baseValue > $1.baseValue }

        summary.custodySummaries = CustodyInstitution.allCases.map { institution in
            let aggregate = custodyAggregates[institution]
            let accounts = aggregate?.accounts.values
                .sorted { $0.totalBaseValue > $1.totalBaseValue }
                .map {
                    AssetManagementReportSummary.CustodyInstitutionSummary.AccountBreakdown(
                        id: "\(institution.rawValue)_\($0.id)",
                        name: $0.name,
                        totalBaseValue: $0.totalBaseValue,
                        positions: $0.positions.sorted { $0.baseValue > $1.baseValue }
                    )
                } ?? []
            return AssetManagementReportSummary.CustodyInstitutionSummary(
                id: institution.rawValue,
                displayName: institution.displayName,
                totalBaseValue: aggregate?.totalBaseValue ?? 0,
                accounts: accounts
            )
        }

        return summary
    }

    private func isCashPosition(subClass: String?, code: String?) -> Bool {
        if let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), code == "CASH" {
            return true
        }
        guard let subClass else { return false }
        return subClass.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("cash") == .orderedSame
    }

    private func isNearCash(subClassCode: String?) -> Bool {
        guard let code = subClassCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else {
            return false
        }
        return nearCashSubClassCodes.contains(code)
    }

    private func isCryptoPosition(_ position: PositionReportData) -> Bool {
        if let classCode = position.assetClassCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
           classCode.contains("CRYP") {
            return true
        }
        if let subClassCode = position.assetSubClassCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
           subClassCode.contains("CRYP") {
            return true
        }
        if let className = position.assetClass?.lowercased(), className.contains("crypto") {
            return true
        }
        if let subClassName = position.assetSubClass?.lowercased(), subClassName.contains("crypto") {
            return true
        }
        return false
    }

    private func normalizedAccountIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func normalizedBaseCurrency(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercased = trimmed.isEmpty ? "CHF" : trimmed.uppercased()
        return uppercased
    }
}

private extension Optional where Wrapped == String {
    var trimmedNonEmpty: String? {
        guard let value = self else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension DateFormatter {
    static let assetReport: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
#endif
