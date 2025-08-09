import SwiftUI
import OSLog
import Foundation

extension Notification.Name {
    static let targetsUpdated = Notification.Name("targetsUpdated")
}

struct TargetEditPanel: View {
    @EnvironmentObject var db: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    let classId: Int

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
    @State private var validationStatus: String = "compliant"
    @State private var isInitialLoad = true
    @State private var initialRows: [Int: Row] = [:]
    @State private var showReasons = false
    @State private var statusLoadError = false

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

    private var showWhyLink: Bool {
        (validationStatus.lowercased() == "warning" || validationStatus.lowercased() == "error") && !reasons.isEmpty
    }

    private var statusLabel: String {
        switch validationStatus.lowercased() {
        case "warning": return "Warning"
        case "error": return "Error"
        case "compliant": return "Compliant"
        default: return "Unknown"
        }
    }

    private var reasons: [String] {
        var msgs: [String] = []
        let tol = tolerance
        let tolStr = String(format: "%.1f", tol)
        if abs(sumChildPercent - 100) > tol {
            msgs.append("Sub-class % sum is \(formatPercent(sumChildPercent))% (expected 100% ± \(tolStr)%).")
        }
        if rows.contains(where: { $0.kind == .amount }) || kind == .amount {
            let delta = abs(sumChildAmount - parentAmount)
            let tolAmt = parentAmount * tol / 100
            if delta > tolAmt {
                msgs.append("Sub-class CHF sum is \(formatChf(sumChildAmount)) (expected \(formatChf(parentAmount)) ± \(tolStr)%).")
            }
        }
        if kind == .percent {
            if abs(remaining) > tol {
                msgs.append("Remaining to allocate is \(formatPercent(remaining))% (expected 0% ± \(tolStr)%).")
            }
        } else {
            let tolAmt = parentAmount * tol / 100
            if abs(remaining) > tolAmt {
                msgs.append("Remaining to allocate is \(formatChf(remaining)) (expected 0 ± \(tolStr)%).")
            }
        }
        if kind == .percent && rows.contains(where: { $0.kind == .amount }) && parentAmount == 0 {
            msgs.append("Class target is %, but sub-targets are CHF without a defined class CHF baseline.")
        }
        return msgs
    }
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sub-Class Targets:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Name")
                                .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
                            Text("Kind").frame(width: 80)
                            Text("Target %").frame(width: 80, alignment: .trailing)
                            Text("Target CHF").frame(width: 100, alignment: .trailing)
                            Text("Tol %").frame(width: 60, alignment: .trailing)
                        }
                        Divider()
                        ForEach($rows) { $row in
                            HStack {
                                Text(row.name)
                                    .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)

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
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }

                    Text("Remaining to allocate: \(remaining, format: .number.precision(.fractionLength(1))) \(kind == .percent ? "%" : "CHF")")
                        .foregroundColor(remaining == 0 ? .primary : .red)
                }
                .padding(24)
            }
            Divider()
            footerSection
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("Asset Allocation for \(className)")
        .onAppear { load() }
        .onChange(of: kind) { _, _ in
            guard !isInitialLoad else { return }
            if kind == .percent {
                parentAmount = portfolioTotal * parentPercent / 100
            } else {
                parentPercent = portfolioTotal > 0 ? parentAmount / portfolioTotal * 100 : 0
            }
            updateRows()
        }
        .onChange(of: parentAmount) { _, _ in
            guard !isInitialLoad else { return }
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
        .onChange(of: validationStatus) { _, newVal in
            if newVal.lowercased() != "warning" && newVal.lowercased() != "error" {
                showReasons = false
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Target Kind")
                    Picker("", selection: $kind) {
                        Text("%").tag(TargetKind.percent)
                        Text("CHF").tag(TargetKind.amount)
                    }
                    .pickerStyle(.radioGroup)
                    .frame(width: 120)
                }

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
                        }
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
                        }
                }

                VStack(alignment: .leading) {
                    Text("Tolerance %")
                    TextField("", value: $tolerance, formatter: Self.numberFormatter)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                }

                Spacer()

                VStack(alignment: .leading) {
                    HStack {
                        Text("Validation Status")
                        if showWhyLink {
                            Button("Why?") {
                                let rs = reasons
                                log("WHY?", "class id=\(classId) reasons: \(rs.joined(separator: "; "))", type: .info)
                                showReasons.toggle()
                            }
                            .font(.caption)
                        }
                    }
                    Text(statusLabel)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorForStatus(validationStatus))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .help(statusLoadError ? "Couldn't load validation status" : "")
                    if showReasons {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(reasons, id: \.self) { reason in
                                HStack(alignment: .top, spacing: 4) {
                                    Text("•")
                                    Text(reason)
                                }
                            }
                        }
                        .font(.caption)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Divider()
            HStack(spacing: 32) {
                Text("Σ Sub-class % = \(sumChildPercent, format: .number.precision(.fractionLength(1)))%")
                Text("Σ Sub-class CHF = \(formatChf(sumChildAmount))")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding(24)
        .background(Color.sectionBlue.cornerRadius(8))
    }

    private var footerSection: some View {
        HStack {
            Button("Auto-balance") { autoBalance() }
            Spacer()
            Button("Cancel") { cancel() }
            Button("Save") { save() }
        }
        .padding([.leading, .trailing, .bottom], 24)
    }

    private func load() {
        className = db.fetchAssetClassDetails(id: classId)?.name ?? ""
        portfolioTotal = calculatePortfolioTotal()
        log("FETCH", "Fetching ClassTargets for id=\(classId)", type: .info)
        if let parent = db.fetchClassTarget(classId: classId) {
            kind = parent.targetKind == "amount" ? .amount : .percent
            parentPercent = parent.percent
            parentAmount = parent.amountCHF
            tolerance = parent.tolerance
            validationStatus = parent.validationStatus
            statusLoadError = false
            log("STATUS", "Loaded validation_status=\(validationStatus) for class id=\(classId)", type: .info)
        } else {
            kind = .percent
            parentPercent = 0
            parentAmount = 0
            tolerance = 0
            validationStatus = "unknown"
            statusLoadError = true
            log("STATUS", "Failed to load validation_status for class id=\(classId)", type: .error)
        }
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
        isInitialLoad = false
        showReasons = false
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
        log("EDIT PANEL CANCEL", "Discarded changes for \(className)", type: .info)
        NotificationCenter.default.post(name: .targetsUpdated, object: nil)
        dismiss()
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
        let oldStatus = validationStatus
        if let status = db.fetchClassValidationStatus(classId: classId) {
            validationStatus = status
            statusLoadError = false
            log("STATUS", "Badge status \(oldStatus)→\(status)", type: .info)
        } else {
            validationStatus = "unknown"
            statusLoadError = true
            log("STATUS", "Badge status \(oldStatus)→unknown", type: .error)
        }
        NotificationCenter.default.post(name: .targetsUpdated, object: nil)
        dismiss()
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "warning": return .warning
        case "error": return .error
        case "compliant": return .success
        default: return .gray
        }
    }

    private func formatChf(_ value: Double) -> String {
        Self.chfFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    private func formatPercent(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
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
        TargetEditPanel(classId: 1)
            .environmentObject(DatabaseManager())
    }
}
