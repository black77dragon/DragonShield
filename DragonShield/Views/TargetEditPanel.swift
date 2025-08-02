import SwiftUI
import AppKit

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



    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit \"\(className)\" Targets")
                .font(.headline)

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
                            .onChange(of: parentPercent) { oldVal, newVal in
                                guard kind == .percent else { return }
                                parentAmount = portfolioTotal * newVal / 100
                                let msg = String(format: "Changed percent %.1f→%.1f ⇒ CHF=%.2f×%@=%@",
                                                 oldVal,
                                                 newVal,
                                                 newVal / 100,
                                                 formatChf(portfolioTotal),
                                                 formatChf(parentAmount))
                                LoggingService.shared.log(msg, type: .debug, logger: .ui)
                            }
                    }
                    VStack(alignment: .leading) {
                        Text("Target CHF")
                        TextField("", text: chfBinding(key: "parent", value: $parentAmount))
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .disabled(kind != .amount)
                            .focused($focusedChfField, equals: "parent")
                            .onChange(of: parentAmount) { oldVal, newVal in
                                guard kind == .amount else { return }
                                parentPercent = portfolioTotal > 0 ? newVal / portfolioTotal * 100 : 0
                                let msg = String(format: "Changed CHF %@→%@ ⇒ percent=(%@÷%@)×100=%.1f",
                                                 formatChf(oldVal),
                                                 formatChf(newVal),
                                                 formatChf(newVal),
                                                 formatChf(portfolioTotal),
                                                 parentPercent)
                                LoggingService.shared.log(msg, type: .debug, logger: .ui)
                            }
                    }
                }
                HStack {
                    Text("Tolerance")
                    Spacer()
                    TextField("", value: $tolerance, formatter: Self.numberFormatter)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                    Text("%")
                }
            }
            .padding(8)
            .background(Color.sectionBlue)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("Sub-Class Targets:")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    Text("Kind").frame(width: 80)
                    Text("Target %").frame(width: 80, alignment: .trailing)
                    Text("Target CHF").frame(width: 100, alignment: .trailing)
                    Text("Tol %").frame(width: 60, alignment: .trailing)
                    Text("")
                }
                Divider().gridCellColumns(5)
                ForEach($rows) { $row in
                    GridRow {
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
                            .onChange(of: row.percent) { oldVal, newVal in
                                guard row.kind == .percent else { return }
                                row.amount = parentAmount * newVal / 100
                                let msg = String(format: "Changed percent %.1f→%.1f for sub-class id=%d ⇒ CHF=%.2f×%@=%@",
                                                 oldVal,
                                                 newVal,
                                                 row.id,
                                                 newVal / 100,
                                                 formatChf(parentAmount),
                                                 formatChf(row.amount))
                                LoggingService.shared.log(msg, type: .debug, logger: .ui)
                            }

                        TextField("", text: chfBinding(key: "row-\(row.id)", value: $row.amount))
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .disabled(row.kind != .amount)
                            .focused($focusedChfField, equals: "row-\(row.id)")
                            .onChange(of: row.amount) { oldVal, newVal in
                                guard row.kind == .amount else { return }
                                row.percent = parentAmount > 0 ? newVal / parentAmount * 100 : 0
                                let msg = String(format: "Changed CHF %@→%@ for sub-class id=%d ⇒ percent=(%@÷%@)×100=%.1f",
                                                 formatChf(oldVal),
                                                 formatChf(newVal),
                                                 row.id,
                                                 formatChf(newVal),
                                                 formatChf(parentAmount),
                                                 row.percent)
                                LoggingService.shared.log(msg, type: .debug, logger: .ui)
                            }

                        TextField("", value: $row.tolerance, formatter: Self.numberFormatter)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)

                        Text(row.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider().background(Color.systemGray4).gridCellColumns(5)
                }
            }

            Text("Remaining to allocate: \(remaining, format: .number.precision(.fractionLength(1))) \(kind == .percent ? "%" : "CHF")")
                .foregroundColor(remaining == 0 ? .primary : .red)

            HStack {
                Button("Auto-balance") { autoBalance() }
                Spacer()
                Button("Cancel") { onClose() }
                Button("Save") { save() }
            }
        }
        .padding()
        .frame(minWidth: 360)
        .onAppear { load() }
        .onChange(of: kind) { _, _ in
            if kind == .percent {
                parentAmount = portfolioTotal * parentPercent / 100
            } else {
                parentPercent = portfolioTotal > 0 ? parentAmount / portfolioTotal * 100 : 0
            }
            updateRows()
        }
        .onChange(of: parentAmount) { _, _ in
            updateRows()
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

        let records = db.fetchPortfolioTargetRecords(portfolioId: 1)
        if let parent = records.first(where: { $0.classId == classId && $0.subClassId == nil }) {
            kind = parent.targetKind == "amount" ? .amount : .percent
            parentPercent = parent.percent
            parentAmount = parent.amountCHF ?? portfolioTotal * parent.percent / 100
            tolerance = parent.tolerance
        }
        let loadMsg = String(format: "Loading \"%@\" id=%d: percent=%.1f, CHF=%@, kind=%@, tol=%.1f",
                              className,
                              classId,
                              parentPercent,
                              formatChf(parentAmount),
                              kind.rawValue,
                              tolerance)
        LoggingService.shared.log(loadMsg, type: .info, logger: .ui)

        let subs = db.subAssetClasses(for: classId)
        rows = subs.map { sub in
            let rec = records.first { $0.subClassId == sub.id }
            let rk = rec?.targetKind == "amount" ? TargetKind.amount : TargetKind.percent
            let pct = rec?.percent ?? 0
            let amt = rec?.amountCHF ?? parentAmount * pct / 100
            return Row(id: sub.id,
                       name: sub.name,
                       percent: pct,
                       amount: amt,
                       kind: rk,
                       tolerance: rec?.tolerance ?? tolerance)
        }
        for row in rows {
            let msg = String(format: "Loading sub-class \"%@\" id=%d: percent=%.1f, CHF=%@, kind=%@, tol=%.1f",
                              row.name,
                              row.id,
                              row.percent,
                              formatChf(row.amount),
                              row.kind.rawValue,
                              row.tolerance)
            LoggingService.shared.log(msg, type: .info, logger: .ui)
        }

        updateRows()
        if focusedChfField == nil {
            refreshDrafts()
        }
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
                rows[idx].amount = parentAmount * rows[idx].percent / 100
            } else {
                rows[idx].percent = parentAmount > 0 ? rows[idx].amount / parentAmount * 100 : 0
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

    private func validateTotals() -> Bool {
        let records = db.fetchPortfolioTargetRecords(portfolioId: 1)
        var classPct: [Int: Double] = [:]
        var classChf: [Int: Double] = [:]
        var subPct: [Int: [Int: Double]] = [:]
        var subChf: [Int: [Int: Double]] = [:]

        for rec in records {
            let cid = rec.classId ?? 0
            if let sid = rec.subClassId {
                subPct[cid, default: [:]][sid] = rec.percent
                if let amt = rec.amountCHF { subChf[cid, default: [:]][sid] = amt }
            } else {
                classPct[cid] = rec.percent
                if let amt = rec.amountCHF { classChf[cid] = amt }
            }
        }

        classPct[classId] = parentPercent
        classChf[classId] = parentAmount
        subPct[classId] = [:]
        subChf[classId] = [:]
        for row in rows {
            subPct[classId]?[row.id] = row.percent
            subChf[classId]?[row.id] = row.amount
        }

        var issues: [String] = []
        let pctTotal = classPct.values.reduce(0, +)
        if abs(pctTotal - 100) > 0.001 {
            let msg = String(format: "asset-class %% sum=%.1f%% (expected 100%%)", pctTotal)
            LoggingService.shared.log(msg, type: .default, logger: .ui)
            issues.append(msg)
        }
        let chfTotal = classChf.values.reduce(0, +)
        if abs(chfTotal - portfolioTotal) > 0.01 {
            let msg = "asset-class CHF sum=\(formatChf(chfTotal)) (expected \(formatChf(portfolioTotal)))"
            LoggingService.shared.log(msg, type: .default, logger: .ui)
            issues.append(msg)
        }

        for (cid, _) in classPct {
            let name = cid == classId ? className : db.fetchAssetClassDetails(id: cid)?.name ?? "Class \(cid)"
            if let subs = subPct[cid], !subs.isEmpty {
                let sumPct = subs.values.reduce(0, +)
                if abs(sumPct - 100) > 0.001 {
                    let msg = String(format: "\"%@\" sub-class %% sum=%.1f%% (expected 100%%)", name, sumPct)
                    LoggingService.shared.log(msg, type: .default, logger: .ui)
                    issues.append(msg)
                }
            }
            if let subs = subChf[cid], !subs.isEmpty {
                let parentAmt = classChf[cid] ?? 0
                let sumAmt = subs.values.reduce(0, +)
                if parentAmt > 0 && abs(sumAmt - parentAmt) > 0.01 {
                    let msg = String(format: "\"%@\" sub-class CHF sum=%@ (expected %@)", name, formatChf(sumAmt), formatChf(parentAmt))
                    LoggingService.shared.log(msg, type: .default, logger: .ui)
                    issues.append(msg)
                }
            }
        }

        if !issues.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Validation Failed"
            alert.informativeText = issues.joined(separator: "\n")
            alert.alertStyle = .warning
            alert.runModal()
            return false
        }
        return true
    }

    private func save() {
        guard validateTotals() else { return }

        let msg = String(format: "Saving \"%@\" id=%d: percent=%.1f, CHF=%@, kind=%@, tol=%.1f",
                          className,
                          classId,
                          parentPercent,
                          formatChf(parentAmount),
                          kind.rawValue,
                          tolerance)
        LoggingService.shared.log(msg, type: .info, logger: .ui)

        db.upsertClassTarget(portfolioId: 1,
                             classId: classId,
                             percent: parentPercent,
                             amountChf: parentAmount,
                             tolerance: tolerance)
        for row in rows {
            let subMsg = String(format: "Saving sub-class \"%@\" id=%d: percent=%.1f, CHF=%@, kind=%@, tol=%.1f",
                                row.name,
                                row.id,
                                row.percent,
                                formatChf(row.amount),
                                row.kind.rawValue,
                                row.tolerance)
            LoggingService.shared.log(subMsg, type: .info, logger: .ui)
            db.upsertSubClassTarget(portfolioId: 1,
                                    subClassId: row.id,
                                    percent: row.percent,
                                    amountChf: row.amount,
                                    tolerance: row.tolerance)
        }
        onClose()
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
