import SwiftUI

struct TargetEditPanel: View {
    @EnvironmentObject var db: DatabaseManager
    let classId: Int
    let onClose: () -> Void

    @State private var className: String = ""
    @State private var kind: TargetKind = .percent
    @State private var parentPercent: Double = 0
    @State private var parentAmount: Double = 0
    @State private var tolerance: Double = 5
    @State private var rows: [Row] = []

    struct Row: Identifiable {
        let id: Int
        let name: String
        var kind: TargetKind
        var percent: Double
        var amount: Double
        var tolerance: Double
    }

    enum TargetKind: String, CaseIterable { case percent, amount }

    private var total: Double {
        if kind == .percent {
            rows.reduce(0) { $0 + $1.percent }
        } else {
            rows.reduce(0) { $0 + $1.amount }
        }
    }

    private var remaining: Double {
        if kind == .percent {
            parentPercent - total
        } else {
            parentAmount - total
        }
    }

    private var remainingText: String {
        let suffix = kind == .percent ? "%" : "CHF"
        let val = remaining
        let formatted = Self.numberFormatter.string(from: NSNumber(value: abs(val))) ?? "0"
        if val == 0 {
            return "Remaining to allocate: 0\(suffix)"
        }
        let sign = val < 0 ? "–" : ""
        return "Remaining to allocate: \(sign)\(formatted) \(suffix)"
    }

    private var bindingForParentValue: Binding<Double> {
        Binding<Double>(
            get: { kind == .percent ? parentPercent : parentAmount },
            set: { newVal in
                if kind == .percent { parentPercent = newVal } else { parentAmount = newVal }
            }
        )
    }

    private func binding(for row: Row) -> Binding<Double> {
        Binding<Double>(
            get: { row.kind == .percent ? row.percent : row.amount },
            set: { newVal in
                if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                    if row.kind == .percent { rows[idx].percent = newVal } else { rows[idx].amount = newVal }
                }
            }
        )
    }

    private var canSave: Bool {
        if kind == .percent {
            abs(total - parentPercent) < 0.1
        } else {
            abs(total - parentAmount) < 1.0
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit \"\(className)\" Targets")
                .font(.headline)
            VStack {
                Grid(horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Target Kind")
                        Text(kind == .percent ? "Target %" : "Target CHF")
                        Text("Tolerance (%)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    GridRow {
                        Picker("Target Kind", selection: $kind) {
                            Text("%").tag(TargetKind.percent)
                            Text("CHF").tag(TargetKind.amount)
                        }
                        .pickerStyle(.radioGroup)
                        .frame(width: 100, alignment: .leading)

                        TextField("", value: bindingForParentValue, formatter: Self.numberFormatter)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)

                        TextField("", value: $tolerance, formatter: Self.numberFormatter)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(8)
                .background(Color.groupBlue)
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sub-Class Targets:")
                    .font(.headline)
                Grid(horizontalSpacing: 16, verticalSpacing: 4) {
                    GridRow {
                        Text("%  CHF")
                        Text("Value")
                        Text("Tolerance")
                        Text("")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    ForEach($rows) { $row in
                        GridRow {
                            Picker("", selection: $row.kind) {
                                Text("%").tag(TargetKind.percent)
                                Text("CHF").tag(TargetKind.amount)
                            }
                            .pickerStyle(.radioGroup)
                            .frame(width: 80, alignment: .leading)

                            TextField("", value: binding(for: row), formatter: Self.numberFormatter)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)

                            TextField("", value: $row.tolerance, formatter: Self.numberFormatter)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)

                            Text(row.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                    }
                }
            }

            Text(remainingText)
                .foregroundColor(remaining == 0 ? .primary : .red)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Auto-Balance", action: autoBalance)
                Spacer()
                Button("Cancel") { onClose() }
                Button("Save") { save() }
                    .disabled(!canSave)
            }
            .padding(.top)
        }
        .padding(20)
        .frame(maxWidth: 400)
        .onAppear(perform: load)
    }

    private func load() {
        className = db.fetchAssetClassDetails(id: classId)?.name ?? ""
        let records = db.fetchPortfolioTargetRecords(portfolioId: 1)
        if let parent = records.first(where: { $0.classId == classId && $0.subClassId == nil }) {
            kind = TargetKind(rawValue: parent.targetKind) ?? .percent
            parentPercent = parent.percent
            parentAmount = parent.amountCHF ?? 0
            tolerance = parent.tolerance
        }
        let subs = db.subAssetClasses(for: classId)
        rows = subs.map { sub in
            let rec = records.first(where: { $0.subClassId == sub.id })
            return Row(
                id: sub.id,
                name: sub.name,
                kind: TargetKind(rawValue: rec?.targetKind ?? kind.rawValue) ?? kind,
                percent: rec?.percent ?? 0,
                amount: rec?.amountCHF ?? 0,
                tolerance: rec?.tolerance ?? tolerance
            )
        }
    }

    private func autoBalance() {
        guard !rows.isEmpty else { return }
        let share = remaining / Double(rows.count)
        for idx in rows.indices {
            if kind == .percent {
                rows[idx].percent += share
            } else {
                rows[idx].amount += share
            }
        }
        if let last = rows.indices.last {
            if kind == .percent {
                rows[last].percent += remaining - share * Double(rows.count)
            } else {
                rows[last].amount += remaining - share * Double(rows.count)
            }
        }
    }

    private func save() {
        db.upsertClassTarget(portfolioId: 1,
                             classId: classId,
                             percent: parentPercent,
                             amountChf: parentAmount,
                             tolerance: tolerance)
        for row in rows {
            db.upsertSubClassTarget(portfolioId: 1,
                                    subClassId: row.id,
                                    percent: row.percent,
                                    amountChf: row.amount,
                                    tolerance: row.tolerance)
        }
        onClose()
    }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }()
}

struct TargetEditPanel_Previews: PreviewProvider {
    static var previews: some View {
        TargetEditPanel(classId: 1, onClose: {})
            .environmentObject(DatabaseManager())
    }
}
