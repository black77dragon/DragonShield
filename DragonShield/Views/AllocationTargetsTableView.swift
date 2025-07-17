import SwiftUI

struct AllocationAsset: Identifiable {
    let id: String
    var name: String
    var actualPct: Double
    var actualChf: Double
    var targetPct: Double
    var targetChf: Double
    var children: [AllocationAsset]? = nil

    var deviationPct: Double { actualPct - targetPct }
    var deviationChf: Double { actualChf - targetChf }
    var ragColor: Color {
        let diff = abs(deviationPct)
        switch diff {
        case 0..<5: return .success
        case 5..<15: return .warning
        default: return .error
        }
    }
}

final class AllocationTargetsTableViewModel: ObservableObject {
    @Published var assets: [AllocationAsset] = []
    private var db: DatabaseManager?
    private var portfolioValue: Double = 0

    func load(using dbManager: DatabaseManager) {
        self.db = dbManager
        let variance = dbManager.fetchAssetAllocationVariance()
        portfolioValue = variance.portfolioValue
        var actualMap: [String: (pct: Double, chf: Double)] = [:]
        for item in variance.items {
            actualMap[item.assetClassName] = (item.currentPercent, item.currentValue)
        }
        let classes = dbManager.fetchPortfolioClassTargets()
        assets = classes.map { cls in
            let actual = actualMap[cls.name] ?? (0, 0)
            return AllocationAsset(
                id: "class-\(cls.id)",
                name: cls.name,
                actualPct: actual.pct,
                actualChf: actual.chf,
                targetPct: cls.targetPercent,
                targetChf: cls.targetPercent * portfolioValue / 100,
                children: cls.subTargets.map { sub in
                    AllocationAsset(
                        id: "sub-\(sub.id)",
                        name: sub.name,
                        actualPct: sub.currentPercent,
                        actualChf: sub.currentPercent * portfolioValue / 100,
                        targetPct: sub.targetPercent,
                        targetChf: sub.targetPercent * portfolioValue / 100,
                        children: nil
                    )
                }
            )
        }
    }

    func binding(for asset: AllocationAsset) -> Binding<Double> {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else {
            return .constant(asset.targetPct)
        }
        return Binding(get: {
            self.assets[index].targetPct
        }, set: { newVal in
            self.assets[index].targetPct = newVal
            self.assets[index].targetChf = newVal * self.portfolioValue / 100
            if let db = self.db {
                if asset.id.hasPrefix("class-") {
                    if let classId = Int(asset.id.dropFirst(6)) {
                        db.upsertClassTarget(portfolioId: 1, classId: classId, percent: newVal)
                    }
                } else if asset.id.hasPrefix("sub-") {
                    if let subId = Int(asset.id.dropFirst(4)) {
                        db.upsertSubClassTarget(portfolioId: 1, subClassId: subId, percent: newVal)
                    }
                }
            }
        })
    }
}

struct AllocationTargetsTableView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationTargetsTableViewModel()

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }()

    var body: some View {
        List {
            headerRow
            OutlineGroup(viewModel.assets, children: \.children) { asset in
                tableRow(for: asset)
            }
        }
        .onAppear { viewModel.load(using: dbManager) }
        .navigationTitle("Allocation Targets")
    }

    private var headerRow: some View {
        HStack {
            Text("Asset")
                .frame(width: 200, alignment: .leading)
            Text("Target %")
                .frame(width: 80)
            Text("Actual %")
                .frame(width: 80)
            Text("Actual CHF")
                .frame(width: 100)
            Text("Δ %")
                .frame(width: 80)
            Text("Δ CHF")
                .frame(width: 100)
            Text("Status")
                .frame(width: 60)
        }
        .font(.caption)
    }

    @ViewBuilder
    private func tableRow(for asset: AllocationAsset) -> some View {
        HStack {
            Text(asset.name)
                .frame(width: 200, alignment: .leading)
            TextField("", value: viewModel.binding(for: asset), formatter: numberFormatter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80, alignment: .trailing)
            Text(String(format: "%.1f%%", asset.actualPct))
                .frame(width: 80, alignment: .trailing)
            Text(String(format: "%.0f", asset.actualChf))
                .frame(width: 100, alignment: .trailing)
            Text(String(format: "%+.1f%%", asset.deviationPct))
                .frame(width: 80)
                .padding(4)
                .background(asset.ragColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            Text(String(format: "%+.0f", asset.deviationChf))
                .frame(width: 100)
                .padding(4)
                .background(asset.ragColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            Circle()
                .fill(asset.ragColor)
                .frame(width: 16, height: 16)
                .frame(width: 60, alignment: .center)
        }
        .frame(height: 48)
    }
}

struct AllocationTargetsTableView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationTargetsTableView()
            .environmentObject(DatabaseManager())
    }
}
