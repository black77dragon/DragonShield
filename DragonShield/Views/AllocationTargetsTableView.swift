import SwiftUI
import Charts

enum AllocationInputMode: String {
    case percent
    case chf
}

enum SortColumn {
    case targetPct
    case actualPct
    case deltaPct
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

    /// Difference between target and actual percentage.
    var deviationPct: Double { targetPct - actualPct }
    /// Difference between target and actual CHF amount.
    var deviationChf: Double { targetChf - actualChf }
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
    @Published var sortColumn: SortColumn = .actualPct
    @Published var sortAscending: Bool = false
    private var db: DatabaseManager?
    private var portfolioValue: Double = 0
    /// Mapping of sub-class IDs to their parent class IDs for validation.
    private var subToClass: [Int: Int] = [:]
    /// Asset class IDs that fail sub-class sum validation.
    @Published var invalidClassIds: Set<String> = []

    /// Locate an asset within the top-level list and return the index path.
    /// The second tuple element is the child index if the asset is a sub-class.
    private func indexPath(for id: String) -> (classIndex: Int, childIndex: Int?)? {
        if let idx = assets.firstIndex(where: { $0.id == id }) {
            return (idx, nil)
        }
        for (classIdx, cls) in assets.enumerated() {
            if let childIdx = cls.children?.firstIndex(where: { $0.id == id }) {
                return (classIdx, childIdx)
            }
        }
        return nil
    }

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

    var totalsValid: Bool {
        targetPctTotal >= 99 && targetPctTotal <= 101
    }

    func toggleSort(column: SortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = false
        }
        sortAssets()
    }

    func sortAssets() {
        assets.sort { lhs, rhs in
            let lhsActive = isActive(lhs)
            let rhsActive = isActive(rhs)
            if lhsActive != rhsActive { return lhsActive && !rhsActive }
            let lhsVal: Double
            let rhsVal: Double
           switch sortColumn {
           case .targetPct:
               lhsVal = lhs.targetPct
               rhsVal = rhs.targetPct
           case .actualPct:
               lhsVal = lhs.actualPct
               rhsVal = rhs.actualPct
            case .deltaPct:
                lhsVal = lhs.deviationPct
                rhsVal = rhs.deviationPct
           }
            if lhsVal == rhsVal { return lhs.name < rhs.name }
            return sortAscending ? lhsVal < rhsVal : lhsVal > rhsVal
        }
        updateValidation()
    }

    private func updateValidation() {
        var invalid: Set<String> = []
        for asset in assets where asset.id.hasPrefix("class-") {
            guard let children = asset.children else { continue }
            let parentZero = isZeroPct(asset.targetPct) && isZeroChf(asset.targetChf)
            if parentZero {
                // When the parent has no target but subclasses do, don't flag as invalid
                continue
            }

            let sumPct = children.map(\.targetPct).reduce(0, +)
            // Sub-class target percentages are relative to their parent so totals must be ~100%
            let pctValid = abs(sumPct - 100) <= 1
            let sumChf = children.map(\.targetChf).reduce(0, +)
            // CHF targets should equal the parent target within ±1%
            let tol = abs(asset.targetChf) * 0.01
            let chfValid = abs(sumChf - asset.targetChf) <= tol
            if !(pctValid && chfValid) {
                invalid.insert(asset.id)
            }
        }
        invalidClassIds = invalid
    }

    func rowHasWarning(_ asset: AllocationAsset) -> Bool {
        if asset.id.hasPrefix("class-") {
            return invalidClassIds.contains(asset.id)
        } else if asset.id.hasPrefix("sub-") {
            if let subId = Int(asset.id.dropFirst(4)), let parent = subToClass[subId] {
                return invalidClassIds.contains("class-\(parent)")
            }
        }
        return false
    }

    private func isZeroPct(_ value: Double) -> Bool { abs(value) < 0.0001 }
    private func isZeroChf(_ value: Double) -> Bool { abs(value) < 0.01 }

    func isActive(_ asset: AllocationAsset) -> Bool {
        if !(isZeroPct(asset.targetPct) && isZeroChf(asset.targetChf) &&
             isZeroPct(asset.actualPct) && isZeroChf(asset.actualChf)) {
            return true
        }
        if let children = asset.children {
            for child in children {
                if !(isZeroPct(child.targetPct) && isZeroChf(child.targetChf) &&
                      isZeroPct(child.actualPct) && isZeroChf(child.actualChf)) {
                    return true
                }
            }
        }
        return false
    }

    private func parentHasSubActivity(_ asset: AllocationAsset) -> Bool {
        guard asset.id.hasPrefix("class-"), let children = asset.children else { return false }
        let assetZero = isZeroPct(asset.targetPct) && isZeroChf(asset.targetChf) &&
            isZeroPct(asset.actualPct) && isZeroChf(asset.actualChf)
        guard assetZero else { return false }
        return children.contains { !(isZeroPct($0.targetPct) && isZeroChf($0.targetChf) &&
                                     isZeroPct($0.actualPct) && isZeroChf($0.actualChf)) }
    }

    func rowNeedsOrange(_ asset: AllocationAsset) -> Bool {
        if asset.id.hasPrefix("class-") {
            return parentHasSubActivity(asset)
        } else if asset.id.hasPrefix("sub-") {
            if let subId = Int(asset.id.dropFirst(4)), let parent = subToClass[subId],
               let idx = assets.firstIndex(where: { $0.id == "class-\(parent)" }) {
                return parentHasSubActivity(assets[idx])
            }
        }
        return false
    }

    func rowHasActualButNoTarget(_ asset: AllocationAsset) -> Bool {
        let noTarget = isZeroPct(asset.targetPct) && isZeroChf(asset.targetChf)
        let hasActual = !(isZeroPct(asset.actualPct) && isZeroChf(asset.actualChf))
        return noTarget && hasActual
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
        if let path = indexPath(for: id) {
            if let child = path.childIndex {
                assets[path.classIndex].children?[child].mode = mode
            } else {
                assets[path.classIndex].mode = mode
            }
        }
    }

    func modeBinding(for asset: AllocationAsset) -> Binding<AllocationInputMode> {
        Binding(get: {
            asset.mode
        }, set: { newMode in
            self.saveMode(newMode, for: asset.id)
        })
    }

    func parentClassId(for assetId: String) -> Int? {
        guard assetId.hasPrefix("sub-"), let subId = Int(assetId.dropFirst(4)) else { return nil }
        return subToClass[subId]
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
        self.subToClass = subToClass

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
                let sPct = actualCHF > 0 ? sChf / actualCHF * 100 : 0
                let tp = subTargetPct[sub.id] ?? 0
                let tc = subTargetChf[sub.id] ?? tChf * tp / 100
                return AllocationAsset(id: "sub-\(sub.id)", name: sub.name, actualPct: sPct, actualChf: sChf, targetPct: tp, targetChf: tc, mode: Self.loadMode(id: "sub-\(sub.id)"), children: nil)
            }
            return AllocationAsset(id: "class-\(cls.id)", name: cls.name, actualPct: actualPct, actualChf: actualCHF, targetPct: tPct, targetChf: tChf, mode: Self.loadMode(id: "class-\(cls.id)"), children: children)
        }
        sortAssets()
    }

    func percentBinding(for asset: AllocationAsset) -> Binding<Double> {
        Binding(
            get: {
                guard let path = self.indexPath(for: asset.id) else {
                    return asset.targetPct
                }
                if let child = path.childIndex {
                    return self.assets[path.classIndex].children?[child].targetPct ?? 0
                } else {
                    return self.assets[path.classIndex].targetPct
                }
            },
            set: { newVal in
                let val = min(max(0, newVal), 100)
                guard let path = self.indexPath(for: asset.id) else { return }
                if let child = path.childIndex {
                    self.assets[path.classIndex].children?[child].targetPct = val
                    let parentChf = self.assets[path.classIndex].targetChf
                    let chf = parentChf * val / 100
                    self.assets[path.classIndex].children?[child].targetChf = chf
                    if let asset = self.assets[path.classIndex].children?[child] {
                        self.persistAsset(asset)
                    }
                } else {
                    self.assets[path.classIndex].targetPct = val
                    let chf = val * self.portfolioValue / 100
                    self.assets[path.classIndex].targetChf = chf
                    self.persistAsset(self.assets[path.classIndex])
                }
                DispatchQueue.main.async {
                    self.sortAssets()
                }
            }
        )
    }

    func chfBinding(for asset: AllocationAsset) -> Binding<Double> {
        Binding(
            get: {
                guard let path = self.indexPath(for: asset.id) else {
                    return asset.targetChf
                }
                if let child = path.childIndex {
                    return self.assets[path.classIndex].children?[child].targetChf ?? 0
                } else {
                    return self.assets[path.classIndex].targetChf
                }
            },
            set: { newVal in
                let val = min(max(0, newVal), self.portfolioValue)
                guard let path = self.indexPath(for: asset.id) else { return }
                if let child = path.childIndex {
                    self.assets[path.classIndex].children?[child].targetChf = val
                    let parentChf = self.assets[path.classIndex].targetChf
                    let pct = parentChf > 0 ? val / parentChf * 100 : 0
                    self.assets[path.classIndex].children?[child].targetPct = pct
                    if let asset = self.assets[path.classIndex].children?[child] {
                        self.persistAsset(asset)
                    }
                } else {
                    self.assets[path.classIndex].targetChf = val
                    let pct = self.portfolioValue > 0 ? val / self.portfolioValue * 100 : 0
                    self.assets[path.classIndex].targetPct = pct
                    self.persistAsset(self.assets[path.classIndex])
                }
                DispatchQueue.main.async {
                    self.sortAssets()
                }
            }
        )
    }

    func persistAll() {
        for asset in assets {
            persistAsset(asset)
            if let children = asset.children {
                for child in children {
                    persistAsset(child)
                }
            }
        }
    }

    private func persistAsset(_ asset: AllocationAsset) {
        guard let db else { return }
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

struct AllocationTargetsTableView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = AllocationTargetsTableViewModel()
    @State private var chfDrafts: [String: String] = [:]
    @FocusState private var focusedChfField: String?
    @FocusState private var focusedPctField: String?
    @State private var showDetails = true
    @State private var showDonut = true
    @State private var showDelta = true
    @State private var editingClassId: Int?

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

    private var activeAssets: [AllocationAsset] {
        viewModel.assets.filter { viewModel.isActive($0) }
    }

    private var inactiveAssets: [AllocationAsset] {
        viewModel.assets.filter { !viewModel.isActive($0) }
    }

    private var chartAllocations: [AssetAllocation] {
        viewModel.assets.filter { $0.id.hasPrefix("class-") }.map {
            AssetAllocation(name: $0.name, targetPercent: $0.targetPct, actualPercent: $0.actualPct)
        }
    }

    private var validationMessages: [String] {
        var issues: [String] = []
        if !viewModel.totalsValid {
            issues.append(String(format: "Overall Target %% total is %.1f%%, which is outside the 99\u{2013}101%% tolerance", viewModel.targetPctTotal))
        }
        for asset in viewModel.assets {
            if asset.id.hasPrefix("class-") {
                if viewModel.rowHasWarning(asset) {
                    let sumPct = asset.children?.map(\.targetPct).reduce(0, +) ?? 0
                    issues.append("Total Target % for Asset Class '\(asset.name)' is \(formatPercent(sumPct))%, which is outside the 99\u{2013}101% tolerance")
                } else if viewModel.rowNeedsOrange(asset) {
                    issues.append("No sub-asset class allocation defined for Asset Class '\(asset.name)'")
                }
                if asset.actualChf > 0 && abs(asset.targetChf) < 0.01 && abs(asset.targetPct) < 0.0001 {
                    issues.append("Asset Class '\(asset.name)' has actual CHF but no target defined")
                }
            } else if asset.id.hasPrefix("sub-") {
                if asset.actualChf > 0 && abs(asset.targetChf) < 0.01 && abs(asset.targetPct) < 0.0001 {
                    issues.append("Asset Sub-Class '\(asset.name)' has actual CHF but no target defined")
                }
            }
        }
        return issues
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Table(viewModel.assets, children: \.children) { asset in
                TableColumn("Asset") {
                    Text(asset.name)
                        .fontWeight((abs(asset.targetPct) > 0.0001 || abs(asset.targetChf) > 0.01) ? .bold : .regular)
                }
                TableColumn("Mode") {
                    Picker("", selection: viewModel.modeBinding(for: asset)) {
                        Text("%" ).tag(AllocationInputMode.percent)
                        Text("CHF").tag(AllocationInputMode.chf)
                    }
                    .pickerStyle(.segmented)
                    .tint(.softBlue)
                }
                TableColumn("Target %") {
                    if asset.mode == .percent {
                        TextField("", value: viewModel.percentBinding(for: asset), formatter: percentFormatter)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(formatPercent(asset.targetPct))
                    }
                }
                TableColumn("Target CHF") {
                    HStack {
                        if asset.mode == .chf {
                            TextField("", text: chfTextBinding(for: asset))
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(formatChf(asset.targetChf))
                        }
                        if asset.id.hasPrefix("class-") {
                            let cid = Int(asset.id.dropFirst(6))
                            Button {
                                if let id = cid { editingClassId = id }
                            } label: {
                                Image(systemName: editingClassId == cid ? "pencil.circle.fill" : "pencil.circle")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit targets for \(asset.name)")
                        }
                    }
                }
                TableColumn("Actual %") { item in
                    Text("\(formatPercent(item.actualPct))%")
                        .foregroundColor(item.actualPct == 0 ? .secondary : .primary)
                }
                TableColumn("Actual CHF") { item in
                    Text(formatChf(item.actualChf))
                        .foregroundColor(item.actualChf == 0 ? .secondary : .primary)
                }
                TableColumn("Δ %") { item in
                    let dColor = deltaColor(item.deviationPct)
                    Text(formatSignedPercent(item.deviationPct))
                        .padding(4)
                        .background(dColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                TableColumn("Δ CHF") { item in
                    let dColor = deltaColor(item.deviationPct)
                    Text(formatSignedChf(item.deviationChf))
                        .padding(4)
                        .background(dColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DisclosureGroup(isExpanded: $showDetails) {
                        VStack(alignment: .leading, spacing: 2) {
                            if validationMessages.isEmpty {
                                Text("No issues")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(validationMessages, id: \.self) { msg in
                                    Text("• \(msg)")
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    } label: {
                        Text("Asset Allocation Errors")
                            .font(.headline)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.softBlue)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    DisclosureGroup("Double Donut", isExpanded: $showDonut) {
                        DualRingDonutChart(data: chartAllocations)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 16)
                    .background(Color.softBlue)

                    DisclosureGroup("Delta Bar Asset Class", isExpanded: $showDelta) {
                        DeltaBarLayout(data: chartAllocations)
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color.softBlue)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .trailing) {
            if let cid = editingClassId {
                TargetEditPanel(classId: cid) {
                    viewModel.load(using: dbManager)
                    refreshDrafts()
                    withAnimation { editingClassId = nil }
                }
                .environmentObject(dbManager)
            }
        }
        .onAppear {
            viewModel.load(using: dbManager)
            refreshDrafts()
        }
        .onDisappear { viewModel.persistAll() }
        .navigationTitle("Allocation Targets")
    }

    private func deltaColor(_ value: Double) -> Color {
        if abs(value) > 5 { return .warning }
        if value > 0 { return .success }
        if value < 0 { return .error }
        return .gray
    }

}

struct AllocationTargetsTableView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationTargetsTableView()
            .environmentObject(DatabaseManager())
    }
}

// MARK: - Comparative Visual Components

struct AssetAllocation: Identifiable {
    var id: String { name }
    let name: String
    let targetPercent: Double
    let actualPercent: Double
    var delta: Double { actualPercent - targetPercent }
}

struct DualRingDonutChart: View {
    let data: [AssetAllocation]
    @State private var selected: AssetAllocation?

    private let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]

    private var targetTotal: Double { data.map(\.targetPercent).reduce(0, +) }

    private func color(for name: String) -> Color {
        if let idx = data.firstIndex(where: { $0.name == name }) {
            return colors[idx % colors.count]
        }
        return .blue
    }

    private func item(at angle: Double) -> AssetAllocation? {
        var cumulative = 0.0
        for item in data {
            let end = cumulative + item.actualPercent / 100 * 360
            if angle >= cumulative && angle < end {
                return item
            }
            cumulative = end
        }
        return nil
    }

    private func handleTap(_ location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        let minRadius = min(size.width, size.height) / 2
        guard radius >= minRadius * 0.35, radius <= minRadius else { return }
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        if let item = item(at: angle) {
            selected = item
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Chart(data, id: \.name) { item in
                    SectorMark(
                        angle: .value("Actual", item.actualPercent),
                        innerRadius: .ratio(0.55),
                        outerRadius: .ratio(1.0)
                    )
                    .foregroundStyle(color(for: item.name))
                    .shadow(color: abs(item.delta) > 2 ? .red : .clear, radius: 4)
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        handleTap(value.location, in: geo.size)
                                    }
                            )
                    }
                }
                Chart(data, id: \.name) { item in
                    SectorMark(
                        angle: .value("Target", item.targetPercent),
                        innerRadius: .ratio(0.35),
                        outerRadius: .ratio(0.55)
                    )
                    .foregroundStyle(color(for: item.name).opacity(0.4))
                }

                if abs(targetTotal - 100) > 0.1 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                } else {
                    Text("Target vs Actual")
                        .font(.caption)
                }
            }
            .frame(width: 200, height: 200)
            .chartLegend(.hidden)
            .popover(item: $selected) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.headline)
                    Text(String(format: "Target %.1f%%", item.targetPercent))
                    Text(String(format: "Actual %.1f%%", item.actualPercent))
                    Text(String(format: "Delta %+.1f%%", item.delta))
                }
                .padding()
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(data.indices, id: \.self) { idx in
                    let item = data[idx]
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(color(for: item.name))
                            .frame(width: 12, height: 12)
                        Text(item.name)
                            .frame(width: 80, alignment: .leading)
                        Text(String(format: "%.1f%%", item.targetPercent))
                            .frame(width: 50, alignment: .trailing)
                        Text(String(format: "%.1f%%", item.actualPercent))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .font(.caption)
                }
            }
        }
    }
}

struct DeltaBarLayout: View {
    let data: [AssetAllocation]
    var tolerance: Double = 2.0

    @State private var sortByDelta = true
    @State private var ascending = false

    private let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]

    private func color(for name: String) -> Color {
        if let idx = data.firstIndex(where: { $0.name == name }) {
            return colors[idx % colors.count]
        }
        return .blue
    }

    private var sortedData: [AssetAllocation] {
        data.sorted { lhs, rhs in
            if sortByDelta {
                if lhs.delta == rhs.delta { return lhs.name < rhs.name }
                return ascending ? lhs.delta < rhs.delta : lhs.delta > rhs.delta
            } else {
                return ascending ? lhs.name < rhs.name : lhs.name > rhs.name
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                headerButton(title: "Asset Class", delta: false)
                    .frame(width: 120, alignment: .leading)
                Spacer()
                headerButton(title: "Δ %", delta: true)
                    .frame(width: 50, alignment: .trailing)
            }
            ForEach(sortedData.indices, id: \.self) { idx in
                let item = sortedData[idx]
                HStack(alignment: .center) {
                    Text(item.name)
                        .frame(width: 120, alignment: .leading)
                    GeometryReader { geo in
                        let width = geo.size.width
                        ZStack {
                            HStack {
                                Capsule()
                                    .fill(color(for: item.name).opacity(0.4))
                                    .frame(width: width * item.targetPercent / 100, height: 8)
                                Spacer()
                            }
                            HStack {
                                Spacer()
                                Capsule()
                                    .fill(color(for: item.name))
                                    .frame(width: width * item.actualPercent / 100, height: 8)
                                    .overlay(
                                        Capsule().stroke(Color.red, lineWidth: abs(item.delta) > tolerance ? 2 : 0)
                                    )
                            }
                        }
                    }
                    .frame(height: 8)
                    Text(String(format: "%+.1f%%", item.delta))
                        .padding(4)
                        .background(abs(item.delta) <= tolerance ? Color.success : Color.error)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .frame(width: 60, alignment: .trailing)
                }
                .font(.caption)
            }
        }
    }

    private func headerButton(title: String, delta: Bool) -> some View {
        Button {
            if sortByDelta == delta {
                ascending.toggle()
            } else {
                sortByDelta = delta
                ascending = false
            }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                Image(systemName: ascending && sortByDelta == delta ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
    }
}
