import SwiftUI

struct TradingProfileSettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var profiles: [TradingProfileRow] = []
    @State private var editorContext: TradingProfileEditorContext?
    let showsCancel: Bool

    init(showsCancel: Bool = false) {
        self.showsCancel = showsCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            if profiles.count == 1, let profile = profiles.first {
                TradingProfileEditorForm(
                    profile: profile,
                    onSave: saveProfile,
                    dismissOnSave: false,
                    showsCancel: false
                )
            } else {
                List {
                    if profiles.isEmpty {
                        Text("No Trading Profiles found.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(profiles) { profile in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name)
                                        .font(.headline)
                                    Text(profile.type)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if profile.isDefault {
                                    Text("Default")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                Button("Edit") {
                                    editorContext = TradingProfileEditorContext(profile: profile)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Trading Profile Settings")
        .onAppear(perform: loadProfiles)
        .toolbar {
            if showsCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $editorContext, onDismiss: loadProfiles) { context in
            TradingProfileEditorForm(
                profile: context.profile,
                onSave: saveProfile,
                dismissOnSave: true,
                showsCancel: true
            )
        }
    }

    private func loadProfiles() {
        profiles = dbManager.fetchTradingProfiles(includeInactive: false)
    }

    private func saveProfile(_ updated: TradingProfileEditorData) -> Bool {
        if updated.isDefault {
            _ = dbManager.setDefaultTradingProfile(id: updated.id)
        }
        let ok = dbManager.updateTradingProfile(
            id: updated.id,
            name: updated.name,
            type: updated.type,
            primaryObjective: updated.primaryObjective,
            tradingStrategyExecutiveSummary: updated.tradingStrategyExecutiveSummary,
            lastReviewDate: updated.lastReviewDate,
            nextReviewText: updated.nextReviewText,
            activeRegime: updated.activeRegime,
            regimeConfidence: updated.regimeConfidence,
            riskState: updated.riskState,
            isDefault: updated.isDefault,
            isActive: updated.isActive
        )
        guard ok else { return false }
        for (index, coordinate) in updated.coordinates.enumerated() {
            _ = dbManager.updateTradingProfileCoordinate(
                id: coordinate.id,
                title: coordinate.title,
                weightPercent: coordinate.weightPercent,
                value: coordinate.value,
                sortOrder: index + 1,
                isLocked: coordinate.isLocked
            )
        }
        let dominanceInputs = buildDominanceInputs(from: updated)
        if !dbManager.replaceTradingProfileDominance(profileId: updated.id, items: dominanceInputs) {
            return false
        }
        loadProfiles()
        return true
    }

    private func buildDominanceInputs(from updated: TradingProfileEditorData) -> [TradingProfileDominanceInput] {
        var items: [TradingProfileDominanceInput] = []
        var order = 1
        for text in updated.dominancePrimary {
            items.append(TradingProfileDominanceInput(category: "primary", text: text, sortOrder: order))
            order += 1
        }
        order = 1
        for text in updated.dominanceSecondary {
            items.append(TradingProfileDominanceInput(category: "secondary", text: text, sortOrder: order))
            order += 1
        }
        order = 1
        for text in updated.dominanceAvoid {
            items.append(TradingProfileDominanceInput(category: "avoid", text: text, sortOrder: order))
            order += 1
        }
        return items
    }
}

private struct TradingProfileEditorContext: Identifiable {
    let id = UUID()
    let profile: TradingProfileRow
}

private struct TradingProfileEditorData {
    let id: Int
    let name: String
    let type: String
    let primaryObjective: String?
    let tradingStrategyExecutiveSummary: String?
    let lastReviewDate: String?
    let nextReviewText: String?
    let activeRegime: String?
    let regimeConfidence: String?
    let riskState: String?
    let isDefault: Bool
    let isActive: Bool
    let coordinates: [TradingProfileCoordinateRow]
    let dominancePrimary: [String]
    let dominanceSecondary: [String]
    let dominanceAvoid: [String]
}

private struct TradingProfileEditorForm: View {
    let profile: TradingProfileRow
    var onSave: (TradingProfileEditorData) -> Bool
    let dismissOnSave: Bool
    let showsCancel: Bool

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var name: String = ""
    @State private var type: String = ""
    @State private var primaryObjective: String = ""
    @State private var tradingStrategyExecutiveSummary: String = ""
    @State private var lastReviewDate: String = ""
    @State private var nextReviewText: String = ""
    @State private var activeRegime: String = ""
    @State private var regimeConfidence: String = ""
    @State private var riskState: String = ""
    @State private var isDefault: Bool = false
    @State private var isActive: Bool = true
    @State private var coordinates: [TradingProfileCoordinateRow] = []
    @State private var dominancePrimary: [DominanceEditorItem] = []
    @State private var dominanceSecondary: [DominanceEditorItem] = []
    @State private var dominanceAvoid: [DominanceEditorItem] = []
    @State private var showSaveError = false
    private let labelWidth: CGFloat = 220

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Edit Trading Profile")
                    .font(.title2)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent {
                            TextField("Profile Name", text: $name)
                        } label: {
                            Text("Profile Name")
                                .frame(width: labelWidth, alignment: .leading)
                        }
                        LabeledContent {
                            TextField("Profile Type", text: $type)
                        } label: {
                            Text("Profile Type")
                                .frame(width: labelWidth, alignment: .leading)
                        }
                        LabeledContent {
                            TextField("Active Regime", text: $activeRegime)
                        } label: {
                            Text("Active Regime")
                                .frame(width: labelWidth, alignment: .leading)
                        }
                        LabeledContent {
                            TextField("Regime Confidence", text: $regimeConfidence)
                        } label: {
                            Text("Regime Confidence")
                                .frame(width: labelWidth, alignment: .leading)
                        }
                        LabeledContent {
                            TextField("Risk State", text: $riskState)
                        } label: {
                            Text("Risk State")
                                .frame(width: labelWidth, alignment: .leading)
                        }
                        LabeledContent {
                            TextField("Last Review (YYYY-MM-DD)", text: $lastReviewDate)
                        } label: {
                            Text("Last Review (YYYY-MM-DD)")
                                .frame(width: labelWidth, alignment: .leading)
                        }
                        LabeledContent {
                            TextField("Next Review", text: $nextReviewText)
                        } label: {
                            Text("Next Review")
                                .frame(width: labelWidth, alignment: .leading)
                        }
                        LabeledContent {
                            TextEditor(text: $primaryObjective)
                                .frame(minHeight: 80, maxHeight: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        } label: {
                            Text("Primary Objective")
                                .frame(width: labelWidth, alignment: .leading)
                        }
                        LabeledContent {
                            TextEditor(text: $tradingStrategyExecutiveSummary)
                                .frame(minHeight: 160, maxHeight: 220)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        } label: {
                            Text("Trading Strategy Executive Summary")
                                .frame(width: labelWidth, alignment: .leading)
                        }
                        HStack(spacing: 24) {
                            Toggle("Default Profile", isOn: $isDefault)
                            Toggle("Active", isOn: $isActive)
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                } label: {
                    Text("Identity")
                        .font(.headline)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        dominanceSection(title: "What Defines Me", items: $dominancePrimary)
                        dominanceSection(title: "Secondary Modulators", items: $dominanceSecondary)
                        dominanceSection(title: "Should Not Drive Decisions", items: $dominanceAvoid)
                    }
                    .padding(.vertical, 4)
                } label: {
                    Text("Dominance Stack")
                        .font(.headline)
                }

                GroupBox {
                    if coordinates.isEmpty {
                        Text("No profile coordinates found.")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach($coordinates) { $coordinate in
                                VStack(alignment: .leading, spacing: 8) {
                                    LabeledContent {
                                        TextField("Axis", text: $coordinate.title)
                                    } label: {
                                        Text("Axis")
                                            .frame(width: labelWidth, alignment: .leading)
                                    }
                                    LabeledContent {
                                        HStack(spacing: 12) {
                                            TextField("Weight", value: $coordinate.weightPercent, format: .number.precision(.fractionLength(1)))
                                                .frame(width: 90)
                                            Stepper("", value: $coordinate.weightPercent, in: 0...100, step: 1)
                                                .labelsHidden()
                                            Spacer()
                                            Text(String(format: "%.1f", coordinate.weightPercent))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } label: {
                                        Text("Weight")
                                            .frame(width: labelWidth, alignment: .leading)
                                    }
                                    LabeledContent {
                                        HStack(spacing: 12) {
                                            Slider(value: $coordinate.value, in: 0...10, step: 0.5)
                                            Text(String(format: "%.1f", coordinate.value))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .frame(width: 44, alignment: .trailing)
                                        }
                                    } label: {
                                        Text("Value")
                                            .frame(width: labelWidth, alignment: .leading)
                                    }
                                }
                                if coordinate.id != coordinates.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } label: {
                    Text("Profile Coordinates")
                        .font(.headline)
                }

                HStack {
                    Spacer()
                    if showsCancel {
                        Button("Cancel") { dismiss() }
                    }
                    Button("Save") {
                        let data = TradingProfileEditorData(
                            id: profile.id,
                            name: name,
                            type: type,
                            primaryObjective: primaryObjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : primaryObjective,
                            tradingStrategyExecutiveSummary: tradingStrategyExecutiveSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tradingStrategyExecutiveSummary,
                            lastReviewDate: lastReviewDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : lastReviewDate,
                            nextReviewText: nextReviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nextReviewText,
                            activeRegime: activeRegime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : activeRegime,
                            regimeConfidence: regimeConfidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : regimeConfidence,
                            riskState: riskState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : riskState,
                            isDefault: isDefault,
                            isActive: isActive,
                            coordinates: coordinates,
                            dominancePrimary: dominancePrimary.compactMap { $0.cleanedText },
                            dominanceSecondary: dominanceSecondary.compactMap { $0.cleanedText },
                            dominanceAvoid: dominanceAvoid.compactMap { $0.cleanedText }
                        )
                        if onSave(data) {
                            if dismissOnSave {
                                dismiss()
                            }
                        } else {
                            showSaveError = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
        .frame(minWidth: 980, idealWidth: 1120, maxWidth: 1280, minHeight: 820, idealHeight: 940, maxHeight: .infinity)
        .onAppear(perform: loadProfile)
        .alert("Save failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please check the inputs and try again.")
        }
    }

    private func loadProfile() {
        name = profile.name
        type = profile.type
        primaryObjective = profile.primaryObjective ?? ""
        tradingStrategyExecutiveSummary = profile.tradingStrategyExecutiveSummary ?? ""
        lastReviewDate = profile.lastReviewDate ?? ""
        nextReviewText = profile.nextReviewText ?? ""
        activeRegime = profile.activeRegime ?? ""
        regimeConfidence = profile.regimeConfidence ?? ""
        riskState = profile.riskState ?? ""
        isDefault = profile.isDefault
        isActive = profile.isActive
        coordinates = dbManager.fetchTradingProfileCoordinates(profileId: profile.id)
        let dominanceRows = dbManager.fetchTradingProfileDominance(profileId: profile.id)
        dominancePrimary = dominanceRows
            .filter { $0.category == "primary" }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { DominanceEditorItem(text: $0.text) }
        dominanceSecondary = dominanceRows
            .filter { $0.category == "secondary" }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { DominanceEditorItem(text: $0.text) }
        dominanceAvoid = dominanceRows
            .filter { $0.category == "avoid" }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { DominanceEditorItem(text: $0.text) }
    }

    private func dominanceSection(title: String, items: Binding<[DominanceEditorItem]>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            ForEach(items) { $item in
                HStack(spacing: 8) {
                    TextField("Entry", text: $item.text)
                    Button {
                        items.wrappedValue.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                items.wrappedValue.append(DominanceEditorItem(text: ""))
            } label: {
                Label("Add Item", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DominanceEditorItem: Identifiable, Hashable {
    let id = UUID()
    var text: String

    var cleanedText: String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
