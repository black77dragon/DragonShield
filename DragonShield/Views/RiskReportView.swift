import Charts
import SwiftUI

struct RiskReportView: View {
    @EnvironmentObject var assetManager: AssetManager
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var positions: [PositionReportData] = []
    @State private var overrides: [DatabaseManager.RiskOverrideRow] = []
    @State private var riskLookup: [Int: (sri: Int?, liquidity: Int?)] = [:]
    @State private var expandedSRI: Set<Int> = []
    @State private var expandedLiquidity: Set<Int> = []
    @State private var sortSRIByCount: Bool = false
    @State private var sortAllocationByValue: Bool = true
    @State private var sriMetric: SRIMetric = .value

    private let riskColors: [Color] = [
        Color.green.opacity(0.7),
        Color.green,
        Color.yellow,
        Color.orange,
        Color.orange.opacity(0.85),
        Color.red.opacity(0.9),
        Color.red
    ]

    private var heroColumns: [GridItem] { [GridItem(.adaptive(minimum: 240), spacing: 12)] }

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
            trendsCard
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

    private var trendsCard: some View {
        reportCard(title: "Trends (by report date)", subtitle: "Risk score & illiquid share") {
            if riskHistory.count < 2 {
                Text("Not enough history to chart trends yet.")
                    .foregroundColor(.secondary)
            } else {
                Chart {
                    ForEach(riskHistory) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Risk", point.riskScore)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.cardinal)
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Risk", point.riskScore)
                        )
                        .foregroundStyle(.blue.opacity(0.12))

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Illiquid", point.illiquidShare * 7)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.cardinal)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Illiquid", point.illiquidShare * 7)
                        )
                        .foregroundStyle(.orange)
                    }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(riskHistory.count / 4, 1)))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        reportCard(title: "Exposure Heatmap", subtitle: "Top asset classes vs SRI buckets") {
            if heatmapRows.isEmpty {
                Text("No positions to display.")
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Text("Asset Class")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 140, alignment: .leading)
                        ForEach(sriBuckets, id: \.value) { bucket in
                            Text(bucket.label)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(heatmapRows) { row in
                        HStack(spacing: 4) {
                            Text(row.label)
                                .font(.subheadline)
                                .frame(width: 140, alignment: .leading)
                            ForEach(row.cells, id: \.bucket) { cell in
                                Rectangle()
                                    .fill(heatmapColor(for: cell))
                                    .overlay(
                                        Text(cell.value > 0 ? formatPercent(cell.share) : "")
                                            .font(.caption2)
                                            .foregroundColor(.primary.opacity(0.8))
                                    )
                                    .frame(height: 36)
                                    .cornerRadius(6)
                            }
                        }
                        .background(DSColor.surface.opacity(0.01))
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
            ForEach(sortedSRIBuckets()) { bucket in
                let shareValue = share(for: bucket, metric: sriMetric)
                HStack {
                    riskBadge(bucket.bucket)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bucket.label)
                        Text("\(bucket.count) • \(formatCurrency(bucket.value)) • \(formatPercent(shareValue))")
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
                        x: .value("Value", segment.value),
                        y: .value("Asset Class", segment.classLabel)
                    )
                    .foregroundStyle(by: .value("SRI", "SRI \(segment.sri)"))
                    .position(by: .value("SRI", segment.sri))
                }
                .chartForegroundStyleScale(
                    domain: sriBuckets.map { "SRI \($0.value)" },
                    range: riskColors
                )
                .chartLegend(.visible)
                .frame(height: max(Double(allocationSegments.count) * 14.0, 200))
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
        positions = dbManager.fetchPositionReports()
        overrides = dbManager.listRiskOverrides()
        riskLookup = Dictionary(uniqueKeysWithValues: assetManager.assets.map { asset in
            (asset.id, (asset.riskSRI, asset.riskLiquidityTier))
        })
    }

    private func positionValue(_ pr: PositionReportData) -> Double {
        let price = pr.currentPrice ?? pr.purchasePrice ?? 0
        return price * pr.quantity
    }

    private var totalPortfolioValue: Double {
        positions.reduce(0) { $0 + positionValue($1) }
    }

    private var portfolioRiskScore: Double? {
        let total = totalPortfolioValue
        guard total > 0 else { return nil }
        let weighted = positions.reduce(0.0) { acc, pr in
            guard let iid = pr.instrumentId, let sri = riskLookup[iid]?.sri else { return acc }
            return acc + Double(sri) * positionValue(pr)
        }
        return weighted / total
    }

    private var riskHistory: [TrendPoint] {
        let grouped = Dictionary(grouping: positions) { Calendar.current.startOfDay(for: $0.reportDate) }
        let points = grouped.map { date, rows -> TrendPoint in
            let total = rows.reduce(0.0) { $0 + positionValue($1) }
            let score: Double
            if total > 0 {
                let weighted = rows.reduce(0.0) { acc, pr in
                    guard let iid = pr.instrumentId, let sri = riskLookup[iid]?.sri else { return acc }
                    return acc + Double(sri) * positionValue(pr)
                }
                score = weighted / total
            } else {
                score = 0
            }
            let illiquidTotal = rows.filter { liquidityForPosition($0) == 2 }.reduce(0.0) { $0 + positionValue($1) }
            let illiquidShare = total > 0 ? illiquidTotal / total : 0
            return TrendPoint(date: date, riskScore: score, illiquidShare: illiquidShare)
        }
        return points.sorted { $0.date < $1.date }
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

    private var heatmapRows: [HeatmapRow] {
        let grouped = Dictionary(grouping: positions) { $0.assetClass ?? "Unclassified" }
        let rows = grouped.map { label, rows in
            let total = rows.reduce(0.0) { $0 + positionValue($1) }
            let cells = sriBuckets.map { bucket -> HeatmapCell in
                let bucketValue = rows.filter { bucketForPosition($0) == bucket.value }
                    .reduce(0.0) { $0 + positionValue($1) }
                let share = total > 0 ? bucketValue / total : 0
                return HeatmapCell(bucket: bucket.value, value: bucketValue, share: share)
            }
            return HeatmapRow(id: label, label: label, total: total, cells: cells)
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
                .map { AllocationSegment(id: UUID(), classLabel: row.label, sri: $0.bucket, value: $0.value) }
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
                HStack {
                    Text(pr.instrumentName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(positionValue(pr)))
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func liquidityList(for tier: Int) -> some View {
        let items = instruments(forLiquidity: tier)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.id) { pr in
                HStack {
                    Text(pr.instrumentName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(positionValue(pr)))
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(.secondary)
                }
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
        formatter.currencyCode = "CHF"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
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

    private func heatmapColor(for cell: HeatmapCell) -> Color {
        let base = riskColors[max(0, cell.bucket - 1)]
        return base.opacity(0.25 + 0.6 * min(cell.share, 1))
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
    let cells: [HeatmapCell]
}

private struct HeatmapCell {
    let bucket: Int
    let value: Double
    let share: Double
}

private struct AllocationSegment: Identifiable {
    let id: UUID
    let classLabel: String
    let sri: Int
    let value: Double
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
        RiskReportView()
            .environmentObject(AssetManager())
            .environmentObject(DatabaseManager())
    }
}
