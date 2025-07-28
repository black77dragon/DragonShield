import SwiftUI

struct TargetAllocationSidePanel: View {
    enum TargetKind: String { case percent, amount }

    struct Child: Identifiable {
        let id: Int
        var name: String
        var value: Double
        var locked: Bool
    }

    let classId: Int
    let className: String
    @State var targetKind: TargetKind = .percent
    @State var parentValue: Double = 0
    @State var children: [Child] = []

    @EnvironmentObject var db: DatabaseManager
    @Environment(\.dismiss) var dismiss

    private var remaining: Double {
        let sum = children.map(\.value).reduce(0, +)
        return targetKind == .percent ? 100.0 - sum : parentValue - sum
    }

    private var canSave: Bool {
        if targetKind == .percent {
            return abs(remaining) < 0.1
        } else {
            return abs(remaining) < 1.0
        }
    }

    private func load() {
        let rows = db.fetchPortfolioTargetRecords(portfolioId: 1)
        if let row = rows.first(where: { $0.classId == classId && $0.subClassId == nil }) {
            parentValue = row.amountCHF ?? row.percent
            targetKind = TargetKind(rawValue: row.targetKind) ?? .percent
        }
        children = rows.filter { $0.subClassId != nil && $0.classId == classId }.map {
            Child(id: $0.subClassId!, name: "Sub \($0.subClassId!)", value: $0.amountCHF ?? $0.percent, locked: false)
        }
    }

    private func save() {
        if targetKind == .percent {
            db.upsertClassTarget(portfolioId: 1, classId: classId, percent: parentValue)
        } else {
            db.upsertClassTarget(portfolioId: 1, classId: classId, percent: 0, amountChf: parentValue)
        }
        for child in children {
            if targetKind == .percent {
                db.upsertSubClassTarget(portfolioId: 1, subClassId: child.id, percent: child.value)
            } else {
                db.upsertSubClassTarget(portfolioId: 1, subClassId: child.id, percent: 0, amountChf: child.value)
            }
        }
        dismiss()
    }

    private func autoBalance() {
        var unlocked = children.enumerated().filter { !$0.element.locked }
        guard !unlocked.isEmpty else { return }
        let remainder = remaining
        let share = remainder / Double(unlocked.count)
        for idx in unlocked.map(\.offset) {
            children[idx].value = (children[idx].value + share).rounded(toPlaces: 1)
        }
        let diff = remaining
        if let last = unlocked.last?.offset {
            children[last].value = (children[last].value - diff).rounded(toPlaces: 1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Edit targets — \(className)")
                    .font(.headline)
                Spacer()
            }
            Picker("Target Kind", selection: $targetKind) {
                Text("%").tag(TargetKind.percent)
                Text("CHF").tag(TargetKind.amount)
            }.pickerStyle(.radioGroup)
            HStack {
                TextField("", value: $parentValue, format: .number)
                    .frame(width: 80)
                Text(targetKind == .percent ? "%" : "CHF")
            }
            Divider()
            List($children) { $child in
                HStack {
                    Text(child.name)
                    Spacer()
                    TextField("", value: $child.value, format: .number)
                        .frame(width: 80)
                    if targetKind == .percent { Text("%") } else { Text("CHF") }
                }
            }
            Text(String(format: "Remaining to allocate: %.1f %@", remaining, targetKind == .percent ? "%" : "CHF"))
                .foregroundColor(abs(remaining) < 0.001 ? .primary : .red)
            HStack {
                Button("Auto-balance", action: autoBalance)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }.disabled(!canSave)
            }
        }
        .padding()
        .onAppear(perform: load)
        .frame(width: 300)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}

struct TargetAllocationSidePanel_Previews: PreviewProvider {
    static var previews: some View {
        TargetAllocationSidePanel(classId: 1, className: "Equity")
            .environmentObject(DatabaseManager())
    }
}
