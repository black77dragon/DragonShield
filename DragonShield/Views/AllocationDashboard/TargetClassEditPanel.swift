import SwiftUI

/// Side-panel for editing an asset class target and its sub-classes.
struct TargetClassEditPanel: View {
    @EnvironmentObject var db: DatabaseManager
    @Binding var isPresented: Bool

    let assetClassId: Int

    @StateObject private var viewModel: ViewModel

    init(assetClassId: Int, isPresented: Binding<Bool>) {
        self.assetClassId = assetClassId
        _isPresented = isPresented
        _viewModel = StateObject(wrappedValue: ViewModel(classId: assetClassId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Back") { isPresented = false }
                Spacer()
                Text("Edit targets — \(viewModel.className)")
                    .font(.headline)
            }

            Picker("Target Kind", selection: $viewModel.targetKind) {
                Text("%" ).tag(ViewModel.TargetKind.percent)
                Text("CHF").tag(ViewModel.TargetKind.amount)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.kindLocked)

            HStack {
                TextField("", value: $viewModel.targetValue, formatter: viewModel.valueFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Text(viewModel.unitLabel)
            }

            Divider()

            List {
                ForEach($viewModel.children) { $child in
                    HStack {
                        Text(child.name)
                        Spacer()
                        TextField("", value: $child.value, formatter: viewModel.valueFormatter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
            }
            .listStyle(.plain)

            Text(viewModel.remainingText)
                .foregroundColor(viewModel.remainingIsZero ? .secondary : .red)

            HStack {
                Button("Auto-balance") { viewModel.autoBalance() }
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Save") { viewModel.save(using: db); isPresented = false }
                    .disabled(!viewModel.canSave)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
        .onAppear { viewModel.load(using: db) }
    }
}

extension TargetClassEditPanel {
    final class ViewModel: ObservableObject {
        enum TargetKind: String { case percent, amount }

        struct Child: Identifiable {
            let id: Int
            let name: String
            var value: Double
        }

        @Published var className: String = ""
        @Published var targetKind: TargetKind = .percent
        @Published var targetValue: Double = 0
        @Published var children: [Child] = []
        var kindLocked: Bool = false

        private let classId: Int
        private let tolerancePct: Double = 0.1
        private let toleranceChf: Double = 1.0

        init(classId: Int) {
            self.classId = classId
        }

        var remaining: Double {
            let sum = children.reduce(0) { $0 + $1.value }
            if targetKind == .percent {
                return 100 - sum
            } else {
                return targetValue - sum
            }
        }

        var remainingText: String {
            if targetKind == .percent {
                return String(format: "Remaining to allocate: %.1f %%", remaining)
            } else {
                return String(format: "Remaining to allocate: %.0f CHF", remaining)
            }
        }

        var remainingIsZero: Bool {
            if targetKind == .percent {
                abs(remaining) < tolerancePct
            } else {
                abs(remaining) < toleranceChf
            }
        }

        var canSave: Bool { remainingIsZero && children.allSatisfy { $0.value >= 0 } }

        var valueFormatter: NumberFormatter {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = targetKind == .percent ? 1 : 0
            return f
        }

        var unitLabel: String { targetKind == .percent ? "%" : "CHF" }

        func load(using db: DatabaseManager) {
            if let cls = db.fetchAssetClassDetails(id: classId) {
                className = cls.name
            }
            let rows = db.fetchPortfolioTargetRecords(portfolioId: 1)
            if let row = rows.first(where: { $0.classId == classId && $0.subClassId == nil }) {
                targetKind = TargetKind(rawValue: row.targetKind) ?? .percent
                targetValue = targetKind == .percent ? row.percent : (row.amountCHF ?? 0)
            }
            children = db.subAssetClasses(for: classId).map { sub in
                let childRow = rows.first(where: { $0.subClassId == sub.id })
                let val = targetKind == .percent ? (childRow?.percent ?? 0) : (childRow?.amountCHF ?? 0)
                return Child(id: sub.id, name: sub.name, value: val)
            }
        }

        func autoBalance() {
            var unlockedIndices = Array(children.indices)
            guard !unlockedIndices.isEmpty else { return }
            var remainder = remaining
            let share = remainder / Double(unlockedIndices.count)
            for idx in unlockedIndices.dropLast() {
                children[idx].value += share
                remainder -= share
            }
            if let last = unlockedIndices.last { children[last].value += remainder }
            if targetKind == .percent {
                for idx in children.indices {
                    children[idx].value = (children[idx].value * 10).rounded() / 10
                }
            }
        }

        func save(using db: DatabaseManager) {
            if targetKind == .percent {
                db.upsertClassTarget(portfolioId: 1, classId: classId, percent: targetValue)
                for c in children {
                    db.upsertSubClassTarget(portfolioId: 1, subClassId: c.id, percent: c.value)
                }
            } else {
                db.upsertClassTarget(portfolioId: 1, classId: classId, percent: 0, amountChf: targetValue)
                for c in children {
                    db.upsertSubClassTarget(portfolioId: 1, subClassId: c.id, percent: 0, amountChf: c.value)
                }
            }
        }
    }
}

#if DEBUG
struct TargetClassEditPanel_Previews: PreviewProvider {
    static var previews: some View {
        TargetClassEditPanel(assetClassId: 1, isPresented: .constant(true))
            .environmentObject(DatabaseManager())
    }
}
#endif

