import SwiftUI

struct RiskManagementMaintenanceView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var mappings: [DatabaseManager.RiskMappingItem] = []
    @State private var unmapped: [DatabaseManager.SubClassOption] = []
    @State private var defaults: DatabaseManager.RiskConfigDefaults = .init(fallbackSRI: 5, fallbackLiquidityTier: 1, mappingVersion: "risk_map_v1")

    @State private var showEditSheet = false
    @State private var editingMapping: DatabaseManager.RiskMappingItem?
    @State private var formSubClassId: Int = 0
    @State private var formSRI: Int = 5
    @State private var formLiquidityTier: Int = 1
    @State private var formRationale: String = ""

    @State private var statusMessage: String?
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: DatabaseManager.RiskMappingItem?
    @State private var infoDefaults = false
    @State private var infoMapped = false
    @State private var sheetContext: SheetContext?
    private let riskColors: [Color] = [
        Color.green.opacity(0.7),
        Color.green,
        Color.yellow,
        Color.orange,
        Color.orange.opacity(0.85),
        Color.red.opacity(0.9),
        Color.red
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                defaultsSection
                mappingsSection
                unmappedSection
                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .onAppear(perform: loadData)
        .sheet(item: $sheetContext) { ctx in
            mappingEditorSheet(context: ctx)
        }
        .alert("Delete mapping?", isPresented: $showDeleteConfirm, presenting: deleteTarget) { item in
            Button("Delete", role: .destructive) { deleteMapping(item) }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("Remove risk defaults for \(item.code) — \(item.name)? Instruments will fall back to global defaults until a new mapping is added.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Risk Management Maintenance")
                    .font(.title2).bold()
                Text("Manage risk mappings, defaults, and overrides governance.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Refresh", action: loadData)
        }
    }

    private var defaultsSection: some View {
        sectionCard(title: "Unmapped Defaults", subtitle: "Applied to instrument types without an explicit mapping.", info: "Defaults also act as fallback if mapping tables are missing in a snapshot.", showInfo: $infoDefaults) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Stepper("Default SRI: \(defaults.fallbackSRI)", value: $defaults.fallbackSRI, in: 1 ... 7)
                    Spacer()
                    Picker("Default Liquidity", selection: $defaults.fallbackLiquidityTier) {
                        Text("Liquid").tag(0)
                        Text("Restricted").tag(1)
                        Text("Illiquid").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 320)
                    .help("Liquidity tier used when no mapping exists (0=Liquid, 1=Restricted, 2=Illiquid).")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mapping version tag").font(.footnote).foregroundColor(.secondary)
                    TextField("risk_map_v1", text: $defaults.mappingVersion)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 220)
                        .help("Version string stored with computed profiles to trace which mapping produced the values.")
                }
                Button("Save Defaults", action: saveDefaults)
                    .buttonStyle(DSButtonStyle(type: .primary, size: .small))
            }
        }
    }

    private var mappingsSection: some View {
        sectionCard(title: "Mapped Instrument Types", subtitle: "Default SRI and liquidity per instrument type.", info: "Edits apply to new and existing instruments (recalc).", showInfo: $infoMapped) {
            if mappings.isEmpty {
                Text("No mappings yet. Add one from the unmapped list below.")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(mappings) { item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.code) — \(item.name)")
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    riskBadge(item.defaultSRI)
                                    Text("SRI \(item.defaultSRI)")
                                    Text("• \(liquidityLabel(item.defaultLiquidityTier)) • v\(item.mappingVersion)")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                Text(shortSRIText(item.defaultSRI))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                if !item.rationale.isEmpty {
                                    Text(item.rationale)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Button("Edit") { startEditing(item) }
                                Button("Delete", role: .destructive) {
                                    deleteTarget = item
                                    showDeleteConfirm = true
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
        }
    }

    private var unmappedSection: some View {
        sectionCard(title: "Unmapped Instrument Types", subtitle: "Types missing a mapping. Add defaults to remove fallbacks.") {
            if unmapped.isEmpty {
                Text("All instrument types are mapped.")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(unmapped) { type in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(type.code) — \(type.name)")
                                Text("Currently uses unmapped defaults").font(.footnote).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Add Mapping") {
                                startNewMapping(for: type)
                            }
                            .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func mappingEditorSheet(context: SheetContext) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(context.title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Instrument Type:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(context.displayName)")
                        .fontWeight(.bold)
                }

                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Defaults")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Stepper("SRI: \(formSRI)", value: $formSRI, in: 1 ... 7)
                    HStack(spacing: 8) {
                        riskBadge(formSRI)
                        Text(shortSRIText(formSRI))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    Picker("Liquidity", selection: $formLiquidityTier) {
                        Text("Liquid").tag(0)
                        Text("Restricted").tag(1)
                        Text("Illiquid").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    Text("These values become the computed baseline for all instruments of this type.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rationale (optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextEditor(text: $formRationale)
                        .frame(minHeight: 80)
                        .help("Short note to explain why this type is mapped to the given SRI/liquidity tier.")
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DSColor.border, lineWidth: 1)
                        )
                }
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    sheetContext = nil
                }
                Button("Save") { saveMapping() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(formSubClassId == 0)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 420)
    }

    // MARK: - Actions

    private func loadData() {
        defaults = dbManager.fetchRiskConfigDefaults()
        mappings = dbManager.fetchRiskMappings()
        unmapped = dbManager.fetchUnmappedSubClasses()
    }

    private func saveDefaults() {
        let ok = dbManager.updateRiskConfigDefaults(
            fallbackSRI: defaults.fallbackSRI,
            fallbackLiquidityTier: defaults.fallbackLiquidityTier,
            mappingVersion: defaults.mappingVersion
        )
        statusMessage = ok ? "Defaults saved" : "Failed to save defaults"
    }

    private func startNewMapping(for type: DatabaseManager.SubClassOption) {
        editingMapping = nil
        formSubClassId = type.id
        formSRI = defaults.fallbackSRI
        formLiquidityTier = defaults.fallbackLiquidityTier
        formRationale = ""
        sheetContext = .new(type)
    }

    private func startEditing(_ item: DatabaseManager.RiskMappingItem) {
        editingMapping = item
        formSubClassId = item.id
        formSRI = item.defaultSRI
        formLiquidityTier = item.defaultLiquidityTier
        formRationale = item.rationale
        sheetContext = .edit(item)
    }

    private func saveMapping() {
        let ok = dbManager.upsertRiskMapping(
            subClassId: formSubClassId,
            defaultSRI: formSRI,
            defaultLiquidityTier: formLiquidityTier,
            rationale: formRationale.trimmingCharacters(in: .whitespacesAndNewlines),
            mappingVersion: defaults.mappingVersion
        )
        statusMessage = ok ? "Mapping saved" : "Failed to save mapping"
        if ok {
            sheetContext = nil
            showEditSheet = false
            loadData()
        }
    }

    private func deleteMapping(_ item: DatabaseManager.RiskMappingItem) {
        let ok = dbManager.deleteRiskMapping(subClassId: item.id)
        statusMessage = ok ? "Mapping deleted" : "Failed to delete mapping"
        loadData()
    }

    private func sectionCard<Content: View>(title: String, subtitle: String? = nil, info: String? = nil, showInfo: Binding<Bool>? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                if let info {
                    HoverInfoIcon(text: info, isPresented: showInfo ?? .constant(false))
                }
                Spacer()
            }
            content()
        }
        .padding()
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSLayout.radiusM))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.radiusM)
                .stroke(DSColor.border, lineWidth: 1)
        )
    }

    private func liquidityLabel(_ tier: Int) -> String {
        switch tier {
        case 0: return "Liquid"
        case 1: return "Restricted"
        default: return "Illiquid"
        }
    }

    private func shortSRIText(_ value: Int) -> String {
        switch value {
        case 1: return "Very low risk: cash-like."
        case 2: return "Low risk: short-duration, high quality."
        case 3: return "Low–medium risk: IG credit / balanced."
        case 4: return "Medium risk: diversified equity beta."
        case 5: return "Medium–high risk: concentrated/EM/commods."
        case 6: return "High risk: volatile, leverage or complex."
        case 7: return "Very high risk: speculative / extreme moves."
        default: return "Risk category"
        }
    }

    @ViewBuilder
    private func riskBadge(_ value: Int) -> some View {
        if value >= 1 && value <= 7 {
            Text("SRI \(value)")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(riskColors[value - 1])
                .foregroundColor(.white)
                .clipShape(Capsule())
        } else {
            EmptyView()
        }
    }
}

private enum SheetContext: Identifiable {
    case new(DatabaseManager.SubClassOption)
    case edit(DatabaseManager.RiskMappingItem)

    var id: String {
        switch self {
        case .new(let opt): return "new-\(opt.id)"
        case .edit(let item): return "edit-\(item.id)"
        }
    }

    var displayName: String {
        switch self {
        case .new(let opt): return "\(opt.code) — \(opt.name)"
        case .edit(let item): return "\(item.code) — \(item.name)"
        }
    }

    var title: String {
        switch self {
        case .new: return "Add Risk Mapping"
        case .edit: return "Edit Risk Mapping"
        }
    }
}

private struct HoverInfoIcon: View {
    let text: String
    @Binding var isPresented: Bool

    var body: some View {
        Image(systemName: "info.circle")
            .foregroundColor(.secondary)
            .padding(.leading, 4)
            .onHover { hover in isPresented = hover }
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                Text(text)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .padding(12)
                    .frame(minWidth: 200, alignment: .leading)
            }
    }
}

// MARK: - Preview

struct RiskManagementMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        RiskManagementMaintenanceView()
            .environmentObject(DatabaseManager())
    }
}
