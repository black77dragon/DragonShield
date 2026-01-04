import SwiftUI

struct TradingProfileView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var selection: TradingProfileSection = .profile
    @State private var profile: TradingProfileRow? = nil
    @State private var coordinates: [TradingProfileCoordinateRow] = []
    @State private var dominance: [TradingProfileDominanceRow] = []
    @State private var strategyFits: [TradingProfileStrategyFitRow] = []
    @State private var reviewEntries: [TradingProfileReviewLogRow] = []
    @State private var showSettings = false

    var body: some View {
        ZStack {
            TradingProfileBackground()
            HStack(spacing: 0) {
                TradingProfileRail(selection: $selection, snapshot: snapshot)
                    .frame(width: DSLayout.sidebarWidth)
                Divider()
                VStack(spacing: 0) {
                    TradingProfileTopBar(
                        snapshot: snapshot,
                        onOpenSettings: { showSettings = true }
                    )
                    ScrollView {
                        VStack(alignment: .leading, spacing: DSLayout.spaceL) {
                            content(for: selection)
                        }
                        .padding(DSLayout.spaceL)
                    }
                }
            }
        }
        .navigationTitle("Trading Profile")
        .onAppear(perform: loadProfileData)
        .sheet(isPresented: $showSettings) {
            TradingProfileSettingsView(showsCancel: true)
                .environmentObject(dbManager)
        }
    }

    private var snapshot: TradingProfileSnapshot {
        let name = profile?.name ?? "Trading Profile"
        let type = profile?.type ?? "-"
        return TradingProfileSnapshot(
            name: name,
            profileType: type
        )
    }

    @ViewBuilder
    private func content(for section: TradingProfileSection) -> some View {
        if profile == nil {
            EmptyProfileState()
        } else {
        switch section {
        case .profile:
            profileContent
        case .coordinates:
            coordinatesContent
        case .reviewLog:
            reviewLogContent
        }
        }
    }

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceL) {
            SectionTitle(title: "Investment Profile", subtitle: "Identity and governance anchors.")
            DSCard {
                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    Text("Profile Identity")
                        .dsHeaderSmall()
                    KeyValueRow(title: "Type", value: profile?.type ?? "-")
                    KeyValueRow(
                        title: "Primary Objective",
                        value: profile?.primaryObjective ?? "-"
                    )
                    HStack(spacing: DSLayout.spaceL) {
                        KeyValueRow(title: "Last Review", value: profile?.lastReviewDate ?? "-")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        KeyValueRow(title: "Next Review", value: profile?.nextReviewText ?? "-")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Constraint: No P&L or charts in this view.")
                        .dsCaption()
                }
            }

            DSCard {
                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    Text("Trading Strategy Executive Summary")
                        .dsHeaderSmall()
                    Text(profile?.tradingStrategyExecutiveSummary ?? "-")
                        .dsBody()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DSLayout.spaceL) {
                    dominanceStackCard
                }
                VStack(alignment: .leading, spacing: DSLayout.spaceL) {
                    dominanceStackCard
                }
            }

            DSCard {
                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    Text("Strategy Compatibility")
                        .dsHeaderSmall()
                    ForEach(strategyFits) { row in
                        StrategyFitRowView(
                            name: row.name,
                            label: row.statusLabel,
                            tone: StatusTone(dbValue: row.statusTone) ?? .neutral,
                            reason: row.reason
                        )
                        if row.id != strategyFits.last?.id {
                            Divider()
                        }
                    }
                }
            }

            DSCard {
                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    Text("Control Flow (Mental Model)")
                        .dsHeaderSmall()
                    VStack(alignment: .leading, spacing: DSLayout.spaceS) {
                        FlowStepRow(title: "Profile Identity")
                        FlowConnector()
                        FlowStepRow(title: "Macro Regime")
                        FlowConnector()
                        FlowStepRow(title: "Allowed Strategies")
                        FlowConnector()
                        FlowStepRow(title: "Position Sizing")
                        FlowConnector()
                        FlowStepRow(title: "Actions or Blocks")
                    }
                }
            }
        }
    }

    private var coordinatesContent: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceL) {
            SectionTitle(title: "Integrated Profile Coordinates & Weighting", subtitle: "What defines my investor identity mechanically, and what matters most?")
            profileCoordinatesCard
        }
    }

    private var profileCoordinatesCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                HStack {
                    Text("Profile Coordinates & Weighting")
                        .dsHeaderSmall()
                }
                if coordinates.isEmpty {
                    Text("No profile coordinates configured.")
                        .dsBodySmall()
                } else {
                    VStack(spacing: DSLayout.spaceM) {
                        ForEach($coordinates) { $coordinate in
                            let descriptor = descriptor(for: coordinate.title)
                            ProfileCoordinateRow(
                                title: descriptor?.displayTitle ?? coordinate.title,
                                weight: coordinate.weightPercent,
                                value: $coordinate.value,
                                minLabel: descriptor?.minLabel,
                                maxLabel: descriptor?.maxLabel,
                                isEditable: false
                            )
                        }
                    }
                }
            }
        }
    }

    private var dominanceStackCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                Text("Dominance Stack")
                    .dsHeaderSmall()
                DominanceList(
                    title: "What Defines Me (Do Not Violate)",
                    icon: "checkmark.seal.fill",
                    tone: .success,
                    items: dominancePrimaryTexts
                )
                DominanceList(
                    title: "Secondary Modulators",
                    icon: "circle.fill",
                    tone: .neutral,
                    items: dominanceSecondaryTexts
                )
                DominanceList(
                    title: "Should Not Drive Decisions",
                    icon: "xmark.octagon.fill",
                    tone: .danger,
                    items: dominanceAvoidTexts
                )
            }
        }
    }

    private var reviewLogContent: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceL) {
            SectionTitle(title: "Review Log", subtitle: "Immutable decision memory.")
            DSCard {
                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    ForEach(reviewEntries) { entry in
                        ReviewLogEntryRow(entry: entry)
                        if entry.id != reviewEntries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var dominancePrimaryTexts: [String] {
        normalizedList(dominance.filter { $0.category == "primary" }.map { $0.text })
    }

    private var dominanceSecondaryTexts: [String] {
        normalizedList(dominance.filter { $0.category == "secondary" }.map { $0.text })
    }

    private var dominanceAvoidTexts: [String] {
        normalizedList(dominance.filter { $0.category == "avoid" }.map { $0.text })
    }

    private func normalizedList(_ items: [String]) -> [String] {
        items.isEmpty ? ["-"] : items
    }

    private func descriptor(for title: String) -> ProfileCoordinateDescriptor? {
        let normalized = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        switch normalized {
        case "timehorizon":
            return ProfileCoordinateDescriptor(
                displayTitle: "Time Horizon",
                minLabel: "1 (days)",
                maxLabel: "10 (3+ years)"
            )
        case "beliefupdating", "beliefupdatingstyle":
            return ProfileCoordinateDescriptor(
                displayTitle: "Belief Updating Style",
                minLabel: "1 (conviction)",
                maxLabel: "10 (Bayesian)"
            )
        case "losssensitivity":
            return ProfileCoordinateDescriptor(
                displayTitle: "Loss Sensitivity",
                minLabel: "1 (drawdown-tolerant)",
                maxLabel: "10 (drawdown-averse)"
            )
        case "positionconcentration":
            return ProfileCoordinateDescriptor(
                displayTitle: "Position Concentration",
                minLabel: "1 (very diversified)",
                maxLabel: "10 (highly concentrated)"
            )
        case "decisiontrigger":
            return ProfileCoordinateDescriptor(
                displayTitle: "Decision Trigger",
                minLabel: "1 (price-only)",
                maxLabel: "10 (narrative-driven)"
            )
        case "marketalignment":
            return ProfileCoordinateDescriptor(
                displayTitle: "Market Alignment",
                minLabel: "1 (contrarian)",
                maxLabel: "10 (trend-aligned)"
            )
        case "activitylevel":
            return ProfileCoordinateDescriptor(
                displayTitle: "Activity Level",
                minLabel: "1 (very active)",
                maxLabel: "10 (very infrequent)"
            )
        case "researchstyle":
            return ProfileCoordinateDescriptor(
                displayTitle: "Research Style",
                minLabel: "1 (deep single idea)",
                maxLabel: "10 (broad macro scan)"
            )
        case "erroracceptance":
            return ProfileCoordinateDescriptor(
                displayTitle: "Error Acceptance",
                minLabel: "1 (defensive)",
                maxLabel: "10 (high tolerance)"
            )
        default:
            return nil
        }
    }

    private func loadProfileData() {
        let current = dbManager.fetchDefaultTradingProfile()
        profile = current
        guard let current else {
            coordinates = []
            dominance = []
            strategyFits = []
            reviewEntries = []
            return
        }
        coordinates = dbManager.fetchTradingProfileCoordinates(profileId: current.id)
        dominance = dbManager.fetchTradingProfileDominance(profileId: current.id)
        strategyFits = dbManager.fetchTradingProfileStrategyFits(profileId: current.id)
        reviewEntries = dbManager.fetchTradingProfileReviewLogs(profileId: current.id)
    }
}

private enum TradingProfileSection: String, CaseIterable, Identifiable {
    case profile = "Profile"
    case coordinates = "Profile Coordinates & Weighting"
    case reviewLog = "Review Log"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .profile: return "person.text.rectangle"
        case .coordinates: return "slider.horizontal.3"
        case .reviewLog: return "clock.arrow.circlepath"
        }
    }
}

private struct TradingProfileSnapshot {
    let name: String
    let profileType: String
}

private struct TradingProfileRail: View {
    @Binding var selection: TradingProfileSection
    let snapshot: TradingProfileSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.name)
                    .dsHeaderSmall()
                Text(snapshot.profileType)
                    .dsCaption()
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                ForEach(TradingProfileSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(section.rawValue)
                                .font(.ds.bodySmall)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(selection == section ? DSColor.surfaceHighlight : Color.clear)
                        .cornerRadius(DSLayout.radiusM)
                        .overlay(
                            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                                .stroke(selection == section ? DSColor.borderStrong : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                Text("Governance first, execution second.")
                    .dsCaption()
            }
        }
        .padding(DSLayout.spaceM)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DSColor.surfaceSecondary)
    }
}

private struct TradingProfileTopBar: View {
    let snapshot: TradingProfileSnapshot
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: DSLayout.spaceM) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trading Profile")
                    .dsHeaderSmall()
                Text("\(snapshot.name) / \(snapshot.profileType)")
                    .dsCaption()
            }
            Spacer()
            Spacer(minLength: 0)
            Button {
                onOpenSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
            }
            .buttonStyle(DSButtonStyle(type: .secondary))
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceM)
        .background(
            LinearGradient(
                colors: [DSColor.surfaceSecondary, DSColor.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            Rectangle()
                .fill(DSColor.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

private struct TradingProfileBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DSColor.background,
                    DSColor.surfaceSecondary.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(DSColor.accentMain.opacity(0.06))
                .frame(width: 420, height: 420)
                .offset(x: -260, y: -240)
                .blur(radius: 30)
            RoundedRectangle(cornerRadius: 180, style: .continuous)
                .fill(DSColor.accentWarning.opacity(0.08))
                .frame(width: 460, height: 220)
                .rotationEffect(.degrees(12))
                .offset(x: 320, y: -140)
                .blur(radius: 26)
        }
        .ignoresSafeArea()
    }
}

private struct EmptyProfileState: View {
    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spaceS) {
                Text("No Trading Profile configured")
                    .dsHeaderSmall()
                Text("Create or edit one in Trading Profile Settings under Configuration.")
                    .dsBodySmall()
            }
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .dsHeaderMedium()
            Text(subtitle)
                .dsBodySmall()
        }
    }
}

private struct KeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .dsCaption()
            Text(value)
                .dsBody()
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProfileCoordinateRow: View {
    let title: String
    let weight: Double
    @Binding var value: Double
    let minLabel: String?
    let maxLabel: String?
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .dsBody()
                Spacer()
                Text("Weight \(String(format: "%.0f", weight))%")
                    .dsCaption()
            }
            HStack(spacing: 12) {
                Slider(value: $value, in: 0...10, step: 0.5)
                    .accentColor(DSColor.accentMain)
                    .disabled(!isEditable)
                Text(String(format: "%.1f", value))
                    .font(.ds.monoSmall)
                    .foregroundStyle(DSColor.textSecondary)
                    .frame(width: 44, alignment: .trailing)
            }
            if let minLabel, let maxLabel {
                HStack {
                    Text(minLabel)
                        .dsCaption()
                    Spacer()
                    Text(maxLabel)
                        .dsCaption()
                }
                .foregroundStyle(DSColor.textSecondary)
            }
        }
    }
}

private struct DominanceList: View {
    let title: String
    let icon: String
    let tone: StatusTone
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            Text(title)
                .font(.ds.body.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .foregroundStyle(tone.color)
                            .font(.system(size: 12, weight: .semibold))
                        Text(item)
                            .dsBody()
                    }
                }
            }
        }
    }
}

private struct SignalList: View {
    let title: String
    let icon: String
    let tone: StatusTone
    let signals: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            Text(title)
                .font(.ds.body.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(signals, id: \.self) { signal in
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .foregroundStyle(tone.color)
                            .font(.system(size: 12, weight: .semibold))
                        Text(signal)
                            .dsBody()
                    }
                }
            }
        }
    }
}

private struct StatusChip: View {
    let title: String
    let value: String
    let icon: String
    let tone: StatusTone

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                Text(value)
                    .font(.ds.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tone.color.opacity(0.12))
        .foregroundStyle(tone.color)
        .cornerRadius(DSLayout.radiusM)
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                .stroke(tone.color.opacity(0.4), lineWidth: 1)
        )
    }
}

private enum StatusTone {
    case success
    case warning
    case danger
    case accent
    case neutral

    init?(dbValue: String) {
        switch dbValue.lowercased() {
        case "success":
            self = .success
        case "warning":
            self = .warning
        case "danger":
            self = .danger
        case "accent":
            self = .accent
        case "neutral":
            self = .neutral
        default:
            return nil
        }
    }

    var color: Color {
        switch self {
        case .success: return DSColor.accentSuccess
        case .warning: return DSColor.accentWarning
        case .danger: return DSColor.accentError
        case .accent: return DSColor.accentMain
        case .neutral: return DSColor.textSecondary
        }
    }

    var iconName: String {
        switch self {
        case .danger:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .neutral:
            return "minus.circle.fill"
        case .success, .accent:
            return "checkmark.circle.fill"
        }
    }
}

private struct StatusBadge: View {
    let label: String
    let tone: StatusTone

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tone.iconName)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.ds.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tone.color.opacity(0.12))
        .foregroundStyle(tone.color)
        .cornerRadius(DSLayout.radiusS)
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.radiusS)
                .stroke(tone.color.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct StrategyFitRowView: View {
    let name: String
    let label: String
    let tone: StatusTone
    let reason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .dsBody()
                Spacer()
                StatusBadge(label: label, tone: tone)
            }
            if let reason, !reason.isEmpty {
                Text("Reason: \(reason)")
                    .dsBodySmall()
            }
        }
    }
}

private struct ReviewLogEntryRow: View {
    let entry: TradingProfileReviewLogRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.date)
                .dsCaption()
            HStack(spacing: DSLayout.spaceM) {
                KeyValueRow(title: "Event", value: entry.event)
                    .frame(maxWidth: .infinity, alignment: .leading)
                KeyValueRow(title: "Decision", value: entry.decision)
                    .frame(maxWidth: .infinity, alignment: .leading)
                KeyValueRow(title: "Confidence", value: entry.confidence)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Notes: \(entry.notes ?? "-")")
                .dsBodySmall()
        }
    }
}

private struct FlowStepRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(DSColor.textSecondary)
            Text(title)
                .dsBody()
        }
    }
}

private struct FlowConnector: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColor.textSecondary)
            Text("")
        }
        .padding(.leading, 2)
    }
}

private struct ProfileCoordinateDescriptor {
    let displayTitle: String
    let minLabel: String
    let maxLabel: String
}

struct TradingProfileView_Previews: PreviewProvider {
    static var previews: some View {
        TradingProfileView()
            .environmentObject(DatabaseManager())
            .environmentObject(DatabaseManager().preferences)
    }
}
