import Charts
import SwiftUI

private let riskColors: [Color] = [
    Color.green.opacity(0.7),
    Color.green,
    Color.yellow,
    Color.orange,
    Color.orange.opacity(0.85),
    Color.red.opacity(0.9),
    Color.red
]

private func riskColor(for bucket: Int) -> Color {
    let index = max(0, min(riskColors.count - 1, bucket - 1))
    return riskColors[index]
}

private let riskScoreGradient = LinearGradient(
    gradient: Gradient(stops: [
        .init(color: Color.green.opacity(0.8), location: 0.0),
        .init(color: Color.yellow, location: 0.45),
        .init(color: Color.orange, location: 0.7),
        .init(color: Color.red, location: 1.0)
    ]),
    startPoint: .leading,
    endPoint: .trailing
)

private func liquidityColor(_ tier: Int) -> Color {
    switch tier {
    case 0: return .teal
    case 1: return .orange
    default: return .red
    }
}

private func percentText(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

private func currencyText(_ value: Double, code: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(String(format: "%.0f", value))"
}

private struct InstrumentIdent: Identifiable {
    let value: Int
    var id: Int { value }
}

private struct BucketSelection: Identifiable {
    let value: Int
    var id: Int { value }
}

private struct OverrideSelection: Identifiable {
    let value: DashboardOverrideStatus
    var id: DashboardOverrideStatus { value }
}

// MARK: - Risk Score Tile

struct RiskScoreTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = DashboardRiskTilesViewModel()
    @State private var showBreakdown = false
    @State private var editingInstrumentId: Int?

    init() {}
    static let tileID = "risk_score"
    static let tileName = "Risk Score"
    static let iconName = "speedometer"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if viewModel.loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                scoreContent
            }
        }
        .onAppear { viewModel.load(using: dbManager) }
        .sheet(isPresented: $showBreakdown) {
            breakdownSheet
        }
        .sheet(item: editBinding) { ident in
            InstrumentEditView(
                instrumentId: ident.value,
                isPresented: Binding(
                    get: { editingInstrumentId != nil },
                    set: { if !$0 { editingInstrumentId = nil } }
                )
            )
            .environmentObject(dbManager)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var scoreContent: some View {
        let snap = viewModel.snapshot
        if snap.totalValue == 0 {
            Text("No priced positions available.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(snap.riskScore.map { String(format: "%.1f", $0) } ?? "—")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    if let category = snap.category {
                        Text(category.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(categoryColor(category).opacity(0.16))
                            .foregroundColor(categoryColor(category))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Button(action: { showBreakdown = true }) {
                        Text("Breakdown")
                    }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                    .disabled(snap.totalValue == 0)
                }
                RiskScoreGradientSlider(score: snap.riskScore)
                    .frame(height: 28)

                HStack(spacing: 12) {
                    Text("High risk 6–7: \(percentText(snap.highRiskShare))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Illiquid+Restricted: \(percentText(snap.illiquidShare))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Text("Total \(snap.baseCurrency):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currencyText(snap.totalValue, code: snap.baseCurrency))
                        .font(.caption.weight(.semibold))
                    if let asOf = snap.priceAsOf {
                        Text("Prices as of \(asOf.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                if snap.missingPriceCount > 0 || snap.missingFxCount > 0 || snap.fallbackCount > 0 {
                    Text(footnoteText(for: snap))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var breakdownSheet: some View {
        let snap = viewModel.snapshot
        let instruments = snap.instrumentsBySRI.values.flatMap { $0 }.sorted { $0.valueChf > $1.valueChf }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Risk Contributions")
                    .font(.headline)
                Spacer()
                Button("Close") { showBreakdown = false }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
            if instruments.isEmpty {
                Text("No priced positions available.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(instruments) { item in
                            Button(action: { editingInstrumentId = item.id }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Text("SRI \(item.sri) • \(liquidityLabel(item.liquidityTier))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(currencyText(item.valueChf, code: snap.baseCurrency))
                                            .font(.caption.monospacedDigit())
                                        Text(percentText(item.weight))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DSColor.surface)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 360)
    }

    private var editBinding: Binding<InstrumentIdent?> {
        Binding(
            get: { editingInstrumentId.map { InstrumentIdent(value: $0) } },
            set: { editingInstrumentId = $0?.value }
        )
    }

    private func footnoteText(for snapshot: DashboardRiskSnapshot) -> String {
        var parts: [String] = []
        if snapshot.missingPriceCount > 0 {
            parts.append("Missing price: \(snapshot.missingPriceCount)")
        }
        if snapshot.missingFxCount > 0 {
            parts.append("Missing FX: \(snapshot.missingFxCount)")
        }
        if snapshot.fallbackCount > 0 {
            parts.append("Fallback risk: \(snapshot.fallbackCount)")
        }
        return parts.joined(separator: " • ")
    }

    private func categoryColor(_ category: PortfolioRiskCategory) -> Color {
        switch category {
        case .low: return .green
        case .moderate: return .yellow
        case .elevated: return .orange
        case .high: return .red
        }
    }

    private func liquidityLabel(_ tier: Int) -> String {
        switch tier {
        case 0: return "Liquid"
        case 1: return "Restricted"
        default: return "Illiquid"
        }
    }
}

private struct RiskScoreGradientSlider: View {
    var score: Double?

    private var clampedScore: Double {
        let value = score ?? 1
        return min(max(value, 1), 7)
    }

    private var thumbColor: Color {
        guard score != nil else { return Color.gray.opacity(0.5) }
        return riskColor(for: Int(round(clampedScore)))
    }

    private var progress: CGFloat {
        CGFloat((clampedScore - 1) / 6)
    }

    var body: some View {
        GeometryReader { geo in
            let knobRadius: CGFloat = 10
            let trackHeight: CGFloat = 12
            let availableWidth = max(0, geo.size.width - knobRadius * 2)
            let knobX = knobRadius + progress * availableWidth

            ZStack {
                RoundedRectangle(cornerRadius: 999)
                    .fill(riskScoreGradient)
                    .frame(height: trackHeight)
                RoundedRectangle(cornerRadius: 999)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    .frame(height: trackHeight)
                Circle()
                    .fill(thumbColor)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .frame(width: knobRadius * 2, height: knobRadius * 2)
                    .shadow(color: Color.black.opacity(0.15), radius: 2, y: 1)
                    .position(x: knobX, y: geo.size.height / 2)
            }
        }
        .frame(height: 28)
        .accessibilityLabel("Risk score slider")
        .accessibilityValue(score.map { String(format: "%.1f", $0) } ?? "Not available")
    }
}

// MARK: - SRI Donut Tile

struct RiskSRIDonutTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = DashboardRiskTilesViewModel()
    @State private var selectedBucket: Int?
    @State private var editingInstrumentId: Int?

    init() {}
    static let tileID = "risk_sri_donut"
    static let tileName = "SRI Distribution"
    static let iconName = "shield.lefthalf.filled"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if viewModel.loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.snapshot.totalValue == 0 {
                Text("No priced positions available.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                sriContent
            }
        }
        .onAppear { viewModel.load(using: dbManager) }
        .sheet(item: bucketBinding) { bucket in
            bucketSheet(bucket: bucket.value)
        }
        .sheet(item: editBinding) { ident in
            InstrumentEditView(
                instrumentId: ident.value,
                isPresented: Binding(
                    get: { editingInstrumentId != nil },
                    set: { if !$0 { editingInstrumentId = nil } }
                )
            )
            .environmentObject(dbManager)
        }
        .accessibilityElement(children: .combine)
    }

    private var sriContent: some View {
        let snap = viewModel.snapshot
        return VStack(alignment: .leading, spacing: 10) {
            Chart(snap.sriBuckets) { bucket in
                SectorMark(
                    angle: .value("Share", bucket.share),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.2
                )
                .foregroundStyle(riskColor(for: bucket.id))
                .opacity(bucket.share > 0 ? 1 : 0.25)
            }
            .chartLegend(.hidden)
            .frame(height: 160)

            HStack(spacing: 10) {
                Text("High risk (6–7): \(percentText(snap.highRiskShare))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let top = snap.sriBuckets.max(by: { $0.share < $1.share }) {
                    Text("Top: \(top.label) \(percentText(top.share))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(snap.sriBuckets) { bucket in
                    HStack {
                        Circle()
                            .fill(riskColor(for: bucket.id))
                            .frame(width: 10, height: 10)
                        Text(bucket.label)
                        Spacer()
                        Text(percentText(bucket.share))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                        Text("\(bucket.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedBucket = bucket.id }
                }
            }
            .font(.subheadline)
        }
    }

    private func bucketSheet(bucket: Int) -> some View {
        let snap = viewModel.snapshot
        let items = snap.instrumentsBySRI[bucket] ?? []
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SRI \(bucket) Instruments")
                    .font(.headline)
                Spacer()
                Button("Close") { selectedBucket = nil }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
            if items.isEmpty {
                Text("No instruments in this bucket.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            Button(action: { editingInstrumentId = item.id }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Text(liquidityLabel(item.liquidityTier))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(currencyText(item.valueChf, code: snap.baseCurrency))
                                            .font(.caption.monospacedDigit())
                                        Text(percentText(item.weight))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DSColor.surface)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 380, minHeight: 320)
    }

    private var bucketBinding: Binding<BucketSelection?> {
        Binding(
            get: { selectedBucket.map { BucketSelection(value: $0) } },
            set: { selectedBucket = $0?.value }
        )
    }

    private var editBinding: Binding<InstrumentIdent?> {
        Binding(
            get: { editingInstrumentId.map { InstrumentIdent(value: $0) } },
            set: { editingInstrumentId = $0?.value }
        )
    }

    private func liquidityLabel(_ tier: Int) -> String {
        switch tier {
        case 0: return "Liquid"
        case 1: return "Restricted"
        default: return "Illiquid"
        }
    }
}

// MARK: - Liquidity Donut Tile

struct RiskLiquidityDonutTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = DashboardRiskTilesViewModel()
    @State private var selectedBucket: Int?
    @State private var editingInstrumentId: Int?

    init() {}
    static let tileID = "risk_liquidity_donut"
    static let tileName = "Liquidity Mix"
    static let iconName = "drop"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if viewModel.loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.snapshot.totalValue == 0 {
                Text("No priced positions available.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                liquidityContent
            }
        }
        .onAppear { viewModel.load(using: dbManager) }
        .sheet(item: bucketBinding) { bucket in
            bucketSheet(bucket: bucket.value)
        }
        .sheet(item: editBinding) { ident in
            InstrumentEditView(
                instrumentId: ident.value,
                isPresented: Binding(
                    get: { editingInstrumentId != nil },
                    set: { if !$0 { editingInstrumentId = nil } }
                )
            )
            .environmentObject(dbManager)
        }
        .accessibilityElement(children: .combine)
    }

    private var liquidityContent: some View {
        let snap = viewModel.snapshot
        return VStack(alignment: .leading, spacing: 10) {
            Chart(snap.liquidityBuckets) { bucket in
                SectorMark(
                    angle: .value("Share", bucket.share),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.2
                )
                .foregroundStyle(liquidityColor(bucket.id))
                .opacity(bucket.share > 0 ? 1 : 0.25)
            }
            .chartLegend(.hidden)
            .frame(height: 160)
            HStack(spacing: 8) {
                Text("Illiquid + Restricted: \(percentText(snap.illiquidShare))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let largest = snap.liquidityBuckets.max(by: { $0.share < $1.share }) {
                    Text("Top: \(largest.label) \(percentText(largest.share))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(snap.liquidityBuckets) { bucket in
                    HStack {
                        Circle()
                            .fill(liquidityColor(bucket.id))
                            .frame(width: 10, height: 10)
                        Text(bucket.label)
                        Spacer()
                        Text(percentText(bucket.share))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                        Text("\(bucket.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedBucket = bucket.id }
                }
            }
            .font(.subheadline)
        }
    }

    private func bucketSheet(bucket: Int) -> some View {
        let snap = viewModel.snapshot
        let items = snap.instrumentsByLiquidity[bucket] ?? []
        let title = bucket == 0 ? "Liquid" : (bucket == 1 ? "Restricted" : "Illiquid")
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(title) Instruments")
                    .font(.headline)
                Spacer()
                Button("Close") { selectedBucket = nil }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
            if items.isEmpty {
                Text("No instruments in this bucket.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            Button(action: { editingInstrumentId = item.id }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Text("SRI \(item.sri)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(currencyText(item.valueChf, code: snap.baseCurrency))
                                            .font(.caption.monospacedDigit())
                                        Text(percentText(item.weight))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DSColor.surface)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 380, minHeight: 320)
    }

    private var bucketBinding: Binding<BucketSelection?> {
        Binding(
            get: { selectedBucket.map { BucketSelection(value: $0) } },
            set: { selectedBucket = $0?.value }
        )
    }

    private var editBinding: Binding<InstrumentIdent?> {
        Binding(
            get: { editingInstrumentId.map { InstrumentIdent(value: $0) } },
            set: { editingInstrumentId = $0?.value }
        )
    }
}

// MARK: - Overrides Tile

struct RiskOverridesTile: DashboardTile {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = DashboardRiskTilesViewModel()
    @State private var selectedStatus: DashboardOverrideStatus?
    @State private var editingInstrumentId: Int?

    init() {}
    static let tileID = "risk_overrides"
    static let tileName = "Risk Overrides"
    static let iconName = "exclamationmark.shield"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            if viewModel.loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                overridesContent
            }
        }
        .onAppear { viewModel.load(using: dbManager) }
        .sheet(item: statusBinding) { status in
            overridesSheet(status: status.value)
        }
        .sheet(item: editBinding) { ident in
            InstrumentEditView(
                instrumentId: ident.value,
                isPresented: Binding(
                    get: { editingInstrumentId != nil },
                    set: { if !$0 { editingInstrumentId = nil } }
                )
            )
            .environmentObject(dbManager)
        }
        .accessibilityElement(children: .combine)
    }

    private var overridesContent: some View {
        let snap = viewModel.snapshot
        let counts = snap.overrideSummary.counts
        let active = counts[.active] ?? 0
        let expiringSoon = counts[.expiringSoon] ?? 0
        let expired = counts[.expired] ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                statusPill(label: "Active", value: active, tint: .blue.opacity(0.16), textColor: .blue)
                    .onTapGesture { selectedStatus = .active }
                statusPill(label: "Expiring", value: expiringSoon, tint: .orange.opacity(0.18), textColor: .orange)
                    .onTapGesture { selectedStatus = .expiringSoon }
                statusPill(label: "Expired", value: expired, tint: .red.opacity(0.16), textColor: .red)
                    .onTapGesture { selectedStatus = .expired }
                Spacer()
            }
            if let next = snap.overrideSummary.nextExpiry {
                Text("Next expiry: \(next.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No override expiries on file.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if snap.overrides.isEmpty {
                Text("No manual overrides recorded.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                Button("View all overrides") { selectedStatus = .active }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
        }
    }

    private func overridesSheet(status: DashboardOverrideStatus) -> some View {
        let overrides = overrides(for: status)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(label(for: status)) Overrides")
                    .font(.headline)
                Spacer()
                Button("Close") { selectedStatus = nil }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
            if overrides.isEmpty {
                Text("No overrides in this state.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(overrides) { row in
                            Button(action: { editingInstrumentId = row.id }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.instrumentName)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Text("Computed SRI \(row.computedSRI) → Override \(row.overrideSRI ?? row.computedSRI)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Liquidity \(liquidityLabel(row.computedLiquidityTier)) → \(liquidityLabel(row.overrideLiquidityTier ?? row.computedLiquidityTier))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if let expires = row.overrideExpiresAt {
                                            Text(expires.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("No expiry")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text(row.overrideBy ?? "")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DSColor.surface)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 320)
    }

    private func overrides(for status: DashboardOverrideStatus) -> [DatabaseManager.RiskOverrideRow] {
        viewModel.snapshot.overrides.filter { overrideStatus(for: $0) == status }
    }

    private var statusBinding: Binding<OverrideSelection?> {
        Binding(
            get: { selectedStatus.map { OverrideSelection(value: $0) } },
            set: { selectedStatus = $0?.value }
        )
    }

    private var editBinding: Binding<InstrumentIdent?> {
        Binding(
            get: { editingInstrumentId.map { InstrumentIdent(value: $0) } },
            set: { editingInstrumentId = $0?.value }
        )
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

    private func label(for status: DashboardOverrideStatus) -> String {
        switch status {
        case .active: return "Active"
        case .expiringSoon: return "Expiring soon"
        case .expired: return "Expired"
        }
    }

    private func overrideStatus(for row: DatabaseManager.RiskOverrideRow) -> DashboardOverrideStatus {
        guard let expires = row.overrideExpiresAt else { return .active }
        if expires < Date() { return .expired }
        if let soon = Calendar.current.date(byAdding: .day, value: 30, to: Date()), expires < soon {
            return .expiringSoon
        }
        return .active
    }

    private func liquidityLabel(_ tier: Int) -> String {
        switch tier {
        case 0: return "Liquid"
        case 1: return "Restricted"
        default: return "Illiquid"
        }
    }
}
