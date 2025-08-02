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
    @State private var validationError: String?
    @State private var isInitialLoad = true

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
                                guard !isInitialLoad, kind == .percent else { return }
                                let capped = min(newVal, 100)
                                if capped != newVal { parentPercent = capped }
                                parentAmount = portfolioTotal * capped / 100
                                let ratio = String(format: "%.2f", capped / 100)
                                log("DEBUG", "Changed percent \(oldVal)→\(capped) ⇒ CHF=\(ratio)×\(formatChf(portfolioTotal))=\(formatChf(parentAmount))", type: .debug)
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
                                guard !isInitialLoad, kind == .amount else { return }
                                let capped = min(newVal, portfolioTotal)
                                if capped != newVal { parentAmount = capped }
                                parentPercent = portfolioTotal > 0 ? capped / portfolioTotal * 100 : 0
                                log("DEBUG", "Changed CHF \(formatChf(oldVal))→\(formatChf(capped)) ⇒ percent=(\(formatChf(capped))÷\(formatChf(portfolioTotal)))×100=\(String(format: "%.1f", parentPercent))", type: .debug)
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
                                guard !isInitialLoad, row.kind == .percent else { return }
                                let capped = min(newVal, 100)
                                if capped != newVal { row.percent = capped }
                                row.amount = parentAmount * capped / 100
                                let ratio = String(format: "%.2f", capped / 100)
                                log("DEBUG", "Changed percent \(oldVal)→\(capped) ⇒ CHF=\(ratio)×\(formatChf(parentAmount))=\(formatChf(row.amount))", type: .debug)
                            }

                        TextField("", text: chfBinding(key: "row-\(row.id)", value: $row.amount))
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .disabled(row.kind != .amount)
                            .focused($focusedChfField, equals: "row-\(row.id)")
                            .onChange(of: row.amount) { oldVal, newVal in
                                guard !isInitialLoad, row.kind == .amount else { return }
                                let capped = min(newVal, parentAmount)
                                if capped != newVal { row.amount = capped }
                                row.percent = parentAmount > 0 ? capped / parentAmount * 100 : 0
                                log("DEBUG", "Changed CHF \(formatChf(oldVal))→\(formatChf(capped)) ⇒ percent=(\(formatChf(capped))÷\(formatChf(parentAmount)))×100=\(String(format: "%.1f", row.percent))", type: .debug)
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
        .alert("Validation Error",
               isPresented: Binding(get: { validationError != nil },
                                    set: { _ in validationError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationError ?? "")
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

        updateRows()
        if focusedChfField == nil {
            refreshDrafts()
        }
        log("INFO", "Loading \"\(className)\" id=\(classId): percent=\(parentPercent), CHF=\(parentAmount), kind=\(kind.rawValue), tol=\(tolerance)", type: .info)
        for r in rows {
            log("INFO", "Loading sub-class \"\(r.name)\" id=\(r.id): percent=\(r.percent), CHF=\(r.amount), kind=\(r.kind.rawValue), tol=\(r.tolerance)", type: .info)
        }
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
                rows[idx].percent = min(rows[idx].percent, 100)
                rows[idx].amount = min(parentAmount * rows[idx].percent / 100, parentAmount)
            } else {
                rows[idx].amount = min(rows[idx].amount, parentAmount)
                rows[idx].percent = parentAmount > 0 ? min(rows[idx].amount / parentAmount * 100, 100) : 0
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

    private func validateAll() -> [String] {
        var warnings: [String] = []

        let records = db.fetchPortfolioTargetRecords(portfolioId: 1)
        let classes = db.fetchAssetClassesDetailed()

        var classPercents: [Int: Double] = [:]
        var classAmounts: [Int: Double] = [:]

        // Read parent targets
        for cls in classes {
            let rec = records.first { $0.classId == cls.id && $0.subClassId == nil }
            let percent = cls.id == classId ? parentPercent : (rec?.percent ?? 0)
            let amount: Double
            if cls.id == classId {
                amount = parentAmount
            } else if let amt = rec?.amountCHF {
                amount = amt
            } else {
                amount = portfolioTotal * percent / 100
            }
            classPercents[cls.id] = percent
            classAmounts[cls.id] = amount
            log("DEBUG", "Read asset-class \"\(cls.name)\" id=\(cls.id): percent=\(percent), CHF=\(amount)", type: .debug)
        }

        let pctSum = classPercents.values.reduce(0, +)
        log("DEBUG", String(format: "Parent %% sum=%.1f%%", pctSum), type: .debug)
        if abs(pctSum - 100) > 0.01 {
            let msg = String(format: "asset-class %% sum=%.1f%% (expected 100%%)", pctSum)
            warnings.append(msg)
            log("WARN", msg, type: .default)
        }

        let chfSum = classAmounts.values.reduce(0, +)
        log("DEBUG", "Parent CHF sum=\(formatChf(chfSum))", type: .debug)
        if abs(chfSum - portfolioTotal) > 0.01 {
            let msg = "asset-class CHF sum=\(formatChf(chfSum)) (expected \(formatChf(portfolioTotal)))"
            warnings.append(msg)
            log("WARN", msg, type: .default)
        }

        // Child level validation per class
        for cls in classes {
            let parentPct = classPercents[cls.id] ?? 0
            let parentAmt = classAmounts[cls.id] ?? 0
            var subPct = 0.0
            var subAmt = 0.0

            if cls.id == classId {
                for row in rows {
                    subPct += row.percent
                    subAmt += row.amount
                    log("DEBUG", "Read sub-class \"\(row.name)\" id=\(row.id) of \"\(cls.name)\": percent=\(row.percent), CHF=\(row.amount)", type: .debug)
                }
            } else {
                let subRecords = records.filter { $0.classId == cls.id && $0.subClassId != nil }
                let subNames = Dictionary(uniqueKeysWithValues: db.subAssetClasses(for: cls.id).map { ($0.id, $0.name) })
                for rec in subRecords {
                    let amt = rec.amountCHF ?? parentAmt * rec.percent / 100
                    subPct += rec.percent
                    subAmt += amt
                    let name = subNames[rec.subClassId ?? 0] ?? "id \(rec.subClassId ?? 0)"
                    log("DEBUG", "Read sub-class \"\(name)\" id=\(rec.subClassId ?? 0) of \"\(cls.name)\": percent=\(rec.percent), CHF=\(amt)", type: .debug)
                }
            }

            log("DEBUG", String(format: "\"%@\" sub-class %% sum=%.1f%%", cls.name, subPct), type: .debug)
            let expectedPct = (parentPct > 0 || parentAmt > 0) ? 100.0 : 0.0
            if abs(subPct - expectedPct) > 0.01 {
                let msg = String(format: "\"%@\" sub-class %% sum=%.1f%% (expected %.1f%%)", cls.name, subPct, expectedPct)
                warnings.append(msg)
                log("WARN", msg, type: .default)
            }

            log("DEBUG", "\"\(cls.name)\" sub-class CHF sum=\(formatChf(subAmt))", type: .debug)
            let expectedAmt = (parentPct > 0 || parentAmt > 0) ? parentAmt : 0
            if abs(subAmt - expectedAmt) > 0.01 {
                let msg = "\"\(cls.name)\" sub-class CHF sum=\(formatChf(subAmt)) (expected \(formatChf(expectedAmt)))"
                warnings.append(msg)
                log("WARN", msg, type: .default)
            }
        }

        return warnings
    }

    private func save() {
        let warnings = validateAll()
        if !warnings.isEmpty {
            for w in warnings { log("WARN", w, type: .default) }
            log("ERROR", "Save aborted due to validation errors", type: .error)
            validationError = warnings.map { "Validation Failed: \($0)" }.joined(separator: "\n")
            return
        }
        db.upsertClassTarget(portfolioId: 1,
                             classId: classId,
                             percent: parentPercent,
                             amountChf: parentAmount,
                             tolerance: tolerance)
        log("INFO", "Saving \"\(className)\" id=\(classId): percent=\(parentPercent), CHF=\(parentAmount), kind=\(kind.rawValue), tol=\(tolerance)", type: .info)
        for row in rows {
            db.upsertSubClassTarget(portfolioId: 1,
                                    subClassId: row.id,
                                    percent: row.percent,
                                    amountChf: row.amount,
                                    tolerance: row.tolerance)
            log("INFO", "Saving sub-class \"\(row.name)\" id=\(row.id): percent=\(row.percent), CHF=\(row.amount), kind=\(row.kind.rawValue), tol=\(row.tolerance)", type: .info)
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
