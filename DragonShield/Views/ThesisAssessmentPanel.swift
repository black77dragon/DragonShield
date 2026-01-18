import SwiftUI

struct ThesisAssessmentPanel: View {
    @Binding var draft: ThesisAssessmentDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let summary = draft.thesisSummary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            summaryRow
            verdictRow
            if !draft.drivers.isEmpty {
                driverTable
            } else {
                Text("No drivers configured for this thesis.")
                    .foregroundColor(.secondary)
            }
            if !draft.risks.isEmpty {
                riskTable
            } else {
                Text("No risks configured for this thesis.")
                    .foregroundColor(.secondary)
            }
            actionsRow
        }
        .padding(12)
        .background(DSColor.surfaceSubtle)
        .cornerRadius(10)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(draft.thesisName)
                .font(.headline)
            Spacer()
            Button("Carry forward last week") {
                draft.carryForward()
            }
            .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
        }
    }

    private var summaryRow: some View {
        let driverScore = driverStrengthScore
        let riskScore = riskPressureScore
        let suggestion = verdictSuggestion
        return HStack(spacing: 12) {
            metricCard(title: "Driver Strength", value: driverScore)
            metricCard(title: "Risk Pressure", value: riskScore)
            if let suggestion {
                HStack(spacing: 6) {
                    Text("Suggested")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DSBadge(text: suggestion.rawValue.capitalized, color: verdictColor(suggestion))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DSColor.surface)
                .cornerRadius(8)
            }
            Spacer()
        }
    }

    private var verdictRow: some View {
        HStack(spacing: 12) {
            Text("Verdict")
                .font(.subheadline)
            Picker("Verdict", selection: verdictBinding) {
                Text("Select...").tag(ThesisVerdict?.none)
                ForEach(ThesisVerdict.allCases, id: \.self) { verdict in
                    Text(verdict.rawValue.capitalized).tag(Optional(verdict))
                }
            }
            .labelsHidden()
            Spacer()
        }
    }

    private var driverTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drivers")
                .font(.subheadline.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Driver").font(.caption).foregroundColor(.secondary)
                    Text("Score").font(.caption).foregroundColor(.secondary)
                    Text("Delta").font(.caption).foregroundColor(.secondary)
                    Text("RAG").font(.caption).foregroundColor(.secondary)
                    Text("Change").font(.caption).foregroundColor(.secondary)
                    Text("Implication").font(.caption).foregroundColor(.secondary)
                }
                ForEach(draft.drivers) { driver in
                    let itemBinding = driverItemBinding(driver.id)
                    GridRow {
                        Text("\(driver.code) • \(driver.name)")
                        scoreFieldInternal(score: driverScoreBinding(itemBinding), isDriver: true)
                        deltaView(score: itemBinding.wrappedValue.score, prior: draft.priorDriverScores[driver.id])
                        ragIndicator(rag: resolvedDriverRag(for: itemBinding.wrappedValue))
                        TextField("One sentence", text: changeSentenceBinding(itemBinding))
                            .textFieldStyle(.roundedBorder)
                        Picker("Implication", selection: implicationBinding(itemBinding)) {
                            Text("None").tag(ThesisDriverImplication?.none)
                            ForEach(ThesisDriverImplication.allCases, id: \.self) { item in
                                Text(item.rawValue.capitalized).tag(Optional(item))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    .padding(.vertical, 6)
                    .background(rowHighlight(score: itemBinding.wrappedValue.score, prior: draft.priorDriverScores[driver.id], rag: resolvedDriverRag(for: itemBinding.wrappedValue)))
                }
            }
        }
    }

    private var riskTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Risks")
                .font(.subheadline.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Risk").font(.caption).foregroundColor(.secondary)
                    Text("Score").font(.caption).foregroundColor(.secondary)
                    Text("Delta").font(.caption).foregroundColor(.secondary)
                    Text("RAG").font(.caption).foregroundColor(.secondary)
                    Text("Change").font(.caption).foregroundColor(.secondary)
                    Text("Impact").font(.caption).foregroundColor(.secondary)
                    Text("Action").font(.caption).foregroundColor(.secondary)
                }
                ForEach(draft.risks) { risk in
                    let itemBinding = riskItemBinding(risk.id)
                    GridRow {
                        Text(risk.name)
                        scoreFieldInternal(score: riskScoreBinding(itemBinding), isDriver: false)
                        deltaView(score: itemBinding.wrappedValue.score, prior: draft.priorRiskScores[risk.id])
                        ragIndicator(rag: resolvedRiskRag(for: itemBinding.wrappedValue))
                        TextField("One sentence", text: changeSentenceBinding(itemBinding))
                            .textFieldStyle(.roundedBorder)
                        Picker("Impact", selection: impactBinding(itemBinding)) {
                            Text("None").tag(ThesisRiskImpact?.none)
                            ForEach(ThesisRiskImpact.allCases, id: \.self) { item in
                                Text(item.rawValue.capitalized).tag(Optional(item))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                        Picker("Action", selection: actionBinding(itemBinding)) {
                            Text("None").tag(ThesisRiskAction?.none)
                            ForEach(ThesisRiskAction.allCases, id: \.self) { item in
                                Text(item.rawValue.capitalized).tag(Optional(item))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    .padding(.vertical, 6)
                    .background(rowHighlight(score: itemBinding.wrappedValue.score, prior: draft.priorRiskScores[risk.id], rag: resolvedRiskRag(for: itemBinding.wrappedValue)))
                }
            }
        }
    }

    private var actionsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top changes / Actions")
                .font(.subheadline.weight(.semibold))
            TextField("Top changes", text: topChangesBinding)
                .textFieldStyle(.roundedBorder)
            TextField("Action summary", text: actionsSummaryBinding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func metricCard(title: String, value: Double?) -> some View {
        let text = value.map { String(format: "%.1f", $0) } ?? "n/a"
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DSColor.surface)
        .cornerRadius(8)
    }

    private func scoreFieldInternal(score: Binding<String>, isDriver: Bool) -> some View {
        TextField("", text: score)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            .frame(width: 60)
            .help(isDriver ? "1-10 (support strength)" : "1-10 (risk pressure)")
    }

    private func deltaView(score: Int?, prior: Int?) -> some View {
        let delta = deltaValue(current: score, prior: prior)
        let symbol: String
        let color: Color
        switch delta {
        case let value? where value > 0:
            symbol = "arrow.up"
            color = DSColor.accentSuccess
        case let value? where value < 0:
            symbol = "arrow.down"
            color = DSColor.accentError
        case _:
            symbol = "arrow.right"
            color = .secondary
        }
        let label = delta.map { String(abs($0)) } ?? "0"
        return HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(label)
                .font(.caption)
        }
        .foregroundColor(color)
        .frame(width: 50, alignment: .leading)
    }

    private func ragIndicator(rag: ThesisRAG?) -> some View {
        let color = ragColor(rag)
        return Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
    }

    private func rowHighlight(score: Int?, prior: Int?, rag: ThesisRAG?) -> some View {
        let delta = deltaValue(current: score, prior: prior)
        let highlightDelta = (delta.map { abs($0) >= 2 } ?? false)
        let highlightRag = rag == .red
        if highlightDelta || highlightRag {
            return DSColor.accentWarning.opacity(highlightRag ? 0.18 : 0.12)
        }
        return Color.clear
    }

    private func ragColor(_ rag: ThesisRAG?) -> Color {
        switch rag {
        case .green: return DSColor.accentSuccess
        case .amber: return DSColor.accentWarning
        case .red: return DSColor.accentError
        case .none: return Color.gray.opacity(0.4)
        }
    }

    private func verdictColor(_ verdict: ThesisVerdict) -> Color {
        switch verdict {
        case .valid: return DSColor.accentSuccess
        case .watch: return DSColor.accentWarning
        case .impaired, .broken: return DSColor.accentError
        }
    }

    private func deltaValue(current: Int?, prior: Int?) -> Int? {
        guard let current, let prior else { return nil }
        return current - prior
    }

    private func resolvedDriverRag(for item: DriverWeeklyAssessmentItem) -> ThesisRAG? {
        item.rag ?? ThesisRAG.driverRAG(for: item.score)
    }

    private func resolvedRiskRag(for item: RiskWeeklyAssessmentItem) -> ThesisRAG? {
        item.rag ?? ThesisRAG.riskRAG(for: item.score)
    }

    private var driverStrengthScore: Double? {
        let weights = Dictionary(uniqueKeysWithValues: draft.drivers.map { ($0.id, $0.weight) })
        let items = draft.driverItems.map { (score: $0.score, weight: weights[$0.driverDefId] ?? nil) }
        return ThesisScoring.weightedAverage(items: items)
    }

    private var riskPressureScore: Double? {
        let weights = Dictionary(uniqueKeysWithValues: draft.risks.map { ($0.id, $0.weight) })
        let items = draft.riskItems.map { (score: $0.score, weight: weights[$0.riskDefId] ?? nil) }
        return ThesisScoring.weightedAverage(items: items)
    }

    private var verdictSuggestion: ThesisVerdict? {
        ThesisScoring.verdictSuggestion(driverStrength: driverStrengthScore, riskPressure: riskPressureScore, driverItems: draft.driverItems, riskItems: draft.riskItems, riskDefinitions: draft.risks)
    }

    private var verdictBinding: Binding<ThesisVerdict?> {
        Binding(
            get: { draft.verdict ?? verdictSuggestion },
            set: { draft.verdict = $0 }
        )
    }

    private var topChangesBinding: Binding<String> {
        Binding(
            get: { draft.topChangesText },
            set: { draft.topChangesText = $0 }
        )
    }

    private var actionsSummaryBinding: Binding<String> {
        Binding(
            get: { draft.actionsSummary },
            set: { draft.actionsSummary = $0 }
        )
    }

    private func driverItemBinding(_ driverDefId: Int) -> Binding<DriverWeeklyAssessmentItem> {
        Binding(
            get: {
                draft.driverItems.first { $0.driverDefId == driverDefId } ?? DriverWeeklyAssessmentItem(id: 0, assessmentId: 0, driverDefId: driverDefId, rag: nil, score: nil, deltaVsPrior: nil, changeSentence: "", evidenceRefs: [], implication: nil, sortOrder: 0)
            },
            set: { newValue in
                guard let index = draft.driverItems.firstIndex(where: { $0.driverDefId == driverDefId }) else { return }
                draft.driverItems[index] = newValue
            }
        )
    }

    private func riskItemBinding(_ riskDefId: Int) -> Binding<RiskWeeklyAssessmentItem> {
        Binding(
            get: {
                draft.riskItems.first { $0.riskDefId == riskDefId } ?? RiskWeeklyAssessmentItem(id: 0, assessmentId: 0, riskDefId: riskDefId, rag: nil, score: nil, deltaVsPrior: nil, changeSentence: "", evidenceRefs: [], thesisImpact: nil, recommendedAction: nil, sortOrder: 0)
            },
            set: { newValue in
                guard let index = draft.riskItems.firstIndex(where: { $0.riskDefId == riskDefId }) else { return }
                draft.riskItems[index] = newValue
            }
        )
    }

    private func driverScoreBinding(_ binding: Binding<DriverWeeklyAssessmentItem>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue.score.map(String.init) ?? "" },
            set: { newValue in
                var item = binding.wrappedValue
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    item.score = nil
                    item.rag = nil
                } else if let val = Int(trimmed) {
                    let bounded = min(max(val, 1), 10)
                    item.score = bounded
                    item.rag = ThesisRAG.driverRAG(for: bounded)
                }
                binding.wrappedValue = item
            }
        )
    }

    private func riskScoreBinding(_ binding: Binding<RiskWeeklyAssessmentItem>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue.score.map(String.init) ?? "" },
            set: { newValue in
                var item = binding.wrappedValue
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    item.score = nil
                    item.rag = nil
                } else if let val = Int(trimmed) {
                    let bounded = min(max(val, 1), 10)
                    item.score = bounded
                    item.rag = ThesisRAG.riskRAG(for: bounded)
                }
                binding.wrappedValue = item
            }
        )
    }

    private func changeSentenceBinding(_ binding: Binding<DriverWeeklyAssessmentItem>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue.changeSentence ?? "" },
            set: { newValue in
                var item = binding.wrappedValue
                item.changeSentence = newValue
                binding.wrappedValue = item
            }
        )
    }

    private func changeSentenceBinding(_ binding: Binding<RiskWeeklyAssessmentItem>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue.changeSentence ?? "" },
            set: { newValue in
                var item = binding.wrappedValue
                item.changeSentence = newValue
                binding.wrappedValue = item
            }
        )
    }

    private func implicationBinding(_ binding: Binding<DriverWeeklyAssessmentItem>) -> Binding<ThesisDriverImplication?> {
        Binding(
            get: { binding.wrappedValue.implication },
            set: { newValue in
                var item = binding.wrappedValue
                item.implication = newValue
                binding.wrappedValue = item
            }
        )
    }

    private func impactBinding(_ binding: Binding<RiskWeeklyAssessmentItem>) -> Binding<ThesisRiskImpact?> {
        Binding(
            get: { binding.wrappedValue.thesisImpact },
            set: { newValue in
                var item = binding.wrappedValue
                item.thesisImpact = newValue
                binding.wrappedValue = item
            }
        )
    }

    private func actionBinding(_ binding: Binding<RiskWeeklyAssessmentItem>) -> Binding<ThesisRiskAction?> {
        Binding(
            get: { binding.wrappedValue.recommendedAction },
            set: { newValue in
                var item = binding.wrappedValue
                item.recommendedAction = newValue
                binding.wrappedValue = item
            }
        )
    }
}
