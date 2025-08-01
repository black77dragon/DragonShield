import SwiftUI

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

    private var canSave: Bool {
        if kind == .percent {
            abs(subTotal - 100) < 0.1 && parentPercent >= 0
        } else {
            abs(subTotal - parentAmount) < 1.0 && parentAmount >= 0
        }
    }

    private var targetLabel: String { kind == .percent ? "Target %" : "Target CHF" }

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
                HStack {
                    Text(targetLabel)
                    Spacer()
                    TextField("", value: kind == .percent ? $parentPercent : $parentAmount,
                              formatter: Self.numberFormatter)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
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
                    Text("Value").frame(width: 80, alignment: .trailing)
                    Text("Tol %").frame(width: 60, alignment: .trailing)
                    Text("")
                }
                Divider().gridCellColumns(4)
                ForEach($rows) { $row in
                    GridRow {
                        Picker("", selection: $row.kind) {
                            Text("%").tag(TargetKind.percent)
                            Text("CHF").tag(TargetKind.amount)
                        }
                        .pickerStyle(.radioGroup)
                        .frame(width: 80)

                        TextField("", value: row.kind == .percent ? $row.percent : $row.amount,
                                  formatter: Self.numberFormatter)
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
                    Divider().background(Color.systemGray4).gridCellColumns(4)
                }
            }

            Text("Remaining to allocate: \(remaining, format: .number.precision(.fractionLength(1))) \(kind == .percent ? "%" : "CHF")")
                .foregroundColor(remaining == 0 ? .primary : .red)

            HStack {
                Button("Auto-balance") { autoBalance() }
                Spacer()
                Button("Cancel") { onClose() }
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .padding()
        .frame(minWidth: 360)
        .onAppear { load() }
    }

    private func load() {
        className = db.fetchAssetClassDetails(id: classId)?.name ?? ""
        let records = db.fetchPortfolioTargetRecords(portfolioId: 1)
        if let parent = records.first(where: { $0.classId == classId && $0.subClassId == nil }) {
            kind = parent.targetKind == "amount" ? .amount : .percent
            parentPercent = parent.percent
            parentAmount = parent.amountCHF ?? 0
            tolerance = parent.tolerance
        }
        let subs = db.subAssetClasses(for: classId)
        rows = subs.map { sub in
            let rec = records.first { $0.subClassId == sub.id }
            let rk = rec?.targetKind == "amount" ? TargetKind.amount : TargetKind.percent
            return Row(id: sub.id,
                       name: sub.name,
                       percent: rec?.percent ?? 0,
                       amount: rec?.amountCHF ?? 0,
                       kind: rk,
                       tolerance: rec?.tolerance ?? tolerance)
        }
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
