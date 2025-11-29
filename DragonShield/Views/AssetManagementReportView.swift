import SwiftUI
#if canImport(Charts)
    import Charts
#endif
import UniformTypeIdentifiers
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

private enum ReportPalette {
    static let background = DSColor.background
    static let surface = DSColor.surface
    static let surfaceSubtle = DSColor.surfaceSubtle
    static let border = DSColor.border
    static let accent = DSColor.accentMain
    static let textPrimary = DSColor.textPrimary
    static let textSecondary = DSColor.textSecondary
    static let shadow = Color.black.opacity(0.08)
}

private enum ReportLayout {
    static let outerPadding: CGFloat = DSLayout.spaceL
    static let sectionSpacing: CGFloat = DSLayout.spaceL
    static let cardPadding: CGFloat = DSLayout.spaceM
    static let cardCornerRadius: CGFloat = DSLayout.radiusXL
    static let cardContentSpacing: CGFloat = DSLayout.spaceS
    static let cardHeaderSpacing: CGFloat = DSLayout.spaceS
    static let letterSize: CGFloat = 28
    static let letterCornerRadius: CGFloat = DSLayout.radiusM
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowYOffset: CGFloat = 3
}

struct AssetManagementReportView: View {
    @EnvironmentObject private var dbManager: DatabaseManager
    @StateObject private var viewModel: AssetManagementReportViewModel
    @State private var showCashDetails = false
    @State private var showNearCashDetails = false
    @State private var showCurrencyDetails = false
    @State private var showAssetClassDetails = false
    @State private var showCryptoDetails = false
    @State private var showCustodyDetails = false
    @State private var expandedCustodyAccounts: Set<String> = []
    @State private var selectedAssetClass: AssetManagementReportSummary.AssetClassBreakdown?
    @State private var selectedNearCashCategoryID: String?
    @State private var isGeneratingPDF = false
    @State private var pdfExportDocument = ReportPDFDocument.empty
    @State private var isShowingPDFExporter = false
    @State private var exportErrorMessage: String?
    @State private var isShowingExportError = false

    private var summary: AssetManagementReportSummary { viewModel.summary }
    private var sortedAssetClassBreakdown: [AssetManagementReportSummary.AssetClassBreakdown] {
        summary.assetClassBreakdown.sorted { $0.baseValue > $1.baseValue }
    }

    private var custodySummaryCards: [CustodySummaryCard] {
        let defaults: [(id: String, title: String)] = [
            (id: "ZKB", title: "Zürcher Kantonalbank"),
            (id: "UBS", title: "UBS (Credit-Suisse)"),
        ]
        let totals = Dictionary(uniqueKeysWithValues: summary.custodySummaries.map { ($0.id, $0.totalBaseValue) })
        return defaults.map { definition in
            CustodySummaryCard(
                id: definition.id,
                title: definition.title,
                amount: totals[definition.id] ?? 0
            )
        }
    }

    private var custodyHoldings: [AssetManagementReportSummary.CustodyInstitutionSummary] {
        summary.custodySummaries.filter { !$0.accounts.isEmpty }
    }

    private func filteredNearCashHoldings(for categoryID: String?) -> [AssetManagementReportSummary.NearCashHolding] {
        guard let categoryID else {
            return summary.nearCashHoldings
        }
        let holdings = summary.nearCashHoldings.filter { $0.category == categoryID }
        return holdings.isEmpty ? summary.nearCashHoldings : holdings
    }

    init(viewModel: AssetManagementReportViewModel = AssetManagementReportViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @ViewBuilder
    private func reportContent(expandedAll: Bool, includePrintButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: ReportLayout.sectionSpacing) {
            header(includePrintButton: includePrintButton)
            if viewModel.isLoading {
                loadingState
            } else {
                cashSection(expandedAll: expandedAll)
                nearCashSection(expandedAll: expandedAll)
                currencySection(expandedAll: expandedAll)
                assetClassSection(expandedAll: expandedAll)
                cryptoSection(expandedAll: expandedAll)
                custodySection(expandedAll: expandedAll)
            }
            if let message = viewModel.errorMessage {
                placeholder(message)
            }
        }
        .padding(ReportLayout.outerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var printableReportView: some View {
        reportContent(expandedAll: true, includePrintButton: false)
            .background(ReportPalette.surface)
    }

    private var pdfDefaultFileName: String {
        let dateComponent = DateFormatter.assetReportFileSafe.string(from: summary.reportDate)
        return "Asset-Management-Report-\(dateComponent)"
    }

    @available(macOS 13.0, iOS 16.0, *)
    private func renderPDFData<Content: View>(from view: Content) -> Data? {
        let renderer = ImageRenderer(content: view)
        #if os(macOS)
            renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        #else
            renderer.scale = UIScreen.main.scale
        #endif
        guard let cgImage = renderer.cgImage else { return nil }
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            return nil
        }
        context.beginPDFPage(nil)
        context.draw(cgImage, in: mediaBox)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    @MainActor
    private func exportReportAsPDF() async {
        guard summary.hasData else {
            presentExportError("Nothing to print yet. Refresh the report and try again.")
            return
        }
        guard !isGeneratingPDF else { return }

        #if os(macOS)
            guard #available(macOS 13.0, *) else {
                presentExportError("Printing requires macOS 13 or newer.")
                return
            }
        #else
            guard #available(iOS 16.0, macCatalyst 16.0, *) else {
                presentExportError("Printing requires iOS/macCatalyst 16 or newer.")
                return
            }
        #endif

        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        if #available(macOS 13.0, iOS 16.0, *) {
            if let data = renderPDFData(from: printableReportView) {
                pdfExportDocument = ReportPDFDocument(data: data, suggestedFilename: pdfDefaultFileName)
                isShowingPDFExporter = true
            } else {
                presentExportError("Unable to render the report to PDF.")
            }
        }
    }

    @MainActor
    private func handleFileExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            exportErrorMessage = nil
        case let .failure(error):
            presentExportError("Failed to save the PDF: \(error.localizedDescription)")
        }
        pdfExportDocument = .empty
    }

    private func presentExportError(_ message: String) {
        exportErrorMessage = message
        isShowingExportError = true
        pdfExportDocument = .empty
    }

    var body: some View {
        ScrollView {
            reportContent(expandedAll: false, includePrintButton: true)
        }
        .background(ReportPalette.background.ignoresSafeArea())
        .navigationTitle("Asset Management Report")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.load(using: dbManager)
                } label: {
                    Label("Refresh Report", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("Recompute the report with the latest portfolio data.")
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
        .fileExporter(
            isPresented: $isShowingPDFExporter,
            document: pdfExportDocument,
            contentType: .pdf,
            defaultFilename: pdfExportDocument.suggestedFilename,
            onCompletion: handleFileExportResult
        )
        .alert("Print Failed", isPresented: $isShowingExportError, presenting: exportErrorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private func header(includePrintButton: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DSLayout.spaceM) {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                Text("Asset Management Report")
                    .font(.ds.headerLarge)
                    .foregroundColor(ReportPalette.textPrimary)
                HStack(spacing: DSLayout.spaceS) {
                    Text("As of \(reportDateText)")
                        .font(.ds.bodySmall)
                        .foregroundColor(ReportPalette.textSecondary)
                    if includePrintButton {
                        Button {
                            Task { await exportReportAsPDF() }
                        } label: {
                            Label(isGeneratingPDF ? "Preparing…" : "Print", systemImage: "printer")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                        .disabled(isGeneratingPDF || viewModel.isLoading || !summary.hasData)
                        .help("Create a PDF copy of the current report.")
                    }
                }
            }
            Spacer()
            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(ReportPalette.accent)
                Text(currentDateText)
                    .font(.ds.body)
                    .foregroundColor(ReportPalette.textPrimary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: DSLayout.radiusL)
                    .fill(ReportPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSLayout.radiusL)
                            .stroke(ReportPalette.border, lineWidth: 1)
                    )
            )
        }
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
            RoundedRectangle(cornerRadius: DSLayout.radiusXL)
                .fill(ReportPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: DSLayout.radiusXL).stroke(ReportPalette.border, lineWidth: 1))
        )
    }

    private func cashSection(expandedAll: Bool) -> some View {
        ReportSectionCard(
            letter: "A",
            header: {
                sectionHeaderWithSummary(
                    title: Text("How much ") + highlight("cash") + Text(" do I have?"),
                    summaryTitle: "Total cash",
                    amount: summary.totalCashBase,
                    currency: summary.baseCurrency
                )
            }
        ) {
            if summary.cashBreakdown.isEmpty {
                placeholder("No cash accounts matched the configured filters.")
            } else {
                let disclosure = DisclosureGroup(
                    isExpanded: expandedAll ? .constant(true) : $showCashDetails
                ) {
                    cashBreakdownTable
                } label: {
                    detailDisclosureLabel("Tap for account level detail")
                }
                if expandedAll {
                    disclosure
                } else {
                    disclosure.animation(.easeInOut(duration: 0.2), value: showCashDetails)
                }
            }
        }
    }

    private var cashBreakdownTable: some View {
        VStack(spacing: 0) {
            tableHeader(
                columns: ["Account", "Local", summary.baseCurrency],
                boldColumnIndices: [2]
            )
            .padding(.bottom, 2)
            ForEach(summary.cashBreakdown) { row in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.accountName)
                                .font(.headline)
                            Text(row.institutionName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(row.currency) \(formatNumber(row.localAmount, decimals: 0))")
                            .font(.body.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                        Text(formatCurrency(row.baseAmount, currency: summary.baseCurrency))
                            .font(.body.monospacedDigit())
                            .fontWeight(.semibold)
                            .frame(width: 160, alignment: .trailing)
                    }
                    Divider()
                        .padding(.top, 1)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 4)
    }

    private func nearCashSection(expandedAll: Bool) -> some View {
        let activeCategory = expandedAll ? nil : selectedNearCashCategoryID
        let detailRows = filteredNearCashHoldings(for: activeCategory)

        return ReportSectionCard(
            letter: "B",
            header: {
                sectionHeaderWithSummary(
                    title: Text("What can I ") + highlight("convert into cash") + Text(" early?"),
                    summaryTitle: "Total near cash",
                    amount: summary.totalNearCashBase,
                    currency: summary.baseCurrency
                )
            }
        ) {
            if nearCashCategories.isEmpty {
                placeholder("No fixed income or money market holdings detected.")
            } else {
                let disclosure = DisclosureGroup(
                    isExpanded: expandedAll ? .constant(true) : $showNearCashDetails
                ) {
                    VStack(spacing: 12) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                            ForEach(nearCashCategories) { category in
                                let isSelected = activeCategory == category.id
                                Button {
                                    guard !expandedAll else { return }
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedNearCashCategoryID = isSelected ? nil : category.id
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(category.name)
                                            .font(CategoryCardStyle.titleFont)
                                            .foregroundStyle(isSelected ? Color.white : ReportPalette.textPrimary)
                                        Text(formatCurrency(category.totalBase, currency: summary.baseCurrency))
                                            .font(.footnote.monospacedDigit())
                                            .foregroundColor(isSelected ? Color.white.opacity(0.9) : .secondary)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(isSelected ? ReportPalette.accent : ReportPalette.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(isSelected ? ReportPalette.accent : ReportPalette.border, lineWidth: 1)
                                            )
                                    )
                                }
                                .disabled(expandedAll)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)

                        Divider().padding(.vertical, 8)

                        nearCashDetailTable(rows: detailRows)
                    }
                } label: {
                    detailDisclosureLabel("Tap for near-cash detail")
                }
                if expandedAll {
                    disclosure
                } else {
                    disclosure.animation(.easeInOut(duration: 0.2), value: showNearCashDetails)
                }
            }
        }
    }

    private func nearCashDetailTable(rows: [AssetManagementReportSummary.NearCashHolding]) -> some View {
        VStack(spacing: 4) {
            tableHeader(columns: ["Instrument", "Currency", summary.baseCurrency])
            if rows.isEmpty {
                Text("No holdings match the selected category.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(row.category) • \(row.accountName)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
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
        .padding(.top, 4)
    }

    private func currencySection(expandedAll: Bool) -> some View {
        ReportSectionCard(
            letter: "C",
            header: {
                currencyHeader
            }
        ) {
            if summary.currencyAllocations.isEmpty {
                placeholder("No currency exposure available yet.")
            } else {
                let disclosure = DisclosureGroup(
                    isExpanded: expandedAll ? .constant(true) : $showCurrencyDetails
                ) {
                    VStack(alignment: .leading, spacing: ReportRowLayout.stackSpacing) {
                        ForEach(summary.currencyAllocations) { allocation in
                            VStack(alignment: .leading, spacing: ReportRowLayout.rowSpacing) {
                                HStack {
                                    Text(allocation.currency)
                                        .font(.headline)
                                    Spacer()
                                    Text(formatCurrency(allocation.baseValue, currency: summary.baseCurrency))
                                        .font(.body.monospacedDigit())
                                }
                                ProgressView(value: allocation.percentage, total: 100)
                                    .tint(currencyColor(for: allocation.currency))
                                Text(String(format: "%.1f%% of invested assets", allocation.percentage))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, ReportRowLayout.rowPadding)
                        }
                    }
                } label: {
                    detailDisclosureLabel("Tap for currency exposure detail")
                }
                if expandedAll {
                    disclosure
                } else {
                    disclosure.animation(.easeInOut(duration: 0.2), value: showCurrencyDetails)
                }
            }
        }
    }

    private var currencyHeader: some View {
        HStack(alignment: .center, spacing: 28) {
            sectionTitleView(Text("In which ") + highlight("currencies") + Text(" am I allocated?"))
                .layoutPriority(1)
            Spacer(minLength: 12)
            if !summary.currencyAllocations.isEmpty {
                CurrencyAllocationBarView(
                    allocations: summary.currencyAllocations,
                    colorProvider: { currencyColor(for: $0) }
                )
                .frame(height: CurrencyBarLayout.headerHeight)
                .frame(minWidth: CurrencyBarLayout.minWidth, maxWidth: CurrencyBarLayout.maxWidth)
                .padding(.leading, 8)
                .opacity(0.95)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    private func assetClassSection(expandedAll: Bool) -> some View {
        ReportSectionCard(
            letter: "D",
            header: {
                assetClassHeader
            }
        ) {
            if sortedAssetClassBreakdown.isEmpty {
                placeholder("No asset class data available yet.")
            } else {
                let disclosure = DisclosureGroup(
                    isExpanded: expandedAll ? .constant(true) : $showAssetClassDetails
                ) {
                    VStack(alignment: .leading, spacing: 18) {
                        AssetClassStackedBarView(
                            breakdown: sortedAssetClassBreakdown,
                            onSegmentDoubleTap: { selectedAssetClass = $0 }
                        )
                        .frame(height: AssetClassBarLayout.primaryHeight)

                        Text("Double-click a segment or row to see the subclass breakdown, then double-click a subclass for position details.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(sortedAssetClassBreakdown) { item in
                                Button {
                                    selectedAssetClass = item
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 10) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(item.displayColor)
                                                .frame(width: 12, height: 12)
                                            Text(item.name)
                                                .font(.headline)
                                            Spacer()
                                            Text(formatCurrency(item.baseValue, currency: summary.baseCurrency))
                                                .font(.subheadline.monospacedDigit())
                                        }
                                        HStack {
                                            ProgressView(value: item.percentage, total: 100)
                                                .tint(item.displayColor)
                                            Text(String(format: "%.1f%%", item.percentage))
                                                .font(.caption.monospacedDigit())
                                                .foregroundColor(.secondary)
                                                .frame(width: 60, alignment: .trailing)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .simultaneousGesture(
                                    TapGesture(count: 2)
                                        .onEnded { selectedAssetClass = item }
                                )
                            }
                        }
                    }
                } label: {
                    detailDisclosureLabel("Tap for asset class detail")
                }
                if expandedAll {
                    disclosure
                } else {
                    disclosure.animation(.easeInOut(duration: 0.2), value: showAssetClassDetails)
                }
            }
        }
    }

    private func cryptoSection(expandedAll: Bool) -> some View {
        ReportSectionCard(
            letter: "E",
            header: {
                sectionHeaderWithSummary(
                    title: Text("What is my ") + highlight("crypto currency") + Text(" exposure?"),
                    summaryTitle: "Total crypto",
                    amount: summary.totalCryptoBase,
                    currency: summary.baseCurrency
                )
            }
        ) {
            if summary.cryptoHoldings.isEmpty {
                placeholder("No crypto holdings detected.")
            } else {
                let disclosure = DisclosureGroup(
                    isExpanded: expandedAll ? .constant(true) : $showCryptoDetails
                ) {
                    cryptoBreakdownTable
                } label: {
                    detailDisclosureLabel("Tap for crypto detail")
                }
                if expandedAll {
                    disclosure
                } else {
                    disclosure.animation(.easeInOut(duration: 0.2), value: showCryptoDetails)
                }
            }
        }
    }

    private var cryptoBreakdownTable: some View {
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
                            .frame(width: 160, alignment: .trailing)
                        Text(formatCurrency(row.baseValue, currency: summary.baseCurrency))
                            .font(.body.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                        Text(formatPercentage(percentageShare(of: row.baseValue, total: summary.totalCryptoBase)))
                            .font(.body.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                        Text(formatPercentage(percentageShare(of: row.baseValue, total: summary.totalPortfolioBase)))
                            .font(.body.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                    }
                    Divider()
                        .padding(.top, 1)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 4)
    }

    private func custodySection(expandedAll: Bool) -> some View {
        ReportSectionCard(
            letter: "F",
            header: {
                sectionHeaderWithSummary(
                    title: Text("Custody exposure: ") + highlight("ZKB") + Text(" vs ") + highlight("UBS"),
                    summaryTitle: "Tracked custody",
                    amount: summary.totalTrackedCustodyBase,
                    currency: summary.baseCurrency
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                custodySummaryGrid
                if custodyHoldings.isEmpty {
                    placeholder("No custody positions recorded for ZKB or UBS / Credit-Suisse.")
                } else {
                    let disclosure = DisclosureGroup(
                        isExpanded: expandedAll ? .constant(true) : $showCustodyDetails
                    ) {
                        custodyDetailList(expandedAll: expandedAll)
                    } label: {
                        detailDisclosureLabel("Tap for custody account detail")
                    }
                    if expandedAll {
                        disclosure
                    } else {
                        disclosure.animation(.easeInOut(duration: 0.2), value: showCustodyDetails)
                    }
                }
            }
        }
    }

    private var custodySummaryGrid: some View {
        let totalTrackedAmount = custodySummaryCards.reduce(0) { $0 + $1.amount }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(custodySummaryCards) { card in
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formatCurrency(card.amount, currency: summary.baseCurrency))
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundColor(ReportPalette.textPrimary)
                        Text(formatPercentage(percentageShare(of: card.amount, total: totalTrackedAmount)))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ReportPalette.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ReportPalette.border, lineWidth: 1)
                        )
                )
            }
        }
    }

    private func custodyDetailList(expandedAll: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(custodyHoldings) { institution in
                custodyInstitutionCard(institution, expandedAll: expandedAll)
            }
        }
        .padding(.top, 6)
    }

    private func custodyInstitutionCard(
        _ institution: AssetManagementReportSummary.CustodyInstitutionSummary,
        expandedAll: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(institution.displayName)
                    .font(.headline)
                Spacer()
                Text(formatCurrency(institution.totalBaseValue, currency: summary.baseCurrency))
                    .font(.headline.monospacedDigit())
            }
            VStack(spacing: 8) {
                ForEach(institution.accounts) { account in
                    custodyAccountBlock(account: account, expandedAll: expandedAll)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ReportPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ReportPalette.border, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func custodyAccountBlock(
        account: AssetManagementReportSummary.CustodyInstitutionSummary.AccountBreakdown,
        expandedAll: Bool
    ) -> some View {
        if expandedAll {
            VStack(alignment: .leading, spacing: 8) {
                custodyAccountHeader(account)
                custodyPositionsList(for: account)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ReportPalette.surface.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ReportPalette.border.opacity(0.7), lineWidth: 0.8)
                    )
            )
        } else {
            DisclosureGroup(
                isExpanded: bindingForCustodyAccount(account.id)
            ) {
                custodyPositionsList(for: account)
            } label: {
                custodyAccountHeader(account)
            }
            .animation(.easeInOut(duration: 0.2), value: expandedCustodyAccounts)
        }
    }

    private func custodyAccountHeader(
        _ account: AssetManagementReportSummary.CustodyInstitutionSummary.AccountBreakdown
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(account.positions.count) positions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(account.totalBaseValue, currency: summary.baseCurrency))
                .font(.subheadline.monospacedDigit())
        }
    }

    private func custodyPositionsList(
        for account: AssetManagementReportSummary.CustodyInstitutionSummary.AccountBreakdown
    ) -> some View {
        VStack(spacing: 4) {
            tableHeader(columns: ["Instrument", "Local", summary.baseCurrency], boldColumnIndices: [2])
                .padding(.bottom, 2)
            ForEach(account.positions) { position in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(position.instrumentName)
                                .font(.subheadline.weight(.semibold))
                            Text(position.assetSubClass)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(position.currency) \(formatNumber(position.localValue, decimals: 0))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                        Text(formatCurrency(position.baseValue, currency: summary.baseCurrency))
                            .font(.caption.monospacedDigit())
                            .frame(width: 160, alignment: .trailing)
                    }
                    Divider()
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 4)
    }

    private var assetClassHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            sectionTitleView(Text("In which ") + highlight("asset classes") + Text(" am I invested?"))
                .layoutPriority(1)
            Spacer(minLength: 12)
            if !sortedAssetClassBreakdown.isEmpty {
                VStack(alignment: .trailing, spacing: 6) {
                    AssetClassStackedBarView(
                        breakdown: sortedAssetClassBreakdown,
                        onSegmentDoubleTap: { selectedAssetClass = $0 }
                    )
                    .frame(height: CurrencyBarLayout.headerHeight)
                    .frame(minWidth: CurrencyBarLayout.minWidth, maxWidth: CurrencyBarLayout.maxWidth)
                    .padding(.leading, 8)
                    .opacity(0.85)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total value in \(summary.baseCurrency == "CHF" ? "CH" : summary.baseCurrency)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(summary.totalPortfolioBase, currency: summary.baseCurrency))
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .foregroundColor(ReportPalette.textPrimary)
                    }
                }
            }
        }
    }

    private func metricRow(title: String, amount: Double, currency: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .kerning(1)
                .foregroundColor(ReportPalette.textSecondary)
            Text(formatCurrency(amount, currency: currency))
                .font(.system(size: 30, weight: .regular, design: .rounded))
                .foregroundColor(ReportPalette.textPrimary)
            Text(currency)
                .font(.title3.weight(.semibold))
                .foregroundColor(ReportPalette.textSecondary)
        }
        .lineLimit(1)
    }

    private func sectionTitleView(_ text: Text) -> some View {
        text
            .font(.ds.headerMedium)
            .foregroundColor(ReportPalette.textPrimary)
            .multilineTextAlignment(.leading)
    }

    private func sectionHeaderWithSummary(
        title: Text,
        summaryTitle: String,
        amount: Double,
        currency: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            sectionTitleView(title)
                .layoutPriority(1)
            Spacer(minLength: 12)
            metricRow(title: summaryTitle, amount: amount, currency: currency)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func detailDisclosureLabel(_ title: String) -> some View {
        Label(title, systemImage: "chevron.down.circle")
            .labelStyle(.titleAndIcon)
            .font(.ds.bodySmall)
            .foregroundColor(ReportPalette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tableHeader(columns: [String], boldColumnIndices: [Int] = []) -> some View {
        let boldColumns = Set(boldColumnIndices)
        return HStack {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, title in
                let isBold = boldColumns.contains(index)
                if index == 0 {
                    Text(title.uppercased())
                        .font(.caption2)
                        .fontWeight(isBold ? .semibold : .regular)
                        .foregroundColor(ReportPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(title.uppercased())
                        .font(.caption2)
                        .fontWeight(isBold ? .semibold : .regular)
                        .foregroundColor(ReportPalette.textSecondary)
                        .frame(width: 160, alignment: .trailing)
                }
            }
        }
    }

    private func highlight(_ word: String) -> Text {
        Text(word)
            .fontWeight(.black)
            .foregroundColor(ReportPalette.accent)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(ReportPalette.textSecondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundColor(ReportPalette.border)
            )
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

    private var nearCashCategories: [CategoryAggregate] {
        let grouped = Dictionary(grouping: summary.nearCashHoldings, by: { $0.category })
        return grouped.map { key, rows in
            CategoryAggregate(id: key, name: key, totalBase: rows.reduce(0) { $0 + $1.baseValue })
        }
        .sorted { $0.totalBase > $1.totalBase }
    }

    private var reportDateText: String {
        DateFormatter.assetReportShort.string(from: summary.reportDate)
    }

    private var currentDateText: String {
        DateFormatter.assetReportShort.string(from: Date())
    }

    private func formatCurrency(_ value: Double, currency: String, decimals: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency) \(value)"
    }

    private func formatNumber(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
    }

    private func formatPercentage(_ value: Double, decimals: Int = 1) -> String {
        "\(formatNumber(value, decimals: decimals))%"
    }

    private func formatCryptoQuantity(_ value: Double) -> String {
        let magnitude = abs(value)
        let decimals: Int
        switch magnitude {
        case 100...:
            decimals = 2
        case 1...:
            decimals = 4
        case 0.01...:
            decimals = 6
        default:
            decimals = 8
        }
        return formatNumber(value, decimals: decimals)
    }

    private func percentageShare(of value: Double, total: Double) -> Double {
        guard abs(total) > 0.0001 else { return 0 }
        return (value / total) * 100
    }

    private func currencyColor(for code: String) -> Color {
        Theme.currencyColors[code.uppercased()] ?? ReportPalette.accent
    }

    private enum CategoryCardStyle {
        static let titleFont: Font = .system(size: 11, weight: .semibold, design: .rounded)
    }

    private enum ReportRowLayout {
        static let stackSpacing: CGFloat = 2
        static let rowSpacing: CGFloat = 2
        static let rowPadding: CGFloat = 1
    }

    private enum CurrencyBarLayout {
        static let headerHeight: CGFloat = 34
        static let minWidth: CGFloat = 220
        static let maxWidth: CGFloat = 420
    }

    private enum AssetClassBarLayout {
        static let primaryHeight: CGFloat = 34
    }

    private struct CurrencyAllocationBarView: View {
        let allocations: [AssetManagementReportSummary.CurrencyAllocation]
        let colorProvider: (String) -> Color

        private var displayAllocations: [AssetManagementReportSummary.CurrencyAllocation] {
            let filtered = allocations.filter { $0.percentage > 0.01 }
            return filtered.isEmpty ? allocations : filtered
        }

        var body: some View {
            GeometryReader { proxy in
                let totalWidth = max(proxy.size.width, 1)
                let totalPercentage = max(
                    displayAllocations.reduce(0) { $0 + max($1.percentage, 0) },
                    0.01
                )
                HStack(spacing: 0) {
                    ForEach(displayAllocations) { allocation in
                        CurrencyAllocationSegmentView(
                            currency: allocation.currency,
                            percentage: allocation.percentage,
                            color: colorProvider(allocation.currency),
                            width: totalWidth * CGFloat(max(allocation.percentage, 0) / totalPercentage)
                        )
                    }
                }
                .frame(width: totalWidth, height: proxy.size.height)
                .background(
                    Rectangle()
                        .fill(ReportPalette.border.opacity(0.18))
                )
                .clipShape(Rectangle())
                .overlay(
                    Rectangle()
                        .stroke(ReportPalette.border.opacity(0.5), lineWidth: 0.8)
                )
            }
        }
    }

    private struct CurrencyAllocationSegmentView: View {
        let currency: String
        let percentage: Double
        let color: Color
        let width: CGFloat

        var body: some View {
            ZStack {
                color
                VStack(spacing: 2) {
                    Text(currency)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(String(format: "%.0f%%", percentage))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .opacity(0.92)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
            }
            .frame(width: max(width, 0))
            .frame(maxHeight: .infinity)
        }
    }

    private struct CategoryAggregate: Identifiable {
        let id: String
        let name: String
        let totalBase: Double
    }

    private struct CustodySummaryCard: Identifiable {
        let id: String
        let title: String
        let amount: Double
    }
}

private struct ReportPDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [.pdf] }
    static var empty: ReportPDFDocument {
        ReportPDFDocument(data: Data(), suggestedFilename: "Asset-Management-Report")
    }

    var data: Data
    var suggestedFilename: String

    init(data: Data, suggestedFilename: String) {
        self.data = data
        self.suggestedFilename = suggestedFilename
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
        suggestedFilename = "Asset-Management-Report"
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = suggestedFilename
        return wrapper
    }
}

private struct ReportSectionCard<Header: View, Content: View>: View {
    let letter: String
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ReportLayout.cardContentSpacing) {
            HStack(alignment: .center, spacing: ReportLayout.cardHeaderSpacing) {
                Text(letter)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: ReportLayout.letterSize, height: ReportLayout.letterSize)
                    .background(
                        RoundedRectangle(cornerRadius: ReportLayout.letterCornerRadius)
                            .fill(ReportPalette.accent)
                    )
                header()
            }
            content()
        }
        .padding(ReportLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ReportLayout.cardCornerRadius)
                .fill(ReportPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ReportLayout.cardCornerRadius)
                        .stroke(ReportPalette.border, lineWidth: 1)
                )
                .shadow(
                    color: ReportPalette.shadow.opacity(0.12),
                    radius: ReportLayout.cardShadowRadius,
                    x: 0,
                    y: ReportLayout.cardShadowYOffset
                )
        )
    }
}

private extension DateFormatter {
    static let assetReportShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yy"
        return formatter
    }()

    static let assetReportFileSafe: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

private struct PositionsDetailContext: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let totalValue: Double
    let percentageDescription: String
    let positions: [AssetManagementReportSummary.AssetClassPosition]
}

private enum DetailListLayout {
    static let listSpacing: CGFloat = 6
    static let rowStackSpacing: CGFloat = 4
    static let metadataSpacing: CGFloat = 8
    static let rowPaddingVertical: CGFloat = 8
    static let rowPaddingHorizontal: CGFloat = 12
    static let rowCornerRadius: CGFloat = 10
}

private struct AssetClassSubClassSheet: View {
    let breakdown: AssetManagementReportSummary.AssetClassBreakdown
    let baseCurrency: String
    let formatCurrency: (Double, String, Int) -> String
    let formatNumber: (Double, Int) -> String

    @Environment(\.dismiss) private var dismiss
    @State private var selectedContext: PositionsDetailContext?

    private var subClassRows: [SubClassRow] {
        let grouped = Dictionary(grouping: breakdown.positions, by: { $0.assetSubClass })
        return grouped.map { key, positions in
            let totalBase = positions.reduce(0) { $0 + $1.baseValue }
            let percentageOfClass = breakdown.baseValue != 0 ? (totalBase / breakdown.baseValue) * 100 : 0
            let percentageOfPortfolio = breakdown.percentage * (percentageOfClass / 100)
            return SubClassRow(
                name: key,
                totalBase: totalBase,
                percentageOfClass: percentageOfClass,
                percentageOfPortfolio: percentageOfPortfolio,
                positions: positions.sorted { $0.baseValue > $1.baseValue }
            )
        }
        .sorted { $0.totalBase > $1.totalBase }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(breakdown.name)
                        .font(.title2.weight(.bold))
                    Text(String(format: "%.1f%% of portfolio", breakdown.percentage))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Button("Exit") {
                        dismiss()
                    }
                    .buttonStyle(ExitButtonStyle())
                    Text(formatCurrency(breakdown.baseValue, baseCurrency, 0))
                        .font(.title3.monospacedDigit())
                    Button("View detailed positions") {
                        selectedContext = contextForClass()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }

            Divider()

            if subClassRows.isEmpty {
                Text("No subclass detail available for this asset class.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                Text("Double-click a subclass to inspect all of its positions.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(spacing: DetailListLayout.listSpacing) {
                        ForEach(subClassRows) { row in
                            VStack(alignment: .leading, spacing: DetailListLayout.rowStackSpacing) {
                                HStack {
                                    Text(row.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(formatCurrency(row.totalBase, baseCurrency, 0))
                                        .font(.subheadline.monospacedDigit())
                                }
                                HStack(spacing: DetailListLayout.metadataSpacing) {
                                    Text(String(format: "%.1f%% of %@", row.percentageOfClass, breakdown.name))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f%% of portfolio", row.percentageOfPortfolio))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, DetailListLayout.rowPaddingVertical)
                            .padding(.horizontal, DetailListLayout.rowPaddingHorizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: DetailListLayout.rowCornerRadius)
                                    .fill(ReportPalette.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DetailListLayout.rowCornerRadius)
                                            .stroke(ReportPalette.border, lineWidth: 1)
                                    )
                            )
                            .contentShape(RoundedRectangle(cornerRadius: DetailListLayout.rowCornerRadius))
                            .onTapGesture(count: 2) {
                                selectedContext = context(for: row)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 460)
        .sheet(item: $selectedContext) { context in
            PositionsDetailSheet(
                context: context,
                baseCurrency: baseCurrency,
                formatCurrency: formatCurrency,
                formatNumber: formatNumber
            )
        }
    }

    private func context(for row: SubClassRow) -> PositionsDetailContext {
        PositionsDetailContext(
            title: row.name,
            subtitle: breakdown.name,
            totalValue: row.totalBase,
            percentageDescription: String(
                format: "%.1f%% of %@ • %.1f%% of portfolio",
                row.percentageOfClass,
                breakdown.name,
                row.percentageOfPortfolio
            ),
            positions: row.positions
        )
    }

    private func contextForClass() -> PositionsDetailContext {
        PositionsDetailContext(
            title: breakdown.name,
            subtitle: nil,
            totalValue: breakdown.baseValue,
            percentageDescription: String(format: "%.1f%% of portfolio", breakdown.percentage),
            positions: breakdown.positions
        )
    }

    private struct SubClassRow: Identifiable {
        let id = UUID()
        let name: String
        let totalBase: Double
        let percentageOfClass: Double
        let percentageOfPortfolio: Double
        let positions: [AssetManagementReportSummary.AssetClassPosition]
    }
}

private struct PositionsDetailSheet: View {
    let context: PositionsDetailContext
    let baseCurrency: String
    let formatCurrency: (Double, String, Int) -> String
    let formatNumber: (Double, Int) -> String

    @Environment(\.dismiss) private var dismiss
    private var sortedPositions: [AssetManagementReportSummary.AssetClassPosition] {
        context.positions.sorted { $0.baseValue > $1.baseValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.title)
                        .font(.title2.weight(.bold))
                    if let subtitle = context.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(context.percentageDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Button("Exit") {
                        dismiss()
                    }
                    .buttonStyle(ExitButtonStyle())
                    Text(formatCurrency(context.totalValue, baseCurrency, 0))
                        .font(.title3.monospacedDigit())
                }
            }

            Divider()

            ScrollView {
                VStack(spacing: DetailListLayout.listSpacing) {
                    ForEach(sortedPositions) { position in
                        VStack(alignment: .leading, spacing: DetailListLayout.rowStackSpacing) {
                            HStack {
                                Text(position.instrumentName)
                                    .font(.headline)
                                Spacer()
                                Text(formatCurrency(position.baseValue, baseCurrency, 0))
                                    .font(.subheadline.monospacedDigit())
                            }
                            Text("\(position.assetSubClass) • \(position.accountName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: DetailListLayout.metadataSpacing) {
                                Text("Quantity: \(formatNumber(position.quantity, 2))")
                                    .font(.caption)
                                Spacer()
                                Text("Local: \(formatCurrency(position.localValue, position.currency, 0))")
                                    .font(.caption.monospacedDigit())
                            }
                        }
                        .padding(.vertical, DetailListLayout.rowPaddingVertical)
                        .padding(.horizontal, DetailListLayout.rowPaddingHorizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: DetailListLayout.rowCornerRadius)
                                .fill(ReportPalette.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DetailListLayout.rowCornerRadius)
                                        .stroke(ReportPalette.border, lineWidth: 1)
                                )
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
    }
}

private struct ExitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .foregroundColor(ReportPalette.accent)
            .background(
                Rectangle()
                    .fill(configuration.isPressed ? ReportPalette.accent.opacity(0.08) : Color.clear)
            )
            .overlay(
                Rectangle()
                    .stroke(ReportPalette.accent, lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

private struct AssetClassStackedBarView: View {
    let breakdown: [AssetManagementReportSummary.AssetClassBreakdown]
    let onSegmentDoubleTap: (AssetManagementReportSummary.AssetClassBreakdown) -> Void

    private var totalValue: Double {
        breakdown.reduce(0) { $0 + max($1.baseValue, 0) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(ReportPalette.surface)
                    .overlay(Rectangle().stroke(ReportPalette.border, lineWidth: 1))

                if totalValue > 0 {
                    HStack(spacing: 0) {
                        ForEach(breakdown) { item in
                            let ratio = max(item.baseValue, 0) / totalValue
                            Rectangle()
                                .fill(item.displayColor)
                                .frame(width: max(CGFloat(ratio) * geo.size.width, ratio > 0 ? 2 : 0))
                                .overlay(alignment: .center) {
                                    if ratio > 0.09 {
                                        VStack(spacing: 2) {
                                            Text(item.name)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundColor(.white)
                                            Text(String(format: "%.0f%%", item.percentage))
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.85))
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    onSegmentDoubleTap(item)
                                }
                                .accessibilityLabel("\(item.name) \(String(format: "%.1f%%", item.percentage))")
                        }
                    }
                    .clipShape(Rectangle())
                } else {
                    Text("No invested assets yet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private extension AssetManagementReportSummary.AssetClassBreakdown {
    var displayColor: Color {
        if let code = code?.uppercased(), let classCode = AssetClassCode(rawValue: code) {
            return Theme.assetClassColors[classCode] ?? ReportPalette.accent
        }
        return ReportPalette.accent
    }
}

#if DEBUG
    struct AssetManagementReportView_Previews: PreviewProvider {
        static var previews: some View {
            let vm = AssetManagementReportViewModel()
            vm.applyPreviewData(.preview)
            return AssetManagementReportView(viewModel: vm)
                .environmentObject(DatabaseManager())
                .frame(width: 900)
        }
    }
#endif
