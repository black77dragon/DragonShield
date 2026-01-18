import SwiftUI

struct ThesisExposureRuleEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    let portfolioThesisId: Int
    let thesisName: String

    @State private var sleeves: [PortfolioThesisSleeve] = []
    @State private var rules: [PortfolioThesisExposureRule] = []
    @State private var nextTempSleeveId: Int = -1
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Exposure Rules: \(thesisName)")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            Form {
                Section(header: Text("Sleeves")) {
                    if sleeves.isEmpty {
                        Text("No sleeves configured.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(sleeves.indices, id: \.self) { index in
                        sleeveEditor(index: index)
                    }
                    Button("Add Sleeve") { addSleeve() }
                        .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                }

                Section(header: Text("Exposure Rules")) {
                    if rules.isEmpty {
                        Text("No exposure rules configured.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(rules.indices, id: \.self) { index in
                        ruleEditor(index: index)
                    }
                    Button("Add Rule") { addRule() }
                        .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                Button("Save") { save() }
                    .buttonStyle(DSButtonStyle(type: .primary, size: .small))
            }
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 600)
        .onAppear(perform: load)
    }

    private func load() {
        sleeves = dbManager.listPortfolioThesisSleeves(portfolioThesisId: portfolioThesisId)
        rules = dbManager.listPortfolioThesisExposureRules(portfolioThesisId: portfolioThesisId)
        nextTempSleeveId = -1
    }

    private func addSleeve() {
        let tempId = nextTempSleeveId
        nextTempSleeveId -= 1
        let sleeve = PortfolioThesisSleeve(id: tempId, portfolioThesisId: portfolioThesisId, name: "", targetMinPct: nil, targetMaxPct: nil, maxPct: nil, ruleText: nil, sortOrder: sleeves.count)
        sleeves.append(sleeve)
    }

    private func addRule() {
        let rule = PortfolioThesisExposureRule(id: 0, portfolioThesisId: portfolioThesisId, sleeveId: nil, ruleType: .byTicker, ruleValue: "", weighting: nil, effectiveFrom: nil, effectiveTo: nil, isActive: true)
        rules.append(rule)
    }

    private func sleeveEditor(index: Int) -> some View {
        let binding = Binding(
            get: { sleeves[index] },
            set: { sleeves[index] = $0 }
        )
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Name", text: binding.name)
                    .textFieldStyle(.roundedBorder)
                Button("Remove") { sleeves.remove(at: index) }
                    .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
            }
            HStack(spacing: 12) {
                TextField("Min %", text: doubleBinding(binding.targetMinPct))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField("Max %", text: doubleBinding(binding.targetMaxPct))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                TextField("Hard max %", text: doubleBinding(binding.maxPct))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                TextField("Rule text", text: Binding(
                    get: { binding.ruleText.wrappedValue ?? "" },
                    set: { binding.ruleText.wrappedValue = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding(8)
        .background(DSColor.surface)
        .cornerRadius(8)
    }

    private func ruleEditor(index: Int) -> some View {
        let binding = Binding(
            get: { rules[index] },
            set: { rules[index] = $0 }
        )
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Picker("Type", selection: binding.ruleType) {
                    ForEach(ThesisExposureRuleType.allCases, id: \.self) { item in
                        Text(item.rawValue.replacingOccurrences(of: "by_", with: "").replacingOccurrences(of: "_", with: " ").capitalized)
                            .tag(item)
                    }
                }
                .frame(width: 180)
                TextField("Value", text: binding.ruleValue)
                    .textFieldStyle(.roundedBorder)
                TextField("Weight", text: doubleBinding(binding.weighting))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Picker("Sleeve", selection: Binding(
                    get: { binding.sleeveId.wrappedValue ?? 0 },
                    set: { binding.sleeveId.wrappedValue = $0 == 0 ? nil : $0 }
                )) {
                    Text("None").tag(0)
                    ForEach(sleeves) { sleeve in
                        Text(sleeve.name.isEmpty ? "Unnamed" : sleeve.name).tag(sleeve.id)
                    }
                }
                .frame(width: 160)
                Toggle("Active", isOn: binding.isActive)
                    .toggleStyle(.switch)
            }
            HStack {
                TextField("Effective from (ISO)", text: Binding(
                    get: { binding.effectiveFrom.wrappedValue ?? "" },
                    set: { binding.effectiveFrom.wrappedValue = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                TextField("Effective to (ISO)", text: Binding(
                    get: { binding.effectiveTo.wrappedValue ?? "" },
                    set: { binding.effectiveTo.wrappedValue = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Button("Remove") { rules.remove(at: index) }
                    .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
            }
        }
        .padding(8)
        .background(DSColor.surface)
        .cornerRadius(8)
    }

    private func doubleBinding(_ binding: Binding<Double?>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue.map { String(format: "%.2f", $0) } ?? "" },
            set: { binding.wrappedValue = Double($0) }
        )
    }

    private func save() {
        errorMessage = nil
        let existingSleeves = dbManager.listPortfolioThesisSleeves(portfolioThesisId: portfolioThesisId)
        let existingRules = dbManager.listPortfolioThesisExposureRules(portfolioThesisId: portfolioThesisId)

        var sleeveIdMap: [Int: Int] = [:]
        var savedSleeveIds: Set<Int> = []
        for (index, var sleeve) in sleeves.enumerated() {
            sleeve.portfolioThesisId = portfolioThesisId
            sleeve.sortOrder = index
            if let saved = dbManager.upsertPortfolioThesisSleeve(sleeve) {
                savedSleeveIds.insert(saved.id)
                sleeveIdMap[sleeve.id] = saved.id
            }
        }

        for sleeve in existingSleeves where !savedSleeveIds.contains(sleeve.id) {
            _ = dbManager.deletePortfolioThesisSleeve(id: sleeve.id)
        }

        var savedRuleIds: Set<Int> = []
        for var rule in rules {
            rule.portfolioThesisId = portfolioThesisId
            if let sleeveId = rule.sleeveId, let mapped = sleeveIdMap[sleeveId] {
                rule.sleeveId = mapped
            }
            if let saved = dbManager.upsertPortfolioThesisExposureRule(rule) {
                savedRuleIds.insert(saved.id)
            }
        }

        for rule in existingRules where !savedRuleIds.contains(rule.id) {
            _ = dbManager.deletePortfolioThesisExposureRule(id: rule.id)
        }

        dismiss()
    }
}
