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
    @State private var errorMessage: String?

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
                                let newAmount = portfolioTotal * newVal / 100
                                LoggingService.shared.log(
                                    "Changed percent \(String(format: "%.1f", oldVal))→\(String(format: "%.1f", newVal)) ⇒ CHF=\(String(format: "%.2f", newVal/100))×\(formatChf(portfolioTotal))=\(formatChf(newAmount))",
                                    type: .debug,
                                    logger: .ui)
                                parentAmount = newAmount
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
                                let newPercent = portfolioTotal > 0 ? newVal / portfolioTotal * 100 : 0
                                LoggingService.shared.log(
                                    "Changed CHF \(formatChf(oldVal))→\(formatChf(newVal)) ⇒ percent=(\(formatChf(newVal))÷\(formatChf(portfolioTotal)))×100=\(String(format: "%.1f", newPercent))",
                                    type: .debug,
                                    logger: .ui)
                                parentPercent = newPercent
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
                                let newAmount = parentAmount * newVal / 100
                                LoggingService.shared.log(
                                    "Changed percent \(String(format: "%.1f", oldVal))→\(String(format: "%.1f", newVal)) ⇒ CHF=\(String(format: "%.2f", newVal/100))×\(formatChf(parentAmount))=\(formatChf(newAmount)) for sub-class \(row.id)",
                                    type: .debug,
                                    logger: .ui)
                                row.amount = newAmount
                            }

                        TextField("", text: chfBinding(key: "row-\(row.id)", value: $row.amount))
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .disabled(row.kind != .amount)
                            .focused($focusedChfField, equals: "row-\(row.id)")
                            .onChange(of: row.amount) { oldVal, newVal in
                                guard row.kind == .amount else { return }
                                let newPercent = parentAmount > 0 ? newVal / parentAmount * 100 : 0
                                LoggingService.shared.log(
                                    "Changed CHF \(formatChf(oldVal))→\(formatChf(newVal)) ⇒ percent=(\(formatChf(newVal))÷\(formatChf(parentAmount)))×100=\(String(format: "%.1f", newPercent)) for sub-class \(row.id)",
                                    type: .debug,
                                    logger: .ui)
                                row.percent = newPercent
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
        .alert("Validation Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
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
            LoggingService.shared.log(
                "Loading \"\(className)\" id=\(classId): percent=\(parentPercent), CHF=\(parentAmount), kind=\(kind.rawValue), tol=\(tolerance)",
                logger: .ui)
        }

        let subs = db.subAssetClasses(for: classId)
        rows = subs.map { sub in
            let rec = records.first { $0.subClassId == sub.id }
            let rk = rec?.targetKind == "amount" ? TargetKind.amount : TargetKind.percent
            let pct = rec?.percent ?? 0
            let amt = rec?.amountCHF ?? parentAmount * pct / 100
            LoggingService.shared.log(
                "Loading sub-class \"\(sub.name)\" id=\(sub.id): percent=\(pct), CHF=\(amt), kind=\(rk.rawValue), tol=\(rec?.tolerance ?? tolerance)",
                logger: .ui)
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

    private func validate() -> Bool {
        var warnings: [String] = []
        let records = db.fetchPortfolioTargetRecords(portfolioId: 1)
        var percentSum = 0.0
        var chfSum = 0.0
        for rec in records where rec.subClassId == nil {
            if rec.classId == classId {
                percentSum += parentPercent
                chfSum += parentAmount
            } else {
                percentSum += rec.percent
                chfSum += rec.amountCHF ?? portfolioTotal * rec.percent / 100
            }
        }
        if abs(percentSum - 100) > 0.01 {
            let msg = "asset-class % sum=\(percentSum) (expected 100%)"
            warnings.append(msg)
            LoggingService.shared.log(msg, type: .default, logger: .ui)
        }
        if abs(chfSum - portfolioTotal) > 0.01 {
            let msg = "asset-class CHF sum=\(chfSum) (expected \(portfolioTotal))"
            warnings.append(msg)
            LoggingService.shared.log(msg, type: .default, logger: .ui)
        }

        let rowPercentSum = rows.map(\.percent).reduce(0, +)
        if abs(rowPercentSum - 100) > 0.01 {
            let msg = "\"\(className)\" sub-class % sum=\(rowPercentSum) (expected 100%)"
            warnings.append(msg)
            LoggingService.shared.log(msg, type: .default, logger: .ui)
        }
        let rowAmountSum = rows.map(\.amount).reduce(0, +)
        if abs(rowAmountSum - parentAmount) > 0.01 {
            let msg = "\"\(className)\" sub-class CHF sum=\(rowAmountSum) (expected \(parentAmount))"
            warnings.append(msg)
            LoggingService.shared.log(msg, type: .default, logger: .ui)
        }

        if !warnings.isEmpty {
            errorMessage = warnings.joined(separator: "\n")
            return false
        }
        return true
    }

    private func save() {
        guard validate() else {
            LoggingService.shared.log("Validation failed; save aborted for class id \(classId)", type: .error, logger: .ui)
            return
        }
        LoggingService.shared.log("Saving \"\(className)\" id=\(classId): percent=\(parentPercent), CHF=\(parentAmount), kind=\(kind.rawValue), tol=\(tolerance)", logger: .ui)
        db.upsertClassTarget(portfolioId: 1,
                             classId: classId,
                             percent: parentPercent,
                             amountChf: parentAmount,
                             tolerance: tolerance)
        for row in rows {
            LoggingService.shared.log("Saving sub-class \"\(row.name)\" id=\(row.id): percent=\(row.percent), CHF=\(row.amount), kind=\(row.kind.rawValue), tol=\(row.tolerance)", logger: .ui)
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
