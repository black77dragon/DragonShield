// DragonShield/Views/ThesisManagementView.swift
// Desktop-first Thesis Management module (v1.2)

import SwiftUI
import Combine
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(Charts)
import Charts
#endif
#if os(macOS)
import AppKit
#else
import UIKit
#endif

private enum Surface {
    static var secondary: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }

    static var tertiary: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.tertiarySystemBackground)
        #endif
    }
}

private enum ThesisModuleSection: String, CaseIterable, Identifiable {
    case dashboard
    case theses
    case imports

    var id: String { rawValue }
    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .theses: return "Theses"
        case .imports: return "Workflow"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .theses: return "list.bullet.rectangle"
        case .imports: return "square.and.arrow.down.on.square"
        }
    }
}

private enum JsonInputSource: String, CaseIterable, Identifiable {
    case paste
    case upload

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paste: return "Paste JSON"
        case .upload: return "Upload File"
        }
    }
}

private enum ThesisRoute: Hashable {
    case detail(String)
    case review(String, WeekNumber)
}

private enum DashboardSheet: Identifiable {
    case detail(Thesis)
    case review(Thesis, WeekNumber)

    var id: String {
        switch self {
        case .detail(let thesis):
            return "detail_\(thesis.id)"
        case .review(let thesis, let week):
            return "review_\(thesis.id)_\(week.stringValue)"
        }
    }
}

private struct ThesisImportPayload: Codable {
    struct Assumption: Codable {
        var id: String?
        var title: String
        var detail: String
    }

    struct KillCriterion: Codable {
        var id: String?
        var description: String
    }

    struct Range: Codable {
        var lower: Double
        var upper: Double
    }

    struct RangeSet: Codable {
        var green: Range
        var amber: Range
        var red: Range
    }

    struct KPI: Codable {
        var id: String?
        var name: String
        var unit: String
        var description: String
        var source: String?
        var isPrimary: Bool
        var direction: KPIDirection
        var ranges: RangeSet

        enum CodingKeys: String, CodingKey {
            case id, name, unit, description, source, direction, ranges
            case isPrimary = "is_primary"
        }
    }

    var schema: String
    var name: String
    var tier: ThesisTier
    var investmentRole: String
    var northStar: String
    var nonGoals: String
    var assumptions: [Assumption]
    var killCriteria: [KillCriterion]
    var kpis: [KPI]

    enum CodingKeys: String, CodingKey {
        case schema, name, tier, assumptions, kpis
        case investmentRole = "investment_role"
        case northStar = "north_star"
        case nonGoals = "non_goals"
        case killCriteria = "kill_criteria"
    }
}

private struct ThesisImportValidation {
    enum Status {
        case green
        case amber
        case red
    }

    var status: Status
    var errors: [String]
    var warnings: [String]
    var payload: ThesisImportPayload?

    var isGreen: Bool { status == .green }
}

private func validateThesisImport(json: String) -> ThesisImportValidation {
    let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return ThesisImportValidation(status: .red, errors: ["JSON is empty"], warnings: [], payload: nil)
    }
    let decoder = JSONDecoder()
    do {
        let data = Data(trimmed.utf8)
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            let preview = jsonPreview(trimmed)
            return ThesisImportValidation(
                status: .red,
                errors: ["Invalid JSON at root: \(error.localizedDescription). Input starts with: \"\(preview)\""],
                warnings: [],
                payload: nil
            )
        }
        let payload = try decoder.decode(ThesisImportPayload.self, from: data)
        var errors: [String] = []
        let warnings: [String] = []

        if payload.schema != "thesis_import_v1" {
            errors.append("schema must be thesis_import_v1 (got '\(payload.schema)')")
        }
        if payload.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("name is required (non-empty string)")
        }
        if payload.northStar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("north_star is required (5-8 sentences)")
        }
        let investmentRole = payload.investmentRole.trimmingCharacters(in: .whitespacesAndNewlines)
        if investmentRole.isEmpty {
            errors.append("investment_role is required (hedge | convexity | growth | income | optionality)")
        } else {
            let allowed = ["hedge", "convexity", "growth", "income", "optionality"]
            if !allowed.contains(investmentRole.lowercased()) {
                errors.append("investment_role must be one of: hedge, convexity, growth, income, optionality (got '\(investmentRole)')")
            }
        }
        if payload.nonGoals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("non_goals is required (non-empty string)")
        }
        if payload.assumptions.count < 3 || payload.assumptions.count > 5 {
            errors.append("assumptions must be 3-5 (got \(payload.assumptions.count))")
        }
        if payload.killCriteria.isEmpty {
            errors.append("kill_criteria must include at least 1 item (got 0)")
        }
        let primaryCount = payload.kpis.filter { $0.isPrimary }.count
        let secondaryCount = payload.kpis.filter { !$0.isPrimary }.count
        let totalCount = payload.kpis.count
        if primaryCount < 3 || primaryCount > 5 {
            errors.append("primary KPIs must be 3-5 (got \(primaryCount))")
        }
        if secondaryCount > 4 {
            errors.append("secondary KPIs must be 0-4 (got \(secondaryCount))")
        }
        if totalCount > 9 {
            errors.append("total KPIs must be <= 9 (got \(totalCount))")
        }
        let nonEmptyIds = payload.kpis.compactMap { $0.id }.filter { !$0.isEmpty }
        if Set(nonEmptyIds).count != nonEmptyIds.count {
            errors.append("kpi ids must be unique (duplicate ids found)")
        }
        for (idx, assumption) in payload.assumptions.enumerated() {
            if assumption.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("assumptions[\(idx)].title is required")
            }
            if assumption.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("assumptions[\(idx)].detail is required")
            }
        }
        for (idx, kill) in payload.killCriteria.enumerated() {
            if kill.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("kill_criteria[\(idx)].description is required")
            }
        }
        for (idx, kpi) in payload.kpis.enumerated() {
            if kpi.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("kpis[\(idx)].name is required")
            }
            if kpi.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("kpis[\(idx)].unit is required")
            }
            if kpi.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("kpis[\(idx)].description is required")
            }
            if kpi.ranges.green.lower >= kpi.ranges.green.upper {
                errors.append("kpis[\(idx)].ranges.green lower must be < upper (got \(kpi.ranges.green.lower) >= \(kpi.ranges.green.upper))")
            }
            if kpi.ranges.amber.lower >= kpi.ranges.amber.upper {
                errors.append("kpis[\(idx)].ranges.amber lower must be < upper (got \(kpi.ranges.amber.lower) >= \(kpi.ranges.amber.upper))")
            }
            if kpi.ranges.red.lower >= kpi.ranges.red.upper {
                errors.append("kpis[\(idx)].ranges.red lower must be < upper (got \(kpi.ranges.red.lower) >= \(kpi.ranges.red.upper))")
            }
        }

        let status: ThesisImportValidation.Status
        if !errors.isEmpty {
            status = .red
        } else if !warnings.isEmpty {
            status = .amber
        } else {
            status = .green
        }
        return ThesisImportValidation(status: status, errors: errors, warnings: warnings, payload: payload)
    } catch {
        let preview = jsonPreview(trimmed)
        return ThesisImportValidation(
            status: .red,
            errors: [decodeErrorMessage(error, preview: preview)],
            warnings: [],
            payload: nil
        )
    }
}

private func decodeErrorMessage(_ error: Error, preview: String) -> String {
    guard let decodingError = error as? DecodingError else {
        return "Invalid JSON: \(error.localizedDescription). Input starts with: \"\(preview)\""
    }
    switch decodingError {
    case .typeMismatch(let type, let context):
        return "Invalid type at \(codingPath(context.codingPath)): expected \(type). \(context.debugDescription)"
    case .valueNotFound(let type, let context):
        return "Missing value at \(codingPath(context.codingPath)): expected \(type). \(context.debugDescription)"
    case .keyNotFound(let key, let context):
        return "Missing key '\(key.stringValue)' at \(codingPath(context.codingPath)). \(context.debugDescription)"
    case .dataCorrupted(let context):
        let path = codingPath(context.codingPath)
        if path == "root" {
            return "Invalid JSON at root: \(context.debugDescription). Input starts with: \"\(preview)\""
        }
        return "Invalid value at \(path): \(context.debugDescription)"
    @unknown default:
        return "Invalid JSON: \(error.localizedDescription). Input starts with: \"\(preview)\""
    }
}

private func codingPath(_ path: [CodingKey]) -> String {
    guard !path.isEmpty else { return "root" }
    return path.map { $0.stringValue }.joined(separator: ".")
}

private func jsonPreview(_ text: String) -> String {
    let condensed = text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ")
    let prefix = condensed.prefix(120)
    return String(prefix)
}

private struct ThesisEditorModel {
    struct AssumptionRow: Identifiable {
        let id: String
        var title: String
        var detail: String
    }

    struct KillRow: Identifiable {
        let id: String
        var description: String
    }

    var id: String?
    var name: String
    var northStar: String
    var investmentRole: String
    var nonGoals: String
    var tier: ThesisTier
    var assumptions: [AssumptionRow]
    var kills: [KillRow]
    var primaryKPIs: [KPIDefinition]
    var secondaryKPIs: [KPIDefinition]

    init(thesis: Thesis? = nil) {
        if let thesis {
            id = thesis.id
            name = thesis.name
            northStar = thesis.northStar
            investmentRole = thesis.investmentRole
            nonGoals = thesis.nonGoals
            tier = thesis.tier
            assumptions = thesis.assumptions.map { AssumptionRow(id: $0.id, title: $0.title, detail: $0.detail) }
            kills = thesis.killCriteria.map { KillRow(id: $0.id, description: $0.description) }
            primaryKPIs = thesis.primaryKPIs
            secondaryKPIs = thesis.secondaryKPIs
        } else {
            id = nil
            name = ""
            northStar = ""
            investmentRole = ""
            nonGoals = ""
            tier = .tier2
            assumptions = []
            kills = []
            primaryKPIs = []
            secondaryKPIs = []
        }
    }

    init(importPayload: ThesisImportPayload) {
        id = nil
        name = importPayload.name
        northStar = importPayload.northStar
        investmentRole = importPayload.investmentRole
        nonGoals = importPayload.nonGoals
        tier = importPayload.tier
        assumptions = importPayload.assumptions.map {
            AssumptionRow(id: $0.id ?? UUID().uuidString, title: $0.title, detail: $0.detail)
        }
        kills = importPayload.killCriteria.map {
            KillRow(id: $0.id ?? UUID().uuidString, description: $0.description)
        }
        let mapped = importPayload.kpis.map { kpi -> KPIDefinition in
            KPIDefinition(
                id: kpi.id ?? UUID().uuidString,
                name: kpi.name,
                unit: kpi.unit,
                description: kpi.description,
                source: kpi.source ?? "",
                isPrimary: kpi.isPrimary,
                direction: kpi.direction,
                ranges: KPIRangeSet(
                    green: .init(lower: kpi.ranges.green.lower, upper: kpi.ranges.green.upper),
                    amber: .init(lower: kpi.ranges.amber.lower, upper: kpi.ranges.amber.upper),
                    red: .init(lower: kpi.ranges.red.lower, upper: kpi.ranges.red.upper)
                )
            )
        }
        primaryKPIs = mapped.filter { $0.isPrimary }
        secondaryKPIs = mapped.filter { !$0.isPrimary }
    }

    func buildThesis() -> Thesis {
        let thesisId = id ?? UUID().uuidString
        let assumptionDefs = assumptions.map { AssumptionDefinition(id: $0.id, title: $0.title, detail: $0.detail) }
        let killDefs = kills.map { KillCriterion(id: $0.id, description: $0.description) }
        return Thesis(
            id: thesisId,
            name: name,
            northStar: northStar,
            investmentRole: investmentRole,
            nonGoals: nonGoals,
            tier: tier,
            assumptions: assumptionDefs,
            killCriteria: killDefs,
            primaryKPIs: primaryKPIs,
            secondaryKPIs: secondaryKPIs
        )
    }
}

private struct ThesisEditorView: View {
    enum Mode {
        case create
        case edit(Thesis)

        var title: String {
            switch self {
            case .create: return "New Thesis"
            case .edit: return "Edit Thesis"
            }
        }
    }

    let mode: Mode
    let importPayload: ThesisImportPayload?
    let onSave: (Thesis) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: ThesisStore
    @State private var model: ThesisEditorModel
    @State private var showKpiMaintenance = false
    @State private var showImportSheet = false
    @State private var importMessage: String?
    @State private var showExportSheet = false

    init(mode: Mode, importPayload: ThesisImportPayload? = nil, onSave: @escaping (Thesis) -> Void) {
        self.mode = mode
        self.importPayload = importPayload
        self.onSave = onSave
        switch mode {
        case .create:
            if let importPayload {
                _model = State(initialValue: ThesisEditorModel(importPayload: importPayload))
                _importMessage = State(initialValue: "Imported thesis draft. Review and save.")
            } else {
                _model = State(initialValue: ThesisEditorModel())
                _importMessage = State(initialValue: nil)
            }
        case .edit(let thesis):
            _model = State(initialValue: ThesisEditorModel(thesis: thesis))
            _importMessage = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let importMessage {
                        Text(importMessage)
                            .foregroundStyle(.secondary)
                    }
                    if case .create = mode, importPayload == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Import Draft")
                                    .font(.headline)
                                Spacer()
                                Button("Upload") { showImportSheet = true }
                                    .buttonStyle(.borderedProminent)
                            }
                            Text("Use the prompt to generate thesis JSON, then import it here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
                    }
                    if case .edit = mode {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Actions")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    showExportSheet = true
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .tint(.teal)
                                .disabled(model.id == nil)
                            }
                            Text("Export the full thesis for sharing with an LLM.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
                    }
                    // Basics block
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basics")
                            .font(.headline)
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                            GridRow {
                                HStack(spacing: 6) {
                                    Text("Name")
                                    InfoIcon(text: ThesisFieldHelp.name)
                                }
                                TextField("AI Infrastructure Rail", text: $model.name)
                                    .textFieldStyle(.roundedBorder)
                            }
                            GridRow {
                                HStack(spacing: 6) {
                                    Text("Tier")
                                    InfoIcon(text: ThesisFieldHelp.tier)
                                }
                                Picker("Tier", selection: $model.tier) {
                                    ForEach(ThesisTier.allCases, id: \.self) { tier in
                                        Text(tier.label).tag(tier)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            GridRow {
                                HStack(spacing: 6) {
                                    Text("Investment Role")
                                    InfoIcon(text: ThesisFieldHelp.investmentRole)
                                }
                                TextField("Growth with optionality", text: $model.investmentRole)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("North Star")
                                    .font(.subheadline)
                                InfoIcon(text: ThesisFieldHelp.northStar)
                            }
                            TextEditor(text: $model.northStar)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Non-goals")
                                    .font(.subheadline)
                                InfoIcon(text: ThesisFieldHelp.nonGoals)
                            }
                            TextEditor(text: $model.nonGoals)
                                .frame(minHeight: 60)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))

                    // Assumptions
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                        Text("Core Assumptions")
                            .font(.headline)
                        InfoIcon(text: ThesisFieldHelp.assumptions)
                        Spacer()
                        Button {
                            model.assumptions.append(.init(id: UUID().uuidString, title: "Assumption", detail: ""))
                        } label: {
                            Label("Add", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                        }
                        Text("3–5 crisp, falsifiable statements.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach($model.assumptions) { $row in
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Title", text: $row.title)
                                    .textFieldStyle(.roundedBorder)
                                TextEditor(text: $row.detail)
                                    .frame(minHeight: 60)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Surface.tertiary))
                        }
                        .onDelete { idx in
                            model.assumptions.remove(atOffsets: idx)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))

                    // Kill criteria
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                        Text("Kill Criteria (Breakers)")
                            .font(.headline)
                        InfoIcon(text: ThesisFieldHelp.killCriteria)
                        Spacer()
                        Button {
                            model.kills.append(.init(id: UUID().uuidString, description: ""))
                        } label: {
                            Label("Add", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                        }
                        Text("Binary breakers; if triggered, thesis is invalid.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach($model.kills) { $row in
                            TextEditor(text: $row.description)
                                .frame(minHeight: 50)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                                .background(RoundedRectangle(cornerRadius: 8).fill(Surface.tertiary))
                        }
                        .onDelete { idx in
                            model.kills.remove(atOffsets: idx)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))

                    // KPI note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("KPIs")
                            .font(.headline)
                        InfoIcon(text: ThesisFieldHelp.kpis)
                        Text("Manage KPI definitions in the KPIs tab after saving. Primary ≤5, Secondary ≤4, Total ≤9.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let primaryDisplay = currentThesis?.primaryKPIs ?? model.primaryKPIs
                        let secondaryDisplay = currentThesis?.secondaryKPIs ?? model.secondaryKPIs
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Primary \(primaryDisplay.count)/5 • Secondary \(secondaryDisplay.count)/4")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if primaryDisplay.isEmpty && secondaryDisplay.isEmpty {
                                Text("No KPIs defined yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(primaryDisplay) { kpi in
                                        KPICompactRow(definition: kpi, badge: "PRIMARY")
                                    }
                                    ForEach(secondaryDisplay) { kpi in
                                        KPICompactRow(definition: kpi, badge: "SECONDARY")
                                    }
                                }
                            }
                        }
                        HStack {
                            Button("Open KPI Maintenance") {
                                showKpiMaintenance = true
                            }
                            .disabled(model.id == nil)
                            if model.id == nil {
                                Text("Save the thesis first to manage KPIs.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
                }
                .padding()
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if case .edit = mode {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showExportSheet = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .tint(.teal)
                        .disabled(model.id == nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showKpiMaintenance) {
            if let thesisId = model.id {
                KPIMgmtView(thesisId: thesisId, showClose: true)
                    .frame(minWidth: 720, minHeight: 540)
            } else {
                Text("Save the thesis first.")
                    .padding()
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ThesisImportSheet { payload in
                model = ThesisEditorModel(importPayload: payload)
                importMessage = "Imported thesis draft. Review and save."
            }
            .frame(minWidth: 780, minHeight: 640)
        }
        .sheet(isPresented: $showExportSheet) {
            if let thesisId = model.id {
                ThesisExportSheet(thesisId: thesisId)
                    .frame(minWidth: 760, minHeight: 620)
            }
        }
    }

    private func save() {
        var updated = model.buildThesis()
        let id = updated.id
        if let current = store.thesis(id: id) {
            updated.primaryKPIs = current.primaryKPIs
            updated.secondaryKPIs = current.secondaryKPIs
        }
        onSave(updated)
        dismiss()
    }

    private var currentThesis: Thesis? {
        guard let id = model.id else { return nil }
        return store.thesis(id: id)
    }
}

private struct ThesisImportSheet: View {
    @EnvironmentObject var store: ThesisStore
    @Environment(\.dismiss) private var dismiss
    let onApply: (ThesisImportPayload) -> Void
    @State private var promptText: String = ""
    @State private var jsonText: String = ""
    @State private var jsonSource: JsonInputSource = .paste
    @State private var jsonFileName: String?
    @State private var validation: ThesisImportValidation?
    @State private var showJsonImporter = false
    @State private var fileImportError: String?
    @State private var showTemplateManager = false

    init(onApply: @escaping (ThesisImportPayload) -> Void) {
        self.onApply = onApply
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Upload Thesis")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Exit") { dismiss() }
                        .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt")
                        .font(.headline)
                    TextEditor(text: $promptText)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                        .disabled(true)
                    HStack {
                        Button("Manage Templates") { showTemplateManager = true }
                            .buttonStyle(.bordered)
                        Button("Copy Prompt") {
                            copyToClipboard(promptText)
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))

                VStack(alignment: .leading, spacing: 8) {
                    Text("JSON Input")
                        .font(.headline)
                    Picker("Input", selection: $jsonSource) {
                        ForEach(JsonInputSource.allCases) { source in
                            Text(source.label).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    if jsonSource == .paste {
                        TextEditor(text: $jsonText)
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    } else {
                        HStack {
                            Button("Choose JSON File") {
                                showJsonImporter = true
                            }
                            .buttonStyle(.bordered)
                            if let jsonFileName {
                                Text(jsonFileName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        if jsonText.isEmpty {
                            Text("No file loaded yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        TextEditor(text: $jsonText)
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    }
                    HStack {
                        Button("Validate") {
                            fileImportError = nil
                            validation = validateThesisImport(json: jsonText)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Copy JSON") {
                            copyToClipboard(jsonText)
                        }
                        .buttonStyle(.bordered)
                        Button("Create Thesis") {
                            guard let payload = validation?.payload, validation?.isGreen == true else { return }
                            onApply(payload)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(validation?.isGreen != true)
                        Spacer()
                    }
                    if let fileImportError {
                        Text(fileImportError)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))

                if let validation {
                    ValidationStatusView(validation: validation)
                }
            }
            .padding()
        }
        .onAppear {
            promptText = store.thesisImportPrompt()
        }
        .onChange(of: jsonSource) { _, newValue in
            if newValue == .paste {
                jsonFileName = nil
            }
            fileImportError = nil
        }
        .sheet(isPresented: $showTemplateManager) {
            PromptTemplateManagerSheet(initialKey: .thesisImport)
        }
        .onChange(of: showTemplateManager) { _, isPresented in
            if !isPresented {
                promptText = store.thesisImportPrompt()
            }
        }
        .fileImporter(
            isPresented: $showJsonImporter,
            allowedContentTypes: allowedJsonTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let data = try Data(contentsOf: url)
                    guard let content = String(data: data, encoding: .utf8) else {
                        fileImportError = "Unable to read file as UTF-8 text."
                        return
                    }
                    jsonText = content
                    jsonFileName = url.lastPathComponent
                    fileImportError = nil
                    validation = validateThesisImport(json: jsonText)
                } catch {
                    fileImportError = "Failed to read file: \(error.localizedDescription)"
                }
            case .failure(let error):
                fileImportError = "File import failed: \(error.localizedDescription)"
            }
        }
    }

    private var allowedJsonTypes: [UTType] {
        #if canImport(UniformTypeIdentifiers)
        return [UTType.json, UTType.text]
        #else
        return []
        #endif
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

private struct ValidationStatusView: View {
    let validation: ThesisImportValidation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Validation")
                    .font(.headline)
                StatusPill(status: validation.status)
                Spacer()
                if !validation.errors.isEmpty {
                    Button("Copy Errors") {
                        copyToClipboard(errorText)
                    }
                    .buttonStyle(.bordered)
                }
            }
            if !validation.errors.isEmpty {
                Text("Errors")
                    .font(.subheadline)
                ForEach(validation.errors, id: \.self) { error in
                    Text("• \(error)")
                        .foregroundStyle(.red)
                }
            }
            if !validation.warnings.isEmpty {
                Text("Warnings")
                    .font(.subheadline)
                ForEach(validation.warnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .foregroundStyle(.secondary)
                }
            }
            if validation.errors.isEmpty && validation.warnings.isEmpty {
                Text("All checks passed.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
    }

    private var errorText: String {
        validation.errors.joined(separator: "\n")
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

private struct StatusPill: View {
    let status: ThesisImportValidation.Status

    var body: some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .green: return "Green"
        case .amber: return "Amber"
        case .red: return "Red"
        }
    }

    private var color: Color {
        switch status {
        case .green: return .green
        case .amber: return .orange
        case .red: return .red
        }
    }
}

private enum ThesisFieldHelp {
    static let name = "Short thesis name (1–120 chars)."
    static let tier = "Tier-1 theses are pinned and prioritized on the dashboard."
    static let investmentRole = "What the thesis is for (hedge, convexity, growth, income, optionality)."
    static let northStar = "5–8 durable sentences that anchor the thesis."
    static let nonGoals = "Boundaries and exclusions to avoid dilution."
    static let assumptions = "3–5 crisp, falsifiable assumptions to pressure-test weekly."
    static let killCriteria = "Binary breakers; if triggered, the thesis is invalid."
    static let kpis = "Define KPIs in the KPIs tab after saving; caps: Primary ≤5, Secondary ≤4, Total ≤9."
}

private struct InfoIcon: View {
    let text: String
    @State private var hovering = false

    var body: some View {
        Image(systemName: "info.circle")
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 16, alignment: .center)
            .help(text)
            .accessibilityLabel(text)
            #if os(macOS)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.hovering = hovering
                }
            }
            .popover(isPresented: $hovering, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                TooltipBubble(text: text)
                    .padding(6)
            }
            #endif
    }
}

private struct TooltipBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(8)
            .foregroundStyle(.primary)
            .background(bubbleColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.25))
            )
            .cornerRadius(8)
    }

    private var bubbleColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
}

struct ThesisManagementRootView: View {
    @EnvironmentObject var thesisStore: ThesisStore
    @State private var selection: ThesisModuleSection = .dashboard
    @State private var path: [ThesisRoute] = []
    @State private var showingCreateSheet = false
    @State private var dashboardSheet: DashboardSheet?
    @StateObject private var workflowState = GuidedWorkflowState(thesisId: nil, availableFlows: GuidedFlow.allCases)

    var body: some View {
        Group {
            #if os(macOS)
            HSplitView {
                sidebar
                    .frame(minWidth: 190, idealWidth: 210, maxWidth: 240)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #else
            NavigationSplitView {
                sidebar
            } detail: {
                detail
            }
            #endif
        }
        .sheet(isPresented: $showingCreateSheet) {
            ThesisEditorView(mode: .create) { thesis in
                let created = thesisStore.createThesis(
                    name: thesis.name,
                    northStar: thesis.northStar,
                    investmentRole: thesis.investmentRole,
                    nonGoals: thesis.nonGoals,
                    tier: thesis.tier,
                    assumptions: thesis.assumptions,
                    killCriteria: thesis.killCriteria,
                    primaryKPIs: thesis.primaryKPIs,
                    secondaryKPIs: thesis.secondaryKPIs
                )
                path = [.detail(created.id)]
            }
            .frame(minWidth: 700, minHeight: 540)
        }
        .sheet(item: $dashboardSheet) { destination in
            switch destination {
            case .detail(let thesis):
                ThesisDetailView(thesis: thesisStore.thesis(id: thesis.id) ?? thesis) { week in
                    dashboardSheet = .review(thesis, week)
                }
                .frame(minWidth: 900, minHeight: 700)
            case .review(let thesis, let week):
                WeeklyReviewFocusView(thesis: thesisStore.thesis(id: thesis.id) ?? thesis, week: week)
                    .frame(minWidth: 1000, minHeight: 700)
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                ForEach(ThesisModuleSection.allCases) { section in
                    Label(section.label, systemImage: section.icon)
                        .tag(section)
                }
            }
            if selection == .imports {
                Section("Workflow Progress") {
                    WorkflowSidebarProgressView(workflow: workflowState)
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 8, trailing: 8))
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Thesis Mgmt")
    }

    private var detail: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: ThesisRoute.self) { route in
                    switch route {
                    case .detail(let id):
                        if let thesis = thesisStore.thesis(id: id) {
                            ThesisDetailView(thesis: thesis) { week in
                                path.append(.review(id, week))
                            }
                        } else {
                            Text("Thesis not found")
                        }
                    case .review(let id, let week):
                        if let thesis = thesisStore.thesis(id: id) {
                            WeeklyReviewFocusView(thesis: thesis, week: week)
                        } else {
                            Text("Thesis not found")
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .dashboard:
            ThesisDashboardView { thesis in
                dashboardSheet = .detail(thesis)
            } onReview: { thesis in
                dashboardSheet = .review(thesis, WeekNumber.current())
            }
        case .theses:
            ThesisListView(onNew: { showingCreateSheet = true }) { thesis in
                path.append(.detail(thesis.id))
            }
        case .imports:
            GuidedThesisWorkflowView(workflow: workflowState)
                .padding()
                .navigationTitle("Thesis Workflow")
        }
    }
}

// MARK: - Dashboard

private struct ThesisDashboardView: View {
    @EnvironmentObject var thesisStore: ThesisStore
    let onOpen: (Thesis) -> Void
    let onReview: (Thesis) -> Void

    private var tier1: [Thesis] {
        thesisStore.theses.filter { $0.tier == .tier1 }
    }

    private var tier2: [Thesis] {
        thesisStore.theses.filter { $0.tier == .tier2 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Global Dashboard")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 12) {
                    ThesisTierHeader(title: "Tier-1 (Pinned)", accent: Color.accentColor)
                    ThesisCardGrid(theses: tier1, onOpen: onOpen, onReview: onReview)
                }
                Divider()
                    .padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 12) {
                    ThesisTierHeader(title: "Tier-2", accent: Color.secondary)
                    ThesisCardGrid(theses: tier2, onOpen: onOpen, onReview: onReview)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Dashboard")
    }
}

private struct ThesisTierHeader: View {
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 4, height: 18)
            Text(title)
                .font(.title3)
                .bold()
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct ThesisCardGrid: View {
    let theses: [Thesis]
    let onOpen: (Thesis) -> Void
    let onReview: (Thesis) -> Void
    @EnvironmentObject var store: ThesisStore

    private let grid = [GridItem(.adaptive(minimum: 320), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: grid, spacing: 16) {
            ForEach(theses) { thesis in
                ThesisCard(thesis: thesis, onOpen: onOpen, onReview: onReview)
            }
        }
    }
}

private struct ThesisCard: View {
    let thesis: Thesis
    let onOpen: (Thesis) -> Void
    let onReview: (Thesis) -> Void
    @EnvironmentObject var store: ThesisStore

    private var latestReview: WeeklyReview? { store.latestReview(for: thesis.id) }

    private var overallStatus: RAGStatus {
        latestReview?.status ?? .unknown
    }

    private var dueText: String {
        guard let days = store.daysSinceLastReview(thesisId: thesis.id) else { return "New" }
        if days <= 0 { return "Today" }
        return "\(days)d"
    }

    private var overdue: Bool { store.overdueFlag(for: thesis.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(thesis.name)
                        .font(.headline)
                    Text(thesis.tier.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                RAGBadge(status: overallStatus)
            }
            if let lastDecision = latestReview?.decision {
                Text("Last: \(lastDecision.rawValue)")
                    .font(.subheadline)
            } else {
                Text("No reviews yet")
                    .font(.subheadline)
            }
            HStack {
                Label("Due: \(dueText)", systemImage: overdue ? "exclamationmark.triangle.fill" : "clock")
                    .foregroundStyle(overdue ? .orange : .secondary)
                Spacer()
                if latestReview?.patchId != nil {
                    Label("LLM", systemImage: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Primary KPIs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(store.topPrimaryKPIs(for: thesis, limit: 3), id: \.0.id) { def, reading in
                    HStack {
                        Text(def.name)
                            .font(.subheadline)
                        Spacer()
                        KPIStatusPill(status: reading?.status ?? .unknown)
                    }
                }
            }
            HStack {
                Button {
                    onReview(thesis)
                } label: {
                    Label("Review", systemImage: "pencil.and.outline")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    onOpen(thesis)
                } label: {
                    Label("Details", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(overdue ? Color.orange : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct KPIStatusPill: View {
    let status: RAGStatus

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .green: return .green
        case .amber: return .orange
        case .red: return .red
        case .unknown: return .gray
        }
    }
}

private struct RAGBadge: View {
    let status: RAGStatus
    var body: some View {
        Text(status == .unknown ? "N/A" : status.rawValue.uppercased())
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .green: return .green
        case .amber: return .orange
        case .red: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Thesis list

private struct ThesisListView: View {
    @EnvironmentObject var thesisStore: ThesisStore
    let onNew: () -> Void
    let onSelect: (Thesis) -> Void
    @State private var editingThesis: Thesis?
    @State private var deletingThesis: Thesis?
    @State private var exportingThesis: Thesis?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(thesisStore.theses) { thesis in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(thesis.name)
                                    .font(.headline)
                                RAGBadge(status: thesisStore.latestReview(for: thesis.id)?.status ?? .unknown)
                            }
                            Text(thesis.northStar)
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Button {
                                    editingThesis = thesis
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                                Button {
                                    exportingThesis = thesis
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .tint(.teal)
                                Button(role: .destructive) {
                                    deletingThesis = thesis
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(thesis.tier.label)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)))
                            if let last = thesisStore.latestReview(for: thesis.id) {
                                Text("Last decision: \(last.decision.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No reviews yet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Surface.secondary)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(thesis) }
                    .contextMenu {
                        Button {
                            editingThesis = thesis
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deletingThesis = thesis
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Theses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onNew()
                } label: {
                    Label("New Thesis", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editingThesis, content: { thesis in
            ThesisEditorView(mode: .edit(thesis)) { updated in
                _ = thesisStore.updateThesis(updated)
            }
            .frame(minWidth: 720, minHeight: 540)
        })
        .sheet(item: $exportingThesis) { thesis in
            ThesisExportSheet(thesisId: thesis.id)
                .frame(minWidth: 760, minHeight: 620)
        }
        .alert("Delete thesis?", isPresented: Binding(get: { deletingThesis != nil }, set: { if !$0 { deletingThesis = nil } })) {
            Button("Delete", role: .destructive) {
                if let target = deletingThesis { thesisStore.deleteThesis(id: target.id) }
                deletingThesis = nil
            }
            Button("Cancel", role: .cancel) { deletingThesis = nil }
        } message: {
            Text("This removes the thesis and its weekly reviews.")
        }
    }
}

// MARK: - Thesis detail

private struct ThesisDetailView: View {
    let thesis: Thesis
    let onStartReview: (WeekNumber) -> Void
    @EnvironmentObject var store: ThesisStore
    @State private var tab: Tab = .overview
    @State private var showPrompt = false
    @State private var showImport = false
    @State private var showEdit = false
    @State private var showExport = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss
    enum Tab: String, CaseIterable, Identifiable {
        case overview, thisWeek, trends, history, kpis, llm
        var id: String { rawValue }
        var label: String {
            switch self {
            case .overview: return "Overview"
            case .thisWeek: return "This Week"
            case .trends: return "Trends"
            case .history: return "History"
            case .kpis: return "KPIs"
            case .llm: return "LLM"
            }
        }
    }

    private var currentThesis: Thesis {
        store.thesis(id: thesis.id) ?? thesis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Picker("Tab", selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            Group {
                switch tab {
                case .overview:
                    ThesisOverviewTab(thesis: currentThesis)
                case .thisWeek:
                    WeeklyReviewFocusView(thesis: currentThesis, week: WeekNumber.current())
                case .trends:
                    ThesisTrendsView(thesis: currentThesis)
                case .history:
                    ThesisHistoryView(thesis: currentThesis)
                case .kpis:
                    KPIMgmtView(thesisId: thesis.id)
                case .llm:
                    GuidedThesisWorkflowContainerView(
                        thesisId: thesis.id,
                        availableFlows: [.weeklyUpdate],
                        initialFlow: .weeklyUpdate
                    )
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .sheet(isPresented: $showPrompt) {
            GuidedThesisWorkflowContainerView(
                thesisId: thesis.id,
                availableFlows: [.weeklyUpdate],
                initialFlow: .weeklyUpdate,
                initialWeeklyStep: .generatePrompt
            )
            .frame(minWidth: 760, minHeight: 620)
        }
        .sheet(isPresented: $showImport) {
            GuidedThesisWorkflowContainerView(
                thesisId: thesis.id,
                availableFlows: [.weeklyUpdate],
                initialFlow: .weeklyUpdate,
                initialWeeklyStep: .importPatch
            )
            .frame(minWidth: 760, minHeight: 620)
        }
        .sheet(isPresented: $showExport) {
            ThesisExportSheet(thesisId: thesis.id)
                .frame(minWidth: 760, minHeight: 620)
        }
        .sheet(isPresented: $showEdit) {
            ThesisEditorView(mode: .edit(currentThesis)) { updated in
                _ = store.updateThesis(updated)
            }
            .frame(minWidth: 720, minHeight: 540)
        }
        .alert("Delete thesis?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                store.deleteThesis(id: thesis.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the thesis and its weekly reviews.")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentThesis.name)
                    .font(.title2)
                    .bold()
                Text("Tier: \(currentThesis.tier.label)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onStartReview(WeekNumber.current())
            } label: {
                Label("Start Review", systemImage: "pencil.and.outline")
            }
            .buttonStyle(.borderedProminent)
            Button {
                tab = .kpis
            } label: {
                Label("Manage KPIs", systemImage: "chart.bar")
            }
            .buttonStyle(.bordered)
            Button {
                showExport = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .tint(.teal)
            Button {
                showEdit = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            Button {
                showPrompt = true
            } label: {
                Label("Generate LLM Prompt", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            Button {
                showImport = true
            } label: {
                Label("Import JSON", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            Button {
                dismiss()
            } label: {
                Label("Exit", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
        }
    }
}

private struct ThesisExportSheet: View {
    @EnvironmentObject var store: ThesisStore
    @Environment(\.dismiss) private var dismiss
    let thesisId: String
    @State private var exportText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Export Thesis")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Exit") { dismiss() }
                    .buttonStyle(.bordered)
            }
            TextEditor(text: $exportText)
                .frame(minHeight: 360)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            HStack {
                Button("Copy to Clipboard") {
                    copyToClipboard(exportText)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
        .padding()
        .onAppear {
            exportText = buildExport()
        }
    }

    private func buildExport() -> String {
        guard let thesis = store.thesis(id: thesisId) else { return "Thesis not found." }
        var lines: [String] = []
        lines.append("THESIS EXPORT")
        lines.append("")
        lines.append("Name (\(ThesisFieldHelp.name)): \(thesis.name)")
        lines.append("Tier (\(ThesisFieldHelp.tier)): \(thesis.tier.label)")
        lines.append("Investment Role (\(ThesisFieldHelp.investmentRole)): \(thesis.investmentRole)")
        lines.append("")
        lines.append("North Star (\(ThesisFieldHelp.northStar)):")
        lines.append(thesis.northStar)
        lines.append("")
        lines.append("Non-Goals (\(ThesisFieldHelp.nonGoals)):")
        lines.append(thesis.nonGoals)
        lines.append("")
        lines.append("Assumptions (\(ThesisFieldHelp.assumptions)):")
        if thesis.assumptions.isEmpty {
            lines.append("- None")
        } else {
            for assumption in thesis.assumptions {
                lines.append("- \(assumption.title) [\(assumption.id)]")
                lines.append("  \(assumption.detail)")
            }
        }
        lines.append("")
        lines.append("Kill Criteria (\(ThesisFieldHelp.killCriteria)):")
        if thesis.killCriteria.isEmpty {
            lines.append("- None")
        } else {
            for kill in thesis.killCriteria {
                lines.append("- \(kill.description) [\(kill.id)]")
            }
        }
        lines.append("")
        lines.append("Primary KPIs (\(ThesisFieldHelp.kpis)):")
        appendKpis(thesis.primaryKPIs, lines: &lines)
        lines.append("")
        lines.append("Secondary KPIs (\(ThesisFieldHelp.kpis)):")
        appendKpis(thesis.secondaryKPIs, lines: &lines)
        lines.append("")
        lines.append("KPI Pack Prompt:")
        let kpiPrompt = store.activeThesisKpiPrompt(for: thesis.id)?.body.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if kpiPrompt.isEmpty {
            lines.append("- Not set")
        } else {
            lines.append(kpiPrompt)
        }
        lines.append("")
        lines.append("Weekly Reviews:")
        let reviews = store.reviews(for: thesis.id)
        if reviews.isEmpty {
            lines.append("- None")
        } else {
            let defMap = Dictionary(uniqueKeysWithValues: (thesis.primaryKPIs + thesis.secondaryKPIs).map { ($0.id, $0) })
            for review in reviews {
                lines.append("- Week \(review.week.stringValue)")
                lines.append("  Status: \(review.status.rawValue.uppercased()) | Decision: \(review.decision.rawValue) | Confidence: \(review.confidence)")
                lines.append("  Headline: \(review.headline)")
                if let finalized = review.finalizedAt {
                    lines.append("  Finalized: \(isoFormatter.string(from: finalized))")
                } else {
                    lines.append("  Finalized: Draft")
                }
                if let patch = review.patchId, !patch.isEmpty {
                    lines.append("  Patch ID: \(patch)")
                }
                if !review.macroEvents.isEmpty {
                    lines.append("  Macro Events:")
                    review.macroEvents.forEach { lines.append("  - \($0)") }
                }
                if !review.microEvents.isEmpty {
                    lines.append("  Micro Events:")
                    review.microEvents.forEach { lines.append("  - \($0)") }
                }
                if !review.assumptionStatuses.isEmpty {
                    lines.append("  Assumptions Status:")
                    for status in review.assumptionStatuses {
                        let title = thesis.assumptions.first(where: { $0.id == status.assumptionId })?.title ?? status.assumptionId
                        let note = status.note?.isEmpty == false ? " (\(status.note!))" : ""
                        lines.append("  - \(title): \(status.status.rawValue)\(note)")
                    }
                }
                if !review.kpiReadings.isEmpty {
                    lines.append("  KPI Readings:")
                    for reading in review.kpiReadings {
                        let name = defMap[reading.kpiId]?.name ?? reading.kpiId
                        let value = reading.currentValue.map { formatNumber($0) } ?? "n/a"
                        lines.append("  - \(name): \(value) | \(reading.status.rawValue.uppercased()) | Trend: \(reading.trend.rawValue)")
                        if let comment = reading.comment, !comment.isEmpty {
                            lines.append("    Note: \(comment)")
                        }
                    }
                }
                if !review.rationale.isEmpty {
                    lines.append("  Rationale:")
                    review.rationale.forEach { lines.append("  - \($0)") }
                }
                if !review.watchItems.isEmpty {
                    lines.append("  Watch Items:")
                    review.watchItems.forEach { lines.append("  - \($0)") }
                }
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func appendKpis(_ kpis: [KPIDefinition], lines: inout [String]) {
        if kpis.isEmpty {
            lines.append("- None")
            return
        }
        for kpi in kpis {
            lines.append("- \(kpi.name) [\(kpi.id)]")
            lines.append("  Unit: \(kpi.unit) | Direction: \(kpi.direction.rawValue)")
            lines.append("  Description: \(kpi.description)")
            let sourceText = kpi.source.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("  Source: \(sourceText.isEmpty ? "not specified" : sourceText)")
            lines.append("  Ranges: G \(rangeText(kpi.ranges.green)) | A \(rangeText(kpi.ranges.amber)) | R \(rangeText(kpi.ranges.red))")
        }
    }

    private func rangeText(_ range: KPIRange) -> String {
        "\(formatNumber(range.lower))-\(formatNumber(range.upper))"
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var isoFormatter: ISO8601DateFormatter {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

private struct ThesisOverviewTab: View {
    let thesis: Thesis
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("North Star")
                        .font(.headline)
                    Text(thesis.northStar)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).fill(Surface.secondary))
                }
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Core Assumptions")
                            .font(.headline)
                        ForEach(thesis.assumptions) { assumption in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(assumption.title).bold()
                                Text(assumption.detail)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 8).fill(Surface.tertiary))
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kill Criteria (Breakers)")
                            .font(.headline)
                        ForEach(thesis.killCriteria) { kill in
                            Text(kill.description)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.6)))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Investment Role / Non-goals")
                        .font(.headline)
                    Text("Role: \(thesis.investmentRole)")
                    Text("Non-goals: \(thesis.nonGoals)")
                        .foregroundStyle(.secondary)
                }
                ThesisKPISummaryView(thesis: thesis)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ThesisKPISummaryView: View {
    let thesis: Thesis

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KPI Snapshot")
                .font(.headline)
            Text("Primary KPIs drive status; secondary KPIs are context only.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if thesis.primaryKPIs.isEmpty {
                        Text("No primary KPIs defined.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(thesis.primaryKPIs) { kpi in
                            KPICompactRow(definition: kpi, badge: "PRIMARY")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Secondary")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if thesis.secondaryKPIs.isEmpty {
                        Text("No secondary KPIs defined.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(thesis.secondaryKPIs) { kpi in
                            KPICompactRow(definition: kpi, badge: "SECONDARY")
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
    }
}

private struct KPICompactRow: View {
    let definition: KPIDefinition
    let badge: String

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.subheadline)
                Text(definition.unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(badge)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Weekly Review Focus

private struct WeeklyReviewFocusView: View {
    let thesis: Thesis
    let week: WeekNumber
    @EnvironmentObject var store: ThesisStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WeeklyReview?
    @State private var lastSavedSnapshot: WeeklyReview?
    @State private var statusMessage: String?
    @State private var showError: Bool = false
    @State private var showExitConfirm = false
    @State private var showUnlockConfirm = false

    private var definitionMap: [String: KPIDefinition] {
        Dictionary(uniqueKeysWithValues: (thesis.primaryKPIs + thesis.secondaryKPIs).map { ($0.id, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Review: \(week.stringValue)")
                    .font(.title2)
                    .bold()
                Spacer()
                RAGBadge(status: draft?.status ?? .unknown)
                if isFinalized {
                    Button {
                        showUnlockConfirm = true
                    } label: {
                        Label("Finalized", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Click to unlock for editing.")
                    Button("Unlock") {
                        showUnlockConfirm = true
                    }
                    .buttonStyle(.bordered)
                }
                if let missing = draft?.missingPrimaryKpis, !missing.isEmpty {
                    Text("Missing primary KPIs")
                        .foregroundStyle(.orange)
                }
                Button("Exit") {
                    if hasUnsavedChanges {
                        showExitConfirm = true
                    } else {
                        dismiss()
                    }
                }
                .buttonStyle(.bordered)
                Button("Save Draft") { save(finalize: false) }
                    .buttonStyle(.bordered)
                    .disabled(isFinalized)
                Button("Save and Lock") { save(finalize: true) }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFinalized)
            }
            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(showError ? .red : .secondary)
            }
            Divider()
            HStack(alignment: .top, spacing: 12) {
                contextPanel
                    .frame(width: 320)
                reviewForm
            }
        }
        .padding()
        .padding([.trailing, .bottom], 16)
        .task {
            if draft == nil {
                draft = store.startDraft(thesisId: thesis.id, week: week)
                refreshStatus()
                lastSavedSnapshot = draft
                if isFinalized {
                    statusMessage = "Finalized review is locked."
                    showError = false
                }
            }
        }
        .alert("Discard changes?", isPresented: $showExitConfirm) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Save or discard before exiting.")
        }
        .alert("Unlock finalized review?", isPresented: $showUnlockConfirm) {
            Button("Unlock", role: .destructive) { unlockReview() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Unlocking allows edits to a finalized review.")
        }
    }

    private var contextPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Context")
                    .font(.headline)
                DisclosureGroup("North Star") {
                    Text(thesis.northStar)
                        .padding(.vertical, 6)
                }
                DisclosureGroup("Assumptions") {
                    ForEach(thesis.assumptions) { assumption in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(assumption.title).bold()
                            Text(assumption.detail)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                DisclosureGroup("Kill Criteria") {
                    ForEach(thesis.killCriteria) { kill in
                        Text(kill.description)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Surface.secondary))
    }

    private var reviewForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headlineField
                primaryKPISection
                secondaryKPISection
                eventsSection
                assumptionsSection
                killCriteriaSection
                confidenceDecisionSection
                rationaleSection
            }
            .disabled(isFinalized)
        }
    }

    private var headlineField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Headline")
                .font(.headline)
            TextField("One-line summary", text: binding(\.headline))
                .textFieldStyle(.roundedBorder)
        }
    }

    private var primaryKPISection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Primary KPIs (required)")
                .font(.headline)
            ForEach(thesis.primaryKPIs) { def in
                kpiRow(definition: def)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.2)))
    }

    private var secondaryKPISection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Secondary KPIs")
                .font(.headline)
            if thesis.secondaryKPIs.isEmpty {
                Text("No secondary KPIs configured.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(thesis.secondaryKPIs) { def in
                    kpiRow(definition: def)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
    }

    private func kpiRow(definition: KPIDefinition) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.subheadline)
                Text("Range: G \(rangeText(definition.ranges.green)) | A \(rangeText(definition.ranges.amber)) | R \(rangeText(definition.ranges.red))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TextField("Value", text: kpiValueBinding(for: definition.id))
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
                .onChange(of: kpiValueBinding(for: definition.id).wrappedValue) { _, _ in refreshStatus() }
            Picker("Trend", selection: kpiTrendBinding(for: definition.id)) {
                ForEach(KPITrend.allCases, id: \.self) { trend in
                    Text(trend.rawValue.capitalized).tag(trend)
                }
            }
            .pickerStyle(.menu)
            TextField("Note", text: kpiNoteBinding(for: definition.id))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
            KPIStatusPill(status: kpiStatus(definition.id))
        }
    }

    private func rangeText(_ range: KPIRange) -> String {
        String(format: "%.1f-%.1f", range.lower, range.upper)
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Material Events (max 3 each)")
                .font(.headline)
            EventList(title: "Macro", items: binding(\.macroEvents))
            EventList(title: "Micro", items: binding(\.microEvents))
        }
    }

    private var assumptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assumptions Status")
                .font(.headline)
            if let draft, !draft.assumptionStatuses.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Assumption")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(draft.assumptionStatuses.enumerated()), id: \.element.assumptionId) { idx, entry in
                        GridRow {
                            if let def = thesis.assumptions.first(where: { $0.id == entry.assumptionId }) {
                                Text(def.title)
                                    .frame(width: 160, alignment: .leading)
                            } else {
                                Text("Assumption")
                                    .frame(width: 160, alignment: .leading)
                                    .foregroundStyle(.secondary)
                            }
                            Picker("", selection: Binding<AssumptionHealth>(
                                get: { assumptionBinding(for: idx).wrappedValue.status },
                                set: { newValue in
                                    var value = assumptionBinding(for: idx).wrappedValue
                                    value.status = newValue
                                    assumptionBinding(for: idx).wrappedValue = value
                                    refreshStatus()
                                }
                            )) {
                                ForEach(AssumptionHealth.allCases, id: \.self) { status in
                                    Text(status.rawValue.capitalized).tag(status)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            TextField("Note", text: Binding(get: { assumptionBinding(for: idx).wrappedValue.note ?? "" }, set: { new in
                                var value = assumptionBinding(for: idx).wrappedValue
                                value.note = new.isEmpty ? nil : new
                                assumptionBinding(for: idx).wrappedValue = value
                            }))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Surface.secondary))
    }

    private var killCriteriaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kill Criteria Assessment")
                .font(.headline)
            if thesis.killCriteria.isEmpty {
                Text("No kill criteria configured.")
                    .foregroundStyle(.secondary)
            } else if let draft, !draft.killCriteriaStatuses.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Criterion")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(draft.killCriteriaStatuses.enumerated()), id: \.element.criterionId) { idx, entry in
                        GridRow {
                            if let def = thesis.killCriteria.first(where: { $0.id == entry.criterionId }) {
                                Text(def.description)
                                    .frame(width: 220, alignment: .leading)
                            } else {
                                Text("Kill criterion")
                                    .frame(width: 220, alignment: .leading)
                                    .foregroundStyle(.secondary)
                            }
                            Picker("", selection: Binding<KillCriterionStatus>(
                                get: { killCriteriaBinding(for: idx).wrappedValue.status },
                                set: { newValue in
                                    var value = killCriteriaBinding(for: idx).wrappedValue
                                    value.status = newValue
                                    killCriteriaBinding(for: idx).wrappedValue = value
                                    refreshStatus()
                                }
                            )) {
                                ForEach(KillCriterionStatus.allCases, id: \.self) { status in
                                    Text(status.rawValue.capitalized).tag(status)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            TextField("Note", text: Binding(get: {
                                killCriteriaBinding(for: idx).wrappedValue.note ?? ""
                            }, set: { new in
                                var value = killCriteriaBinding(for: idx).wrappedValue
                                value.note = new.isEmpty ? nil : new
                                killCriteriaBinding(for: idx).wrappedValue = value
                            }))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Surface.secondary))
    }

    private var confidenceDecisionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confidence & Decision")
                .font(.headline)
            HStack {
                Text("Confidence")
                Slider(value: Binding(get: { Double(draft?.confidence ?? 3) }, set: { draft?.confidence = Int($0) }), in: 1...5, step: 1)
                Text("\(draft?.confidence ?? 3)")
                    .frame(width: 24)
            }
            HStack {
                Text("Decision")
                Spacer()
                Picker("Decision", selection: binding(\.decision)) {
                    ForEach(ReviewDecision.ordered, id: \.self) { decision in
                        Text(decision.rawValue).tag(decision)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var rationaleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rationale (≤3) & Watch items (≤2)")
                .font(.headline)
            BulletEditor(title: "Rationale", items: binding(\.rationale), limit: 3)
            BulletEditor(title: "Watch", items: binding(\.watchItems), limit: 2)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<WeeklyReview, Value>) -> Binding<Value> {
        Binding<Value>(
            get: { draft?[keyPath: keyPath] ?? defaultValue(for: keyPath) },
            set: { newValue in
                draft?[keyPath: keyPath] = newValue
                refreshStatus()
            }
        )
    }

    private func defaultValue<Value>(for keyPath: WritableKeyPath<WeeklyReview, Value>) -> Value {
        switch keyPath {
        case \.headline: return "" as! Value
        case \.macroEvents: return [] as! Value
        case \.microEvents: return [] as! Value
        case \.rationale: return [] as! Value
        case \.watchItems: return [] as! Value
        case \.confidence: return 3 as! Value
        case \.decision: return ReviewDecision.hold as! Value
        default:
            fatalError("Unhandled default")
        }
    }

    private func assumptionBinding(for index: Int) -> Binding<AssumptionStatusEntry> {
        Binding<AssumptionStatusEntry>(
            get: { draft?.assumptionStatuses[index] ?? AssumptionStatusEntry(assumptionId: thesis.assumptions[index].id, status: .intact, note: nil) },
            set: { newValue in
                if draft?.assumptionStatuses.indices.contains(index) == true {
                    draft?.assumptionStatuses[index] = newValue
                    refreshStatus()
                }
            }
        )
    }

    private func killCriteriaBinding(for index: Int) -> Binding<KillCriterionStatusEntry> {
        Binding<KillCriterionStatusEntry>(
            get: { draft?.killCriteriaStatuses[index] ?? KillCriterionStatusEntry(criterionId: thesis.killCriteria[index].id, status: .clear, note: nil) },
            set: { newValue in
                if draft?.killCriteriaStatuses.indices.contains(index) == true {
                    draft?.killCriteriaStatuses[index] = newValue
                    refreshStatus()
                }
            }
        )
    }

    private func kpiIndex(for id: String) -> Int? {
        draft?.kpiReadings.firstIndex(where: { $0.kpiId == id })
    }

    private func kpiValueBinding(for id: String) -> Binding<String> {
        Binding<String>(
            get: {
                guard let idx = kpiIndex(for: id), let value = draft?.kpiReadings[idx].currentValue else { return "" }
                return formatNumber(value)
            },
            set: { newValue in
                if let idx = kpiIndex(for: id) {
                    draft?.kpiReadings[idx].currentValue = parseNumber(newValue)
                    refreshStatus()
                }
            }
        )
    }

    private func kpiNoteBinding(for id: String) -> Binding<String> {
        Binding<String>(
            get: {
                guard let idx = kpiIndex(for: id) else { return "" }
                return draft?.kpiReadings[idx].comment ?? ""
            },
            set: { newValue in
                if let idx = kpiIndex(for: id) {
                    draft?.kpiReadings[idx].comment = newValue.isEmpty ? nil : newValue
                }
            }
        )
    }

    private func kpiTrendBinding(for id: String) -> Binding<KPITrend> {
        Binding<KPITrend>(
            get: {
                guard let idx = kpiIndex(for: id) else { return .na }
                return draft?.kpiReadings[idx].trend ?? .na
            },
            set: { newValue in
                if let idx = kpiIndex(for: id) {
                    draft?.kpiReadings[idx].trend = newValue
                }
            }
        )
    }

    private func kpiStatus(_ id: String) -> RAGStatus {
        guard let idx = kpiIndex(for: id), let draft else { return .unknown }
        return draft.kpiReadings[idx].status
    }

    private func parseNumber(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let number = Self.kpiNumberFormatter.number(from: trimmed) {
            return number.doubleValue
        }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func formatNumber(_ value: Double) -> String {
        Self.kpiNumberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static let kpiNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.isLenient = true
        return formatter
    }()

    private func save(finalize: Bool) {
        if isFinalized {
            statusMessage = "Finalized review is locked."
            showError = true
            return
        }
        refreshStatus()
        guard let draft else { return }
        let result = store.save(review: draft, finalize: finalize)
        switch result {
        case .success(let saved):
            self.draft = saved
            lastSavedSnapshot = saved
            statusMessage = finalize ? "Finalized for \(week.stringValue)" : "Draft saved"
            showError = false
            if finalize {
                dismiss()
            }
        case .failure(let error):
            showError = true
            switch error {
            case .primaryKPIIncomplete(let ids):
                statusMessage = "Missing primary KPI values: \(ids.joined(separator: ", "))"
            case .reviewFinalized:
                statusMessage = "Finalized review is locked."
            case .thesisNotFound:
                statusMessage = "Thesis missing"
            default:
                statusMessage = "Could not save: \(error)"
            }
        }
    }

    private func unlockReview() {
        guard var current = draft else { return }
        current.finalizedAt = nil
        if store.unlockReview(id: current.id) {
            draft = current
            lastSavedSnapshot = current
            statusMessage = "Review unlocked for editing."
            showError = false
            refreshStatus()
        } else {
            statusMessage = "Unable to unlock review."
            showError = true
        }
    }

    private var hasUnsavedChanges: Bool {
        guard let draft, let lastSavedSnapshot else { return false }
        return draft != lastSavedSnapshot
    }

    private var isFinalized: Bool {
        draft?.finalizedAt != nil
    }

    private func refreshStatus() {
        guard var current = draft else { return }
        current.kpiReadings = current.kpiReadings.map { reading in
            var copy = reading
            if let def = definitionMap[reading.kpiId] {
                copy.status = def.ranges.status(for: copy.currentValue)
            }
            return copy
        }
        current.missingPrimaryKpis = thesis.primaryKPIs.compactMap { def in
            current.kpiReadings.first(where: { $0.kpiId == def.id })?.currentValue == nil ? def.id : nil
        }
        if !current.killCriteriaStatuses.isEmpty {
            current.killSwitchTriggered = current.killCriteriaStatuses.contains(where: { $0.status == .triggered })
        }
        current.status = store.computeOverallStatus(review: current, thesis: thesis, definitionMap: definitionMap)
        draft = current
    }
}

private struct EventList: View {
    let title: String
    @Binding var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                if items.count < 3 {
                    Button("+ Add") { items.append("") }
                        .buttonStyle(.bordered)
                }
            }
            ForEach(items.indices, id: \.self) { idx in
                HStack {
                    TextField("Detail", text: $items[idx])
                        .textFieldStyle(.roundedBorder)
                    Button(role: .destructive) {
                        items.remove(at: idx)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct BulletEditor: View {
    let title: String
    @Binding var items: [String]
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                if items.count < limit {
                    Button("+ Add") { items.append("") }
                        .buttonStyle(.bordered)
                }
            }
            ForEach(items.indices, id: \.self) { idx in
                TextField("\(title) \(idx + 1)", text: $items[idx])
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - Trends

private struct ThesisTrendsView: View {
    let thesis: Thesis
    @EnvironmentObject var store: ThesisStore
    @State private var window: Int = 12
    @State private var includeSecondary = false

    private var kpis: [KPIDefinition] {
        includeSecondary ? thesis.primaryKPIs + thesis.secondaryKPIs : thesis.primaryKPIs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trends")
                    .font(.title2)
                    .bold()
                Spacer()
                Toggle("Primary + Secondary", isOn: $includeSecondary)
                    .toggleStyle(.switch)
                Picker("Window", selection: $window) {
                    Text("12w").tag(12)
                    Text("26w").tag(26)
                }
                .pickerStyle(.segmented)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(kpis) { kpi in
                        KPITrendRow(thesisId: thesis.id, definition: kpi, window: window)
                    }
                }
            }
        }
        .padding()
    }
}

private struct KPITrendRow: View {
    let thesisId: String
    let definition: KPIDefinition
    let window: Int
    @EnvironmentObject var store: ThesisStore

    private var history: [KPIHistoryPoint] {
        store.history(for: thesisId, kpiId: definition.id, limit: window)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(definition.name)
                    .font(.headline)
                Spacer()
                Text("Range: \(rangeText(definition.ranges.green))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #if canImport(Charts)
            Chart {
                ForEach(history) { point in
                    if let value = point.value {
                        LineMark(
                            x: .value("Week", point.week.startDate),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(color(for: point.status))
                        PointMark(
                            x: .value("Week", point.week.startDate),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(color(for: point.status))
                    }
                }
                RuleMark(y: .value("Green Max", definition.ranges.green.upper))
                    .lineStyle(.init(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.green.opacity(0.3))
            }
            .frame(height: 140)
            #else
            Text("Charts not available on this platform.")
                .foregroundStyle(.secondary)
            #endif
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Surface.secondary))
    }

    private func color(for status: RAGStatus) -> Color {
        switch status {
        case .green: return .green
        case .amber: return .orange
        case .red: return .red
        case .unknown: return .gray
        }
    }

    private func rangeText(_ range: KPIRange) -> String {
        String(format: "%.1f-%.1f", range.lower, range.upper)
    }
}

private struct KPIHeaderView: View {
    let primaryCount: Int
    let secondaryCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KPI Management")
                .font(.title2)
                .bold()
            Text("Primary \(primaryCount)/5 • Secondary \(secondaryCount)/4 • Total \(primaryCount + secondaryCount)/9")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
    }
}

private struct KPISectionView: View {
    let title: String
    let subtitle: String
    let emptyText: String
    let kpis: [KPIDefinition]
    let onEdit: (KPIDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            if kpis.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(kpis) { kpi in
                        KPIRow(definition: kpi) { onEdit(kpi) }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.tertiary))
    }
}
// MARK: - History

private struct ThesisHistoryView: View {
    let thesis: Thesis
    @EnvironmentObject var store: ThesisStore
    @State private var toast: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Export CSV") {
                    exportCSV()
                    toast = "Copied CSV to clipboard"
                }
            }
            if let toast {
                Text(toast)
                    .foregroundStyle(.secondary)
            }
            List(store.reviews(for: thesis.id)) { review in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(review.week.stringValue)
                            .font(.headline)
                        RAGBadge(status: review.status)
                        if review.finalizedAt != nil {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Decision: \(review.decision.rawValue)")
                            .foregroundStyle(.secondary)
                    }
                    Text(review.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private func exportCSV() {
        let rows = store.reviews(for: thesis.id).map { review in
            "\"\(review.week.stringValue)\",\(review.status.rawValue),\(review.decision.rawValue),\"\(review.headline.replacingOccurrences(of: "\"", with: "'"))\",\(review.confidence),\(review.patchId ?? "")"
        }
        let header = "week,status,decision,headline,confidence,patch_id"
        let csv = ([header] + rows).joined(separator: "\n")
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(csv, forType: .string)
        #else
        UIPasteboard.general.string = csv
        #endif
    }
}

// MARK: - KPI Management

private struct KPIMgmtView: View {
    let thesisId: String
    var showClose: Bool = false
    @EnvironmentObject var store: ThesisStore
    @State private var message: String?
    @State private var editingKPI: KPIDefinition?
    @Environment(\.dismiss) private var dismiss

    private var thesis: Thesis? { store.thesis(id: thesisId) }
    private var canAddPrimary: Bool {
        guard let thesis else { return false }
        return thesis.primaryKPIs.count < 5 && totalCount() < 9
    }
    private var canAddSecondary: Bool {
        guard let thesis else { return false }
        return thesis.secondaryKPIs.count < 4 && totalCount() < 9
    }

    var body: some View {
        ScrollView {
            if let thesis {
                VStack(alignment: .leading, spacing: 16) {
                    KPIHeaderView(primaryCount: thesis.primaryKPIs.count, secondaryCount: thesis.secondaryKPIs.count)
                    if let message {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                    ThesisKpiPromptEditor(thesisId: thesis.id)
                    HStack(spacing: 12) {
                        Button("Add Primary KPI") { addKpi(primary: true) }
                            .disabled(!canAddPrimary)
                        Button("Add Secondary KPI") { addKpi(primary: false) }
                            .disabled(!canAddSecondary)
                    }
                    KPISectionView(
                        title: "Primary KPIs",
                        subtitle: "Required every week. Drives overall status.",
                        emptyText: "No primary KPIs yet. Add 3–5 to start.",
                        kpis: thesis.primaryKPIs,
                        onEdit: { editingKPI = $0 }
                    )
                    KPISectionView(
                        title: "Secondary KPIs",
                        subtitle: "Optional context signals; reviewed when relevant.",
                        emptyText: "No secondary KPIs yet. Add up to 4 for context.",
                        kpis: thesis.secondaryKPIs,
                        onEdit: { editingKPI = $0 }
                    )
                }
                .padding()
                .sheet(item: $editingKPI) { kpi in
                    KPIEditorView(
                        definition: kpi,
                        onSave: { updated in
                            let result = store.updateKPI(thesisId: thesisId, updated: updated)
                            switch result {
                            case .success(let def):
                                message = "Saved \(def.name)"
                            case .failure(let error):
                                message = errorMessage(for: error)
                            }
                            return result
                        },
                        onDelete: { definition in
                            let result = store.deleteKPI(thesisId: thesisId, kpiId: definition.id)
                            switch result {
                            case .success:
                                message = "Deleted \(definition.name)"
                            case .failure(let error):
                                message = errorMessage(for: error)
                            }
                            return result
                        }
                    )
                    .frame(minWidth: 520, minHeight: 420)
                }
            } else {
                Text("Thesis not found")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .navigationTitle("KPI Management")
        .onDisappear {
            store.syncKPIs(thesisId: thesisId)
        }
        .toolbar {
            if showClose {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Exit") { dismiss() }
                }
            }
        }
    }

    private func totalCount() -> Int {
        guard let thesis else { return 0 }
        return thesis.primaryKPIs.count + thesis.secondaryKPIs.count
    }

    private func addKpi(primary: Bool) {
        guard let thesis else { return }
        let count = primary ? thesis.primaryKPIs.count + 1 : thesis.secondaryKPIs.count + 1
        let id = "\(thesis.id)_\(primary ? "p" : "s")_\(count)"
        let direction: KPIDirection = .higherIsBetter
        let def = KPIDefinition(
            id: id,
            name: primary ? "Primary KPI \(count)" : "Secondary KPI \(count)",
            unit: primary ? "unit" : "index",
            description: "New KPI placeholder",
            isPrimary: primary,
            direction: direction,
            ranges: defaultRanges(for: direction)
        )
        let result = store.addKPI(to: thesis.id, definition: def)
        switch result {
        case .success:
            message = "Added \(def.name)"
        case .failure(let error):
            switch error {
            case .kpiCapExceeded:
                message = "KPI caps enforced (Primary ≤5, Secondary ≤4, Total ≤9)"
            default:
                message = "Could not add KPI: \(error)"
            }
        }
    }

    private func defaultRanges(for direction: KPIDirection) -> KPIRangeSet {
        switch direction {
        case .higherIsBetter:
            return KPIRangeSet(
                green: .init(lower: 70, upper: 100),
                amber: .init(lower: 40, upper: 70),
                red: .init(lower: 0, upper: 40)
            )
        case .lowerIsBetter:
            return KPIRangeSet(
                green: .init(lower: 0, upper: 30),
                amber: .init(lower: 30, upper: 60),
                red: .init(lower: 60, upper: 100)
            )
        }
    }

    private func errorMessage(for error: ThesisStoreError) -> String {
        switch error {
        case .kpiCapExceeded:
            return "KPI caps enforced (Primary ≤5, Secondary ≤4, Total ≤9)"
        case .kpiNotFound:
            return "KPI not found"
        case .thesisNotFound:
            return "Thesis not found"
        default:
            return "Could not update KPI: \(error)"
        }
    }
}

private struct ThesisKpiPromptEditor: View {
    let thesisId: String
    @EnvironmentObject var store: ThesisStore
    @State private var draftBody: String = ""
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KPI Pack Prompt")
                .font(.headline)
            Text("Stored per thesis and appended to the weekly review prompt.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(activeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $draftBody)
                .frame(minHeight: 200)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            HStack {
                Button("Save New Version (Activate)") { saveNewVersion() }
                    .buttonStyle(.borderedProminent)
                Button("Reset to Active") { loadFromActive() }
                    .buttonStyle(.bordered)
                Button("Copy Draft") { copyToClipboard(draftBody) }
                    .buttonStyle(.bordered)
                Spacer()
                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Versions")
                    .font(.headline)
                if prompts.isEmpty {
                    Text("No prompt versions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(prompts) { prompt in
                        ThesisKpiPromptRow(
                            prompt: prompt,
                            onLoad: { loadFromPrompt(prompt) },
                            onActivate: { activate(prompt) },
                            onArchive: { archive(prompt) }
                        )
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
        .onAppear { loadFromActive() }
    }

    private var prompts: [ThesisKpiPrompt] {
        store.thesisKpiPrompts(for: thesisId)
    }

    private var activeSummary: String {
        guard let active = store.activeThesisKpiPrompt(for: thesisId) else { return "Active: none" }
        let updatedText = dateText(active.updatedAt ?? active.createdAt) ?? "n/a"
        return "Active: v\(active.version) | updated \(updatedText)"
    }

    private func loadFromActive() {
        if let active = store.activeThesisKpiPrompt(for: thesisId) {
            loadFromPrompt(active)
        } else {
            draftBody = ""
        }
    }

    private func loadFromPrompt(_ prompt: ThesisKpiPrompt) {
        draftBody = prompt.body
    }

    private func saveNewVersion() {
        let result = store.createThesisKpiPromptVersion(thesisId: thesisId, body: draftBody)
        message = resultMessage(result)
        if case .success(let created) = result {
            loadFromPrompt(created)
        }
    }

    private func activate(_ prompt: ThesisKpiPrompt) {
        let result = store.activateThesisKpiPrompt(id: prompt.id)
        message = resultMessage(result)
        if case .success = result {
            loadFromActive()
        }
    }

    private func archive(_ prompt: ThesisKpiPrompt) {
        let result = store.archiveThesisKpiPrompt(id: prompt.id)
        message = resultMessage(result)
    }

    private func resultMessage(_ result: Result<ThesisKpiPrompt, ThesisKpiPromptError>) -> String {
        switch result {
        case .success(let prompt):
            return "Active: v\(prompt.version)"
        case .failure(let error):
            return errorMessage(for: error)
        }
    }

    private func errorMessage(for error: ThesisKpiPromptError) -> String {
        switch error {
        case .databaseUnavailable:
            return "Database unavailable"
        case .readOnly:
            return "Database is read-only"
        case .emptyBody:
            return "Prompt body is empty"
        case .invalidKey:
            return "Prompt not found"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    private func dateText(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

private struct ThesisKpiPromptRow: View {
    let prompt: ThesisKpiPrompt
    let onLoad: () -> Void
    let onActivate: () -> Void
    let onArchive: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("v\(prompt.version)")
                .font(.subheadline)
            Text(prompt.status.rawValue.uppercased())
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
            Text(dateText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Load") { onLoad() }
                .buttonStyle(.bordered)
            Button("Activate") { onActivate() }
                .buttonStyle(.bordered)
                .disabled(prompt.status == .active)
            Button("Archive") { onArchive() }
                .buttonStyle(.bordered)
                .disabled(prompt.status == .active || prompt.status == .archived)
        }
    }

    private var statusColor: Color {
        switch prompt.status {
        case .active: return .green
        case .inactive: return .orange
        case .archived: return .gray
        }
    }

    private var dateText: String {
        let date = prompt.updatedAt ?? prompt.createdAt
        guard let date else { return "n/a" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct KPIRow: View {
    let definition: KPIDefinition
    var onEdit: () -> Void = {}
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.name)
                        .font(.headline)
                    Text(definition.unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(definition.isPrimary ? "PRIMARY" : "SECONDARY")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(definition.isPrimary ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                    .clipShape(Capsule())
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.borderless)
            }
            Text(definition.description)
                .foregroundStyle(.secondary)
            Text("Source: \(sourceDisplay)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("Direction: \(definition.direction.rawValue)", systemImage: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Ranges: G \(rangeText(definition.ranges.green)) | A \(rangeText(definition.ranges.amber)) | R \(rangeText(definition.ranges.red))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
    }

    private func rangeText(_ range: KPIRange) -> String {
        String(format: "%.1f-%.1f", range.lower, range.upper)
    }

    private var sourceDisplay: String {
        let trimmed = definition.source.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "not set" : trimmed
    }
}

private struct KPIEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var unit: String
    @State private var description: String
    @State private var source: String
    @State private var direction: KPIDirection
    @State private var isPrimary: Bool
    @State private var greenLow: Double
    @State private var greenHigh: Double
    @State private var amberLow: Double
    @State private var amberHigh: Double
    @State private var redLow: Double
    @State private var redHigh: Double
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    let definition: KPIDefinition
    let onSave: (KPIDefinition) -> Result<KPIDefinition, ThesisStoreError>
    let onDelete: (KPIDefinition) -> Result<Void, ThesisStoreError>

    init(
        definition: KPIDefinition,
        onSave: @escaping (KPIDefinition) -> Result<KPIDefinition, ThesisStoreError>,
        onDelete: @escaping (KPIDefinition) -> Result<Void, ThesisStoreError>
    ) {
        self.definition = definition
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: definition.name)
        _unit = State(initialValue: definition.unit)
        _description = State(initialValue: definition.description)
        _source = State(initialValue: definition.source)
        _direction = State(initialValue: definition.direction)
        _isPrimary = State(initialValue: definition.isPrimary)
        _greenLow = State(initialValue: definition.ranges.green.lower)
        _greenHigh = State(initialValue: definition.ranges.green.upper)
        _amberLow = State(initialValue: definition.ranges.amber.lower)
        _amberHigh = State(initialValue: definition.ranges.amber.upper)
        _redLow = State(initialValue: definition.ranges.red.lower)
        _redHigh = State(initialValue: definition.ranges.red.upper)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Definition")
                            .font(.headline)
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                Text("Name")
                                TextField("KPI name", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }
                            GridRow {
                                Text("Type")
                                Picker("Type", selection: $isPrimary) {
                                    Text("Primary").tag(true)
                                    Text("Secondary").tag(false)
                                }
                                .pickerStyle(.segmented)
                            }
                            GridRow {
                                Text("Unit")
                                TextField("Unit", text: $unit)
                                    .textFieldStyle(.roundedBorder)
                            }
                            GridRow {
                                Text("Source")
                                TextField("Source (data origin)", text: $source)
                                    .textFieldStyle(.roundedBorder)
                            }
                            GridRow {
                                Text("Direction")
                                Picker("Direction", selection: $direction) {
                                    ForEach(KPIDirection.allCases, id: \.self) { dir in
                                        Text(dir.rawValue).tag(dir)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        Text("Description")
                            .font(.subheadline)
                        TextEditor(text: $description)
                            .frame(minHeight: 60)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ranges")
                            .font(.headline)
                        RangeRow(title: "Green", low: $greenLow, high: $greenHigh)
                        RangeRow(title: "Amber", low: $amberLow, high: $amberHigh)
                        RangeRow(title: "Red", low: $redLow, high: $redHigh)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Danger Zone")
                            .font(.headline)
                        Button("Delete KPI", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
                }
                .padding()
            }
            .navigationTitle("Edit KPI")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = KPIDefinition(
                            id: definition.id,
                            name: name,
                            unit: unit,
                            description: description,
                            source: source,
                            isPrimary: isPrimary,
                            direction: direction,
                            ranges: KPIRangeSet(
                                green: .init(lower: greenLow, upper: greenHigh),
                                amber: .init(lower: amberLow, upper: amberHigh),
                                red: .init(lower: redLow, upper: redHigh)
                            )
                        )
                        let result = onSave(updated)
                        switch result {
                        case .success:
                            dismiss()
                        case .failure(let error):
                            errorMessage = errorText(for: error)
                        }
                    }
                }
            }
            .alert("Delete KPI?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    let result = onDelete(definition)
                    switch result {
                    case .success:
                        dismiss()
                    case .failure(let error):
                        errorMessage = errorText(for: error)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes the KPI and its readings.")
            }
        }
    }

    private func errorText(for error: ThesisStoreError) -> String {
        switch error {
        case .kpiCapExceeded:
            return "KPI caps enforced (Primary ≤5, Secondary ≤4, Total ≤9)"
        case .kpiNotFound:
            return "KPI not found"
        case .thesisNotFound:
            return "Thesis not found"
        default:
            return "Could not update KPI: \(error)"
        }
    }
}

private struct RangeRow: View {
    let title: String
    @Binding var low: Double
    @Binding var high: Double

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 60, alignment: .leading)
            TextField("Low", value: $low, formatter: numberFormatter)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
            TextField("High", value: $high, formatter: numberFormatter)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
            Spacer()
        }
    }

    private var numberFormatter: NumberFormatter {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 2
        return fmt
    }
}

// MARK: - Guided Workflow

private enum GuidedFlow: String, CaseIterable, Identifiable {
    case thesisImport
    case weeklyUpdate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thesisImport: return "Thesis Import"
        case .weeklyUpdate: return "Weekly Update"
        }
    }
}

private enum ImportStep: Int, CaseIterable, Identifiable {
    case context
    case importPrompt
    case jsonValidation
    case draftReview
    case saveThesis

    var id: Int { rawValue }

    var spineTitle: String {
        switch self {
        case .context: return "Context"
        case .importPrompt: return "Import Prompt"
        case .jsonValidation: return "JSON Validation"
        case .draftReview: return "Draft Review"
        case .saveThesis: return "Save Thesis"
        }
    }

    var headerTitle: String {
        switch self {
        case .context: return "Context"
        case .importPrompt: return "Thesis Import Prompt"
        case .jsonValidation: return "JSON Validation"
        case .draftReview: return "Draft Review"
        case .saveThesis: return "Save Thesis"
        }
    }

    var typicalTime: String {
        switch self {
        case .context: return "~1 minute"
        case .importPrompt: return "~2 minutes"
        case .jsonValidation: return "~1 minute"
        case .draftReview: return "~3 minutes"
        case .saveThesis: return "~1 minute"
        }
    }
}

private enum WeeklyStep: Int, CaseIterable, Identifiable {
    case generatePrompt
    case runLLM
    case importPatch
    case applyReview

    var id: Int { rawValue }

    var spineTitle: String {
        switch self {
        case .generatePrompt: return "Generate Prompt"
        case .runLLM: return "Run LLM"
        case .importPatch: return "Import Patch"
        case .applyReview: return "Apply Review"
        }
    }

    var headerTitle: String {
        switch self {
        case .generatePrompt: return "Generate Weekly Review Prompt"
        case .runLLM: return "Combined Prompt"
        case .importPatch: return "Import Patch"
        case .applyReview: return "Apply Weekly Review"
        }
    }

    var typicalTime: String {
        switch self {
        case .generatePrompt: return "~1 minute"
        case .runLLM: return "~2 minutes"
        case .importPatch: return "~1 minute"
        case .applyReview: return "~1 minute"
        }
    }
}

private enum SpineStatus {
    case notStarted
    case active
    case completed
    case blocked

    var symbol: String {
        switch self {
        case .notStarted: return "○"
        case .active: return "◉"
        case .completed: return "✓"
        case .blocked: return "⚠"
        }
    }

    var symbolColor: Color {
        switch self {
        case .notStarted: return .secondary
        case .active: return .primary
        case .completed: return .green
        case .blocked: return .red
        }
    }

    var textColor: Color {
        switch self {
        case .notStarted: return .secondary
        case .active: return .primary
        case .completed: return .primary
        case .blocked: return .red
        }
    }
}

private struct ProcessSpineItem: Identifiable {
    let id: String
    let title: String
    let status: SpineStatus
    let isSelectable: Bool
    let help: String?
    let flow: GuidedFlow
    let importStep: ImportStep?
    let weeklyStep: WeeklyStep?
}

private struct ProcessSpineSection: Identifiable {
    let id: String
    let title: String
    let items: [ProcessSpineItem]
}

private struct WorkflowSidebarProgressView: View {
    @ObservedObject var workflow: GuidedWorkflowState
    @EnvironmentObject var store: ThesisStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if workflow.showStartScreen {
                ForEach(spineSections) { section in
                    Text(section.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Select a workflow to begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            } else {
                ForEach(spineSections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(section.items) { item in
                            Button {
                                workflow.select(item)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(item.status.symbol)
                                        .foregroundStyle(item.status.symbolColor)
                                        .frame(width: 16, alignment: .leading)
                                    Text(item.title)
                                        .foregroundStyle(item.status.textColor)
                                        .font(.subheadline)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!item.isSelectable)
                            .help(item.help ?? "")
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spineSections: [ProcessSpineSection] {
        var sections: [ProcessSpineSection] = []
        if workflow.showStartScreen {
            if workflow.availableFlows.contains(.thesisImport) {
                sections.append(ProcessSpineSection(
                    id: "import",
                    title: GuidedFlow.thesisImport.title,
                    items: []
                ))
            }
            if workflow.availableFlows.contains(.weeklyUpdate) {
                sections.append(ProcessSpineSection(
                    id: "weekly",
                    title: GuidedFlow.weeklyUpdate.title,
                    items: []
                ))
            }
            return sections
        }
        switch workflow.activeFlow {
        case .thesisImport:
            if workflow.availableFlows.contains(.thesisImport) {
                sections.append(ProcessSpineSection(
                    id: "import",
                    title: GuidedFlow.thesisImport.title,
                    items: importSpineItems
                ))
            }
        case .weeklyUpdate:
            if workflow.availableFlows.contains(.weeklyUpdate) {
                sections.append(ProcessSpineSection(
                    id: "weekly",
                    title: GuidedFlow.weeklyUpdate.title,
                    items: weeklySpineItems
                ))
            }
        }
        return sections
    }

    private var importSpineItems: [ProcessSpineItem] {
        let currentIndex = workflow.importStep.rawValue
        return ImportStep.allCases.map { step in
            let isSelectable = step.rawValue <= currentIndex
            let status = importStepStatus(step: step)
            return ProcessSpineItem(
                id: "import_\(step.rawValue)",
                title: step.spineTitle,
                status: status,
                isSelectable: isSelectable,
                help: status == .blocked ? importBlockedReason(for: step) : nil,
                flow: .thesisImport,
                importStep: step,
                weeklyStep: nil
            )
        }
    }

    private var weeklySpineItems: [ProcessSpineItem] {
        let currentIndex = workflow.weeklyStep.rawValue
        return WeeklyStep.allCases.map { step in
            let isSelectable = step.rawValue <= currentIndex
            let status = weeklyStepStatus(step: step)
            return ProcessSpineItem(
                id: "weekly_\(step.rawValue)",
                title: step.spineTitle,
                status: status,
                isSelectable: isSelectable,
                help: status == .blocked ? weeklyBlockedReason(for: step) : nil,
                flow: .weeklyUpdate,
                importStep: nil,
                weeklyStep: step
            )
        }
    }

    private func importStepStatus(step: ImportStep) -> SpineStatus {
        if workflow.activeFlow == .thesisImport, step == workflow.importStep { return .active }
        if step.rawValue < workflow.importStep.rawValue { return .completed }
        if !canSelectImportStep(step) { return .blocked }
        return .notStarted
    }

    private func weeklyStepStatus(step: WeeklyStep) -> SpineStatus {
        if workflow.activeFlow == .weeklyUpdate, step == workflow.weeklyStep { return .active }
        if step.rawValue < workflow.weeklyStep.rawValue { return .completed }
        if !canSelectWeeklyStep(step) { return .blocked }
        return .notStarted
    }

    private func canSelectImportStep(_ step: ImportStep) -> Bool {
        switch step {
        case .context, .importPrompt, .jsonValidation:
            return true
        case .draftReview, .saveThesis:
            return workflow.importValidation?.isGreen == true
        }
    }

    private func canSelectWeeklyStep(_ step: WeeklyStep) -> Bool {
        switch step {
        case .generatePrompt:
            return !store.theses.isEmpty
        case .runLLM, .importPatch:
            return !workflow.weeklyCombinedPrompt.isEmpty
        case .applyReview:
            return workflow.weeklyValidation?.isValid == true
        }
    }

    private func importBlockedReason(for step: ImportStep) -> String {
        switch step {
        case .draftReview:
            return "Validate thesis_import_v1 JSON to load the draft."
        case .saveThesis:
            return "JSON validation must pass before saving."
        default:
            return ""
        }
    }

    private func weeklyBlockedReason(for step: WeeklyStep) -> String {
        switch step {
        case .generatePrompt:
            return "Add a thesis before generating the weekly prompt."
        case .runLLM:
            return "Generate the combined prompt first."
        case .importPatch:
            return "Run the LLM and return with patch JSON."
        case .applyReview:
            return "Patch JSON must validate before applying."
        }
    }
}

private struct StepHeaderView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title2)
                .bold()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SystemStateBar: View {
    let message: String

    var body: some View {
        HStack {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Surface.tertiary)
    }
}

private struct PromptInspectorContext: Identifiable {
    let id = UUID()
    let title: String
    let source: String
    let key: String
    let version: String
    let body: String
}

private struct PromptInspectorSheet: View {
    let context: PromptInspectorContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prompt Inspector")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(context.title)
                    .font(.headline)
                Text("Source: \(context.source)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Key: \(context.key)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Version: \(context.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                Text(context.body)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(minHeight: 260)
            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            Spacer(minLength: 0)
        }
        .padding()
        .frame(minWidth: 700, minHeight: 520)
    }
}

private struct ThesisDraftPreviewSheet: View {
    let payload: ThesisImportPayload
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Draft Thesis Preview")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name: \(payload.name)")
                    Text("Tier: \(payload.tier.label)")
                    Text("Investment Role: \(payload.investmentRole)")
                    Text("Assumptions: \(payload.assumptions.count)")
                    Text("Kill Criteria: \(payload.killCriteria.count)")
                    Text("KPIs: \(payload.kpis.count)")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("North Star")
                        .font(.headline)
                    TextEditor(text: .constant(payload.northStar))
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                        .disabled(true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Non-goals")
                        .font(.headline)
                    TextEditor(text: .constant(payload.nonGoals))
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                        .disabled(true)
                }
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 560)
    }
}

private func missingFields(from errors: [String]) -> [String] {
    var fields: [String] = []
    for error in errors {
        if let range = error.range(of: "Missing key '") {
            let remainder = error[range.upperBound...]
            if let end = remainder.firstIndex(of: "'") {
                let field = String(remainder[..<end])
                if !fields.contains(field) {
                    fields.append(field)
                }
            }
        } else if let range = error.range(of: " is required") {
            let field = String(error[..<range.lowerBound])
            if !fields.contains(field) {
                fields.append(field)
            }
        }
    }
    return fields
}

private struct ImportValidationPanel: View {
    let validation: ThesisImportValidation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Validation")
                    .font(.headline)
                StatusPill(status: validation.status)
                Spacer()
                if !validation.errors.isEmpty {
                    Button("Copy Errors") {
                        copyToClipboard(errorText)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            if validation.errors.isEmpty {
                Text("JSON validated successfully.")
                    .foregroundStyle(.secondary)
            } else {
                let fields = missingFields(from: validation.errors)
                if !fields.isEmpty {
                    Text("Missing")
                        .font(.subheadline)
                    ForEach(fields, id: \.self) { field in
                        Text("• \(field)")
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("Errors")
                        .font(.subheadline)
                    ForEach(validation.errors, id: \.self) { error in
                        Text("• \(error)")
                            .foregroundStyle(.red)
                    }
                }
                Text("Impact: Draft thesis cannot be loaded until required fields are fixed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !validation.warnings.isEmpty {
                Text("Warnings")
                    .font(.subheadline)
                ForEach(validation.warnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
        .textSelection(.enabled)
    }

    private var errorText: String {
        validation.errors.joined(separator: "\n")
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

}

private final class GuidedWorkflowState: ObservableObject {
    let thesisId: String?
    let availableFlows: [GuidedFlow]

    @Published var activeFlow: GuidedFlow
    @Published var importStep: ImportStep
    @Published var weeklyStep: WeeklyStep
    @Published var importJson: String
    @Published var importJsonSource: JsonInputSource
    @Published var importJsonFileName: String?
    @Published var importFileError: String?
    @Published var showImportJsonImporter: Bool
    @Published var importValidation: ThesisImportValidation?
    @Published var importDraftPayload: ThesisImportPayload?
    @Published var importDraftConfirmed: Bool
    @Published var importSavedThesisName: String?
    @Published var selectedThesisId: String
    @Published var weeklyCombinedPrompt: String
    @Published var weeklyPromptGeneratedAt: Date?
    @Published var weeklyPatchJson: String
    @Published var weeklyPatchSource: JsonInputSource
    @Published var weeklyPatchFileName: String?
    @Published var weeklyFileError: String?
    @Published var showWeeklyPatchImporter: Bool
    @Published var weeklyValidation: PatchValidationResult?
    @Published var weeklyApplyMessage: String?
    @Published var showTemplateManager: Bool
    @Published var templateManagerKey: PromptTemplateKey
    @Published var showDraftPreview: Bool
    @Published var showDraftEditor: Bool
    @Published var promptInspector: PromptInspectorContext?
    @Published var showStartScreen: Bool

    init(
        thesisId: String?,
        availableFlows: [GuidedFlow],
        initialFlow: GuidedFlow? = nil,
        initialImportStep: ImportStep? = nil,
        initialWeeklyStep: WeeklyStep? = nil
    ) {
        self.thesisId = thesisId
        self.availableFlows = availableFlows
        activeFlow = initialFlow ?? availableFlows.first ?? .thesisImport
        importStep = initialImportStep ?? .context
        weeklyStep = initialWeeklyStep ?? .generatePrompt
        importJson = ""
        importJsonSource = .paste
        importJsonFileName = nil
        importFileError = nil
        showImportJsonImporter = false
        importValidation = nil
        importDraftPayload = nil
        importDraftConfirmed = false
        importSavedThesisName = nil
        selectedThesisId = thesisId ?? ""
        weeklyCombinedPrompt = ""
        weeklyPromptGeneratedAt = nil
        weeklyPatchJson = ""
        weeklyPatchSource = .paste
        weeklyPatchFileName = nil
        weeklyFileError = nil
        showWeeklyPatchImporter = false
        weeklyValidation = nil
        weeklyApplyMessage = nil
        showTemplateManager = false
        templateManagerKey = .weeklyReview
        showDraftPreview = false
        showDraftEditor = false
        promptInspector = nil
        let explicitStart = initialFlow != nil || initialImportStep != nil || initialWeeklyStep != nil
        showStartScreen = availableFlows.count > 1 && !explicitStart
    }

    func select(_ item: ProcessSpineItem) {
        showStartScreen = false
        activeFlow = item.flow
        if let step = item.importStep {
            importStep = step
        }
        if let step = item.weeklyStep {
            weeklyStep = step
        }
    }
}

private struct GuidedThesisWorkflowContainerView: View {
    @StateObject private var workflow: GuidedWorkflowState

    init(
        thesisId: String? = nil,
        availableFlows: [GuidedFlow] = GuidedFlow.allCases,
        initialFlow: GuidedFlow? = nil,
        initialImportStep: ImportStep? = nil,
        initialWeeklyStep: WeeklyStep? = nil
    ) {
        _workflow = StateObject(wrappedValue: GuidedWorkflowState(
            thesisId: thesisId,
            availableFlows: availableFlows,
            initialFlow: initialFlow,
            initialImportStep: initialImportStep,
            initialWeeklyStep: initialWeeklyStep
        ))
    }

    var body: some View {
        GuidedThesisWorkflowView(workflow: workflow)
    }
}

private struct GuidedThesisWorkflowView: View {
    @EnvironmentObject var store: ThesisStore
    @ObservedObject var workflow: GuidedWorkflowState

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                if workflow.showStartScreen {
                    StepHeaderView(title: "Choose Workflow", detail: "Select a workflow to begin")
                    ScrollView {
                        startScreenView
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        StepHeaderView(title: currentHeaderTitle, detail: currentHeaderDetail)
                        Spacer()
                        if workflow.availableFlows.count > 1 {
                            Button("Switch Workflow") {
                                workflow.showStartScreen = true
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                    ScrollView {
                        currentStepContent
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
            Divider()
            SystemStateBar(message: systemStateMessage)
        }
        .sheet(item: $workflow.promptInspector) { context in
            PromptInspectorSheet(context: context)
        }
        .sheet(isPresented: $workflow.showTemplateManager) {
            PromptTemplateManagerSheet(initialKey: workflow.templateManagerKey)
        }
        .sheet(isPresented: $workflow.showDraftPreview) {
            if let payload = workflow.importDraftPayload {
                ThesisDraftPreviewSheet(payload: payload)
            }
        }
        .sheet(isPresented: $workflow.showDraftEditor) {
            if let payload = workflow.importDraftPayload {
                ThesisEditorView(mode: .create, importPayload: payload) { thesis in
                    let created = store.createThesis(
                        name: thesis.name,
                        northStar: thesis.northStar,
                        investmentRole: thesis.investmentRole,
                        nonGoals: thesis.nonGoals,
                        tier: thesis.tier,
                        assumptions: thesis.assumptions,
                        killCriteria: thesis.killCriteria,
                        primaryKPIs: thesis.primaryKPIs,
                        secondaryKPIs: thesis.secondaryKPIs
                    )
                    workflow.importSavedThesisName = created.name
                    workflow.importDraftConfirmed = false
                    workflow.importStep = .saveThesis
                }
                .frame(minWidth: 760, minHeight: 620)
            }
        }
        .onAppear { configureDefaults() }
        .onChange(of: workflow.selectedThesisId) { _, _ in
            resetWeeklyStateForSelection()
        }
    }

    private var currentHeaderTitle: String {
        switch workflow.activeFlow {
        case .thesisImport:
            return workflow.importStep.headerTitle
        case .weeklyUpdate:
            return workflow.weeklyStep.headerTitle
        }
    }

    private var currentHeaderDetail: String {
        let index: Int
        let total: Int
        let time: String
        switch workflow.activeFlow {
        case .thesisImport:
            index = workflow.importStep.rawValue + 1
            total = ImportStep.allCases.count
            time = workflow.importStep.typicalTime
        case .weeklyUpdate:
            index = workflow.weeklyStep.rawValue + 1
            total = WeeklyStep.allCases.count
            time = workflow.weeklyStep.typicalTime
        }
        return "Step \(index) of \(total) - Typical time: \(time)"
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch workflow.activeFlow {
        case .thesisImport:
            switch workflow.importStep {
            case .context:
                importContextView
            case .importPrompt:
                importPromptView
            case .jsonValidation:
                importJsonValidationView
            case .draftReview:
                importDraftReviewView
            case .saveThesis:
                importSaveView
            }
        case .weeklyUpdate:
            switch workflow.weeklyStep {
            case .generatePrompt:
                weeklyGeneratePromptView
            case .runLLM:
                weeklyRunLLMView
            case .importPatch:
                weeklyImportPatchView
            case .applyReview:
                weeklyApplyReviewView
            }
        }
    }

    private var startScreenView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if workflow.availableFlows.contains(.thesisImport) {
                card {
                    Text("Thesis Import")
                        .font(.headline)
                    Text("Create a new thesis from LLM JSON and review the draft before saving.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1) Copy the import prompt")
                        Text("2) Run it externally")
                        Text("3) Validate JSON and review the draft")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    HStack {
                        Button("Start Thesis Import") {
                            startWorkflow(.thesisImport)
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
            }
            if workflow.availableFlows.contains(.weeklyUpdate) {
                card {
                    Text("Weekly Update")
                        .font(.headline)
                    Text("Generate the combined prompt, run the LLM, and apply the weekly patch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1) Generate combined prompt (A+B=C)")
                        Text("2) Run it externally")
                        Text("3) Validate and apply WeeklyReviewPatch v1")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    HStack {
                        Button("Start Weekly Update") {
                            startWorkflow(.weeklyUpdate)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.theses.isEmpty)
                        Spacer()
                    }
                }
            }
        }
    }

    private var importContextView: some View {
        VStack(alignment: .leading, spacing: 16) {
            card {
                Text("Create a new thesis from LLM JSON. The system validates against thesis_import_v1 before allowing any save.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("You will:")
                        .font(.subheadline)
                    Text("1. Copy the prompt\n2. Run it externally\n3. Paste or upload JSON for validation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Continue to Import Prompt") {
                workflow.importStep = .importPrompt
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var importPromptView: some View {
        let promptBody = store.thesisImportPrompt()
        return VStack(alignment: .leading, spacing: 16) {
            card {
                Text("Thesis Import Prompt")
                    .font(.headline)
                Text("Type: Stored global template")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Schema: thesis_import_v1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Version: \(importTemplateVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("View Prompt") {
                        workflow.promptInspector = PromptInspectorContext(
                            title: "Thesis Import Prompt",
                            source: "Global Template",
                            key: "thesis_import",
                            version: importTemplateVersion,
                            body: promptBody
                        )
                    }
                    .buttonStyle(.bordered)
                    Button("Copy") {
                        copyToClipboard(promptBody)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Manage Templates") {
                        workflow.templateManagerKey = .thesisImport
                        workflow.showTemplateManager = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            Button("Continue to JSON Validation") {
                workflow.importStep = .jsonValidation
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var importJsonValidationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            card {
                Text("JSON Input")
                    .font(.headline)
                Picker("Input", selection: $workflow.importJsonSource) {
                    ForEach(JsonInputSource.allCases) { source in
                        Text(source.label).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                if workflow.importJsonSource == .paste {
                    TextEditor(text: $workflow.importJson)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                } else {
                    HStack {
                        Button("Choose JSON File") { workflow.showImportJsonImporter = true }
                            .buttonStyle(.bordered)
                        if let importJsonFileName = workflow.importJsonFileName {
                            Text(importJsonFileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    if workflow.importJson.isEmpty {
                        Text("No file loaded yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextEditor(text: $workflow.importJson)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
                HStack {
                    Button("Validate") {
                        validateImportJson()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                if let importFileError = workflow.importFileError {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(importFileError)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                        Spacer()
                        Button("Copy Error") {
                            copyToClipboard(importFileError)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            if let validation = workflow.importValidation {
                ImportValidationPanel(validation: validation)
            }
            Button("Continue to Draft Review") {
                workflow.importStep = .draftReview
            }
            .buttonStyle(.bordered)
            .disabled(workflow.importValidation?.isGreen != true)
        }
        .onChange(of: workflow.importJsonSource) { _, newValue in
            if newValue == .paste {
                workflow.importJsonFileName = nil
            }
            workflow.importFileError = nil
        }
        .fileImporter(
            isPresented: $workflow.showImportJsonImporter,
            allowedContentTypes: allowedJsonTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportJsonFile(result)
        }
    }

    private var importDraftReviewView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if workflow.importValidation?.isGreen == true {
                Text("✓ JSON validated successfully")
                    .foregroundStyle(.green)
            } else {
                Text("⚠ Blocked")
                    .foregroundStyle(.red)
            }
            if workflow.importDraftPayload != nil {
                card {
                    Text("Thesis (Draft)")
                        .font(.headline)
                    Text("State: Unsaved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Source: thesis_import_v1 JSON")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Review") { workflow.showDraftPreview = true }
                            .buttonStyle(.bordered)
                        Button("Edit") { workflow.showDraftEditor = true }
                            .buttonStyle(.bordered)
                        Spacer()
                    }
                }
            } else {
                card {
                    Text("Draft review is blocked until JSON validation succeeds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Continue to Save Thesis") {
                workflow.importStep = .saveThesis
            }
            .buttonStyle(.bordered)
            .disabled(workflow.importDraftPayload == nil)
        }
    }

    private var importSaveView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let savedName = workflow.importSavedThesisName {
                Text("Saved: \(savedName)")
                    .foregroundStyle(.secondary)
            }
            if workflow.importDraftPayload == nil {
                card {
                    Text("Save is blocked until a valid draft exists.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                card {
                    Toggle("I have reviewed the draft and confirm it is ready to save.", isOn: $workflow.importDraftConfirmed)
                    HStack {
                        Button("Save Thesis") {
                            saveDraftThesis()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!workflow.importDraftConfirmed || workflow.importSavedThesisName != nil)
                        Button("Open Draft Editor") {
                            workflow.showDraftEditor = true
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
            }
        }
    }

    private var weeklyGeneratePromptView: some View {
        let templateBody = store.weeklyReviewPromptTemplate()
        let kpiPromptBody = activeKpiPrompt?.body ?? ""
        return VStack(alignment: .leading, spacing: 16) {
            if store.theses.isEmpty {
                card {
                    Text("No theses available. Create or import a thesis first.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                card {
                    Text("Thesis")
                        .font(.headline)
                    if workflow.thesisId == nil {
                        Picker("Thesis", selection: $workflow.selectedThesisId) {
                            ForEach(store.theses) { thesis in
                                Text(thesis.name).tag(thesis.id)
                            }
                        }
                        .pickerStyle(.menu)
                    } else if let thesis = selectedThesis {
                        Text(thesis.name)
                            .foregroundStyle(.primary)
                    } else {
                        Text("Thesis not found")
                            .foregroundStyle(.secondary)
                    }
                }
                card {
                    Text("Weekly Review Template (A)")
                        .font(.headline)
                    Text("Type: Global template")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Version: \(weeklyTemplateVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("View") {
                            workflow.promptInspector = PromptInspectorContext(
                                title: "Weekly Review Template (A)",
                                source: "Global Template",
                                key: "weekly_review",
                                version: weeklyTemplateVersion,
                                body: templateBody
                            )
                        }
                        .buttonStyle(.bordered)
                        Button("Copy") {
                            copyToClipboard(templateBody)
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button("Manage Templates") {
                            workflow.templateManagerKey = .weeklyReview
                            workflow.showTemplateManager = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                card {
                    Text("KPI Pack Prompt (B)")
                        .font(.headline)
                    Text("Type: Thesis-specific (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Version: \(kpiPromptVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if kpiPromptBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No active KPI pack prompt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("View") {
                            workflow.promptInspector = PromptInspectorContext(
                                title: "KPI Pack Prompt (B)",
                                source: "Thesis-specific",
                                key: "kpi_pack",
                                version: kpiPromptVersion,
                                body: kpiPromptBody
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(kpiPromptBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Copy") {
                            copyToClipboard(kpiPromptBody)
                        }
                        .buttonStyle(.bordered)
                        .disabled(kpiPromptBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                    }
                }
            }
            Button("Generate Combined Prompt") {
                generateCombinedPrompt()
                workflow.weeklyStep = .runLLM
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedThesis == nil)
        }
    }

    private var weeklyRunLLMView: some View {
        let generatedText = workflow.weeklyCombinedPrompt
        return VStack(alignment: .leading, spacing: 16) {
            if generatedText.isEmpty {
                card {
                    Text("Combined prompt not generated yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                card {
                    Text("Combined Weekly Prompt (C)")
                        .font(.headline)
                    Text("Type: Generated for this run")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Persisted: No")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let generatedAt = workflow.weeklyPromptGeneratedAt {
                        Text("Generated: \(dateText(generatedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("View") {
                            workflow.promptInspector = PromptInspectorContext(
                                title: "Combined Weekly Prompt (C)",
                                source: "Runtime",
                                key: "weekly_review_combined",
                                version: combinedPromptVersion,
                                body: generatedText
                            )
                        }
                        .buttonStyle(.bordered)
                        Button("Copy to Clipboard") {
                            copyToClipboard(generatedText)
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
                card {
                    Text("Run the combined prompt in your external LLM. Return with the patch JSON.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Continue to Import Patch") {
                workflow.weeklyStep = .importPatch
            }
            .buttonStyle(.bordered)
            .disabled(generatedText.isEmpty)
        }
    }

    private var weeklyImportPatchView: some View {
        VStack(alignment: .leading, spacing: 16) {
            card {
                Text("Patch JSON")
                    .font(.headline)
                Picker("Input", selection: $workflow.weeklyPatchSource) {
                    ForEach(JsonInputSource.allCases) { source in
                        Text(source.label).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                if workflow.weeklyPatchSource == .paste {
                    TextEditor(text: $workflow.weeklyPatchJson)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                } else {
                    HStack {
                        Button("Choose JSON File") { workflow.showWeeklyPatchImporter = true }
                            .buttonStyle(.bordered)
                        if let weeklyPatchFileName = workflow.weeklyPatchFileName {
                            Text(weeklyPatchFileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    if workflow.weeklyPatchJson.isEmpty {
                        Text("No file loaded yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextEditor(text: $workflow.weeklyPatchJson)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
                HStack {
                    Button("Validate") {
                        workflow.weeklyValidation = store.validatePatch(json: workflow.weeklyPatchJson)
                        workflow.weeklyApplyMessage = nil
                        workflow.weeklyFileError = nil
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                if let weeklyFileError = workflow.weeklyFileError {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(weeklyFileError)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                        Spacer()
                        Button("Copy Error") {
                            copyToClipboard(weeklyFileError)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            if let validation = workflow.weeklyValidation {
                ValidationResultView(result: validation)
                if !validation.errors.isEmpty {
                    Text("Impact: Weekly review cannot be applied until errors are fixed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Continue to Apply Review") {
                workflow.weeklyStep = .applyReview
            }
            .buttonStyle(.bordered)
            .disabled(workflow.weeklyValidation?.isValid != true)
        }
        .onChange(of: workflow.weeklyPatchSource) { _, newValue in
            if newValue == .paste {
                workflow.weeklyPatchFileName = nil
            }
            workflow.weeklyFileError = nil
        }
        .fileImporter(
            isPresented: $workflow.showWeeklyPatchImporter,
            allowedContentTypes: allowedJsonTypes,
            allowsMultipleSelection: false
        ) { result in
            handleWeeklyPatchFile(result)
        }
    }

    private var weeklyApplyReviewView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if workflow.weeklyValidation?.isValid == true {
                Text("✓ WeeklyReviewPatch v1 valid")
                    .foregroundStyle(.green)
            } else {
                Text("⚠ Blocked")
                    .foregroundStyle(.red)
            }
            card {
                HStack {
                    Button("Apply as Draft") { applyWeeklyPatch(finalize: false) }
                        .disabled(workflow.weeklyValidation?.isValid != true)
                    Button("Apply & Finalize") { applyWeeklyPatch(finalize: true) }
                        .disabled(workflow.weeklyValidation?.isValid != true)
                    Spacer()
                }
                if let weeklyApplyMessage = workflow.weeklyApplyMessage {
                    Text(weeklyApplyMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            card {
                Text("Effect:")
                    .font(.headline)
                Text("• Thesis preserved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• Incremental updates applied")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("• History extended")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importTemplateVersion: String {
        if let template = store.activePromptTemplate(for: .thesisImport) {
            return "v\(template.version) (active)"
        }
        return "default (active)"
    }

    private var weeklyTemplateVersion: String {
        if let template = store.activePromptTemplate(for: .weeklyReview) {
            return "v\(template.version) (active)"
        }
        return "default (active)"
    }

    private var activeKpiPrompt: ThesisKpiPrompt? {
        guard let thesisId = resolvedThesisId else { return nil }
        return store.activeThesisKpiPrompt(for: thesisId)
    }

    private var kpiPromptVersion: String {
        guard let activeKpiPrompt else { return "none" }
        return "v\(activeKpiPrompt.version) (active)"
    }

    private var combinedPromptVersion: String {
        var parts: [String] = []
        parts.append("A: \(weeklyTemplateVersion)")
        if kpiPromptVersion != "none" {
            parts.append("B: \(kpiPromptVersion)")
        }
        return parts.joined(separator: ", ")
    }

    private var resolvedThesisId: String? {
        let raw = workflow.thesisId ?? workflow.selectedThesisId
        return raw.isEmpty ? nil : raw
    }

    private var selectedThesis: Thesis? {
        guard let id = resolvedThesisId else { return nil }
        return store.thesis(id: id)
    }

    private var allowedJsonTypes: [UTType] {
        #if canImport(UniformTypeIdentifiers)
        return [UTType.json, UTType.text]
        #else
        return []
        #endif
    }

    private var systemStateMessage: String {
        if workflow.showStartScreen {
            return "READY - Choose a workflow to begin"
        }
        switch workflow.activeFlow {
        case .thesisImport:
            return importStateMessage
        case .weeklyUpdate:
            return weeklyStateMessage
        }
    }

    private var importStateMessage: String {
        if let savedName = workflow.importSavedThesisName {
            return "READY - Thesis saved as \(savedName)"
        }
        if let validation = workflow.importValidation {
            if !validation.errors.isEmpty {
                let missingCount = missingFields(from: validation.errors).count
                if missingCount > 0 {
                    return "VALIDATION BLOCKED - \(missingCount) required fields missing"
                }
                return "VALIDATION BLOCKED - \(validation.errors.first ?? "Fix validation errors")"
            }
            if validation.isGreen {
                return "READY - JSON validated successfully"
            }
        }
        return "READY - Paste or upload thesis import JSON to continue"
    }

    private var weeklyStateMessage: String {
        if store.theses.isEmpty {
            return "VALIDATION BLOCKED - No theses available for weekly review"
        }
        if let validation = workflow.weeklyValidation, !validation.errors.isEmpty {
            return "VALIDATION BLOCKED - \(validation.errors.first ?? "Patch invalid")"
        }
        if let weeklyApplyMessage = workflow.weeklyApplyMessage {
            return "READY - \(weeklyApplyMessage)"
        }
        if let validation = workflow.weeklyValidation, validation.isValid {
            return "READY - WeeklyReviewPatch v1 valid"
        }
        if !workflow.weeklyCombinedPrompt.isEmpty {
            return "READY - Combined weekly prompt generated successfully"
        }
        return "READY - Select a thesis to generate a weekly review prompt"
    }

    private func configureDefaults() {
        if !workflow.availableFlows.contains(workflow.activeFlow), let first = workflow.availableFlows.first {
            workflow.activeFlow = first
        }
        if workflow.selectedThesisId.isEmpty {
            workflow.selectedThesisId = workflow.thesisId ?? store.theses.first?.id ?? ""
        }
    }

    private func startWorkflow(_ flow: GuidedFlow) {
        workflow.activeFlow = flow
        workflow.showStartScreen = false
        switch flow {
        case .thesisImport:
            workflow.importStep = .context
        case .weeklyUpdate:
            workflow.weeklyStep = .generatePrompt
            resetWeeklyStateForSelection()
        }
    }

    private func resetWeeklyStateForSelection() {
        workflow.weeklyCombinedPrompt = ""
        workflow.weeklyPromptGeneratedAt = nil
        workflow.weeklyPatchJson = ""
        workflow.weeklyPatchFileName = nil
        workflow.weeklyFileError = nil
        workflow.weeklyValidation = nil
        workflow.weeklyApplyMessage = nil
        if workflow.weeklyStep.rawValue > WeeklyStep.generatePrompt.rawValue {
            workflow.weeklyStep = .generatePrompt
        }
    }

    private func handleImportJsonFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                guard let content = String(data: data, encoding: .utf8) else {
                    workflow.importFileError = "Unable to read file as UTF-8 text."
                    return
                }
                workflow.importJson = content
                workflow.importJsonFileName = url.lastPathComponent
                workflow.importFileError = nil
                validateImportJson()
            } catch {
                workflow.importFileError = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            workflow.importFileError = "File import failed: \(error.localizedDescription)"
        }
    }

    private func handleWeeklyPatchFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                guard let content = String(data: data, encoding: .utf8) else {
                    workflow.weeklyFileError = "Unable to read file as UTF-8 text."
                    return
                }
                workflow.weeklyPatchJson = content
                workflow.weeklyPatchFileName = url.lastPathComponent
                workflow.weeklyFileError = nil
                workflow.weeklyValidation = store.validatePatch(json: workflow.weeklyPatchJson)
                workflow.weeklyApplyMessage = nil
            } catch {
                workflow.weeklyFileError = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            workflow.weeklyFileError = "File import failed: \(error.localizedDescription)"
        }
    }

    private func validateImportJson() {
        let result = validateThesisImport(json: workflow.importJson)
        workflow.importValidation = result
        workflow.importSavedThesisName = nil
        workflow.importFileError = nil
        if result.isGreen {
            workflow.importDraftPayload = result.payload
            workflow.importDraftConfirmed = false
        } else {
            workflow.importDraftPayload = nil
        }
    }

    private func saveDraftThesis() {
        guard let payload = workflow.importDraftPayload else { return }
        let model = ThesisEditorModel(importPayload: payload)
        let thesis = model.buildThesis()
        let created = store.createThesis(
            name: thesis.name,
            northStar: thesis.northStar,
            investmentRole: thesis.investmentRole,
            nonGoals: thesis.nonGoals,
            tier: thesis.tier,
            assumptions: thesis.assumptions,
            killCriteria: thesis.killCriteria,
            primaryKPIs: thesis.primaryKPIs,
            secondaryKPIs: thesis.secondaryKPIs
        )
        workflow.importSavedThesisName = created.name
        workflow.importDraftConfirmed = false
    }

    private func generateCombinedPrompt() {
        guard let thesisId = resolvedThesisId else { return }
        workflow.weeklyCombinedPrompt = store.generatePrompt(thesisId: thesisId) ?? ""
        workflow.weeklyPromptGeneratedAt = Date()
        workflow.weeklyPatchJson = ""
        workflow.weeklyPatchFileName = nil
        workflow.weeklyFileError = nil
        workflow.weeklyValidation = nil
        workflow.weeklyApplyMessage = nil
    }

    private func applyWeeklyPatch(finalize: Bool) {
        let result = store.applyPatch(json: workflow.weeklyPatchJson, finalize: finalize)
        workflow.weeklyValidation = result.validation
        if result.isDuplicate {
            workflow.weeklyApplyMessage = "Patch already applied"
            return
        }
        if let review = result.review {
            workflow.weeklyApplyMessage = finalize ? "Imported and finalized \(review.week.stringValue)" : "Imported as draft \(review.week.stringValue)"
        } else if let firstError = result.validation.errors.first {
            workflow.weeklyApplyMessage = "Failed: \(firstError)"
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - LLM Prompt / Import

private struct PromptTemplateManagerSheet: View {
    @EnvironmentObject var store: ThesisStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKey: PromptTemplateKey
    @State private var draftBody: String = ""
    @State private var includeRanges = PromptTemplateSettings.weeklyReviewDefault.includeRanges
    @State private var includeLastReview = PromptTemplateSettings.weeklyReviewDefault.includeLastReview
    @State private var historyWindow = PromptTemplateSettings.weeklyReviewDefault.historyWindow
    @State private var message: String?

    init(initialKey: PromptTemplateKey = .weeklyReview) {
        _selectedKey = State(initialValue: initialKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prompt Templates")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Exit") { dismiss() }
                    .buttonStyle(.bordered)
            }
            Picker("Template", selection: $selectedKey) {
                ForEach(PromptTemplateKey.allCases) { key in
                    Text(key.label).tag(key)
                }
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Draft")
                    .font(.headline)
                TextEditor(text: $draftBody)
                    .frame(minHeight: 220)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                if selectedKey == .weeklyReview {
                    HStack(spacing: 12) {
                        Toggle("KPI defs", isOn: $includeRanges)
                        Toggle("Last review", isOn: $includeLastReview)
                        Stepper("History \(historyWindow)w", value: $historyWindow, in: 1...52)
                    }
                }
                HStack {
                    Button("Save New Version (Activate)") { saveNewVersion() }
                        .buttonStyle(.borderedProminent)
                    Button("Reset to Active") { loadFromActive() }
                        .buttonStyle(.bordered)
                    Button("Copy Draft") { copyToClipboard(draftBody) }
                        .buttonStyle(.bordered)
                    Spacer()
                    if let message {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))

            VStack(alignment: .leading, spacing: 8) {
                Text("Versions")
                    .font(.headline)
                if templates.isEmpty {
                    Text("No templates yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { template in
                        PromptTemplateRow(
                            template: template,
                            onLoad: { loadFromTemplate(template) },
                            onActivate: { activate(template) },
                            onArchive: { archive(template) }
                        )
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
            Spacer(minLength: 0)
        }
        .padding()
        .onAppear { loadFromActive() }
        .onChange(of: selectedKey) { _, _ in loadFromActive() }
    }

    private var templates: [PromptTemplate] {
        store.promptTemplates(for: selectedKey)
    }

    private func loadFromActive() {
        if let active = store.activePromptTemplate(for: selectedKey) {
            loadFromTemplate(active)
            return
        }
        draftBody = selectedKey == .thesisImport
            ? store.thesisImportPrompt()
            : store.weeklyReviewPromptTemplate()
        applySettings(nil)
    }

    private func loadFromTemplate(_ template: PromptTemplate) {
        draftBody = template.body
        applySettings(template.settings)
    }

    private func applySettings(_ settings: PromptTemplateSettings?) {
        guard selectedKey == .weeklyReview else { return }
        let resolved = settings ?? PromptTemplateSettings.weeklyReviewDefault
        includeRanges = resolved.includeRanges
        includeLastReview = resolved.includeLastReview
        historyWindow = resolved.historyWindow
    }

    private func saveNewVersion() {
        let settings = selectedKey == .weeklyReview
            ? PromptTemplateSettings(
                includeRanges: includeRanges,
                includeLastReview: includeLastReview,
                historyWindow: historyWindow
            )
            : nil
        let result = store.createPromptTemplateVersion(key: selectedKey, body: draftBody, settings: settings)
        message = resultMessage(result)
        if case .success(let created) = result {
            loadFromTemplate(created)
        }
    }

    private func activate(_ template: PromptTemplate) {
        let result = store.activatePromptTemplate(id: template.id)
        message = resultMessage(result)
        if case .success = result {
            loadFromActive()
        }
    }

    private func archive(_ template: PromptTemplate) {
        let result = store.archivePromptTemplate(id: template.id)
        message = resultMessage(result)
    }

    private func resultMessage(_ result: Result<PromptTemplate, PromptTemplateError>) -> String {
        switch result {
        case .success(let template):
            return "Active: \(template.key.label) v\(template.version)"
        case .failure(let error):
            return errorMessage(for: error)
        }
    }

    private func errorMessage(for error: PromptTemplateError) -> String {
        switch error {
        case .databaseUnavailable:
            return "Database unavailable"
        case .readOnly:
            return "Database is read-only"
        case .emptyBody:
            return "Template body is empty"
        case .invalidKey:
            return "Template not found"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

private struct PromptTemplateRow: View {
    let template: PromptTemplate
    let onLoad: () -> Void
    let onActivate: () -> Void
    let onArchive: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("v\(template.version)")
                .font(.subheadline)
            Text(template.status.rawValue.uppercased())
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
            Text(dateText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Load") { onLoad() }
                .buttonStyle(.bordered)
            Button("Activate") { onActivate() }
                .buttonStyle(.bordered)
                .disabled(template.status == .active)
            Button("Archive") { onArchive() }
                .buttonStyle(.bordered)
                .disabled(template.status == .active || template.status == .archived)
        }
    }

    private var statusColor: Color {
        switch template.status {
        case .active: return .green
        case .inactive: return .orange
        case .archived: return .gray
        }
    }

    private var dateText: String {
        let date = template.updatedAt ?? template.createdAt
        guard let date else { return "n/a" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct PromptGeneratorPanel: View {
    @EnvironmentObject var store: ThesisStore
    @Environment(\.dismiss) private var dismiss
    var thesisId: String? = nil
    var showClose: Bool = false
    @State private var selectedThesisId: String = ""
    @State private var output: String = ""
    @State private var showTemplateManager = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Generate LLM Prompt")
                    .font(.title3)
                    .bold()
                Spacer()
                Button("Manage Templates") { showTemplateManager = true }
                    .buttonStyle(.bordered)
                if showClose {
                    Button("Exit") { dismiss() }
                        .buttonStyle(.bordered)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Active Template")
                    .font(.headline)
                Text(activeTemplateSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Placeholders: {{THESIS_ID}}, {{THESIS_NAME}}, {{THESIS_TIER}}, {{THESIS_NORTH_STAR}}, {{THESIS_INVESTMENT_ROLE}}, {{THESIS_NON_GOALS}}, {{THESIS_ASSUMPTIONS}}, {{THESIS_KILL_CRITERIA}}, {{KPI_DEFINITIONS_BLOCK}}, {{KPI_PACK_PROMPT_BLOCK}}, {{WEEKLY_REVIEW_PATCH_SCHEMA}}, {{REVIEW_HISTORY_BLOCK}}, {{LAST_REVIEW_BLOCK}}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Picker("Thesis", selection: Binding<String>(
                    get: { selectedThesisId },
                    set: { id in
                        selectedThesisId = id
                        output = store.generatePrompt(thesisId: id) ?? ""
                    })
                ) {
                    ForEach(store.theses) { thesis in
                        Text(thesis.name).tag(thesis.id)
                    }
                }
                .pickerStyle(.menu)
            }
            Button("Generate") {
                let target = selectedThesisId.isEmpty ? (thesisId ?? store.theses.first?.id) : selectedThesisId
                output = target.flatMap { store.generatePrompt(thesisId: $0) } ?? ""
            }
            .buttonStyle(.borderedProminent)
            TextEditor(text: $output)
                .frame(minHeight: 200)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            HStack {
                Button("Copy to Clipboard") {
                    copyToClipboard(output)
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding()
        .onAppear {
            if selectedThesisId.isEmpty {
                selectedThesisId = thesisId ?? store.theses.first?.id ?? ""
            }
            if output.isEmpty, !selectedThesisId.isEmpty {
                output = store.generatePrompt(thesisId: selectedThesisId) ?? ""
            }
        }
        .sheet(isPresented: $showTemplateManager) {
            PromptTemplateManagerSheet(initialKey: .weeklyReview)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
    }

    private var activeTemplateSummary: String {
        let template = store.activePromptTemplate(for: .weeklyReview)
        let versionText = template.map { "v\($0.version)" } ?? "default"
        let updatedText = template.flatMap { dateText($0.updatedAt ?? $0.createdAt) } ?? "n/a"
        let settings = store.promptTemplateSettings(for: .weeklyReview)
        return "\(versionText) | history \(settings.historyWindow)w | KPI defs \(settings.includeRanges ? "on" : "off") | last review \(settings.includeLastReview ? "on" : "off") | updated \(updatedText)"
    }

    private func dateText(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

private struct LLMImportPanel: View {
    @EnvironmentObject var store: ThesisStore
    var thesisId: String? = nil
    @State private var jsonText: String = ""
    @State private var validation: PatchValidationResult?
    @State private var applyMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Import LLM Output (WeeklyReviewPatch v1)")
                .font(.title3)
                .bold()
            TextEditor(text: $jsonText)
                .frame(minHeight: 180)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            HStack {
                Button("Validate") {
                    validation = store.validatePatch(json: jsonText)
                    applyMessage = nil
                }
                .buttonStyle(.borderedProminent)
                Button("Apply as Draft") { apply(finalize: false) }
                    .disabled(!isValidPatch)
                Button("Apply & Finalize") { apply(finalize: true) }
                    .disabled(!isValidPatch)
            }
            if let validation {
                ValidationResultView(result: validation)
            }
            if let applyMessage {
                Text(applyMessage)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Surface.secondary))
    }

    private var isValidPatch: Bool {
        validation?.errors.isEmpty == true
    }

    private func apply(finalize: Bool) {
        let result = store.applyPatch(json: jsonText, finalize: finalize)
        validation = result.validation
        if result.isDuplicate {
            applyMessage = "Patch already applied"
            return
        }
        if let review = result.review {
            applyMessage = finalize ? "Imported and finalized \(review.week.stringValue)" : "Imported as draft \(review.week.stringValue)"
        } else if let firstError = result.validation.errors.first {
            applyMessage = "Failed: \(firstError)"
        }
    }
}

private struct ValidationResultView: View {
    let result: PatchValidationResult
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Validation Results")
                    .font(.headline)
                Spacer()
                if !result.errors.isEmpty {
                    Button("Copy Errors") {
                        copyToClipboard(errorText)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            if result.errors.isEmpty {
                Text("✓ schema ok")
                    .foregroundStyle(.green)
            } else {
                ForEach(result.errors, id: \.self) { err in
                    Text("✗ \(err)")
                        .foregroundStyle(.red)
                }
            }
            ForEach(result.warnings, id: \.self) { warn in
                Text("⚠︎ \(warn)")
                    .foregroundStyle(.orange)
            }
            if !result.diff.isEmpty {
                Text("Diff Preview")
                    .font(.subheadline)
                    .bold()
                ForEach(result.diff, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Surface.tertiary))
        .textSelection(.enabled)
    }

    private var errorText: String {
        result.errors.joined(separator: "\n")
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
