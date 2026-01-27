import Charts
import SwiftUI

struct RiskReportView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var preferences: AppPreferences
    @Environment(\.openWindow) private var openWindow

    @State private var positions: [PositionReportData] = []
    @State private var overrides: [DatabaseManager.RiskOverrideRow] = []
    @State private var riskLookup: [Int: (sri: Int, liquidity: Int)] = [:]
    @State private var valueLookup: [Int: Double] = [:]
    @State private var baseCurrency: String = "CHF"
    @State private var expandedSRI: Set<Int> = []
    @State private var expandedLiquidity: Set<Int> = []
    @State private var sortSRIByCount: Bool = false
    @State private var sortAllocationByValue: Bool = true
    @State private var sriMetric: SRIMetric = .value
    @State private var heatmapMode: HeatmapMode = .portfolio

    private let riskColors: [Color] = [
        Color.green.opacity(0.7),
        Color.green,
        Color.yellow,
        Color.orange,
        Color.orange.opacity(0.85),
        Color.red.opacity(0.9),
        Color.red
    ]

    private var heroColumns: [GridItem] { [GridItem(.adaptive(minimum: 240), spacing: 12, alignment: .topLeading)] }

    private var sriBuckets: [(value: Int, label: String)] {
        [
            (1, "SRI 1"), (2, "SRI 2"), (3, "SRI 3"), (4, "SRI 4"),
            (5, "SRI 5"), (6, "SRI 6"), (7, "SRI 7")
        ]
    }

    private var liquidityBuckets: [(value: Int, label: String)] {
        [(0, "Liquid"), (1, "Restricted"), (2, "Illiquid")]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                heroStrip
                heatmapSection
                sriDistributionCard
                liquidityCard
                allocationCard
                overridesPanel
            }
            .padding()
        }
        .navigationTitle("Risk Report")
        .onAppear(perform: loadData)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Risk Report")
                .font(.largeTitle).bold()
            Text("Visual drill-down of SRI, liquidity, exposures, and override governance.")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Hero strip

    private var heroStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: heroColumns, spacing: 12) {
                riskGaugeCard
                sriDonutCard
                liquidityDonutCard
                overridesStatusCard
            }
        }
    }

    private var riskGaugeCard: some View {
        reportCard(title: "Portfolio Risk Score", subtitle: "Weighted by position value") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(portfolioRiskScore.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.title3).bold()
                riskDeltaBadge
                Spacer()
            }
            Gauge(value: portfolioRiskScore ?? 1, in: 1 ... 7) {
                Text("SRI")
            } currentValueLabel: {
                Text(portfolioRiskScore.map { String(format: "%.1f", $0) } ?? "—")
            } minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("7")
            }
            .gaugeStyle(.accessoryLinearCapacity)
            Text("Total value \(formatCurrency(totalPortfolioValue))")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var sriDonutCard: some View {
        reportCard(title: "SRI Mix", subtitle: "Tap slices to filter lists") {
            Picker("Metric", selection: $sriMetric) {
                ForEach(SRIMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            Chart(sriDistributionData) { bucket in
                SectorMark(
                    angle: .value("Share", share(for: bucket, metric: sriMetric)),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(riskColors[max(0, bucket.bucket - 1)])
                .opacity(share(for: bucket, metric: sriMetric) > 0 ? 1 : 0.2)
            }
            .chartLegend(.hidden)
            .frame(height: 160)

            HStack(spacing: 12) {
                Text("High risk (6–7): \(highRiskPercentDisplay())")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                if let top = topBucketByMetric {
                    riskBadge(top.bucket)
                    Text(top.label)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var liquidityDonutCard: some View {
        reportCard(title: "Liquidity", subtitle: "Tier mix + illiquid share") {
            Chart(liquidityDistributionData) { bucket in
                SectorMark(
                    angle: .value("Share", liquidityShare(for: bucket)),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(bucket.color)
                .opacity(liquidityShare(for: bucket) > 0 ? 1 : 0.25)
            }
            .chartLegend(.hidden)
            .frame(height: 160)

            HStack(spacing: 8) {
                Text("Illiquid: \(illiquidPercentDisplay())")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                ForEach(liquidityDistributionData) { bucket in
                    liquidityPill(label: bucket.label, value: bucket.count)
                }
            }
        }
    }

    private var overridesStatusCard: some View {
        let counts = overrideCounts
        return reportCard(title: "Overrides", subtitle: "Active, expiring, expired") {
            HStack(spacing: 8) {
                statusPill(label: "Active", value: counts.active, tint: .blue.opacity(0.15), textColor: .blue)
                statusPill(label: "Expiring soon", value: counts.expiringSoon, tint: .orange.opacity(0.18), textColor: .orange)
                statusPill(label: "Expired", value: counts.expired, tint: .red.opacity(0.15), textColor: .red)
                Spacer()
            }
            if let next = nextOverrideExpiry {
                Text("Next expiry: \(next.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("No override expiries on file")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        reportCard(title: "Exposure Heatmap", subtitle: "Share of total value by SRI bucket") {
            if heatmapRows.isEmpty {
                Text("No positions to display.")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Picker("Heatmap mode", selection: $heatmapMode) {
                            ForEach(HeatmapMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        Spacer()
                    }
                    Text(heatmapMode.caption(baseCurrency: baseCurrency))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("Segment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 160, alignment: .leading)
                        ForEach(sriBuckets, id: \.value) { bucket in
                            Text(bucket.label)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(heatmapRows) { row in
                        HStack(spacing: 4) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.label)
                                    .font(.subheadline)
                                Text("\(formatPercent(row.totalShare)) of total")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 160, alignment: .leading)
                            ForEach(row.cells, id: \.bucket) { cell in
                                Rectangle()
                                    .fill(heatmapFill(for: cell))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(heatmapStroke(for: cell), lineWidth: cell.value > 0 ? 1.5 : 1)
                                    )
                                    .overlay(
                                        VStack(spacing: 2) {
                                            Text(formatPercent(cell.share))
                                            Text(formatCompactCurrency(cell.value))
                                        }
                                        .font(.caption2)
                                        .foregroundColor(heatmapTextColor(for: cell))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)
                                    )
                                    .overlay(alignment: .topTrailing) {
                                        Circle()
                                            .strokeBorder(heatmapStroke(for: cell), lineWidth: 1)
                                            .background(
                                                Circle().fill(cell.value > 0 ? heatmapStroke(for: cell).opacity(0.6) : Color.clear)
                                            )
                                            .frame(width: 10, height: 10)
                                            .shadow(color: heatmapStroke(for: cell).opacity(cell.value > 0 ? 0.35 : 0), radius: 2, x: 0, y: 1)
                                            .padding(6)
                                    }
                                    .frame(height: 48)
                                    .cornerRadius(6)
                            }
                        }
                        .background(DSColor.surface.opacity(0.01))
                    }
                    HStack {
                        ForEach(sriBuckets, id: \.value) { bucket in
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(riskColors[max(0, bucket.value - 1)])
                                    .frame(width: 12, height: 12)
                                Text(bucket.label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(heatmapMode.legend(baseCurrency: baseCurrency))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Detail panels

    private var sriDistributionCard: some View {
        reportCard(
            title: "SRI Distribution",
            subtitle: "Counts and value, tap to expand"
        ) {
            HStack {
                Toggle("Sort by count", isOn: $sortSRIByCount)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text(sortSRIByCount ? "Sorting by count" : "Sorting by bucket")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text("All prices in CHF")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(sortedSRIBuckets()) { bucket in
                let shareValue = share(for: bucket, metric: sriMetric)
                HStack {
                    riskBadge(bucket.bucket)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bucket.label)
                        HStack(spacing: 0) {
                            Text("\(bucket.count) • ")
                            Text(formatChfNoDecimals(bucket.value))
                                .bold()
                                .monospacedDigit()
                            Text(" • \(formatPercent(shareValue))")
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: expandedSRI.contains(bucket.bucket) ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { toggle(&expandedSRI, bucket.bucket) }
                if expandedSRI.contains(bucket.bucket) {
                    instrumentList(for: bucket.bucket)
                }
                Divider()
            }
        }
    }

    private var liquidityCard: some View {
        reportCard(title: "Liquidity Tiers", subtitle: "Counts, value, and drill-down") {
            ForEach(liquidityDistributionData) { bucket in
                let shareValue = liquidityShare(for: bucket)
                HStack {
                    Text(bucket.label)
                        .font(.subheadline)
                    Spacer()
                    Text("\(bucket.count) • \(formatCurrency(bucket.value)) • \(formatPercent(shareValue))")
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(.secondary)
                    Image(systemName: expandedLiquidity.contains(bucket.tier) ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { toggle(&expandedLiquidity, bucket.tier) }
                if expandedLiquidity.contains(bucket.tier) {
                    liquidityList(for: bucket.tier)
                }
                Divider()
            }
        }
    }

    private var allocationCard: some View {
        reportCard(title: "Allocation vs SRI", subtitle: "100% stacked bars per asset class") {
            HStack {
                Toggle("Sort by value", isOn: $sortAllocationByValue)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text(sortAllocationByValue ? "Largest first" : "By name")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
            if allocationSegments.isEmpty {
                Text("No allocation data available.")
                    .foregroundColor(.secondary)
            } else {
                Chart(allocationSegments) { segment in
                    BarMark(
                        x: .value("Share", segment.share),
                        y: .value("Asset Class", segment.classLabel)
                    )
                    .foregroundStyle(by: .value("SRI", "SRI \(segment.sri)"))
                }
                .chartForegroundStyleScale(
                    domain: sriBuckets.map { "SRI \($0.value)" },
                    range: riskColors
                )
                .chartXScale(domain: 0 ... 1)
                .chartXAxis {
                    AxisMarks(values: [0.0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let share = value.as(Double.self) {
                                Text(formatPercent(share))
                            }
                        }
                    }
                }
                .chartXAxisLabel("Share of asset class", alignment: .trailing)
                .chartYAxisLabel("Asset class", alignment: .leading)
                .chartLegend(.visible)
                .frame(height: max(Double(heatmapRows.count) * 36.0, 200))
            }
        }
    }

    private var overridesPanel: some View {
        reportCard(title: "Overrides & Expiries", subtitle: "Computed vs override values") {
            if overrides.isEmpty {
                Text("No active overrides.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(overrides) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.instrumentName).bold()
                            Spacer()
                            riskBadge(item.overrideSRI ?? item.computedSRI)
                        }
                        Text("Computed SRI \(item.computedSRI) → Override \(item.overrideSRI.map(String.init) ?? "—")")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text("Liquidity \(liquidityLabel(item.computedLiquidityTier)) → \(item.overrideLiquidityTier.map(liquidityLabel) ?? "—")")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            if let reason = item.overrideReason, !reason.isEmpty {
                                Text(reason)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(overrideStatus(for: item).label)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(overrideStatus(for: item).tint)
                                .cornerRadius(6)
                        }
                        if let expiresAt = item.overrideExpiresAt {
                            Text("Expires: \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    Divider()
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadData() {
        let reports = dbManager.fetchPositionReports()
        let fxService = FXConversionService(dbManager: dbManager)

        var riskCache: [Int: (sri: Int, liquidity: Int)] = [:]
        var values: [Int: Double] = [:]

        for pr in reports {
            guard let iid = pr.instrumentId else { continue }
            if riskCache[iid] == nil {
                riskCache[iid] = resolveRisk(for: iid)
            }
            if let value = priceInChf(for: pr, fxService: fxService) {
                values[pr.id] = value
            }
        }

        positions = reports
        overrides = dbManager.listRiskOverrides()
        riskLookup = riskCache
        valueLookup = values
        baseCurrency = preferences.baseCurrency
    }

    private func positionValue(_ pr: PositionReportData) -> Double {
        valueLookup[pr.id] ?? 0
    }

    private var totalPortfolioValue: Double {
        positions.reduce(0) { $0 + positionValue($1) }
    }

    private var portfolioRiskScore: Double? {
        let total = totalPortfolioValue
        guard total > 0 else { return nil }

        var weightedSRI = 0.0
        var weightedLiquidityPremium = 0.0

        for pr in positions {
            guard let iid = pr.instrumentId,
                  let risk = riskLookup[iid],
                  let value = valueLookup[pr.id] else { continue }
            let weight = value / total
            weightedSRI += weight * Double(risk.sri)
            weightedLiquidityPremium += weight * liquidityPenalty(for: risk.liquidity)
        }

        return clampScore(weightedSRI + weightedLiquidityPremium)
    }

    private var riskHistory: [TrendPoint] {
        let grouped = Dictionary(grouping: positions) { Calendar.current.startOfDay(for: $0.reportDate) }
        let points = grouped.map { date, rows -> TrendPoint in
            let total = rows.reduce(0.0) { $0 + positionValue($1) }
            let score: Double
            if total > 0 {
                var weightedSRI = 0.0
                var weightedLiquidity = 0.0

                for pr in rows {
                    guard let iid = pr.instrumentId,
                          let risk = riskLookup[iid],
                          let value = valueLookup[pr.id] else { continue }
                    let weight = value / total
                    weightedSRI += weight * Double(risk.sri)
                    weightedLiquidity += weight * liquidityPenalty(for: risk.liquidity)
                }
                score = clampScore(weightedSRI + weightedLiquidity)
            } else {
                score = 0
            }
            let illiquidTotal = rows
                .filter { (liquidityForPosition($0) ?? 0) >= 1 }
                .reduce(0.0) { $0 + positionValue($1) }
            let illiquidShare = total > 0 ? illiquidTotal / total : 0
            return TrendPoint(date: date, riskScore: score, illiquidShare: illiquidShare)
        }
        return points.sorted { $0.date < $1.date }
    }

    private func priceInChf(for pr: PositionReportData, fxService: FXConversionService) -> Double? {
        guard let instrumentId = pr.instrumentId else { return nil }
        guard let latestPrice = dbManager.getLatestPrice(instrumentId: instrumentId) else { return nil }
        let nativeValue = pr.quantity * latestPrice.price
        guard nativeValue != 0 else { return nil }
        guard let converted = fxService.convertToChf(amount: nativeValue, currency: latestPrice.currency) else { return nil }
        return converted.valueChf
    }

    private func resolveRisk(for instrumentId: Int) -> (sri: Int, liquidity: Int) {
        if let profile = dbManager.fetchRiskProfile(instrumentId: instrumentId) {
            return (
                dbManager.coerceSRI(profile.effectiveSRI),
                dbManager.coerceLiquidityTier(profile.effectiveLiquidityTier)
            )
        }
        if let details = dbManager.fetchInstrumentDetails(id: instrumentId) {
            let defaults = dbManager.riskDefaults(for: details.subClassId)
            return (
                dbManager.coerceSRI(defaults.sri),
                dbManager.coerceLiquidityTier(defaults.liquidityTier)
            )
        }
        let sri = dbManager.riskConfigInt(key: "risk_default_sri", fallback: 5, min: 1, max: 7)
        let liq = dbManager.riskConfigInt(key: "risk_default_liquidity_tier", fallback: 1, min: 0, max: 2)
        return (sri, liq)
    }

    private func liquidityPenalty(for tier: Int) -> Double {
        switch tier {
        case 0: return 0.0
        case 1: return 0.5
        default: return 1.0
        }
    }

    private func clampScore(_ score: Double) -> Double {
        max(1.0, min(7.0, score))
    }

    private var riskDeltaBadge: some View {
        let delta = riskDelta
        let text: String
        let color: Color
        if let delta, abs(delta) > 0.001 {
            text = String(format: "%+.2f vs prev", delta)
            color = delta >= 0 ? .orange : .green
        } else {
            text = "No change"
            color = .secondary
        }
        return Text(text)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private var riskDelta: Double? {
        guard riskHistory.count >= 2 else { return nil }
        let latest = riskHistory[riskHistory.count - 1].riskScore
        let prev = riskHistory[riskHistory.count - 2].riskScore
        return latest - prev
    }

    private var sriDistributionData: [DistributionBucket] {
        sriBuckets.map { bucket in
            let rows = positions.filter { bucketForPosition($0) == bucket.value }
            let value = rows.reduce(0.0) { $0 + positionValue($1) }
            return DistributionBucket(bucket: bucket.value, label: bucket.label, count: rows.count, value: value)
        }
    }

    private var liquidityDistributionData: [LiquidityBucket] {
        liquidityBuckets.map { bucket in
            let rows = positions.filter { liquidityForPosition($0) == bucket.value }
            let value = rows.reduce(0.0) { $0 + positionValue($1) }
            return LiquidityBucket(tier: bucket.value, label: bucket.label, count: rows.count, value: value, color: liquidityColor(bucket.value))
        }
    }

    private func share(for bucket: DistributionBucket, metric: SRIMetric) -> Double {
        switch metric {
        case .count:
            let total = sriDistributionData.reduce(0) { $0 + $1.count }
            guard total > 0 else { return 0 }
            return Double(bucket.count) / Double(total)
        case .value:
            guard totalPortfolioValue > 0 else { return 0 }
            return bucket.value / totalPortfolioValue
        }
    }

    private func topBucket(by metric: SRIMetric) -> DistributionBucket? {
        switch metric {
        case .count:
            return sriDistributionData.max(by: { $0.count < $1.count })
        case .value:
            return sriDistributionData.max(by: { $0.value < $1.value })
        }
    }

    private var topBucketByMetric: DistributionBucket? { topBucket(by: sriMetric) }

    private func liquidityShare(for bucket: LiquidityBucket) -> Double {
        guard totalPortfolioValue > 0 else { return 0 }
        return bucket.value / totalPortfolioValue
    }

    private func liquidityColor(_ tier: Int) -> Color {
        switch tier {
        case 0: return .teal
        case 1: return .orange
        default: return .red
        }
    }

    private var highRiskPercent: Double {
        let total = totalPortfolioValue
        guard total > 0 else { return 0 }
        let risky = sriDistributionData
            .filter { $0.bucket >= 6 }
            .reduce(0.0) { $0 + $1.value }
        return risky / total
    }

    private var illiquidPercent: Double {
        let total = totalPortfolioValue
        guard total > 0 else { return 0 }
        let illiquid = liquidityDistributionData
            .filter { $0.tier >= 1 }
            .reduce(0.0) { $0 + $1.value }
        return illiquid / total
    }

    private var heatmapRows: [HeatmapRow] { heatmapRows(for: heatmapMode) }

    private func heatmapRows(for mode: HeatmapMode) -> [HeatmapRow] {
        let grouped = Dictionary(grouping: positions) { $0.assetClass ?? "Unclassified" }
        let rows = grouped.map { label, rows in
            let total = rows.reduce(0.0) { $0 + positionValue($1) }
            let cells = sriBuckets.map { bucket -> HeatmapCell in
                let bucketValue = rows.filter { bucketForPosition($0) == bucket.value }
                    .reduce(0.0) { $0 + positionValue($1) }
                let denominator = mode == .portfolio ? totalPortfolioValue : total
                let share = denominator > 0 ? bucketValue / denominator : 0
                return HeatmapCell(bucket: bucket.value, value: bucketValue, share: share)
            }
            let totalShare = totalPortfolioValue > 0 ? total / totalPortfolioValue : 0
            return HeatmapRow(id: label, label: label, total: total, totalShare: totalShare, cells: cells)
        }
        let sorted = rows.sorted {
            sortAllocationByValue ? $0.total > $1.total : $0.label < $1.label
        }
        return Array(sorted.prefix(6))
    }

    private var allocationSegments: [AllocationSegment] {
        heatmapRows.flatMap { row in
            row.cells
                .filter { $0.value > 0 }
                .map {
                    let share = row.total > 0 ? $0.value / row.total : 0
                    return AllocationSegment(id: UUID(), classLabel: row.label, sri: $0.bucket, value: $0.value, share: share)
                }
        }
    }

    private var overrideCounts: OverrideCounts {
        overrides.reduce(into: OverrideCounts()) { acc, row in
            switch overrideStatus(for: row) {
            case .expired: acc.expired += 1
            case .expiringSoon: acc.expiringSoon += 1
            case .active: acc.active += 1
            }
        }
    }

    private var nextOverrideExpiry: Date? {
        overrides.compactMap { $0.overrideExpiresAt }.sorted().first
    }

    private func bucketForPosition(_ pr: PositionReportData) -> Int? {
        guard let iid = pr.instrumentId else { return nil }
        return riskLookup[iid]?.sri
    }

    private func liquidityForPosition(_ pr: PositionReportData) -> Int? {
        guard let iid = pr.instrumentId else { return nil }
        return riskLookup[iid]?.liquidity
    }

    private func instruments(forSRI bucket: Int) -> [PositionReportData] {
        positions.filter { bucketForPosition($0) == bucket }
    }

    private func instruments(forLiquidity tier: Int) -> [PositionReportData] {
        positions.filter { liquidityForPosition($0) == tier }
    }

    private func instrumentList(for bucket: Int) -> some View {
        let items = instruments(forSRI: bucket)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.id) { pr in
                Button(action: { openInstrumentMaintenance(pr) }) {
                    HStack {
                        Text(pr.instrumentName)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatChfNoDecimals(positionValue(pr)))
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func liquidityList(for tier: Int) -> some View {
        let items = instruments(forLiquidity: tier)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.id) { pr in
                Button(action: { openInstrumentMaintenance(pr) }) {
                    HStack {
                        Text(pr.instrumentName)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrency(positionValue(pr)))
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sortedSRIBuckets() -> [DistributionBucket] {
        let buckets = sriDistributionData
        if sortSRIByCount {
            return buckets.sorted { $0.count > $1.count }
        }
        return buckets.sorted { $0.bucket < $1.bucket }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = baseCurrency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formatChfNoDecimals(_ value: Double) -> String {
        let truncated = value.rounded(.towardZero)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_CH")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: truncated)) ?? String(Int(truncated))
    }

    private func formatCompactCurrency(_ value: Double) -> String {
        if #available(iOS 15.0, macOS 12.0, *) {
            return value.formatted(
                .currency(code: baseCurrency)
                    .notation(.compactName)
                    .precision(.fractionLength(0 ... 1))
            )
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = baseCurrency
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            formatter.usesGroupingSeparator = true
            return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
        }
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func highRiskPercentDisplay() -> String { formatPercent(highRiskPercent) }
    private func illiquidPercentDisplay() -> String { formatPercent(illiquidPercent) }

    private func liquidityPill(label: String, value: Int) -> some View {
        Text("\(label): \(value)")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DSColor.surface.opacity(0.6))
            .cornerRadius(6)
    }

    @ViewBuilder
    private func riskBadge(_ value: Int?) -> some View {
        if let value, value >= 1 && value <= 7 {
            Text("SRI \(value)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(riskColors[value - 1])
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }

    private func statusPill(label: String, value: Int, tint: Color, textColor: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
            Text("\(value)")
                .bold()
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint)
        .foregroundColor(textColor)
        .cornerRadius(8)
    }

    private func heatmapFill(for cell: HeatmapCell) -> Color {
        let base = riskColors[max(0, cell.bucket - 1)]
        if cell.value <= 0 {
            return base.opacity(0.12)
        }
        return base.opacity(0.25 + 0.6 * min(cell.share, 1))
    }

    private func heatmapStroke(for cell: HeatmapCell) -> Color {
        if cell.value <= 0 {
            return DSColor.border
        }
        return riskColors[max(0, cell.bucket - 1)]
    }

    private func heatmapTextColor(for cell: HeatmapCell) -> Color {
        if cell.value <= 0 {
            return .secondary.opacity(0.7)
        }
        return .primary.opacity(0.85)
    }

    private func openInstrumentMaintenance(_ pr: PositionReportData) {
        guard let id = pr.instrumentId else { return }
        openWindow(id: "instrumentDashboard", value: id)
    }

    private func overrideStatus(for row: DatabaseManager.RiskOverrideRow) -> OverrideStatus {
        guard let expires = row.overrideExpiresAt else { return .active }
        if expires < Date() {
            return .expired
        }
        if let soon = Calendar.current.date(byAdding: .day, value: 30, to: Date()), expires < soon {
            return .expiringSoon
        }
        return .active
    }

    private func toggle(_ set: inout Set<Int>, _ value: Int) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    private func liquidityLabel(_ tier: Int) -> String {
        switch tier {
        case 0: return "Liquid"
        case 1: return "Restricted"
        default: return "Illiquid"
        }
    }

    private func reportCard<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            content()
        }
        .padding()
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }
}

// MARK: - Models

private enum SRIMetric: String, CaseIterable, Identifiable {
    case count
    case value

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct DistributionBucket: Identifiable {
    let bucket: Int
    let label: String
    let count: Int
    let value: Double

    var id: Int { bucket }
}

private struct LiquidityBucket: Identifiable {
    let tier: Int
    let label: String
    let count: Int
    let value: Double
    let color: Color

    var id: Int { tier }
}

private struct TrendPoint: Identifiable {
    let date: Date
    let riskScore: Double
    let illiquidShare: Double

    var id: Date { date }
}

private struct HeatmapRow: Identifiable {
    let id: String
    let label: String
    let total: Double
    let totalShare: Double
    let cells: [HeatmapCell]
}

private struct HeatmapCell {
    let bucket: Int
    let value: Double
    let share: Double
}

private enum HeatmapMode: String, CaseIterable, Identifiable {
    case portfolio
    case segment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portfolio: return "Portfolio %"
        case .segment: return "Segment %"
        }
    }

    func caption(baseCurrency: String) -> String {
        switch self {
        case .portfolio:
            return "Cells show % of total asset value and \(baseCurrency) amounts across the whole portfolio."
        case .segment:
            return "Original view: cells show % of the row total (segment-normalized) with \(baseCurrency) amounts."
        }
    }

    func legend(baseCurrency: String) -> String {
        switch self {
        case .portfolio:
            return "% of total asset value • \(baseCurrency) amount per cell"
        case .segment:
            return "% of segment total • \(baseCurrency) amount per cell"
        }
    }
}

private struct AllocationSegment: Identifiable {
    let id: UUID
    let classLabel: String
    let sri: Int
    let value: Double
    let share: Double
}

private enum OverrideStatus {
    case active
    case expiringSoon
    case expired

    var label: String {
        switch self {
        case .active: return "Active"
        case .expiringSoon: return "Expiring soon"
        case .expired: return "Expired"
        }
    }

    var tint: Color {
        switch self {
        case .active: return Color.blue.opacity(0.12)
        case .expiringSoon: return Color.orange.opacity(0.15)
        case .expired: return Color.red.opacity(0.12)
        }
    }
}

private struct OverrideCounts {
    var active: Int = 0
    var expiringSoon: Int = 0
    var expired: Int = 0
}

// MARK: - Preview

struct RiskReportView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = DatabaseManager()
        RiskReportView()
            .environmentObject(AssetManager())
            .environmentObject(manager)
            .environmentObject(manager.preferences)
    }
}
