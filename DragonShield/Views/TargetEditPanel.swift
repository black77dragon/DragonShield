import SwiftUI
import OSLog

struct TargetEditPanel: View {
    @EnvironmentObject var db: DatabaseManager
    let classId: Int
    let onClose: () -> Void

    enum TargetKind: String, CaseIterable { case percent, amount }

    struct Row: Identifiable {
        let id: Int
        let name: String
        var percent: Double
        var amount: Double
        var kind: TargetKind
        var tolerance: Double
        var locked: Bool = false
    }

    @State private var className: String = ""
    @State private var kind: TargetKind = .percent
    @State private var parentPercent: Double = 0
    @State private var parentAmount: Double = 0
    @State private var chfDrafts: [String: String] = [:]
    @FocusState private var focusedChfField: String?
    @State private var portfolioTotal: Double = 0
    @State private var tolerance: Double = 5
    @State private var rows: [Row] = []
    @State private var parentWarning: String? = nil
    @State private var totalClassPercent: Double = 0
    @State private var isInitialLoad = true
    @State private var initialPercent: Double = 0
    @State private var initialAmount: Double = 0
    @State private var initialKind: TargetKind = .percent
    @State private var initialTolerance: Double = 0
    @State private var initialRows: [Int: Row] = [:]

    private var subTotal: Double {
        if kind == .percent {
            rows.map(\.percent).reduce(0, +)
        } else {
            rows.map(\.amount).reduce(0, +)
        }
    }

    private var remaining: Double {
        if kind == .percent {
            100 - subTotal
        } else {
            parentAmount - subTotal
        }
    }

    private var sumChildPercent: Double {
        rows.map(\.percent).reduce(0, +)
    }

    private var sumChildAmount: Double {
        rows.map(\.amount).reduce(0, +)
    }



    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            (Text("Asset Allocations : ") + Text(className).foregroundColor(.darkBlue))
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 8) {
                HStack {
                    Text("Target Kind")
                    Spacer()
                    Picker("", selection: $kind) {
                        Text("%").tag(TargetKind.percent)
                        Text("CHF").tag(TargetKind.amount)
                    }
                    .pickerStyle(.radioGroup)
                    .frame(width: 120)
                }
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Target %")
                        TextField("", value: $parentPercent, formatter: Self.percentFormatter)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .disabled(kind != .percent)
                            .foregroundColor(kind == .percent ? .primary : .secondary)
                            .onChange(of: parentPercent) { oldVal, newVal in
                                guard !isInitialLoad, kind == .percent else { return }
                                let capped = max(0, min(newVal, 100))
                                if capped != newVal { parentPercent = capped }
                                parentAmount = portfolioTotal * capped / 100
                                let ratio = String(format: "%.2f", capped / 100)
                                log("CALC %→CHF", "Changed percent \(oldVal)→\(capped) ⇒ CHF=\(ratio)×\(formatChf(portfolioTotal))=\(formatChf(parentAmount))", type: .debug)
                                updateClassTotals()
                            }
                        Text("Σ Classes % = \(totalClassPercent, format: .number.precision(.fractionLength(1)))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("Target CHF")
                        TextField("", text: chfBinding(key: "parent", value: $parentAmount))
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .disabled(kind != .amount)
                            .foregroundColor(kind == .amount ? .primary : .secondary)
                            .focused($focusedChfField, equals: "parent")
                            .onChange(of: parentAmount) { oldVal, newVal in
                                guard !isInitialLoad, kind == .amount else { return }
                                let capped = max(0, min(newVal, portfolioTotal))
                                if capped != newVal { parentAmount = capped }
                                parentPercent = portfolioTotal > 0 ? capped / portfolioTotal * 100 : parentPercent
                                log("CALC CHF→%", "Changed CHF \(formatChf(oldVal))→\(formatChf(capped)) ⇒ percent=(\(formatChf(capped))÷\(formatChf(portfolioTotal)))×100=\(String(format: "%.1f", parentPercent))", type: .debug)
                                updateClassTotals()
                            }
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Σ Sub-class % = \(sumChildPercent, format: .number.precision(.fractionLength(1)))%")
                    Text("Σ Sub-class CHF = \(formatChf(sumChildAmount))")
                }
                .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.sectionBlue)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Text("Tolerance")
                Spacer()
                TextField("", value: $tolerance, formatter: Self.numberFormatter)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                Text("%")
            }

            Text("Sub-Class Targets:")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    Text("Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Kind").frame(width: 80)
                    Text("Target %").frame(width: 80, alignment: .trailing)
                    Text("Target CHF").frame(width: 100, alignment: .trailing)
                    Text("Tol %").frame(width: 60, alignment: .trailing)
                }
                Divider().gridCellColumns(5)
                ForEach($rows) { $row in
                    GridRow {
                        Text(row.name)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Picker("", selection: $row.kind) {
                            Text("%").tag(TargetKind.percent)
                            Text("CHF").tag(TargetKind.amount)
                        }
                        .pickerStyle(.radioGroup)
                        .frame(width: 80)
                        .onChange(of: row.kind) { _, newKind in
                            if newKind == .percent {
                                row.percent = parentAmount > 0 ? row.amount / parentAmount * 100 : 0
                            } else {
                                row.amount = parentAmount * row.percent / 100
                            }
                        }

                        TextField("", value: $row.percent, formatter: Self.percentFormatter)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .disabled(row.kind != .percent)
                            .foregroundColor(row.kind == .percent ? .primary : .secondary)
                            .onChange(of: row.percent) { oldVal, newVal in
                                guard !isInitialLoad, row.kind == .percent else { return }
                                let capped = max(0, min(newVal, 100))
                                if capped != newVal { row.percent = capped }
                                row.amount = parentAmount * capped / 100
                                let ratio = String(format: "%.2f", capped / 100)
                                log("CALC %→CHF", "Changed percent \(oldVal)→\(capped) ⇒ CHF=\(ratio)×\(formatChf(parentAmount))=\(formatChf(row.amount))", type: .debug)
                            }

                        TextField("", text: chfBinding(key: "row-\(row.id)", value: $row.amount))
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .disabled(row.kind != .amount)
                            .foregroundColor(row.kind == .amount ? .primary : .secondary)
                            .focused($focusedChfField, equals: "row-\(row.id)")
                            .onChange(of: row.amount) { oldVal, newVal in
                                guard !isInitialLoad, row.kind == .amount else { return }
                                let capped = max(0, min(newVal, parentAmount))
                                if capped != newVal { row.amount = capped }
                                row.percent = parentAmount > 0 ? capped / parentAmount * 100 : 0
                                log("CALC CHF→%", "Changed CHF \(formatChf(oldVal))→\(formatChf(capped)) ⇒ percent=(\(formatChf(capped))÷\(formatChf(parentAmount)))×100=\(String(format: "%.1f", row.percent))", type: .debug)
                            }

                        TextField("", value: $row.tolerance, formatter: Self.numberFormatter)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                    }
                    Divider().background(Color.systemGray4).gridCellColumns(5)
                }
            }

            Text("Remaining to allocate: \(remaining, format: .number.precision(.fractionLength(1))) \(kind == .percent ? "%" : "CHF")")
                .foregroundColor(remaining == 0 ? .primary : .red)

            if let warning = parentWarning {
                Text(warning)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                Button("Auto-balance") { autoBalance() }
                Spacer()
                Button("Cancel") { cancel() }
                Button("Save") { save() }
            }
        }
        .padding()
        .frame(minWidth: 560)
        .onAppear { load() }
        .onChange(of: kind) { _, _ in
            guard !isInitialLoad else { return }
            if kind == .percent {
                parentAmount = portfolioTotal * parentPercent / 100
            } else {
                parentPercent = portfolioTotal > 0 ? parentAmount / portfolioTotal * 100 : 0
            }
            updateRows()
            updateClassTotals()
        }
        .onChange(of: parentAmount) { _, _ in
            guard !isInitialLoad else { return }
            updateRows()
            updateClassTotals()
        }
        .onChange(of: focusedChfField) { oldValue, newValue in
            if let old = oldValue, old != newValue {
                if old == "parent" {
                    chfDrafts[old] = formatChf(parentAmount)
                } else if let id = Int(old.dropFirst(4)), let row = rows.first(where: { $0.id == id }) {
                    chfDrafts[old] = formatChf(row.amount)
                }
            }
            if let key = newValue {
                chfDrafts[key] = chfDrafts[key]?.replacingOccurrences(of: "'", with: "")
            }
        }
    }

    private func load() {
        className = db.fetchAssetClassDetails(id: classId)?.name ?? ""
        portfolioTotal = calculatePortfolioTotal()
        parentWarning = nil

        log("FETCH", "Fetching ClassTargets for id=\(classId)", type: .info)
        if let parent = db.fetchClassTarget(classId: classId) {
            kind = parent.targetKind == "amount" ? .amount : .percent
            parentPercent = parent.percent
            parentAmount = parent.amountCHF
            tolerance = parent.tolerance
        } else {
            kind = .percent
            parentPercent = 0
            parentAmount = 0
            tolerance = 0
        }
        initialKind = kind
        initialPercent = parentPercent
        initialAmount = parentAmount
        initialTolerance = tolerance

        log("FETCH", "Fetching SubClassTargets for class id=\(classId)", type: .info)
        let subRecs = db.fetchSubClassTargets(classId: classId)
        rows = subRecs.map { rec in
            let rk = TargetKind(rawValue: rec.targetKind) ?? .percent
            let amt = rk == .amount && rec.amountCHF > 0 ? rec.amountCHF : parentAmount * rec.percent / 100
            let tol = rec.tolerance != 0 ? rec.tolerance : tolerance
            return Row(id: rec.id,
                       name: rec.name,
                       percent: rec.percent,
                       amount: amt,
                       kind: rk,
                       tolerance: tol)
        }
        initialRows = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })

        updateRows()
        if focusedChfField == nil {
            refreshDrafts()
        }
        let childPct = rows.map(\.percent).reduce(0, +)
        let childChf = rows.map(\.amount).reduce(0, +)
        log("INFO", "EditTargetsPanel load → parent \(String(format: "%.1f", parentPercent))% / \(formatChf(parentAmount)) CHF; children sum \(String(format: "%.1f", childPct))% / \(formatChf(childChf)) CHF", type: .info)
        for r in rows {
            log("EDIT PANEL LOAD", "Loaded sub-class \"\(r.name)\" id=\(r.id): percent=\(r.percent), CHF=\(r.amount), kind=\(r.kind.rawValue), tol=\(r.tolerance)", type: .info)
        }
        updateClassTotals()
        isInitialLoad = false
    }

    private func calculatePortfolioTotal() -> Double {
        var total = 0.0
        var rateCache: [String: Double] = [:]
        for p in db.fetchPositionReports() {
            guard let price = p.currentPrice else { continue }
            var value = p.quantity * price
            let currency = p.instrumentCurrency.uppercased()
            if currency != "CHF" {
                if rateCache[currency] == nil {
                    rateCache[currency] = db.fetchExchangeRates(currencyCode: currency, upTo: nil).first?.rateToChf
                }
                guard let r = rateCache[currency] else { continue }
                value *= r
            }
            total += value
        }
        return total
    }

    private func updateRows() {
        for idx in rows.indices {
            if rows[idx].kind == .percent {
                rows[idx].percent = max(0, min(rows[idx].percent, 100))
                rows[idx].amount = max(0, min(parentAmount * rows[idx].percent / 100, parentAmount))
            } else {
                rows[idx].amount = max(0, min(rows[idx].amount, parentAmount))
                rows[idx].percent = parentAmount > 0 ? max(0, min(rows[idx].amount / parentAmount * 100, 100)) : 0
            }
        }
        refreshDrafts()
    }

    private func autoBalance() {
        let unlocked = rows.indices.filter { !rows[$0].locked }
        guard !unlocked.isEmpty else { return }
        let share = remaining / Double(unlocked.count)
        if kind == .percent {
            for idx in unlocked { rows[idx].percent += share }
            if let last = unlocked.last {
                rows[last].percent += remaining - share * Double(unlocked.count)
            }
        } else {
            for idx in unlocked { rows[idx].amount += share }
            if let last = unlocked.last {
                rows[last].amount += remaining - share * Double(unlocked.count)
            }
        }
    }

    private func cancel() {
        isInitialLoad = true
        log("EDIT PANEL CANCEL", "Discarded changes for \(className)", type: .info)
        kind = initialKind
        parentPercent = initialPercent
        parentAmount = initialAmount
        tolerance = initialTolerance
        rows = Array(initialRows.values).sorted { $0.id < $1.id }
        refreshDrafts()
        parentWarning = nil
        isInitialLoad = false
        onClose()
    }

    private func save() {
        log("UPSERT", "Upserting ClassTargets id=\(classId)", type: .info)
        db.upsertClassTarget(portfolioId: 1,
                             classId: classId,
                             percent: parentPercent,
                             amountChf: parentAmount,
                             kind: kind.rawValue,
                             tolerance: tolerance)
        for row in rows {
            let initial = initialRows[row.id]
            log("UPSERT", "Upserting SubClassTargets id=\(row.id) (\(row.name)): percent \(initial?.percent ?? 0)→\(row.percent), CHF \(initial?.amount ?? 0)→\(row.amount), kind \(initial?.kind.rawValue ?? row.kind.rawValue)→\(row.kind.rawValue), tol \(initial?.tolerance ?? row.tolerance)→\(row.tolerance)", type: .info)
            db.upsertSubClassTarget(portfolioId: 1,
                                    subClassId: row.id,
                                    percent: row.percent,
                                    amountChf: row.amount,
                                    kind: row.kind.rawValue,
                                    tolerance: row.tolerance)
        }
        onClose()
    }

    private func updateClassTotals() {
        let records = db.fetchPortfolioTargetRecords(portfolioId: 1)
        let others = records.filter { $0.subClassId == nil && $0.classId != classId }.map(\.percent).reduce(0, +)
        totalClassPercent = others + parentPercent
        let tol = 0.1
        if abs(totalClassPercent - 100) > tol {
            parentWarning = String(format: "Warning: Total Asset Class %% = %.1f%% (expected 100%% ± %.1f%%)", totalClassPercent, tol)
        } else {
            parentWarning = nil
        }
    }

    private func formatChf(_ value: Double) -> String {
        Self.chfFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    private func chfBinding(key: String, value: Binding<Double>) -> Binding<String> {
        Binding(
            get: {
                chfDrafts[key] ?? formatChf(value.wrappedValue)
            },
            set: { newVal in
                chfDrafts[key] = newVal
                let raw = newVal.replacingOccurrences(of: "'", with: "")
                if let v = Double(raw) {
                    value.wrappedValue = v
                }
            }
        )
    }

    private func refreshDrafts() {
        chfDrafts["parent"] = formatChf(parentAmount)
        for row in rows {
            chfDrafts["row-\(row.id)"] = formatChf(row.amount)
        }
    }

    private func log(_ level: String, _ message: String, type: OSLogType) {
        let line = "[\(level)] \(message)"
        print(line)
        LoggingService.shared.log(line, type: type)
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }()

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 1
        return f
    }()

    private static let chfFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()
}

struct TargetEditPanel_Previews: PreviewProvider {
    static var previews: some View {
        TargetEditPanel(classId: 1, onClose: {})
            .environmentObject(DatabaseManager())
    }
}
