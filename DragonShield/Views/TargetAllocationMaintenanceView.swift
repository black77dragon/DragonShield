import SwiftUI
import Charts

struct TargetAllocationMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.presentationMode) private var presentation

    @StateObject private var viewModel: TargetAllocationViewModel
    @State private var editingIndex: Int?
    @State private var selectedClass: DatabaseManager.AssetClassData?

    init(viewModel: TargetAllocationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var total: Double {
        viewModel.classTargets.values.reduce(0, +)
    }

    private var subClassTotalsValid: Bool {
        for cls in viewModel.assetClasses {
            let subs = viewModel.subAssetClasses(for: cls.id)
            if !subs.isEmpty {
                let subtotal = subs.map { viewModel.subClassTargets[$0.id] ?? 0 }.reduce(0, +)
                if abs(subtotal - 100) > 0.01 { return false }
            }
        }
        return true
    }

    private var hasChanges: Bool {
        // Simple change detection by comparing dictionaries to initial load
        viewModel.classTargets != originalClassTargets || viewModel.subClassTargets != originalSubTargets
    }

    @State private var originalClassTargets: [Int: Double] = [:]
    @State private var originalSubTargets: [Int: Double] = [:]

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
                    .modifier(ModernPrimaryButton(color: .blue, isDisabled: !hasChanges))
            }
            ToolbarItemGroup(placement: .cancellationAction) {
                Button("Reset") {
                    viewModel.classTargets = originalClassTargets
                    viewModel.subClassTargets = originalSubTargets
                }
                    .modifier(ModernPrimaryButton(color: .orange, isDisabled: !hasChanges))
                Button("Cancel") { presentation.wrappedValue.dismiss() }
                    .modifier(ModernSubtleButton())
            }
        }
        .sheet(item: $selectedClass, onDismiss: { editingIndex = nil }) { cls in
            SubClassAllocationView(assetClass: cls, viewModel: viewModel)
        }
    }

    private var leftPane: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(viewModel.assetClasses) { cls in
                    ClassRow(
                        assetClass: cls,
                        target: Binding(
                            get: { viewModel.classTargets[cls.id] ?? 0 },
                            set: { viewModel.classTargets[cls.id] = $0 }
                        ),
                        hasSubClasses: !viewModel.subAssetClasses(for: cls.id).isEmpty,
                        percentFormatter: percentFormatter,
                        openSubClasses: {
                            selectedClass = cls
                            editingIndex = viewModel.assetClasses.firstIndex(where: { $0.id == cls.id })
                        }
                    )
                }
            }
            HStack(spacing: 12) {
                Text(String(format: "Total: %.0f%%", total))
                    .foregroundColor(abs(total - 100) < 0.01 ? .secondary : .red)
                if abs(total - 100) > 0.01 {
                    Text("\u{26A0}\u{FE0F} Total is \(Int(total))% (not 100%)")
                        .foregroundColor(.orange)
                }
                if !subClassTotalsValid {
                    Text("\u{26A0}\u{FE0F} Sub-class totals mismatch")
                        .foregroundColor(.orange)
                }
                Spacer()
            }
            .padding([.top, .horizontal])
        }
    }

    private var chartSegments: [(name: String, percent: Double)] {
        guard let editingIndex = editingIndex else {
            return viewModel.assetClasses.map { ($0.name, viewModel.classTargets[$0.id] ?? 0) }
        }
        return viewModel.assetClasses.enumerated().flatMap { idx, cls in
            if idx == editingIndex {
                let subs = viewModel.subAssetClasses(for: cls.id)
                if !subs.isEmpty {
                    return subs.map { ($0.name, viewModel.subClassTargets[$0.id] ?? 0) }
                }
            }
            return [(cls.name, viewModel.classTargets[cls.id] ?? 0)]
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
        originalClassTargets = viewModel.classTargets
        originalSubTargets = viewModel.subClassTargets
    }

    private func save() {
        viewModel.saveTargets()
        originalClassTargets = viewModel.classTargets
        originalSubTargets = viewModel.subClassTargets
    }
}

struct TargetAllocationMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        let db = DatabaseManager()
        let vm = TargetAllocationViewModel(dbManager: db, portfolioId: 1)
        TargetAllocationMaintenanceView(viewModel: vm)
            .environmentObject(db)
    }
}

private struct ClassRow: View {
    let assetClass: DatabaseManager.AssetClassData
    @Binding var target: Double
    let hasSubClasses: Bool
    let percentFormatter: NumberFormatter
    var openSubClasses: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(assetClass.name)
                if hasSubClasses && (target > 0) {
                    Image(systemName: "rectangle.split.3x3")
                        .foregroundColor(.blue)
                        .help("Using sub-class targets")
                }
                Spacer()
                TextField("", value: $target, formatter: percentFormatter)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: target) { _, newVal in
                        target = min(100, max(0, newVal))
                    }
            }
            Slider(value: $target, in: 0...100, step: 5)
                .accessibilityLabel(Text("Target for \(assetClass.name)"))

            if hasSubClasses {
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
    let assetClass: DatabaseManager.AssetClassData
    @ObservedObject var viewModel: TargetAllocationViewModel
    @Environment(\.presentationMode) private var presentationMode

    private var percentFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }

    private var subtotal: Double {
        viewModel.subAssetClasses(for: assetClass.id)
            .map { viewModel.subClassTargets[$0.id] ?? 0 }
            .reduce(0, +)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                let subs = viewModel.subAssetClasses(for: assetClass.id)
                if subs.isEmpty {
                    Text("No sub-classes for \(assetClass.name)")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(subs, id: \.id) { sub in
                            SubClassRow(
                                sub: sub,
                                target: Binding(
                                    get: { viewModel.subClassTargets[sub.id] ?? 0 },
                                    set: { viewModel.subClassTargets[sub.id] = $0 }
                                ),
                                percentFormatter: percentFormatter
                            )
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
            .navigationTitle("\(assetClass.name) Sub-Classes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if abs(subtotal - 100) < 0.01 {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

private struct SubClassRow: View {
    let sub: DatabaseManager.SubClassTarget
    @Binding var target: Double
    let percentFormatter: NumberFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(sub.name)
                    .font(.system(size: 14))
                Spacer()
                TextField("", value: $target, formatter: percentFormatter)
                    .frame(width: 50)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: target) { _, newVal in
                        target = min(100, max(0, newVal))
                    }
            }
            Slider(value: Binding(
                get: { target },
                set: { target = min(100, max(0, $0)) }
            ), in: 0...100, step: 5)
                .accessibilityLabel(Text("Target for \(sub.name)"))
        }
        .padding(.vertical, 4)
    }
}
