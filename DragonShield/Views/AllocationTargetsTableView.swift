import SwiftUI

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
                db.upsertClassTarget(portfolioId: 1, classId: classId, percent: asset.targetPct, amountChf: asset.targetChf, tolerance: 5)
            }
        } else if asset.id.hasPrefix("sub-") {
            if let subId = Int(asset.id.dropFirst(4)) {
                db.upsertSubClassTarget(portfolioId: 1, subClassId: subId, percent: asset.targetPct, amountChf: asset.targetChf, tolerance: 5)
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
    @State private var editingClassId: Int?
    @State private var panelOffset: CGSize = .zero
    @State private var lastPanelOffset: CGSize = .zero
    @Environment(\.colorScheme) private var scheme

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
        HStack(alignment: .top, spacing: 16) {
            List {
                headerRow
                totalsRow
                OutlineGroup(activeAssets, children: \.children) { asset in
                    tableRow(for: asset)
                }
                    if !inactiveAssets.isEmpty {
                        Divider()
                        inactiveHeader
                        OutlineGroup(inactiveAssets, children: \.children) { asset in
                            tableRow(for: asset)
                        }
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

                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 320)
            .background(cardBackground)
        }
        .padding(.horizontal, 24)
        .overlay {
            if let cid = editingClassId {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                TargetEditPanel(classId: cid) {
                    viewModel.load(using: dbManager)
                    refreshDrafts()
                    withAnimation { editingClassId = nil }
                }
                .environmentObject(dbManager)
                .frame(width: 800, height: 600)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 20)
                .offset(panelOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            panelOffset = CGSize(width: lastPanelOffset.width + value.translation.width,
                                                 height: lastPanelOffset.height + value.translation.height)
                        }
                        .onEnded { _ in
                            lastPanelOffset = panelOffset
                        }
                )
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
                sortHeader(title: "Target %", column: .targetPct)
                    .frame(width: 80)
                Text("Target CHF")
                    .frame(width: 100)
            }
            Divider()
            HStack {
                sortHeader(title: "Actual %", column: .actualPct)
                    .frame(width: 80)
                Text("Actual CHF")
                    .frame(width: 100)
            }
            Divider()
            HStack {
                Text("St")
                    .frame(width: 30)
                Text("%-Deviation")
                    .frame(width: 120)
            }
        }
        .font(.system(size: 12, weight: .semibold))
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
                    .frame(width: 30)
                Spacer()
                    .frame(width: 120)
            }
        }
        .font(.subheadline)
        .background(viewModel.totalsValid ? Color.white : Color.paleRed)
    }

    private var inactiveHeader: some View {
        HStack(spacing: 0) {
            Text("Inactive Assets")
                .fontWeight(.semibold)
                .frame(width: 200, alignment: .leading)
            Spacer()
        }
        .padding(.vertical, 2)
        .background(Color(NSColor.windowBackgroundColor))
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

    private func sortHeader(title: String, column: SortColumn) -> some View {
        Button(action: { viewModel.toggleSort(column: column) }) {
            HStack(spacing: 2) {
                Text(title)
                Image(systemName: {
                    let base = viewModel.sortAscending ? "arrowtriangle.up" : "arrowtriangle.down"
                    return viewModel.sortColumn == column ? base + ".fill" : base
                }())
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundColor(viewModel.sortColumn == column ? .accentColor : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .background(viewModel.sortColumn == column ? Color(red: 230/255, green: 247/255, blue: 255/255) : Color.clear)
    }

    private func rowBackground(for asset: AllocationAsset) -> Color {
        if let cid = editingClassId, asset.id == "class-\(cid)" {
            return .rowHighlight
        }
        if viewModel.rowHasWarning(asset) {
            return .paleRed
        }
        if viewModel.rowHasActualButNoTarget(asset) {
            return .paleOrange
        }
        return .white
    }

    private enum ValidationStatus { case compliant, warning, error }

    private func validationStatus(for asset: AllocationAsset) -> ValidationStatus {
        var status: ValidationStatus
        if viewModel.rowHasWarning(asset) {
            status = .warning
        } else {
            let diff = abs(asset.deviationPct)
            if diff <= 5 {
                status = .compliant
            } else if diff <= 10 {
                status = .warning
            } else {
                status = .error
            }
        }
        if let children = asset.children {
            for child in children {
                let childStatus = validationStatus(for: child)
                if childStatus == .error { return .error }
                if childStatus == .warning { status = .warning }
            }
        }
        return status
    }

    private func statusIcon(for asset: AllocationAsset) -> String {
        switch validationStatus(for: asset) {
        case .compliant: return "🟢"
        case .warning: return "🟠"
        case .error: return "🔴"
        }
    }

    private var cardBackground: some View {
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
    }

    @ViewBuilder
    private func tableRow(for asset: AllocationAsset) -> some View {
        let isClass = asset.id.hasPrefix("class-")
        let subclassSumPct = asset.children?.map(\.targetPct).reduce(0, +) ?? 0
        let subclassSumChf = asset.children?.map(\.targetChf).reduce(0, +) ?? 0
        let deltaChf = asset.targetChf - subclassSumChf
        let deltaTol = abs(asset.targetChf) * 0.01
        let aggregateDeltaColor: Color = abs(deltaChf) > deltaTol ? .red : .secondary

        HStack(spacing: 4) {
            if viewModel.rowHasWarning(asset) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
            Text(asset.name)
                .fontWeight((abs(asset.targetPct) > 0.0001 || abs(asset.targetChf) > 0.01) ? .bold : .regular)
        }
        .frame(width: 200, alignment: .leading)
        HStack(spacing: 0) {
            Divider()
            HStack(alignment: .top, spacing: 0) {
                Picker("", selection: viewModel.modeBinding(for: asset)) {
                    Text("%" ).tag(AllocationInputMode.percent)
                    Text("CHF").tag(AllocationInputMode.chf)
                }
                .pickerStyle(.segmented)
                .tint(.softBlue)
                .frame(width: 80)
                if asset.mode == .percent {
                    VStack(alignment: .trailing, spacing: 2) {
                        TextField("", value: viewModel.percentBinding(for: asset), formatter: percentFormatter)
                            .multilineTextAlignment(.trailing)
                            .padding(4)
                            .frame(width: 80, alignment: .trailing)
                            .background(Color.fieldGray)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(focusedPctField == asset.id ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                            .focused($focusedPctField, equals: asset.id)
                        if isClass {
                            Text("Σ \(formatPercent(subclassSumPct))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatChf(asset.targetChf))
                            .frame(width: 100, alignment: .trailing)
                        if isClass {
                            HStack(spacing: 4) {
                                Text("Σ \(formatChf(subclassSumChf))")
                                Text(formatSignedChf(deltaChf))
                                    .fontWeight(abs(deltaChf) > deltaTol ? .bold : .regular)
                                    .foregroundColor(aggregateDeltaColor)
                            }
                            .font(.caption2)
                            .frame(width: 100, alignment: .trailing)
                        }
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatPercent(asset.targetPct))
                            .frame(width: 80, alignment: .trailing)
                        if isClass {
                            Text("Σ \(formatPercent(subclassSumPct))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        TextField("", text: chfTextBinding(for: asset))
                            .multilineTextAlignment(.trailing)
                            .padding(4)
                            .frame(width: 100, alignment: .trailing)
                            .background(Color.fieldGray)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(focusedChfField == asset.id ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                            .focused($focusedChfField, equals: asset.id)
                            .onChange(of: focusedChfField) { oldValue, newValue in
                                if newValue == asset.id {
                                    chfDrafts[asset.id] = chfDrafts[asset.id]?.replacingOccurrences(of: "'", with: "")
                                } else if oldValue == asset.id && chfDrafts[asset.id] != nil {
                                    chfDrafts[asset.id] = formatChf(asset.targetChf)
                                }
                            }
                        if isClass {
                            HStack(spacing: 4) {
                                Text("Σ \(formatChf(subclassSumChf))")
                                Text(formatSignedChf(deltaChf))
                                    .fontWeight(abs(deltaChf) > deltaTol ? .bold : .regular)
                                    .foregroundColor(aggregateDeltaColor)
                            }
                            .font(.caption2)
                            .frame(width: 100, alignment: .trailing)
                        }
                    }
                }
            }
            if isClass {
                let cid = Int(asset.id.dropFirst(6))
                Button {
                    if let id = cid { editingClassId = id }
                } label: {
                    Image(systemName: editingClassId == cid ? "pencil.circle.fill" : "pencil.circle")
                        .foregroundColor(.accentColor)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .accessibilityLabel("Edit targets for \(asset.name)")
            }
            Divider()
            HStack {
                Text("\(formatPercent(asset.actualPct))%")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(asset.actualPct == 0 ? .secondary : .primary)
                Text(formatChf(asset.actualChf))
                    .frame(width: 100, alignment: .trailing)
                    .foregroundColor(asset.actualChf == 0 ? .secondary : .primary)
            }
            Divider()
            HStack {
                Text(statusIcon(for: asset))
                    .frame(width: 30, alignment: .center)
                DeviationBar(target: asset.targetPct,
                             actual: asset.actualPct,
                             trackWidth: 120)
                    .frame(width: 120)
            }
        }
        .frame(height: isClass ? 60 : 48)
        .background(rowBackground(for: asset))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if isClass, let id = Int(asset.id.dropFirst(6)) {
                editingClassId = id
            }
        }
    }
}

struct AllocationTargetsTableView_Previews: PreviewProvider {
    static var previews: some View {
        AllocationTargetsTableView()
            .environmentObject(DatabaseManager())
    }
}

// MARK: - Comparative Visual Components

fileprivate func barColor(_ diffPercent: Double) -> Color {
    let mag = abs(diffPercent)
    if mag <= 10 { return .numberGreen }
    if mag <= 20 { return .numberAmber }
    return .numberRed
}

struct DeviationBar: View {
    let target: Double
    let actual: Double
    var trackWidth: CGFloat

    private var diffPercent: Double {
        guard target != 0 else { return 0 }
        return (actual - target) / target * 100
    }

    private var track: CGFloat { trackWidth - 24 }

    private var span: CGFloat {
        let mag = min(abs(diffPercent), 100)
        return track * CGFloat(mag) / 100 * 0.5
    }

    private var offset: CGFloat {
        if diffPercent < 0 { return span / 2 }
        if diffPercent > 0 { return -span / 2 }
        return 0
    }

    var body: some View {
        ZStack {
            Capsule().fill(Color.systemGray5)
                .frame(height: 6)
                .padding(.horizontal, 12)
            Rectangle().fill(Color.black)
                .frame(width: 1, height: 8)
            Capsule().fill(barColor(diffPercent))
                .frame(width: span, height: 6)
                .offset(x: offset)
                .padding(.horizontal, 12)
        }
        .frame(width: trackWidth)
    }
}

