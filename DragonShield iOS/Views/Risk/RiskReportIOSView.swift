#if os(iOS)
import Charts
import SQLite3
import SwiftUI

/// Mobile Risk tab showing portfolio risk score, SRI/liquidity mix, overrides, and top exposures.
struct RiskReportIOSView: View {
    @EnvironmentObject private var dbManager: DatabaseManager
    @State private var snapshot: RiskSnapshot = .empty(baseCurrency: "CHF")
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let riskColors: [Color] = [
        Color.green.opacity(0.7),
        Color.green,
        Color.yellow,
        Color.orange,
        Color.orange.opacity(0.85),
        Color.red.opacity(0.9),
        Color.red,
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if isLoading {
                    ProgressView("Loading risk…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if snapshot.totalValueBase <= 0 {
                    placeholder("No priced positions with FX available in this snapshot.")
                } else {
                    heroGrid
                    if snapshot.missingPrice > 0 || snapshot.missingFx > 0 || snapshot.missingRisk > 0 {
                        dataQualityNotice
                    }
                    heatmapCard
                    sriSection
                    liquiditySection
                    instrumentsSection
                    overridesSection
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Risk")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    load()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .onAppear(perform: load)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Risk Report")
                .font(.largeTitle).bold()
            HStack(spacing: 10) {
                Label(snapshot.baseCurrency.uppercased(), systemImage: "coloncurrencysign.circle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let date = snapshot.positionsAsOf {
                    Label("As of \(DateFormatter.riskDate.string(from: date))", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let fx = snapshot.fxAsOf {
                    Label("FX \(DateFormatter.riskDate.string(from: fx))", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
            reportCard(title: "Portfolio Risk Score", subtitle: "Weighted by position value") {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(snapshot.scoreText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(riskColor(for: snapshot.score))
                    Text(snapshot.category.rawValue)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Gauge(value: snapshot.score, in: 1 ... 7) { Text("Score") } currentValueLabel: {
                    Text(snapshot.scoreText)
                }
                .gaugeStyle(.accessoryLinearCapacity)
                Text("Total value \(formatCurrency(snapshot.totalValueBase, currency: snapshot.baseCurrency))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Label("High risk \(percent(snapshot.highRiskShare))", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("Illiquid \(percent(snapshot.illiquidShare))", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            reportCard(title: "SRI Mix", subtitle: "Tap legend to inspect buckets") {
                if #available(iOS 17.0, *) {
                    Chart(snapshot.sriBuckets) { bucket in
                        SectorMark(
                            angle: .value("Share", bucket.share(totalValue: snapshot.totalValueBase, totalCount: snapshot.totalInstruments, metric: .value)),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(riskColors[max(0, bucket.bucket - 1)])
                        .opacity(bucket.value > 0 ? 1 : 0.2)
                    }
                    .chartLegend(.hidden)
                    .frame(height: 160)
                } else {
                    placeholder("Charts require iOS 17+. Summary shown.")
                }
                HStack {
                    if let top = snapshot.topSRIBucket {
                        riskBadge(top.bucket)
                        Text("\(top.label) — \(formatCurrency(top.value, currency: snapshot.baseCurrency))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Count \(snapshot.totalInstruments)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            reportCard(title: "Liquidity", subtitle: "Tier mix + illiquid share") {
                if #available(iOS 17.0, *) {
                    Chart(snapshot.liquidityBuckets) { bucket in
                        SectorMark(
                            angle: .value("Share", bucket.share(in: snapshot.totalValueBase)),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(liquidityColor(bucket.tier))
                        .opacity(bucket.value > 0 ? 1 : 0.25)
                    }
                    .chartLegend(.hidden)
                    .frame(height: 160)
                } else {
                    placeholder("Charts require iOS 17+. Summary shown.")
                }
                HStack(spacing: 8) {
                    Text("Illiquid \(percent(snapshot.illiquidShare))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    ForEach(snapshot.liquidityBuckets) { bucket in
                        Text("\(bucket.label): \(bucket.count)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            reportCard(title: "Overrides", subtitle: "Active / expiring / expired") {
                let counts = snapshot.overrideCounts
                HStack(spacing: 8) {
                    statusPill(label: "Active", value: counts.active, tint: .blue.opacity(0.15), textColor: .blue)
                    statusPill(label: "Expiring", value: counts.expiringSoon, tint: .orange.opacity(0.18), textColor: .orange)
                    statusPill(label: "Expired", value: counts.expired, tint: .red.opacity(0.15), textColor: .red)
                    Spacer()
                }
                if let next = snapshot.nextOverrideExpiry {
                    Text("Next expiry \(DateFormatter.riskDate.string(from: next))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("No override expiries on file")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var heatmapCard: some View {
        reportCard(title: "Exposure Heatmap", subtitle: "Top asset classes by SRI bucket") {
            if snapshot.heatmapRows.isEmpty {
                placeholder("No valued positions to plot.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(snapshot.heatmapRows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(row.label)
                                    .font(.headline)
                                Spacer()
                                Text(formatCurrency(row.total, currency: snapshot.baseCurrency))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                ForEach(row.cells) { cell in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(riskColors[max(0, cell.bucket - 1)].opacity(max(0.15, cell.share)))
                                        .overlay(
                                            Text(cell.shareText)
                                                .font(.caption2)
                                                .foregroundColor(.primary.opacity(cell.share > 0.15 ? 0.9 : 0.65))
                                        )
                                        .frame(height: 34)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var dataQualityNotice: some View {
        let parts: [String] = [
            snapshot.missingPrice > 0 ? "\(snapshot.missingPrice) missing price" : nil,
            snapshot.missingFx > 0 ? "\(snapshot.missingFx) missing FX" : nil,
            snapshot.missingRisk > 0 ? "\(snapshot.missingRisk) using fallback risk" : nil,
        ].compactMap { $0 }
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(parts.joined(separator: " · "))
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 6)
    }

    private var sriSection: some View {
        reportCard(title: "SRI Distribution", subtitle: "Value-weighted buckets with drill-down") {
            ForEach(snapshot.sriBuckets) { bucket in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(snapshot.instruments.filter { $0.sri == bucket.bucket }.sorted { $0.valueBase > $1.valueBase }.prefix(6)) { row in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name)
                                        .font(.subheadline)
                                    Text("Liq \(row.liquidityLabel)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(row.valueBase, currency: snapshot.baseCurrency))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                } label: {
                    HStack {
                        riskBadge(bucket.bucket)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bucket.label)
                            Text("\(bucket.count) instruments • \(formatCurrency(bucket.value, currency: snapshot.baseCurrency))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(percent(bucket.share(totalValue: snapshot.totalValueBase, totalCount: snapshot.totalInstruments, metric: .value)))
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                Divider()
            }
        }
    }

    private var liquiditySection: some View {
        reportCard(title: "Liquidity Mix", subtitle: "Tier detail with per-instrument list") {
            ForEach(snapshot.liquidityBuckets) { bucket in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(snapshot.instruments.filter { $0.liquidity == bucket.tier }.sorted { $0.valueBase > $1.valueBase }.prefix(6)) { row in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.name)
                                        .font(.subheadline)
                                    Text("SRI \(row.sri)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(row.valueBase, currency: snapshot.baseCurrency))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                } label: {
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(liquidityColor(bucket.tier))
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bucket.label)
                            Text("\(bucket.count) instruments • \(formatCurrency(bucket.value, currency: snapshot.baseCurrency))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(percent(bucket.share(in: snapshot.totalValueBase)))
                            .font(.footnote.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                Divider()
            }
        }
    }

    private var instrumentsSection: some View {
        reportCard(title: "Top Instruments", subtitle: "Sorted by value contribution") {
            let rows = snapshot.instruments.sorted { $0.valueBase > $1.valueBase }.prefix(8)
            if rows.isEmpty {
                placeholder("No priced instruments.")
            } else {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name)
                                .font(.headline)
                            HStack(spacing: 6) {
                                riskBadge(row.sri)
                                Text(row.assetClass)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatCurrency(row.valueBase, currency: snapshot.baseCurrency))
                                .font(.body.monospacedDigit())
                            Text("Weight \(percent(row.weight)) • SRI \(row.sri) • \(row.liquidityLabel)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Divider()
                }
            }
        }
    }

    private var overridesSection: some View {
        reportCard(title: "Risk Overrides", subtitle: "Manual overrides with expiry") {
            if snapshot.overrides.isEmpty {
                placeholder("No manual overrides detected.")
            } else {
                ForEach(snapshot.overrides) { row in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.instrumentName)
                                .font(.headline)
                            Text("Computed SRI \(row.computedSRI)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let overrideSRI = row.overrideSRI {
                                Text("Override SRI \(overrideSRI)")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            if let expires = row.overrideExpiresAt {
                                Text("Expires \(DateFormatter.riskDate.string(from: expires))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No expiry")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Divider()
                }
            }
        }
    }

    // MARK: - Data loading

    private func load() {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        let base = dbManager.baseCurrency.uppercased()
        DispatchQueue.global(qos: .userInitiated).async {
            let snap = buildSnapshot(baseCurrency: base)
            DispatchQueue.main.async {
                snapshot = snap
                isLoading = false
                if snap.totalValueBase <= 0 {
                    errorMessage = "No positions, missing prices, or missing FX for risk scoring."
                }
            }
        }
    }

    private func buildSnapshot(baseCurrency: String) -> RiskSnapshot {
        let positions = dbManager.fetchPositionReportsSafe()
        var agg: [Int: AggregatedInstrument] = [:]
        var positionsAsOf: Date?
        var fxAsOf: Date?
        var missingPrice = 0
        var missingFx = 0
        var missingRisk = 0

        for pr in positions {
            positionsAsOf = maxDate(positionsAsOf, pr.reportDate)
            guard let instrumentId = pr.instrumentId else { continue }
            guard let price = dbManager.getLatestPrice(instrumentId: instrumentId) else { missingPrice += 1; continue }
            let nativeValue = pr.quantity * price.price
            guard abs(nativeValue) > 0.0001 else { continue }
            guard let (baseValue, rateDate) = convertToBase(nativeValue, currency: price.currency, baseCurrency: baseCurrency) else { missingFx += 1; continue }
            fxAsOf = maxDate(fxAsOf, rateDate)

            let risk = resolveRisk(for: instrumentId)
            if risk.usedFallback { missingRisk += 1 }
            let assetClass = pr.assetClass ?? "Unclassified"
            var current = agg[instrumentId] ?? AggregatedInstrument(valueBase: 0, name: pr.instrumentName, assetClass: assetClass, risk: risk)
            current.valueBase += baseValue
            agg[instrumentId] = current
        }

        let totalValue = agg.values.reduce(0) { $0 + $1.valueBase }
        let instruments: [RiskInstrument] = agg.map { key, entry in
            let weight = totalValue > 0 ? entry.valueBase / totalValue : 0
            let blended = min(7.0, Double(entry.risk.sri) + liquidityPenalty(for: entry.risk.liquidityTier))
            return RiskInstrument(
                id: key,
                name: entry.name,
                sri: entry.risk.sri,
                liquidity: entry.risk.liquidityTier,
                valueBase: entry.valueBase,
                weight: weight,
                blended: blended,
                usedFallback: entry.risk.usedFallback,
                manualOverride: entry.risk.manualOverride,
                overrideExpiresAt: entry.risk.overrideExpiresAt,
                assetClass: entry.assetClass,
                mappingVersion: entry.risk.mappingVersion,
                calcMethod: entry.risk.calcMethod
            )
        }

        let weightedSRI = instruments.reduce(0) { $0 + $1.weight * Double($1.sri) }
        let weightedLiquidity = instruments.reduce(0) { $0 + $1.weight * liquidityPenalty(for: $1.liquidity) }
        let score = clampScore(weightedSRI + weightedLiquidity)
        let highRiskShare = instruments.filter { $0.weight > 0 && $0.sri >= 6 }.reduce(0.0) { $0 + $1.weight }
        let illiquidShare = instruments.filter { $0.weight > 0 && $0.liquidity >= 2 }.reduce(0.0) { $0 + $1.weight }

        let sriBuckets = (1 ... 7).map { bucket -> DistributionBucket in
            let rows = instruments.filter { $0.sri == bucket }
            let value = rows.reduce(0) { $0 + $1.valueBase }
            return DistributionBucket(bucket: bucket, label: "SRI \(bucket)", count: rows.count, value: value)
        }
        let liquidityBuckets = [
            LiquidityBucket(tier: 0, label: "Liquid", count: instruments.filter { $0.liquidity == 0 }.count, value: instruments.filter { $0.liquidity == 0 }.reduce(0) { $0 + $1.valueBase }),
            LiquidityBucket(tier: 1, label: "Restricted", count: instruments.filter { $0.liquidity == 1 }.count, value: instruments.filter { $0.liquidity == 1 }.reduce(0) { $0 + $1.valueBase }),
            LiquidityBucket(tier: 2, label: "Illiquid", count: instruments.filter { $0.liquidity >= 2 }.count, value: instruments.filter { $0.liquidity >= 2 }.reduce(0) { $0 + $1.valueBase }),
        ]

        let grouped = Dictionary(grouping: instruments) { $0.assetClass }
        let heatmapRows = grouped.map { classLabel, rows -> HeatmapRow in
            let total = rows.reduce(0.0) { $0 + $1.valueBase }
            let cells = (1 ... 7).map { bucket -> HeatmapCell in
                let value = rows.filter { $0.sri == bucket }.reduce(0.0) { $0 + $1.valueBase }
                let share = total > 0 ? value / total : 0
                return HeatmapCell(bucket: bucket, value: value, share: share)
            }
            return HeatmapRow(id: classLabel, label: classLabel, total: total, totalShare: totalValue > 0 ? total / totalValue : 0, cells: cells)
        }
        .sorted { $0.total > $1.total }
        .prefix(6)
        .map { $0 }

        let overrides = fetchRiskOverrides()

        return RiskSnapshot(
            baseCurrency: baseCurrency,
            positionsAsOf: positionsAsOf,
            fxAsOf: fxAsOf,
            totalValueBase: totalValue,
            weightedSRI: weightedSRI,
            weightedLiquidityPremium: weightedLiquidity,
            score: score,
            category: category(for: score),
            highRiskShare: highRiskShare,
            illiquidShare: illiquidShare,
            sriBuckets: sriBuckets,
            liquidityBuckets: liquidityBuckets,
            heatmapRows: Array(heatmapRows),
            instruments: instruments,
            overrides: overrides,
            missingPrice: missingPrice,
            missingFx: missingFx,
            missingRisk: missingRisk
        )
    }

    // MARK: - Helpers

    private func fetchRiskOverrides() -> [RiskOverrideRow] {
        guard let db = dbManager.db, tableExists("InstrumentRiskProfile") else { return [] }
        var rows: [RiskOverrideRow] = []
        let sql = """
            SELECT irp.instrument_id,
                   i.instrument_name,
                   irp.computed_sri,
                   irp.override_sri,
                   irp.computed_liquidity_tier,
                   irp.override_liquidity_tier,
                   irp.override_reason,
                   irp.override_by,
                   irp.override_expires_at,
                   irp.mapping_version
              FROM InstrumentRiskProfile irp
              JOIN Instruments i ON i.instrument_id = irp.instrument_id
             WHERE irp.manual_override = 1
             ORDER BY i.instrument_name COLLATE NOCASE
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "Instrument #\(id)"
                let computedSRI = Int(sqlite3_column_int(stmt, 2))
                let overrideSRI = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 3))
                let computedLiq = Int(sqlite3_column_int(stmt, 4))
                let overrideLiq = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 5))
                let reason = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let by = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let expires = sqlite3_column_text(stmt, 8).flatMap { iso.date(from: String(cString: $0)) }
                let mapVer = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
                rows.append(RiskOverrideRow(id: id, instrumentName: name, computedSRI: computedSRI, overrideSRI: overrideSRI, computedLiquidityTier: computedLiq, overrideLiquidityTier: overrideLiq, overrideReason: reason, overrideBy: by, overrideExpiresAt: expires, mappingVersion: mapVer))
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }

    private func resolveRisk(for instrumentId: Int) -> InstrumentRisk {
        if let profile = fetchRiskProfile(instrumentId: instrumentId) {
            return InstrumentRisk(
                sri: coerceSRI(profile.effectiveSRI),
                liquidityTier: coerceLiquidityTier(profile.effectiveLiquidityTier),
                usedFallback: false,
                manualOverride: profile.manualOverride,
                overrideExpiresAt: profile.overrideExpiresAt,
                mappingVersion: profile.mappingVersion,
                calcMethod: profile.calcMethod
            )
        }
        if let details = dbManager.fetchInstrumentDetails(id: instrumentId) {
            let defaults = riskDefaults(for: details.subClassId)
            return InstrumentRisk(
                sri: coerceSRI(defaults.sri),
                liquidityTier: coerceLiquidityTier(defaults.liquidity),
                usedFallback: true,
                manualOverride: false,
                overrideExpiresAt: nil,
                mappingVersion: defaults.mappingVersion,
                calcMethod: defaults.calcMethod
            )
        }
        let fallbackSRI = riskConfigInt(key: "risk_default_sri", fallback: 5, minValue: 1, maxValue: 7)
        let fallbackLiq = riskConfigInt(key: "risk_default_liquidity_tier", fallback: 1, minValue: 0, maxValue: 2)
        return InstrumentRisk(
            sri: fallbackSRI,
            liquidityTier: fallbackLiq,
            usedFallback: true,
            manualOverride: false,
            overrideExpiresAt: nil,
            mappingVersion: nil,
            calcMethod: nil
        )
    }

    private func convertToBase(_ value: Double, currency: String, baseCurrency: String) -> (Double, Date)? {
        let code = currency.uppercased()
        let base = baseCurrency.uppercased()
        if base == code { return (value, .distantPast) }
        guard let (rate, rateDate) = dbManager.latestRateToChf(currencyCode: code) else { return nil }
        if base == "CHF" { return (value * rate, rateDate) }
        guard let baseInfo = dbManager.latestRateToChf(currencyCode: base) else { return nil }
        let baseValue = value * rate / baseInfo.rate
        return (baseValue, max(rateDate, baseInfo.date))
    }

    private func fetchRiskProfile(instrumentId: Int) -> RiskProfileRow? {
        guard let db = dbManager.db, tableExists("InstrumentRiskProfile") else { return nil }
        let sql = """
            SELECT computed_sri, computed_liquidity_tier, manual_override,
                   override_sri, override_liquidity_tier, override_expires_at,
                   calc_method, mapping_version
              FROM InstrumentRiskProfile
             WHERE instrument_id = ?
             LIMIT 1
        """
        var stmt: OpaquePointer?
        var row: RiskProfileRow?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let computedSRI = Int(sqlite3_column_int(stmt, 0))
                let computedLiq = Int(sqlite3_column_int(stmt, 1))
                let manual = sqlite3_column_int(stmt, 2) == 1
                let overrideSRI = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 3))
                let overrideLiq = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
                let overrideExpires = sqlite3_column_text(stmt, 5).flatMap { iso.date(from: String(cString: $0)) }
                let calcMethod = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let mappingVersion = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                row = RiskProfileRow(
                    computedSRI: computedSRI,
                    computedLiquidityTier: computedLiq,
                    manualOverride: manual,
                    overrideSRI: overrideSRI,
                    overrideLiquidityTier: overrideLiq,
                    overrideExpiresAt: overrideExpires,
                    calcMethod: calcMethod,
                    mappingVersion: mappingVersion
                )
            }
        }
        sqlite3_finalize(stmt)
        return row
    }

    private func riskDefaults(for subClassId: Int) -> (sri: Int, liquidity: Int, mappingVersion: String?, calcMethod: String?) {
        guard let db = dbManager.db, tableExists("InstrumentRiskMapping") else {
            let fallbackSRI = riskConfigInt(key: "risk_default_sri", fallback: 5, minValue: 1, maxValue: 7)
            let fallbackLiq = riskConfigInt(key: "risk_default_liquidity_tier", fallback: 1, minValue: 0, maxValue: 2)
            return (fallbackSRI, fallbackLiq, nil, nil)
        }
        let sql = """
            SELECT default_sri, default_liquidity_tier, mapping_version
              FROM InstrumentRiskMapping
             WHERE sub_class_id = ?
             LIMIT 1
        """
        var stmt: OpaquePointer?
        var sri: Int?
        var liq: Int?
        var mappingVersion: String?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(subClassId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                sri = Int(sqlite3_column_int(stmt, 0))
                liq = Int(sqlite3_column_int(stmt, 1))
                mappingVersion = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            }
        }
        sqlite3_finalize(stmt)
        let resolvedSRI = sri ?? riskConfigInt(key: "risk_default_sri", fallback: 5, minValue: 1, maxValue: 7)
        let resolvedLiq = liq ?? riskConfigInt(key: "risk_default_liquidity_tier", fallback: 1, minValue: 0, maxValue: 2)
        return (resolvedSRI, resolvedLiq, mappingVersion, nil)
    }

    private func riskConfigInt(key: String, fallback: Int, minValue: Int, maxValue: Int) -> Int {
        guard let db = dbManager.db, tableExists("Configuration") else { return fallback }
        let sql = "SELECT value FROM Configuration WHERE key = ? LIMIT 1"
        var stmt: OpaquePointer?
        var result: Int?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                if sqlite3_column_type(stmt, 0) != SQLITE_NULL {
                    let val = Int(sqlite3_column_int(stmt, 0))
                    result = val
                }
            }
        }
        sqlite3_finalize(stmt)
        let clamped = Swift.max(minValue, Swift.min(maxValue, result ?? fallback))
        return clamped
    }

    private func coerceSRI(_ value: Int) -> Int {
        max(1, min(7, value))
    }

    private func coerceLiquidityTier(_ value: Int) -> Int {
        max(0, min(2, value))
    }

    private func tableExists(_ name: String) -> Bool {
        dbManager.tableExistsIOS(name)
    }

    private func liquidityPenalty(for tier: Int) -> Double {
        switch tier {
        case 0: return 0
        case 1: return 0.5
        default: return 1.0
        }
    }

    private func clampScore(_ value: Double) -> Double {
        max(1.0, min(7.0, value))
    }

    private func category(for score: Double) -> RiskCategory {
        if score <= 2.5 { return .low }
        if score <= 4.0 { return .moderate }
        if score <= 5.5 { return .elevated }
        return .high
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

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func riskBadge(_ value: Int?) -> some View {
        let v = max(1, min(7, value ?? 1))
        return Text("SRI \(v)")
            .font(.caption2).bold()
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(riskColors[v - 1].opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(6)
    }

    private func liquidityColor(_ tier: Int) -> Color {
        switch tier {
        case 0: return .teal
        case 1: return .orange
        default: return .red
        }
    }

    private func riskColor(for score: Double) -> Color {
        switch score {
        case ..<2.5: return .green
        case ..<4.0: return .yellow
        case ..<5.5: return .orange
        default: return .red
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
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
        .cornerRadius(14)
    }

    private func reportCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundColor(.secondary)
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?): return max(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }
}

// MARK: - Models

private struct RiskSnapshot {
    let baseCurrency: String
    let positionsAsOf: Date?
    let fxAsOf: Date?
    let totalValueBase: Double
    let weightedSRI: Double
    let weightedLiquidityPremium: Double
    let score: Double
    let category: RiskCategory
    let highRiskShare: Double
    let illiquidShare: Double
    let sriBuckets: [DistributionBucket]
    let liquidityBuckets: [LiquidityBucket]
    let heatmapRows: [HeatmapRow]
    let instruments: [RiskInstrument]
    let overrides: [RiskOverrideRow]
    let missingPrice: Int
    let missingFx: Int
    let missingRisk: Int

    var totalInstruments: Int { instruments.count }
    var scoreText: String { totalValueBase > 0 ? String(format: "%.1f", score) : "—" }
    var topSRIBucket: DistributionBucket? { sriBuckets.max(by: { $0.value < $1.value }) }
    var overrideCounts: OverrideCounts {
        overrides.reduce(into: OverrideCounts()) { acc, row in
            let status: OverrideCounts.Status
            if let expires = row.overrideExpiresAt {
                if expires < Date() { status = .expired }
                else if let soon = Calendar.current.date(byAdding: .day, value: 30, to: Date()), expires < soon {
                    status = .expiringSoon
                } else {
                    status = .active
                }
            } else {
                status = .active
            }
            acc.increment(status)
        }
    }
    var nextOverrideExpiry: Date? {
        overrides.compactMap { $0.overrideExpiresAt }.sorted().first
    }

    static func empty(baseCurrency: String) -> RiskSnapshot {
        RiskSnapshot(
            baseCurrency: baseCurrency,
            positionsAsOf: nil,
            fxAsOf: nil,
            totalValueBase: 0,
            weightedSRI: 0,
            weightedLiquidityPremium: 0,
            score: 0,
            category: .low,
            highRiskShare: 0,
            illiquidShare: 0,
            sriBuckets: (1 ... 7).map { DistributionBucket(bucket: $0, label: "SRI \($0)", count: 0, value: 0) },
            liquidityBuckets: [
                LiquidityBucket(tier: 0, label: "Liquid", count: 0, value: 0),
                LiquidityBucket(tier: 1, label: "Restricted", count: 0, value: 0),
                LiquidityBucket(tier: 2, label: "Illiquid", count: 0, value: 0),
            ],
            heatmapRows: [],
            instruments: [],
            overrides: [],
            missingPrice: 0,
            missingFx: 0,
            missingRisk: 0
        )
    }
}

private struct DistributionBucket: Identifiable {
    let id = UUID()
    let bucket: Int
    let label: String
    let count: Int
    let value: Double

    func share(totalValue: Double, totalCount: Int, metric: SRIMetric) -> Double {
        switch metric {
        case .count:
            guard totalCount > 0 else { return 0 }
            return Double(count) / Double(totalCount)
        case .value:
            guard totalValue > 0 else { return 0 }
            return value / totalValue
        }
    }
}

private struct LiquidityBucket: Identifiable {
    let id = UUID()
    let tier: Int
    let label: String
    let count: Int
    let value: Double

    func share(in total: Double) -> Double {
        guard total > 0 else { return 0 }
        return value / total
    }
}

private struct HeatmapRow: Identifiable {
    let id: String
    let label: String
    let total: Double
    let totalShare: Double
    let cells: [HeatmapCell]
}

private struct HeatmapCell: Identifiable {
    let id = UUID()
    let bucket: Int
    let value: Double
    let share: Double
    var shareText: String { share > 0 ? String(format: "%.0f%%", share * 100) : "" }
}

private struct RiskOverrideRow: Identifiable {
    let id: Int
    let instrumentName: String
    let computedSRI: Int
    let overrideSRI: Int?
    let computedLiquidityTier: Int
    let overrideLiquidityTier: Int?
    let overrideReason: String?
    let overrideBy: String?
    let overrideExpiresAt: Date?
    let mappingVersion: String?
}

private struct RiskProfileRow {
    let computedSRI: Int
    let computedLiquidityTier: Int
    let manualOverride: Bool
    let overrideSRI: Int?
    let overrideLiquidityTier: Int?
    let overrideExpiresAt: Date?
    let calcMethod: String?
    let mappingVersion: String?

    var effectiveSRI: Int { manualOverride ? (overrideSRI ?? computedSRI) : computedSRI }
    var effectiveLiquidityTier: Int { manualOverride ? (overrideLiquidityTier ?? computedLiquidityTier) : computedLiquidityTier }
}

private struct RiskInstrument: Identifiable {
    let id: Int
    let name: String
    let sri: Int
    let liquidity: Int
    let valueBase: Double
    let weight: Double
    let blended: Double
    let usedFallback: Bool
    let manualOverride: Bool
    let overrideExpiresAt: Date?
    let assetClass: String
    let mappingVersion: String?
    let calcMethod: String?

    var liquidityLabel: String {
        switch liquidity {
        case 0: return "Liquid"
        case 1: return "Restricted"
        default: return "Illiquid"
        }
    }
}

private struct AggregatedInstrument {
    var valueBase: Double
    var name: String
    var assetClass: String
    var risk: InstrumentRisk
}

private struct InstrumentRisk {
    let sri: Int
    let liquidityTier: Int
    let usedFallback: Bool
    let manualOverride: Bool
    let overrideExpiresAt: Date?
    let mappingVersion: String?
    let calcMethod: String?
}

private enum SRIMetric: CaseIterable {
    case count, value
    var title: String {
        switch self {
        case .count: return "Count"
        case .value: return "Value"
        }
    }
}

private enum RiskCategory: String {
    case low = "Low"
    case moderate = "Moderate"
    case elevated = "Elevated"
    case high = "High"
}

private struct OverrideCounts {
    enum Status { case active, expiringSoon, expired }
    var active = 0
    var expiringSoon = 0
    var expired = 0

    mutating func increment(_ status: Status) {
        switch status {
        case .active: active += 1
        case .expiringSoon: expiringSoon += 1
        case .expired: expired += 1
        }
    }
}

private extension DateFormatter {
    static let riskDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
#endif
