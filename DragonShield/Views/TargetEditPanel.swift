import SwiftUI

struct TargetEditPanel: View {
    @EnvironmentObject var db: DatabaseManager
    let classId: Int
    let onClose: () -> Void

    @State private var kind: TargetKind = .percent
    @State private var parentValue: Double = 0
    @State private var parentTolerance: Double = 5
    @State private var rows: [Row] = []

    struct Row: Identifiable {
        let id: Int
        let name: String
        var value: Double
        var tolerance: Double
        var locked: Bool = false
    }

    enum TargetKind: String, CaseIterable { case percent, amount }

    private var total: Double { rows.map(\.value).reduce(0, +) }

    private var remaining: Double {
        kind == .percent ? (100 - total) : (parentValue - total)
    }

    private var parentOK: Bool {
        if kind == .percent {
            abs(total - 100) < 0.1
        } else {
            abs(total - parentValue) < 1.0
        }
    }

    private var canSave: Bool {
        parentOK &&
        parentValue >= 0 &&
        parentTolerance >= 0 &&
        rows.allSatisfy { $0.value >= 0 && $0.tolerance >= 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Back") { onClose() }
                Spacer()
                Text("Edit targets")
                    .font(.headline)
            }
            .padding(.bottom)

            HStack {
                Text("Target Kind")
                Spacer()
                Picker("Target Kind", selection: $kind) {
                    Text("%").tag(TargetKind.percent)
                    Text("CHF").tag(TargetKind.amount)
                }
                .pickerStyle(.radioGroup)
                .frame(width: 120)
            }

            HStack {
                Text("Target Value")
                Spacer()
                TextField("", value: $parentValue, formatter: Self.numberFormatter)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                Text(kind == .percent ? "%" : "CHF")
            }

            HStack {
                Text("Tolerance")
                Spacer()
                TextField("", value: $parentTolerance, formatter: Self.numberFormatter)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                Text("%")
            }

            Text("Sub-Class Targets")
                .font(.headline)

            Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 4) {
                ForEach($rows) { $row in
                    GridRow {
                        Text(row.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("", value: $row.value, formatter: Self.numberFormatter)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                        Text(kind == .percent ? "%" : "CHF")
                        TextField("", value: $row.tolerance, formatter: Self.numberFormatter)
                            .frame(width: 40)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                        Text("%")
                    }
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
        .frame(maxWidth: 320)
        .onAppear { load() }
        .transition(.move(edge: .trailing))
    }

    private func load() {
        let records = db.fetchPortfolioTargetRecords(portfolioId: 1)
        if let parent = records.first(where: { $0.classId == classId && $0.subClassId == nil }) {
            if parent.targetKind == "amount" { kind = .amount } else { kind = .percent }
            parentValue = kind == .percent ? parent.percent : (parent.amountCHF ?? 0)
            parentTolerance = parent.tolerance
        }
        let subs = db.subAssetClasses(for: classId)
        rows = subs.map { sub in
            let rec = records.first(where: { $0.subClassId == sub.id })
            let val = kind == .percent ? (rec?.percent ?? 0) : (rec?.amountCHF ?? 0)
            let tol = rec?.tolerance ?? parentTolerance
            return Row(id: sub.id, name: sub.name, value: val, tolerance: tol)
        }
    }

    private func autoBalance() {
        let unlocked = rows.indices.filter { !rows[$0].locked }
        guard !unlocked.isEmpty else { return }
        let share = remaining / Double(unlocked.count)
        for idx in unlocked { rows[idx].value += share }
        // minor adjustment to remove rounding drift
        if let last = unlocked.last { rows[last].value += remaining - share * Double(unlocked.count) }
    }

    private func save() {
        if kind == .percent {
            db.upsertClassTarget(portfolioId: 1, classId: classId, percent: parentValue, targetKind: kind.rawValue, tolerance: parentTolerance)
            for r in rows {
                db.upsertSubClassTarget(portfolioId: 1, subClassId: r.id, percent: r.value, targetKind: kind.rawValue, tolerance: r.tolerance)
            }
        } else {
            db.upsertClassTarget(portfolioId: 1, classId: classId, percent: 0, amountChf: parentValue, targetKind: kind.rawValue, tolerance: parentTolerance)
            for r in rows {
                db.upsertSubClassTarget(portfolioId: 1, subClassId: r.id, percent: 0, amountChf: r.value, targetKind: kind.rawValue, tolerance: r.tolerance)
            }
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
