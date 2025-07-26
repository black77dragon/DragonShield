import SwiftUI
import Charts

struct AllocationDashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationDashboardViewModel()

    // MARK: - Column width constants
    private let leftWidth:  Double = 520
    private let rightWidth: Double = 400

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                OverviewBar(portfolioTotal: viewModel.portfolioTotalFormatted,
                            outOfRange: "\(viewModel.outOfRangeCount)",
                            largestDev: String(format: "%.1f%%", viewModel.largestDeviation),
                            rebalAmount: viewModel.rebalanceAmountFormatted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                HStack(alignment: .top, spacing: 32) {
                    AllocationTreeCard(viewModel: viewModel)
                        .frame(width: leftWidth)

                    VStack(spacing: 32) {
                        DeviationChartsCard(bubbles: viewModel.bubbles,
                                           highlighted: $viewModel.highlightedId)
                        RebalanceListCard(actions: viewModel.actions)
                    }
                    .frame(width: rightWidth)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Asset Allocation Targets")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Import Targets") {}
                Button("Auto-Rebalance") {}.disabled(true)
            }
        }
        .onAppear { viewModel.load(using: dbManager) }
    }

}

// MARK: - Components

struct OverviewBar: View {
    let portfolioTotal: String
    let outOfRange: String
    let largestDev: String
    let rebalAmount: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            OverviewTile(value: portfolioTotal, label: "Portfolio Total")

            Divider().frame(width: 1, height: 40)

            OverviewTile(value: outOfRange,
                         label: "Assets Out of Range",
                         style: .alert)

            Divider().frame(width: 1, height: 40)

            OverviewTile(value: largestDev,
                         label: "Largest Deviation",
                         style: .warning)

            Divider().frame(width: 1, height: 40)

            OverviewTile(value: rebalAmount,
                         label: "Rebalancing Amount")
        }
        .padding(.vertical, 20)
        .background(
            Group {
                if scheme == .dark {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.tertiary, lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.quaternary, lineWidth: 1)
                        )
                }
            }
        )
    }
}

enum TileStyle { case neutral, alert, warning }

struct OverviewTile: View {
    var value: String
    var label: String
    var style: TileStyle = .neutral

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(valueColor)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(tileBackground)
    }

    private var valueColor: Color {
        switch style {
        case .alert:    return .red
        case .warning:  return .orange
        case .neutral:  return .primary
        }
    }

    private var tileBackground: some View {
        Group {
            switch style {
            case .alert:
                LinearGradient(colors: [.red.opacity(0.08), .white],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            case .warning:
                LinearGradient(colors: [.orange.opacity(0.08), .white],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            case .neutral:
                Color.clear
            }
        }
    }
}

struct AllocationTreeCard: View {
    @ObservedObject var viewModel: AllocationDashboardViewModel

    private enum DisplayMode { case percent, chf }
    @State private var displayMode: DisplayMode = .percent
    @State private var expanded: [String: Bool] = [:]

    var body: some View {
        Card {
            HStack {
                Text("Asset Classes")
                    .font(.headline)
                Spacer()
                segmentedPicker
            }
            .padding(.horizontal, 24)
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.assets) { parent in
                        AssetRow(node: parentNode(parent), displayMode: displayMode,
                                 expanded: binding(for: parent.id))
                        if expanded[parent.id] ?? false, let children = parent.children {
                            ForEach(children) { child in
                                AssetRow(node: childNode(child), displayMode: displayMode,
                                         expanded: .constant(false))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if expanded.isEmpty {
                for asset in viewModel.assets { expanded[asset.id] = true }
            }
        }
    }

    private var segmentedPicker: some View {
        Picker("", selection: $displayMode) {
            Text("%").tag(DisplayMode.percent)
            Text("CHF").tag(DisplayMode.chf)
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(get: { expanded[id] ?? false }, set: { expanded[id] = $0 })
    }

    private func parentNode(_ asset: AllocationDashboardViewModel.Asset) -> AllocationNode {
        AllocationNode(id: asset.id, name: asset.name, targetPct: asset.targetPct,
                       targetChf: asset.targetChf, actualPct: asset.actualPct,
                       actualChf: asset.actualChf, isParent: true)
    }

    private func childNode(_ asset: AllocationDashboardViewModel.Asset) -> AllocationNode {
        AllocationNode(id: asset.id, name: asset.name, targetPct: asset.targetPct,
                       targetChf: asset.targetChf, actualPct: asset.actualPct,
                       actualChf: asset.actualChf, isParent: false)
    }
}

struct AssetRow: View {
    let node: AllocationNode
    let displayMode: AllocationTreeCard.DisplayMode
    @Binding var expanded: Bool

    var body: some View {
        HStack(spacing: 0) {
            if node.isParent {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .frame(width: 16)
                    .onTapGesture { expanded.toggle() }
                    .keyboardShortcut(.space, modifiers: [])
            } else {
                Spacer().frame(width: 16)
            }

            Text(node.name)
                .font(node.isParent ? .body.weight(.semibold) : .subheadline.weight(.regular))
                .padding(.leading, 4)

            Spacer()

            Text(formatted(value: node.targetValue(mode: displayMode)))
                .frame(width: 60, alignment: .trailing)
                .font(.system(.footnote, design: .monospaced))
            Text(formatted(value: node.actualValue(mode: displayMode)))
                .frame(width: 60, alignment: .trailing)
                .font(.system(.footnote, design: .monospaced))
            deviationBar
                .frame(width: 60)
            Text(formattedDeviation(node.deviationValue(mode: displayMode)))
                .frame(width: 60, alignment: .trailing)
                .font(.system(.footnote, design: .monospaced))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 24)
        .background(node.isParent ? Color.gray.opacity(0.07) : Color.white)
        .accessibilityElement(children: .combine)
    }

    private func formatted(value: Double) -> String {
        if displayMode == .percent {
            return String(format: "%.1f%%", value)
        } else {
            return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
        }
    }

    private func formattedDeviation(_ value: Double) -> String {
        if displayMode == .percent {
            return String(format: "%+.1f%%", value)
        } else {
            return NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
        }
    }

    private var deviationBar: some View {
        let dev = node.deviationValue(mode: .percent)
        let devColor = dev > 0 ? Color.numberRed : Color.numberGreen
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.gray.opacity(0.25))
            Capsule().fill(devColor).frame(width: abs(dev) * 60)
        }
        .frame(height: 6)
        .offset(x: dev >= 0 ? 30 : -30)
    }
}

struct AllocationNode: Identifiable {
    let id: String
    let name: String
    let targetPct: Double
    let targetChf: Double
    let actualPct: Double
    let actualChf: Double
    let isParent: Bool

    func targetValue(mode: AllocationTreeCard.DisplayMode) -> Double {
        mode == .percent ? targetPct : targetChf
    }

    func actualValue(mode: AllocationTreeCard.DisplayMode) -> Double {
        mode == .percent ? actualPct : actualChf
    }

    func deviationValue(mode: AllocationTreeCard.DisplayMode) -> Double {
        mode == .percent ? (actualPct - targetPct) : (actualChf - targetChf)
    }
}

struct DeviationChartsCard: View {
    let bubbles: [AllocationDashboardViewModel.Bubble]
    @Binding var highlighted: String?

    var body: some View {
        Card("Deviation Bubble Chart") {
            Chart(bubbles) { bubble in
                PointMark(
                    x: .value("Deviation", bubble.deviation),
                    y: .value("Allocation", bubble.allocation)
                )
                .symbolSize(by: .value("Allocation %", bubble.allocation))
                .foregroundStyle(bubble.color)
            }
            .chartXScale(domain: -25...25)
            .chartYScale(domain: 0...40)
            .frame(height: 240)
        }
    }
}

struct RebalanceListCard: View {
    let actions: [AllocationDashboardViewModel.Action]

    var body: some View {
        Card("Top Rebalancing Actions") {
            ForEach(actions.prefix(5)) { action in
                HStack {
                    Text(action.label)
                    Spacer()
                    Text(action.amount)
                        .font(.system(.body, design: .monospaced))
                }
            }
            Button("Execute") {}
                .disabled(true)
        }
    }
}

struct AllocationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationDashboardView().environmentObject(DatabaseManager())
    }
}
