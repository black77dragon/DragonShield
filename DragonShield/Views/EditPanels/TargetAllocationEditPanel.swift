import SwiftUI

struct SubTargetInput: Identifiable {
    let id: Int
    let name: String
    var value: Double
}

final class TargetAllocationEditorModel: ObservableObject {
    @Published var kind: AllocationInputMode = .percent
    @Published var targetValue: Double = 0
    @Published var subTargets: [SubTargetInput] = []
    @Published var className: String = ""
    @Published var kindLocked = false

    private let classId: Int
    private unowned let db: DatabaseManager
    private let portfolioId: Int = 1

    init(classId: Int, db: DatabaseManager) {
        self.classId = classId
        self.db = db
        load()
    }

    func load() {
        className = db.fetchAssetClassDetails(id: classId)?.name ?? ""
        subTargets = db.subAssetClasses(for: classId).map {
            SubTargetInput(id: $0.id, name: $0.name, value: 0)
        }
        for row in db.fetchPortfolioTargetRecords(portfolioId: portfolioId) {
            if row.classId == classId && row.subClassId == nil {
                targetValue = row.amountCHF ?? row.percent
                kind = AllocationInputMode(rawValue: row.targetKind) ?? .percent
            }
            if let subId = row.subClassId, row.classId == classId {
                if let idx = subTargets.firstIndex(where: { $0.id == subId }) {
                    subTargets[idx].value = row.amountCHF ?? row.percent
                }
            }
        }
        kindLocked = !subTargets.isEmpty
    }

    private var tolerance: Double { kind == .percent ? 0.1 : 1.0 }

    var remainder: Double {
        let sum = subTargets.map { $0.value }.reduce(0, +)
        return kind == .percent ? 100 - sum : targetValue - sum
    }

    var canSave: Bool { abs(remainder) <= tolerance }

    func autoBalance() {
        guard !subTargets.isEmpty else { return }
        let share = remainder / Double(subTargets.count)
        for idx in subTargets.indices { subTargets[idx].value += share }
        if let last = subTargets.indices.last {
            let sum = subTargets.map { $0.value }.reduce(0, +)
            let diff = (kind == .percent ? (100 - sum) : (targetValue - sum))
            subTargets[last].value += diff
        }
    }

    func save() {
        if kind == .percent {
            db.upsertClassTarget(portfolioId: portfolioId,
                                  classId: classId,
                                  percent: targetValue,
                                  amountChf: nil)
            for sub in subTargets {
                db.upsertSubClassTarget(portfolioId: portfolioId,
                                         subClassId: sub.id,
                                         percent: sub.value,
                                         amountChf: nil)
            }
        } else {
            db.upsertClassTarget(portfolioId: portfolioId,
                                  classId: classId,
                                  percent: 0,
                                  amountChf: targetValue)
            for sub in subTargets {
                db.upsertSubClassTarget(portfolioId: portfolioId,
                                         subClassId: sub.id,
                                         percent: 0,
                                         amountChf: sub.value)
            }
        }
    }

    func binding(for sub: SubTargetInput) -> Binding<Double> {
        Binding(
            get: {
                subTargets.first(where: { $0.id == sub.id })?.value ?? 0
            },
            set: { newVal in
                if let idx = subTargets.firstIndex(where: { $0.id == sub.id }) {
                    subTargets[idx].value = newVal
                }
            }
        )
    }
}

struct TargetAllocationEditPanel: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: TargetAllocationEditorModel

    private var percentFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        return f
    }

    private var chfFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "'"
        f.usesGroupingSeparator = true
        return f
    }

    private func format(_ value: Double) -> String {
        let formatter = model.kind == .percent ? percentFormatter : chfFormatter
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Back") { dismiss() }
                Spacer()
                Text("Edit targets — \(model.className)")
                Spacer()
            }
            Divider()
            Text("TARGET KIND").font(.caption)
            Picker("Kind", selection: $model.kind) {
                Text("%" ).tag(AllocationInputMode.percent)
                Text("CHF").tag(AllocationInputMode.chf)
            }
            .pickerStyle(.radioGroup)
            .disabled(model.kindLocked)
            Text("TARGET VALUE").font(.caption)
            HStack {
                TextField("", value: $model.targetValue, formatter: model.kind == .percent ? percentFormatter : chfFormatter)
                    .frame(width: 80)
                Text(model.kind == .percent ? "%" : "CHF")
            }
            Divider()
            Text("SUB-CLASS TARGETS").font(.caption)
            ForEach(model.subTargets) { sub in
                HStack {
                    Text(sub.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("", value: model.binding(for: sub), formatter: model.kind == .percent ? percentFormatter : chfFormatter)
                        .frame(width: 80)
                    Text(model.kind == .percent ? "%" : "CHF")
                }
            }
            Text("Remaining to allocate: \(format(model.remainder)) \(model.kind == .percent ? "%" : "CHF")")
                .foregroundColor(model.canSave ? .primary : .red)
                .font(.caption)
            Divider()
            HStack {
                Button("Auto-balance") { model.autoBalance() }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    model.save()
                    dismiss()
                }
                .disabled(!model.canSave)
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}

#if DEBUG
struct TargetAllocationEditPanel_Previews: PreviewProvider {
    static var previews: some View {
        TargetAllocationEditPanel(model: TargetAllocationEditorModel(classId: 1, db: DatabaseManager()))
            .frame(width: 360)
    }
}
#endif
