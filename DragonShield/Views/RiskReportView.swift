import SwiftUI

struct RiskReportView: View {
    @EnvironmentObject var assetManager: AssetManager
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var expandedSRI: Set<Int> = []
    @State private var expandedLiquidity: Set<Int> = []
    @State private var sortSRIByCount: Bool = false
    @State private var sortAllocationByValue: Bool = true

    private let riskColors: [Color] = [
        Color.green.opacity(0.7),
        Color.green,
        Color.yellow,
        Color.orange,
        Color.orange.opacity(0.85),
        Color.red.opacity(0.9),
        Color.red
    ]

    private var sriBuckets: [(value: Int, label: String)] {
        [
            (1, "SRI 1"), (2, "SRI 2"), (3, "SRI 3"), (4, "SRI 4"),
            (5, "SRI 5"), (6, "SRI 6"), (7, "SRI 7")
        ]
    }

    private var liquidityBuckets: [(value: Int, label: String)] {
        [(0, "Liquid"), (1, "Restricted"), (2, "Illiquid")]
    }

    private var sriCounts: [Int: Int] {
        Dictionary(grouping: assetManager.assets, by: { $0.riskSRI ?? 0 }).mapValues { $0.count }
    }

    private var liquidityCounts: [Int: Int] {
        Dictionary(grouping: assetManager.assets, by: { $0.riskLiquidityTier ?? -1 }).mapValues { $0.count }
    }

    private var positions: [PositionReportData] { dbManager.fetchPositionReports() }

    private var assetRiskMap: [Int: DatabaseManager.RiskProfileRow] {
        var map: [Int: DatabaseManager.RiskProfileRow] = [:]
        for asset in assetManager.assets {
            if let profile = dbManager.fetchRiskProfile(instrumentId: asset.id) {
                map[asset.id] = profile
            }
        }
        return map
    }

    private var positionsBySRI: [(bucket: Int, total: Double, items: [PositionReportData])] {
        let map = assetRiskMap
        let grouped = Dictionary(grouping: positions) { pr -> Int in
            guard let iid = pr.instrumentId, let profile = map[iid] else { return 0 }
            return profile.effectiveSRI
        }
        return grouped.map { key, list in
            let total = list.reduce(0.0) { acc, pr in
                let price = pr.currentPrice ?? pr.purchasePrice ?? 0
                return acc + price * pr.quantity
            }
            return (bucket: key, total: total, items: list)
        }
    }

    private var overrides: [DatabaseManager.RiskOverrideRow] {
        dbManager.listRiskOverrides()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summarySection
                sriSection
                sriAllocationSection
                liquiditySection
                overridesSection
            }
            .padding()
        }
        .navigationTitle("Risk Report")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Risk Report")
                .font(.largeTitle).bold()
            Text("Overview of SRI distribution, liquidity tiers, and active overrides.")
                .foregroundColor(.secondary)
        }
    }

    private var summarySection: some View {
        HStack(spacing: 16) {
            summaryCard(title: "High Risk (SRI 6–7)", value: highRiskCountDisplay(), color: .red)
            summaryCard(title: "Illiquid + Restricted", value: illiquidCountDisplay(), color: .orange)
            summaryCard(title: "Active Overrides", value: "\(overrides.count)", color: .blue)
        }
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundColor(color)
            Text(value).font(.title2).bold()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private var sriSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SRI Distribution").font(.headline)
                Spacer()
                Toggle("Sort by count", isOn: $sortSRIByCount)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            ForEach(sortedSRIBuckets(), id: \.value) { bucket in
                let count = sriCounts[bucket.value] ?? 0
                HStack {
                    riskBadge(bucket.value)
                    Text(bucket.label)
                    Spacer()
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }
                .contentShape(Rectangle())
                .onTapGesture { toggle(&expandedSRI, bucket.value) }
                Divider()
                if expandedSRI.contains(bucket.value) {
                    let instruments = assetManager.assets.filter { $0.riskSRI == bucket.value }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(instruments, id: \.id) { ins in
                            Text(ins.name)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    Divider()
                }
            }
        }
        .padding()
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private var sriAllocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SRI Allocation (Value)").font(.headline)
                Spacer()
                Toggle("Sort by value", isOn: $sortAllocationByValue)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            let allocation = sortedAllocationBuckets()
            ForEach(allocation, id: \.bucket) { bucket in
                HStack {
                    riskBadge(bucket.bucket)
                    Text("SRI \(bucket.bucket)")
                    Spacer()
                    Text(formatCurrency(bucket.total))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }
                .contentShape(Rectangle())
                .onTapGesture { toggle(&expandedSRI, bucket.bucket) }
                Divider()
                if expandedSRI.contains(bucket.bucket) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(sortedItems(byValue: bucket.items), id: \.id) { pr in
                            let value = (pr.currentPrice ?? pr.purchasePrice ?? 0) * pr.quantity
                            HStack {
                                Text(pr.instrumentName)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(value))
                                    .font(.footnote.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Divider()
                }
            }
        }
        .padding()
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private var liquiditySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Liquidity").font(.headline)
            ForEach(liquidityBuckets, id: \.value) { bucket in
                let count = liquidityCounts[bucket.value] ?? 0
                HStack {
                    Text(bucket.label)
                        .font(.subheadline)
                    Spacer()
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }
                .contentShape(Rectangle())
                .onTapGesture { toggle(&expandedLiquidity, bucket.value) }
                Divider()
                if expandedLiquidity.contains(bucket.value) {
                    let instruments = assetManager.assets.filter { $0.riskLiquidityTier == bucket.value }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(instruments, id: \.id) { ins in
                            Text(ins.name)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    Divider()
                }
            }
        }
        .padding()
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    private var overridesSection: some View {
        let items: [DatabaseManager.RiskOverrideRow] = overrides
        return VStack(alignment: .leading, spacing: 12) {
            Text("Overrides").font(.headline)
            if items.isEmpty {
                Text("No active overrides").foregroundColor(.secondary)
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.instrumentName).bold()
                            Spacer()
                            riskBadge(item.overrideSRI ?? item.computedSRI)
                        }
                        Text("Computed SRI \(item.computedSRI) • Override: \(item.overrideSRI.map { String($0) } ?? "—")")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        if let reason = item.overrideReason, !reason.isEmpty {
                            Text("Reason: \(reason)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        if let by = item.overrideBy {
                            let expiresText = item.overrideExpiresAt.map { " • Expires: \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""
                            Text("Set by: \(by)\(expiresText)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    Divider()
                }
            }
        }
        .padding()
        .background(DSColor.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.border, lineWidth: 1))
    }

    @ViewBuilder
    private func riskBadge(_ value: Int) -> some View {
        if value >= 1 && value <= 7 {
            Text("SRI \(value)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(riskColors[value - 1])
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }

    private func highRiskCountDisplay() -> String {
        let count = (sriCounts[6] ?? 0) + (sriCounts[7] ?? 0)
        return "\(count)"
    }

    private func illiquidCountDisplay() -> String {
        let count = (liquidityCounts[1] ?? 0) + (liquidityCounts[2] ?? 0)
        return "\(count)"
    }

    private func sortedSRIBuckets() -> [(value: Int, label: String)] {
        if sortSRIByCount {
            return sriBuckets.sorted { (sriCounts[$0.value] ?? 0) > (sriCounts[$1.value] ?? 0) }
        }
        return sriBuckets
    }

    private func sortedAllocationBuckets() -> [(bucket: Int, total: Double, items: [PositionReportData])] {
        let buckets = positionsBySRI
        if sortAllocationByValue {
            return buckets.sorted { $0.total > $1.total }
        }
        return buckets.sorted { $0.bucket < $1.bucket }
    }

    private func sortedItems(byValue items: [PositionReportData]) -> [PositionReportData] {
        items.sorted {
            let v1 = ($0.currentPrice ?? $0.purchasePrice ?? 0) * $0.quantity
            let v2 = ($1.currentPrice ?? $1.purchasePrice ?? 0) * $1.quantity
            return v1 > v2
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CHF"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func toggle(_ set: inout Set<Int>, _ value: Int) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

struct RiskReportView_Previews: PreviewProvider {
    static var previews: some View {
        RiskReportView()
            .environmentObject(AssetManager())
            .environmentObject(DatabaseManager())
    }
}
