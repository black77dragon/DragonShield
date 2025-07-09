import SwiftUI
import Charts

struct TargetAllocationMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.presentationMode) private var presentation

    @State private var classTargets: [DatabaseManager.ClassTarget] = []
    @State private var originalTargets: [DatabaseManager.ClassTarget] = []
    @State private var editingIndex: Int?
    @State private var selectedClass: DatabaseManager.ClassTarget?

    private var total: Double {
        classTargets.map(\.targetPercent).reduce(0, +)
    }
    private var subClassTotalsValid: Bool {
        for cls in classTargets {
            if !cls.subTargets.isEmpty {
                let total = cls.subTargets.map(\.targetPercent).reduce(0, +)
                if abs(total - 100) > 0.01 { return false }
            }
        }
        return true
    }

    private var isValid: Bool { abs(total - 100) < 0.01 && subClassTotalsValid }
    private var hasChanges: Bool { classTargets != originalTargets }

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
                Button("Reset") { classTargets = originalTargets }
                    .modifier(ModernPrimaryButton(color: .orange, isDisabled: !hasChanges))
                Button("Cancel") { presentation.wrappedValue.dismiss() }
                    .modifier(ModernSubtleButton())
            }
        }
        .sheet(item: $selectedClass, onDismiss: { editingIndex = nil }) { cls in
            if let index = classTargets.firstIndex(where: { $0.id == cls.id }) {
                SubClassAllocationView(classTarget: $classTargets[index])
            }
        }
    }

    private var leftPane: some View {
        VStack(alignment: .leading) {
            List {
                ForEach($classTargets) { $cls in
                    ClassRow(
                        classTarget: $cls,
                        percentFormatter: percentFormatter,
                        openSubClasses: {
                            selectedClass = cls
                            editingIndex = classTargets.firstIndex(where: { $0.id == cls.id })
                        }
                    )
                }
            }
            HStack {
                Text(String(format: "Total: %.0f%%", total))
                    .foregroundColor(abs(total - 100) < 0.01 ? .secondary : .red)
                Spacer()
            }
            .padding([.top, .horizontal])
        }
    }

    private var chartSegments: [(name: String, percent: Double)] {
        guard let editingIndex = editingIndex else {
            return classTargets.map { ($0.name, $0.targetPercent) }
        }
        return classTargets.enumerated().flatMap { idx, cls in
            if idx == editingIndex && !cls.subTargets.isEmpty {
                return cls.subTargets.map { ($0.name, $0.targetPercent) }
            } else {
                return [(cls.name, cls.targetPercent)]
            }
        }
    }

    private var rightPane: some View {
        Chart(chartSegments, id: \.name) { item in
            SectorMark(
                angle: .value("Target", item.percent),
                innerRadius: .ratio(0.5)
            )
            .foregroundStyle(by: .value("Class", item.name))
            .annotation(position: .overlay) {
                if item.percent > 4 {
                    Text("\(Int(item.percent))%")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .chartLegend(.visible)
        .padding()
    }

    private func loadData() {
        classTargets = dbManager.fetchPortfolioClassTargets()
        originalTargets = classTargets
    }

    private func save() {
        dbManager.savePortfolioClassTargets(classTargets)
        originalTargets = classTargets
    }
}

struct TargetAllocationMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        TargetAllocationMaintenanceView()
            .environmentObject(DatabaseManager())
    }
}

private struct ClassRow: View {
    @Binding var classTarget: DatabaseManager.ClassTarget
    let percentFormatter: NumberFormatter
    var openSubClasses: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(classTarget.name)
                if classTarget.subTargets.contains(where: { $0.targetPercent > 0 }) {
                    Image(systemName: "rectangle.split.3x3")
                        .foregroundColor(.blue)
                        .help("Using sub-class targets")
                }
                Spacer()
                TextField("", value: $classTarget.targetPercent, formatter: percentFormatter)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: classTarget.targetPercent) { newVal in
                        classTarget.targetPercent = min(100, max(0, newVal))
                    }
            }
            Slider(value: $classTarget.targetPercent, in: 0...100, step: 5)
                .accessibilityLabel(Text("Target for \(classTarget.name)"))

            if !classTarget.subTargets.isEmpty {
                Button("Sub-Classes") {
                    openSubClasses()
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel(Text("Edit sub-classes for \(classTarget.name)"))
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SubClassAllocationView: View {
    @Binding var classTarget: DatabaseManager.ClassTarget
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dbManager: DatabaseManager

    private var percentFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }

    private var subtotal: Double {
        classTarget.subTargets.map(\.targetPercent).reduce(0, +)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if classTarget.subTargets.isEmpty {
                    Text("No sub-classes defined for \(classTarget.name)")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach($classTarget.subTargets) { $sub in
                            SubClassRow(subTarget: $sub, percentFormatter: percentFormatter)
                        }
                    }
                }
                HStack {
                    if abs(subtotal - 100) > 0.01 {
                        Label("Totals should equal 100%", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Text(String(format: "Subtotal: %.0f%%", subtotal))
                        .foregroundColor(abs(subtotal - 100) < 0.01 ? .secondary : .red)
                }
                .padding()
            }
            .padding(24)
            .navigationTitle("\(classTarget.name) Sub-Classes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if abs(subtotal - 100) < 0.01 { dismiss() }
                    }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .onAppear {
            if classTarget.subTargets.isEmpty {
                classTarget.subTargets = dbManager.subAssetClasses(for: classTarget.id)
            }
        }
    }
}

private struct SubClassRow: View {
    @Binding var subTarget: DatabaseManager.SubClassTarget
    let percentFormatter: NumberFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(subTarget.name)
                    .font(.system(size: 14))
                Spacer()
                TextField("", value: $subTarget.targetPercent, formatter: percentFormatter)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: subTarget.targetPercent) { newVal in
                        subTarget.targetPercent = min(100, max(0, newVal))
                    }
            }
            Slider(value: Binding(
                get: { subTarget.targetPercent },
                set: { subTarget.targetPercent = min(100, max(0, $0)) }
            ), in: 0...100, step: 5)
                .accessibilityLabel(Text("Target for \(subTarget.name)"))
        }
        .padding(.vertical, 4)
    }
}
