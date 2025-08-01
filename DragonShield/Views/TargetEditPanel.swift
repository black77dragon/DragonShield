import SwiftUI

struct TargetEditPanel: View {
    @EnvironmentObject var db: DatabaseManager
    let classId: Int
    let onClose: () -> Void

    @State private var className: String = ""
    @State private var classKind: TargetKind = .percent
    @State private var classPercent: Double = 0
    @State private var classChf: Double = 0
    @State private var classTolerance: Double = 5
    @State private var rows: [Row] = []

    struct Row: Identifiable {
        let id: Int
        let name: String
        var kind: TargetKind
        var percent: Double
        var chf: Double
        var tolerance: Double
        var locked: Bool = false
    }

    enum TargetKind: String, CaseIterable { case percent, amount }

    private var total: Double {
        if classKind == .percent { return rows.map(\.percent).reduce(0, +) }
        return rows.map(\.chf).reduce(0, +)
    }

    private var remaining: Double {
        if classKind == .percent { return classPercent - total }
        return classChf - total
    }

    private var parentOK: Bool {
        if classKind == .percent {
            return abs(remaining) < 0.1
        } else {
            return abs(remaining) < 1.0
        }
    }

    private var canSave: Bool {
        if classKind == .percent { return parentOK && classPercent >= 0 && rows.allSatisfy { $0.percent >= 0 } }
        return parentOK && classChf >= 0 && rows.allSatisfy { $0.chf >= 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit \"\(className)\" Targets")
                .font(.headline)

            Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Target Kind")
                    Text("Target Value")
                    Text("Tolerance (%)")
                }
                .font(.subheadline.bold())
                GridRow {
                    Picker("Target Kind", selection: $classKind) {
                        Text("%").tag(TargetKind.percent)
                        Text("CHF").tag(TargetKind.amount)
                    }
                    .pickerStyle(.radioGroup)
                    TextField("", value: classKind == .percent ? $classPercent : $classChf, formatter: Self.numberFormatter)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                    TextField("", value: $classTolerance, formatter: Self.numberFormatter)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(8)
            .background(Color(red: 0.90, green: 0.96, blue: 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("Sub-Class Targets:")
                .font(.headline)

            Grid(horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("% / CHF")
                    Text("Value")
                    Text("Tolerance")
                    Text("Name")
                }
                .font(.subheadline.bold())
                ForEach($rows) { $row in
                    Divider()
                    GridRow {
                        Picker("Mode", selection: $row.kind) {
                            Text("%").tag(TargetKind.percent)
                            Text("CHF").tag(TargetKind.amount)
                        }
                        TextField("", value: row.kind == .percent ? $row.percent : $row.chf, formatter: Self.numberFormatter)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                        TextField("", value: $row.tolerance, formatter: Self.numberFormatter)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                        Text(row.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Text("Remaining to allocate: \(remaining, format: .number.precision(.fractionLength(1))) \(classKind == .percent ? "%" : "CHF")")
                .foregroundColor(parentOK ? .primary : .red)

            HStack {
                Button("Auto-Balance") { autoBalance() }
                Spacer()
                Button("Cancel") { onClose() }
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
        .onAppear { load() }
    }

    private func load() {
        className = db.fetchAssetClassDetails(id: classId)?.name ?? ""
        let records = db.fetchPortfolioTargetRecords(portfolioId: 1)
        if let parent = records.first(where: { $0.classId == classId && $0.subClassId == nil }) {
            classKind = parent.targetKind == "amount" ? .amount : .percent
            classPercent = parent.percent
            classChf = parent.amountCHF ?? 0
            classTolerance = parent.tolerance
        }
        let subs = db.subAssetClasses(for: classId)
        rows = subs.map { sub in
            let rec = records.first(where: { $0.subClassId == sub.id })
            let kind = rec.map { $0.targetKind == "amount" ? TargetKind.amount : TargetKind.percent } ?? classKind
            return Row(id: sub.id,
                       name: sub.name,
                       kind: kind,
                       percent: rec?.percent ?? 0,
                       chf: rec?.amountCHF ?? 0,
                       tolerance: rec?.tolerance ?? classTolerance)
        }
    }

    private func autoBalance() {
        let unlocked = rows.indices.filter { !rows[$0].locked }
        guard !unlocked.isEmpty else { return }
        let share = remaining / Double(unlocked.count)
        for idx in unlocked {
            if classKind == .percent { rows[idx].percent += share } else { rows[idx].chf += share }
        }
        if let last = unlocked.last {
            let adjust = remaining - share * Double(unlocked.count)
            if classKind == .percent { rows[last].percent += adjust } else { rows[last].chf += adjust }
        }
    }

    private func save() {
        db.upsertClassTarget(portfolioId: 1,
                             classId: classId,
                             percent: classPercent,
                             amountChf: classChf,
                             tolerance: classTolerance)
        for r in rows {
            db.upsertSubClassTarget(portfolioId: 1,
                                   subClassId: r.id,
                                   percent: r.percent,
                                   amountChf: r.chf,
                                   tolerance: r.tolerance)
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
