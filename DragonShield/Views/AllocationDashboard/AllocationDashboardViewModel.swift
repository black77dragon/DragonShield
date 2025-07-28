import SwiftUI

final class AllocationDashboardViewModel: ObservableObject {
    enum TargetKind: String { case percent, amount }
    struct Asset: Identifiable {
        let id: String
        let name: String
        let actualPct: Double
        let actualChf: Double
        let targetPct: Double
        let targetChf: Double
        let targetKind: TargetKind
        let tolerancePercent: Double
        var children: [Asset]? = nil

        var deviationPct: Double { actualPct - targetPct }
        var deviationChf: Double { actualChf - targetChf }
        var relativeDev: Double {
            guard targetPct != 0 else { return 0 }
            return (actualPct - targetPct) / targetPct
        }
    }

    struct Bubble: Identifiable {
        let id: String
        let name: String
        let deviation: Double
        let allocation: Double
        let size: Double
        let color: Color
    }

    struct Action: Identifiable {
        let id = UUID()
        let label: String
        let amount: String
    }

    @Published var assets: [Asset] = []
    @Published var bubbles: [Bubble] = []
    @Published var actions: [Action] = []
    @Published var highlightedId: String?

    private(set) var portfolioValue: Double = 0

    private let tolerance: Double = 5.0

    var outOfRangeCount: Int {
        assets.flatMap { [$0] + ($0.children ?? []) }
            .filter { abs($0.deviationPct) > tolerance }
            .count
    }

    var largestDeviation: Double {
        assets.flatMap { [$0] + ($0.children ?? []) }
            .map { abs($0.deviationPct) }
            .max() ?? 0
    }

    var rebalanceAmount: Double {
        assets.flatMap { [$0] + ($0.children ?? []) }
            .map { abs($0.deviationChf) }
            .reduce(0, +)
    }

    var portfolioTotalFormatted: String {
        NumberFormatter.localizedString(from: NSNumber(value: portfolioValue), number: .decimal)
    }

    var rebalanceAmountFormatted: String {
        NumberFormatter.localizedString(from: NSNumber(value: rebalanceAmount), number: .decimal)
    }

    func load(using db: DatabaseManager) {
        let classes = db.fetchAssetClassesDetailed()
        var classIdMap: [String: Int] = [:]
        var subIdMap: [String: Int] = [:]
        var subToClass: [Int: Int] = [:]
        for cls in classes {
            classIdMap[cls.name] = cls.id
            for sub in db.subAssetClasses(for: cls.id) {
                subIdMap[sub.name] = sub.id
                subToClass[sub.id] = cls.id
            }
        }

        let targets = db.fetchPortfolioTargetRecords(portfolioId: 1)
        var classTargetPct: [Int: Double] = [:]
        var classTargetChf: [Int: Double] = [:]
        var classTargetKind: [Int: TargetKind] = [:]
        var classTolerance: [Int: Double] = [:]
        var subTargetPct: [Int: Double] = [:]
        var subTargetChf: [Int: Double] = [:]
        var subTargetKind: [Int: TargetKind] = [:]
        var subTolerance: [Int: Double] = [:]
        for row in targets {
            if let sub = row.subClassId {
                subTargetPct[sub] = row.percent
                if let amt = row.amountCHF { subTargetChf[sub] = amt }
                subTargetKind[sub] = TargetKind(rawValue: row.targetKind) ?? .percent
                subTolerance[sub] = row.tolerance
            } else if let cls = row.classId {
                classTargetPct[cls] = row.percent
                if let amt = row.amountCHF { classTargetChf[cls] = amt }
                classTargetKind[cls] = TargetKind(rawValue: row.targetKind) ?? .percent
                classTolerance[cls] = row.tolerance
            }
        }

        var subActual: [Int: Double] = [:]
        var classActual: [Int: Double] = [:]
        var total: Double = 0
        var rateCache: [String: Double] = [:]
        for p in db.fetchPositionReports() {
            guard let subName = p.assetSubClass,
                  let subId = subIdMap[subName],
                  let price = p.currentPrice else { continue }
            var value = p.quantity * price
            let currency = p.instrumentCurrency.uppercased()
            if currency != "CHF" {
                if rateCache[currency] == nil {
                    rateCache[currency] = db.fetchExchangeRates(currencyCode: currency, upTo: nil).first?.rateToChf
                }
                guard let r = rateCache[currency] else { continue }
                value *= r
            }
            subActual[subId, default: 0] += value
            if let clsId = subToClass[subId] {
                classActual[clsId, default: 0] += value
            }
            total += value
        }
        portfolioValue = total

        assets = classes.map { cls in
            let actualCHF = classActual[cls.id] ?? 0
            let actualPct = total > 0 ? actualCHF / total * 100 : 0
            let tPct = classTargetPct[cls.id] ?? 0
            let tChf = classTargetChf[cls.id] ?? tPct * total / 100
            let tol = classTolerance[cls.id] ?? 5.0
            let children = db.subAssetClasses(for: cls.id).map { sub in
                let sChf = subActual[sub.id] ?? 0
                let sPct = actualCHF > 0 ? sChf / actualCHF * 100 : 0
                let tp = subTargetPct[sub.id] ?? 0
                let tc = subTargetChf[sub.id] ?? tChf * tp / 100
                let st = subTolerance[sub.id] ?? tol
                let kind = subTargetKind[sub.id] ?? .percent
                return Asset(id: "sub-\(sub.id)",
                             name: sub.name,
                             actualPct: sPct,
                             actualChf: sChf,
                             targetPct: tp,
                             targetChf: tc,
                             targetKind: kind,
                             tolerancePercent: st,
                             children: nil)
            }
            let kind = classTargetKind[cls.id] ?? .percent
            return Asset(id: "class-\(cls.id)",
                         name: cls.name,
                         actualPct: actualPct,
                         actualChf: actualCHF,
                         targetPct: tPct,
                         targetChf: tChf,
                         targetKind: kind,
                         tolerancePercent: tol,
                         children: children)
        }

        bubbles = assets.map { asset in
            Bubble(id: asset.id,
                   name: asset.name,
                   deviation: asset.deviationPct,
                   allocation: asset.actualPct,
                   size: asset.actualPct * 8,
                   color: bubbleColor(for: asset.deviationPct))
        }

        actions = assets.map { asset in
            let amount = asset.deviationChf
            return Action(label: asset.name, amount: NumberFormatter.localizedString(from: NSNumber(value: amount), number: .decimal))
        }
    }

    private func bubbleColor(for deviation: Double) -> Color {
        let absDev = abs(deviation)
        if absDev > tolerance * 2 { return .red }
        if absDev > tolerance { return .orange }
        return .green
    }
}
