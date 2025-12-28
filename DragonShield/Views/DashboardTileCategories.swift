import SwiftUI

enum DashboardCategory: String, CaseIterable, Identifiable {
    case all
    case overview
    case allocation
    case risk
    case warningsAlerts
    case general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .overview: return "Overview"
        case .allocation: return "Allocation"
        case .risk: return "Risk"
        case .warningsAlerts: return "Warnings & Alerts"
        case .general: return "General"
        }
    }

    var accentColor: Color {
        switch self {
        case .overview: return .blue
        case .allocation: return .indigo
        case .risk: return .orange
        case .warningsAlerts: return .red
        case .general: return .gray
        case .all: return .secondary
        }
    }

    var pillBackground: Color {
        accentColor.opacity(0.12)
    }

    var pillText: Color {
        accentColor
    }

    var isWarningCategory: Bool {
        self == .warningsAlerts
    }
}

enum DashboardTileCategories {
    private static let mapping: [String: DashboardCategory] = [
        TotalValueTile.tileID: .overview,
        TopPositionsTile.tileID: .overview,
        InstitutionsAUMTile.tileID: .overview,
        InstrumentDashboardTile.tileID: .overview,
        "current_date": .overview,

        ThemesOverviewTile.tileID: .allocation,
        CurrencyExposureTile.tileID: .allocation,
        CryptoTop5Tile.tileID: .allocation,

        RiskScoreTile.tileID: .risk,
        RiskSRIDonutTile.tileID: .risk,
        RiskLiquidityDonutTile.tileID: .risk,
        RiskOverridesTile.tileID: .risk,
        RiskBucketsTile.tileID: .risk,

        AccountsNeedingUpdateTile.tileID: .warningsAlerts,
        MissingPricesTile.tileID: .warningsAlerts,
        UpcomingAlertsTile.tileID: .warningsAlerts,

        TodoDashboardTile.tileID: .general,
        AllNotesTile.tileID: .general,
        UnusedInstrumentsTile.tileID: .general,
        UnthemedInstrumentsTile.tileID: .general,
        WeeklyChecklistTile.tileID: .general,
        TextTile.tileID: .general,
    ]

    private static var overrides: [String: DashboardCategory] {
        let dict = UserDefaults.standard.dictionary(forKey: UserDefaultsKeys.dashboardTileCategoryOverrides) as? [String: String] ?? [:]
        return dict.reduce(into: [:]) { result, entry in
            if let cat = DashboardCategory(rawValue: entry.value) {
                result[entry.key] = cat
            }
        }
    }

    private static func persistOverrides(_ values: [String: DashboardCategory]) {
        let raw = values.mapValues { $0.rawValue }
        UserDefaults.standard.set(raw, forKey: UserDefaultsKeys.dashboardTileCategoryOverrides)
    }

    static func setOverride(tileID: String, category: DashboardCategory) {
        var current = overrides
        current[tileID] = category
        persistOverrides(current)
    }

    static func currentOverrides() -> [String: DashboardCategory] {
        overrides
    }

    static func baseCategory(for id: String) -> DashboardCategory {
        mapping[id] ?? .general
    }

    static var warningTileIDs: Set<String> {
        let base = mapping.filter { $0.value == .warningsAlerts }.map(\.key)
        let override = overrides.filter { $0.value == .warningsAlerts }.map(\.key)
        return Set(base).union(override)
    }

    static func category(for id: String) -> DashboardCategory {
        if let override = overrides[id] {
            return override
        }
        return mapping[id] ?? .general
    }
}

struct DashboardCategoryPill: View {
    let category: DashboardCategory
    var body: some View {
        Text(category.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(category.pillBackground)
            )
            .foregroundColor(category.pillText)
            .accessibilityHidden(true)
    }
}
