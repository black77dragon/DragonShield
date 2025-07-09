import SwiftUI
import Charts

struct TargetAllocationMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.presentationMode) private var presentation

    @StateObject private var viewModel: TargetAllocationViewModel

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
    }

    private var leftPane: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(viewModel.assetClasses) { cls in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { viewModel.expandedClasses[cls.id] ?? false },
                            set: { viewModel.expandedClasses[cls.id] = $0 }
                        )
                    ) {
                        ForEach(viewModel.subAssetClasses(for: cls.id), id: \.id) { sub in
                            HStack {
                                Text(sub.name)
                                    .font(.system(size: 14))
                                Spacer()
                                Slider(
                                    value: Binding(
                                        get: { viewModel.subClassTargets[sub.id] ?? 0 },
                                        set: { viewModel.subClassTargets[sub.id] = $0 }
                                    ),
                                    in: 0...100,
                                    step: 5
                                )
                                TextField(
                                    "",
                                    value: Binding(
                                        get: { viewModel.subClassTargets[sub.id] ?? 0 },
                                        set: { viewModel.subClassTargets[sub.id] = $0 }
                                    ),
                                    formatter: viewModel.numberFormatter
                                )
                                .frame(width: 40)
                            }
                            .padding(.vertical, 4)
                        }
                        let sum = viewModel.totalSubClassPct(for: cls.id)
                        if abs(sum - 100) > 0.01 {
                            Text("\u{26A0}\u{FE0F} Sub-class totals: \(Int(sum))% (should be 100%)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } label: {
                        HStack {
                            Text(cls.name)
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Slider(
                                value: Binding(
                                    get: { viewModel.classTargets[cls.id] ?? 0 },
                                    set: { viewModel.classTargets[cls.id] = $0 }
                                ),
                                in: 0...100,
                                step: 5
                            )
                            TextField(
                                "",
                                value: Binding(
                                    get: { viewModel.classTargets[cls.id] ?? 0 },
                                    set: { viewModel.classTargets[cls.id] = $0 }
                                ),
                                formatter: viewModel.numberFormatter
                            )
                            .frame(width: 40)
                        }
                    }
                    .padding(.vertical, 8)
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
        if let expandedId = viewModel.expandedClasses.first(where: { $0.value })?.key,
           let cls = viewModel.assetClasses.first(where: { $0.id == expandedId }) {
            let subs = viewModel.subAssetClasses(for: cls.id)
            if !subs.isEmpty {
                return subs.map { ($0.name, viewModel.subClassTargets[$0.id] ?? 0) }
            }
        }
        return viewModel.assetClasses.map { ($0.name, viewModel.classTargets[$0.id] ?? 0) }
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
        viewModel.saveAllTargets()
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

