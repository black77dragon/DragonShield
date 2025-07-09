import SwiftUI
import Charts

struct TargetAllocationMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.presentationMode) private var presentation

    @State private var classTargets: [DatabaseManager.ClassTarget] = []
    @State private var originalTargets: [DatabaseManager.ClassTarget] = []
    @State private var editingIndex: Int?

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
        .sheet(isPresented: Binding(get: { editingIndex != nil }, set: { if !$0 { editingIndex = nil } })) {
            if let index = editingIndex {
                SubClassEditor(classTarget: $classTargets[index])
            }
        }
    }

    private var leftPane: some View {
        VStack(alignment: .leading) {
            List {
                ForEach($classTargets, id: \.id) { $cls in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(cls.name)
                            if cls.subTargets.contains(where: { $0.targetPercent > 0 }) {
                                Image(systemName: "rectangle.split.3x3")
                                    .foregroundColor(.blue)
                                    .help("Using sub-class targets")
                            }
                            Spacer()
                            TextField("", value: $cls.targetPercent, formatter: percentFormatter)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .onChange(of: cls.targetPercent) { newVal in
                                    cls.targetPercent = min(100, max(0, newVal))
                                }
                        }
                        Slider(value: $cls.targetPercent, in: 0...100, step: 5)
                            .accessibilityLabel(Text("Target for \(cls.name)"))

                        if !cls.subTargets.isEmpty {
                            Button("Sub-Classes") {
                                editingIndex = classTargets.firstIndex(where: { $0.id == cls.id })
                            }
                            .buttonStyle(.borderless)
                            .keyboardShortcut(.defaultAction)
                            .accessibilityLabel(Text("Edit sub-classes for \(cls.name)"))
                        }
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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

private struct SubClassEditor: View {
    @Binding var classTarget: DatabaseManager.ClassTarget
    @Environment(\.dismiss) private var dismiss

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
                List {
                    ForEach($classTarget.subTargets, id: \.id) { $sub in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(sub.name)
                                Spacer()
                                TextField("", value: $sub.targetPercent, formatter: percentFormatter)
                                    .frame(width: 50)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                    .onChange(of: sub.targetPercent) { newVal in
                                        sub.targetPercent = min(100, max(0, newVal))
                                    }
                            }
                            Slider(value: $sub.targetPercent, in: 0...100, step: 5)
                                .accessibilityLabel(Text("Target for \(sub.name)"))
                        }
                        .padding(.vertical, 4)
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
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}
