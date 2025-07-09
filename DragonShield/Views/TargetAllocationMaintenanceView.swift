import SwiftUI
import Charts

struct TargetAllocationMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.presentationMode) private var presentation

    @State private var targets: [DatabaseManager.AllocationTarget] = []
    @State private var originalTargets: [DatabaseManager.AllocationTarget] = []

    private var total: Double { targets.map(\.$0.targetPercent).reduce(0, +) }
    private var isValid: Bool { abs(total - 100) < 0.01 }
    private var hasChanges: Bool { targets != originalTargets }

    private var percentFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }

    var body: some View {
        HStack {
            leftPane
            Divider()
            rightPane
        }
        .padding()
        .navigationTitle("Target Allocation")
        .onAppear(perform: loadData)
        .toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                Button("Save") { save() }
                    .keyboardShortcut("s", modifiers: [.command])
                    .modifier(ModernPrimaryButton(color: .blue, isDisabled: !isValid || !hasChanges))
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                Button("Reset") { targets = originalTargets }
                    .modifier(ModernPrimaryButton(color: .orange, isDisabled: !hasChanges))
                Button("Cancel") { presentation.wrappedValue.dismiss() }
                    .modifier(ModernSubtleButton())
            }
        }
    }

    private var leftPane: some View {
        VStack(alignment: .leading) {
            List {
                ForEach($targets) { $entry in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(entry.assetClassName)
                            Spacer()
                            TextField("", value: $entry.targetPercent, formatter: percentFormatter)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                        }
                        Slider(value: $entry.targetPercent, in: 0...100, step: 1)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            HStack {
                Text(String(format: "Total: %.0f%%", total))
                    .foregroundColor(isValid ? .secondary : .red)
                Spacer()
            }
            .padding([.top, .horizontal])
        }
    }

    private var rightPane: some View {
        Chart(targets) { item in
            SectorMark(
                angle: .value("Target", item.targetPercent),
                innerRadius: .ratio(0.5)
            )
            .foregroundStyle(by: .value("Class", item.assetClassName))
            .annotation(position: .overlay) {
                if item.targetPercent > 4 {
                    Text("\(Int(item.targetPercent))%")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .chartLegend(.visible)
        .padding()
    }

    private func loadData() {
        targets = dbManager.fetchPortfolioTargets()
        originalTargets = targets
    }

    private func save() {
        dbManager.savePortfolioTargets(targets)
        originalTargets = targets
    }
}

struct TargetAllocationMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        TargetAllocationMaintenanceView()
            .environmentObject(DatabaseManager())
    }
}
