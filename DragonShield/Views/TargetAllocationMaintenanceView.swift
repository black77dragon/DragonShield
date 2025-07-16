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
            Toggle("Include Direct Real Estate", isOn: $viewModel.includeDirectRealEstate)
                .toggleStyle(SwitchToggleStyle())
                .padding(.bottom, 8)
            classList
            totalsRow
        }
        .padding(24)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var classList: some View {
        List {
            ForEach(viewModel.sortedClasses) { cls in
                classDisclosure(for: cls)
            }
        }
        .listStyle(.plain)
    }

    private var totalsRow: some View {
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
            if viewModel.includeDirectRealEstate {
                Spacer()
                Text(viewModel.currencyFormatter.string(from: NSNumber(value: viewModel.directRealEstateTargetCHF)) ?? "")
            }
            Spacer()
        }
        .padding([.top, .horizontal])
    }

    private func classDisclosure(for cls: DatabaseManager.AssetClassData) -> some View {
        let expanded = Binding<Bool>(
            get: { viewModel.expandedClasses[cls.id] ?? false },
            set: { viewModel.expandedClasses[cls.id] = $0 }
        )
        let label = classDisclosureLabel(for: cls)
        return DisclosureGroup(isExpanded: expanded) {
            ForEach(viewModel.subAssetClasses(for: cls.id), id: \.id) { sub in
                subClassRow(for: sub, classId: cls.id)
            }
            let sum = viewModel.totalSubClassPct(for: cls.id)
            if abs(sum - 100) > 0.01 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.warning)
                        .accessibilityLabel("Sub-class totals mismatch")
                    Text("Sub-class totals: \(Int(sum))% (should be 100%)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        } label: { label }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func classDisclosureLabel(for cls: DatabaseManager.AssetClassData) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.chartColor(for: cls.id))
                .frame(width: 10, height: 10)
            Text(cls.name)
                .font(.system(size: 16, weight: viewModel.classTargets[cls.id, default: 0] > 0 ? .semibold : .regular))
            if abs(viewModel.totalSubClassPct(for: cls.id) - 100) > 0.01 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.warning)
                    .accessibilityLabel("Sub-class totals mismatch")
                    .onTapGesture { viewModel.expandedClasses[cls.id] = true }
            }
            Spacer()
            Slider(
                value: classTargetBinding(for: cls.id),
                in: 0...100,
                step: 5
            )
            .focusable()
            TextField(
                "",
                value: classTargetBinding(for: cls.id),
                formatter: viewModel.numberFormatter
            )
            .frame(width: 40)
            .focusable()
        }
    }

    private func subClassRow(for sub: DatabaseManager.SubClassTarget, classId: Int) -> some View {
        HStack {
            Text(sub.name)
                .font(.system(size: 14))
            Spacer()
            if sub.name == "Direct Real Estate" {
                TextField(
                    "",
                    value: $viewModel.directRealEstateTargetCHF,
                    formatter: viewModel.currencyFormatter
                )
                .frame(width: 80)
            } else {
                Slider(
                    value: subClassTargetBinding(for: sub.id),
                    in: 0...100,
                    step: 5
                )
                .focusable()
                TextField(
                    "",
                    value: subClassTargetBinding(for: sub.id),
                    formatter: viewModel.numberFormatter
                )
                .frame(width: 40)
                .focusable()
            }
        }
        .padding(.vertical, 4)
        .disabled(viewModel.classTargets[classId] == 0)
        .opacity(viewModel.classTargets[classId] == 0 ? 0.5 : 1.0)
    }

    private func classTargetBinding(for id: Int) -> Binding<Double> {
        Binding(
            get: { viewModel.classTargets[id] ?? 0 },
            set: { viewModel.classTargets[id] = $0 }
        )
    }

    private func subClassTargetBinding(for id: Int) -> Binding<Double> {
        Binding(
            get: { viewModel.subClassTargets[id] ?? 0 },
            set: { viewModel.subClassTargets[id] = $0 }
        )
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

