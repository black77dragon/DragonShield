import SwiftUI

struct TargetAllocationEditPanel: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    let classId: Int
    let className: String

    @State private var mode: AllocationInputMode = .percent
    @State private var targetValue: Double = 0
    @State private var subTargets: [SubRow] = []

    struct SubRow: Identifiable {
        let id: Int
        let name: String
        var value: Double
        var locked: Bool = false
    }

    private var remaining: Double {
        let sum = subTargets.map(\.value).reduce(0, +)
        if mode == .percent {
            return 100 - sum
        }
        return targetValue - sum
    }

    private var canSave: Bool { abs(remaining) < 0.1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Back") { dismiss() }
                Spacer()
                Text("Edit targets — \(className)")
                    .font(.headline)
                Spacer()
            }
            Divider()
            Picker("Target Kind", selection: $mode) {
                Text("%").tag(AllocationInputMode.percent)
                Text("CHF").tag(AllocationInputMode.chf)
            }
            .pickerStyle(.segmented)
            HStack {
                Text("Target Value")
                TextField("", value: $targetValue, formatter: numberFormatter)
                    .frame(width: 80)
                Text(mode == .percent ? "%" : "CHF")
            }
            Divider()
            Text("Sub-Class Targets")
                .font(.subheadline)
            ForEach($subTargets) { $row in
                HStack {
                    Text(row.name)
                        .frame(width: 160, alignment: .leading)
                    TextField("", value: $row.value, formatter: numberFormatter)
                        .frame(width: 80, alignment: .trailing)
                }
            }
            Text(String(format: "Remaining to allocate: %.1f %@",
                         remaining,
                         mode == .percent ? "%" : "CHF"))
                .foregroundColor(canSave ? .secondary : .red)
            HStack {
                Button("Auto-balance") { autoBalance() }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear { load() }
    }

    private var numberFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }

    private func load() {
        let rows = dbManager.fetchPortfolioTargetRecords(portfolioId: 1)
        if let classRow = rows.first(where: { $0.classId == classId && $0.subClassId == nil }) {
            targetValue = classRow.amountCHF ?? classRow.percent
            mode = AllocationInputMode(rawValue: classRow.targetKind) ?? .percent
        }
        subTargets = dbManager.subAssetClasses(for: classId).map { sub in
            let row = rows.first(where: { $0.subClassId == sub.id })
            let val = row?.amountCHF ?? row?.percent ?? 0
            return SubRow(id: sub.id, name: sub.name, value: val)
        }
    }

    private func autoBalance() {
        var unlockedIndices: [Int] = []
        for (idx, row) in subTargets.enumerated() where !row.locked {
            unlockedIndices.append(idx)
        }
        guard !unlockedIndices.isEmpty else { return }
        let share = remaining / Double(unlockedIndices.count)
        for idx in unlockedIndices {
            subTargets[idx].value += share
            subTargets[idx].value = (subTargets[idx].value * 10).rounded() / 10
        }
        let drift: Double
        if mode == .percent {
            drift = 100 - subTargets.map(\.value).reduce(0, +)
        } else {
            drift = targetValue - subTargets.map(\.value).reduce(0, +)
        }
        if let last = unlockedIndices.last {
            subTargets[last].value += drift
        }
    }

    private func save() {
        if mode == .percent {
            dbManager.upsertClassTarget(portfolioId: 1,
                                        classId: classId,
                                        percent: targetValue,
                                        amountChf: nil,
                                        kind: mode)
            for row in subTargets {
                dbManager.upsertSubClassTarget(portfolioId: 1,
                                               subClassId: row.id,
                                               percent: row.value,
                                               amountChf: nil,
                                               kind: mode)
            }
        } else {
            dbManager.upsertClassTarget(portfolioId: 1,
                                        classId: classId,
                                        percent: 0,
                                        amountChf: targetValue,
                                        kind: mode)
            for row in subTargets {
                dbManager.upsertSubClassTarget(portfolioId: 1,
                                               subClassId: row.id,
                                               percent: 0,
                                               amountChf: row.value,
                                               kind: mode)
            }
        }
        dismiss()
    }
}

struct TargetAllocationEditPanel_Previews: PreviewProvider {
    static var previews: some View {
        TargetAllocationEditPanel(classId: 1, className: "Equity")
            .environmentObject(DatabaseManager())
    }
}
