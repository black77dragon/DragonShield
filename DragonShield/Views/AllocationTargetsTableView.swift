import SwiftUI

enum AllocationInputMode: String {
    case percent
    case chf
}

struct AllocationAsset: Identifiable {
    let id: String
    var name: String
    var actualPct: Double
    var actualChf: Double
    var targetPct: Double
    var targetChf: Double
    var mode: AllocationInputMode
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

    // MARK: - Totals
    var targetPctTotal: Double {
        assets.filter { !$0.id.hasPrefix("sub-") }.map(\.targetPct).reduce(0, +)
    }
    var targetChfTotal: Double {
        assets.filter { !$0.id.hasPrefix("sub-") }.map(\.targetChf).reduce(0, +)
    }
    var actualPctTotal: Double {
        assets.filter { !$0.id.hasPrefix("sub-") }.map(\.actualPct).reduce(0, +)
    }
    var actualChfTotal: Double {
        assets.filter { !$0.id.hasPrefix("sub-") }.map(\.actualChf).reduce(0, +)
    }

    private var totalsValid: Bool {
        targetPctTotal >= 99 && targetPctTotal <= 101
    }

    private static func key(for id: String) -> String { "allocMode-\(id)" }
    static func loadMode(id: String) -> AllocationInputMode {
        if let raw = UserDefaults.standard.string(forKey: key(for: id)),
           let mode = AllocationInputMode(rawValue: raw) {
            return mode
        }
        return .percent
    }
    func saveMode(_ mode: AllocationInputMode, for id: String) {
        UserDefaults.standard.set(mode.rawValue, forKey: Self.key(for: id))
        if let idx = assets.firstIndex(where: { $0.id == id }) {
            assets[idx].mode = mode
        }
    }

    func modeBinding(for asset: AllocationAsset) -> Binding<AllocationInputMode> {
        Binding(get: {
            asset.mode
        }, set: { newMode in
            self.saveMode(newMode, for: asset.id)
        })
    }

    func load(using dbManager: DatabaseManager) {
        self.db = dbManager
        let classes = dbManager.fetchAssetClassesDetailed()
        var classIdMap: [String: Int] = [:]
        var subIdMap: [String: Int] = [:]
        var subToClass: [Int: Int] = [:]
        for cls in classes {
            classIdMap[cls.name] = cls.id
            for sub in dbManager.subAssetClasses(for: cls.id) {
                subIdMap[sub.name] = sub.id
                subToClass[sub.id] = cls.id
            }
        }

        let targetRows = dbManager.fetchPortfolioTargetRecords(portfolioId: 1)
        var classTargetPct: [Int: Double] = [:]
        var classTargetChf: [Int: Double] = [:]
        var subTargetPct: [Int: Double] = [:]
        var subTargetChf: [Int: Double] = [:]
        for row in targetRows {
            if let sub = row.subClassId {
                subTargetPct[sub] = row.percent
                if let amt = row.amountCHF { subTargetChf[sub] = amt }
            } else if let cls = row.classId {
                classTargetPct[cls] = row.percent
                if let amt = row.amountCHF { classTargetChf[cls] = amt }
            }
        }

        var subActual: [Int: Double] = [:]
        var classActual: [Int: Double] = [:]
        var total: Double = 0
        var rateCache: [String: Double] = [:]
        for p in dbManager.fetchPositionReports() {
            guard let subName = p.assetSubClass,
                  let subId = subIdMap[subName],
                  let price = p.currentPrice else { continue }
            var value = p.quantity * price
            let currency = p.instrumentCurrency.uppercased()
            if currency != "CHF" {
                if rateCache[currency] == nil {
                    rateCache[currency] = dbManager.fetchExchangeRates(currencyCode: currency, upTo: nil).first?.rateToChf
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
            let children = dbManager.subAssetClasses(for: cls.id).map { sub in
                let sChf = subActual[sub.id] ?? 0
                let sPct = total > 0 ? sChf / total * 100 : 0
                let tp = subTargetPct[sub.id] ?? 0
                let tc = subTargetChf[sub.id] ?? tp * total / 100
                return AllocationAsset(id: "sub-\(sub.id)", name: sub.name, actualPct: sPct, actualChf: sChf, targetPct: tp, targetChf: tc, mode: Self.loadMode(id: "sub-\(sub.id)"), children: nil)
            }
            return AllocationAsset(id: "class-\(cls.id)", name: cls.name, actualPct: actualPct, actualChf: actualCHF, targetPct: tPct, targetChf: tChf, mode: Self.loadMode(id: "class-\(cls.id)"), children: children)
        }
        assets.sort { lhs, rhs in
            if lhs.targetPct == rhs.targetPct { return lhs.name < rhs.name }
            if lhs.targetPct == 0 { return false }
            if rhs.targetPct == 0 { return true }
            return lhs.targetPct > rhs.targetPct
        }
    }

    func percentBinding(for asset: AllocationAsset) -> Binding<Double> {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else {
            return .constant(asset.targetPct)
        }
        return Binding(get: {
            self.assets[index].targetPct
        }, set: { newVal in
            let val = min(max(0, newVal), 100)
            self.assets[index].targetPct = val
            let chf = val * self.portfolioValue / 100
            self.assets[index].targetChf = chf
            self.tryPersist()
        })
    }

    func chfBinding(for asset: AllocationAsset) -> Binding<Double> {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else {
            return .constant(asset.targetChf)
        }
        return Binding(get: {
            self.assets[index].targetChf
        }, set: { newVal in
            let val = min(max(0, newVal), self.portfolioValue)
            self.assets[index].targetChf = val
            let pct = self.portfolioValue > 0 ? val / self.portfolioValue * 100 : 0
            self.assets[index].targetPct = pct
            self.tryPersist()
        })
    }

    func persistAll() {
        guard let db else { return }
        for asset in assets {
            if asset.id.hasPrefix("class-") {
                if let classId = Int(asset.id.dropFirst(6)) {
                    db.upsertClassTarget(portfolioId: 1, classId: classId, percent: asset.targetPct, amountChf: asset.targetChf)
                }
            } else if asset.id.hasPrefix("sub-") {
                if let subId = Int(asset.id.dropFirst(4)) {
                    db.upsertSubClassTarget(portfolioId: 1, subClassId: subId, percent: asset.targetPct, amountChf: asset.targetChf)
                }
            }
        }
    }

    private func tryPersist() {
        if totalsValid {
            persistAll()
        }
    }
}

struct AllocationTargetsTableView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationTargetsTableViewModel()
    @State private var chfDrafts: [String: String] = [:]
    @FocusState private var focusedChfField: String?

    private let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }()

    private let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }()

    private func formatPercent(_ value: Double) -> String {
        percentFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    private func formatChf(_ value: Double) -> String {
        chfFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    private func formatSignedPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + (percentFormatter.string(from: NSNumber(value: abs(value))) ?? "")
    }

    private func formatSignedChf(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return sign + (chfFormatter.string(from: NSNumber(value: abs(value))) ?? "")
    }

    private func chfTextBinding(for asset: AllocationAsset) -> Binding<String> {
        Binding(
            get: {
                chfDrafts[asset.id] ?? formatChf(asset.targetChf)
            },
            set: { newValue in
                chfDrafts[asset.id] = newValue
                let raw = newValue.replacingOccurrences(of: "'", with: "")
                if let val = Double(raw) {
                    viewModel.chfBinding(for: asset).wrappedValue = val
                }
            }
        )
    }

    private func refreshDrafts() {
        chfDrafts = Dictionary(uniqueKeysWithValues: viewModel.assets.map { ($0.id, formatChf($0.targetChf)) })
    }

    var body: some View {
        List {
            headerRow
            totalsRow
            OutlineGroup(viewModel.assets, children: \.children) { asset in
                tableRow(for: asset)
            }
        }
        .onAppear {
            viewModel.load(using: dbManager)
            refreshDrafts()
        }
        .onDisappear { viewModel.persistAll() }
        .navigationTitle("Allocation Targets")
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Asset")
                .frame(width: 200, alignment: .leading)
            Divider()
            HStack {
                Text("Mode")
                    .frame(width: 80)
                Text("Target %")
                    .frame(width: 80)
                Text("Target CHF")
                    .frame(width: 100)
            }
            Divider()
            HStack {
                Text("Actual %")
                    .frame(width: 80)
                Text("Actual CHF")
                    .frame(width: 100)
            }
            Divider()
            HStack {
                Text("Δ %")
                    .frame(width: 80)
                Text("Δ CHF")
                    .frame(width: 100)
                Text("Status")
                    .frame(width: 60)
            }
        }
        .font(.caption)
    }

    private var totalsRow: some View {
        HStack(spacing: 0) {
            Text("Totals")
                .frame(width: 200, alignment: .leading)
            Divider()
            HStack {
                Spacer()
                    .frame(width: 80)
                totalCellPct
                    .frame(width: 80, alignment: .trailing)
                Text(formatChf(viewModel.targetChfTotal))
                    .frame(width: 100, alignment: .trailing)
            }
            Divider()
            HStack {
                Text("\(formatPercent(viewModel.actualPctTotal))%")
                    .frame(width: 80, alignment: .trailing)
                Text(formatChf(viewModel.actualChfTotal))
                    .frame(width: 100, alignment: .trailing)
            }
            Divider()
            HStack {
                Spacer()
                    .frame(width: 80)
                Spacer()
                    .frame(width: 100)
                Spacer()
                    .frame(width: 60)
            }
        }
        .font(.subheadline)
    }

    private var totalCellPct: some View {
        HStack(spacing: 2) {
            Text("\(formatPercent(viewModel.targetPctTotal))%")
                .fontWeight((99...101).contains(viewModel.targetPctTotal) ? .regular : .bold)
                .foregroundColor((99...101).contains(viewModel.targetPctTotal) ? .primary : .red)
            if !(99...101).contains(viewModel.targetPctTotal) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .help("Target % total must be between 99% and 101%")
            }
        }
    }

    @ViewBuilder
    private func tableRow(for asset: AllocationAsset) -> some View {
        HStack(spacing: 0) {
            Text(asset.name)
                .fontWeight((abs(asset.targetPct) > 0.0001 || abs(asset.targetChf) > 0.01) ? .bold : .regular)
                .frame(width: 200, alignment: .leading)
            Divider()
            HStack {
                Picker("", selection: viewModel.modeBinding(for: asset)) {
                    Text("%" ).tag(AllocationInputMode.percent)
                    Text("CHF").tag(AllocationInputMode.chf)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                if asset.mode == .percent {
                    TextField("", value: viewModel.percentBinding(for: asset), formatter: percentFormatter)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80, alignment: .trailing)
                    Text(formatChf(asset.targetChf))
                        .frame(width: 100, alignment: .trailing)
                } else {
                    Text(formatPercent(asset.targetPct))
                        .frame(width: 80, alignment: .trailing)
                    TextField("", text: chfTextBinding(for: asset))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedChfField, equals: asset.id)
                        .frame(width: 100, alignment: .trailing)
                        .onChange(of: focusedChfField) { newValue in
                            if newValue == asset.id {
                                chfDrafts[asset.id] = chfDrafts[asset.id]?.replacingOccurrences(of: "'", with: "")
                            } else if chfDrafts[asset.id] != nil {
                                chfDrafts[asset.id] = formatChf(asset.targetChf)
                            }
                        }
                }
            }
            Divider()
            HStack {
                Text("\(formatPercent(asset.actualPct))%")
                    .frame(width: 80, alignment: .trailing)
                Text(formatChf(asset.actualChf))
                    .frame(width: 100, alignment: .trailing)
            }
            Divider()
            HStack {
                Text("\(formatSignedPercent(asset.deviationPct))%")
                    .frame(width: 80, alignment: .trailing)
                    .padding(4)
                    .background(asset.ragColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                Text(formatSignedChf(asset.deviationChf))
                    .frame(width: 100, alignment: .trailing)
                    .padding(4)
                    .background(asset.ragColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                Circle()
                    .fill(asset.ragColor)
                    .frame(width: 16, height: 16)
                    .frame(width: 60, alignment: .center)
            }
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
