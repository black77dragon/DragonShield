import SwiftUI

struct ThesisDefinitionEditorView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    let existingDefinition: ThesisDefinition?
    let definitionId: Int?

    @State private var name: String = ""
    @State private var summary: String = ""
    @State private var drivers: [ThesisDriverDefinition] = []
    @State private var risks: [ThesisRiskDefinition] = []
    @State private var sections: [ThesisSection] = []
    @State private var bulletsBySection: [Int: [ThesisBullet]] = [:]
    @State private var nextTempSectionId: Int = -1
    @State private var loadedDefinitionId: Int? = nil
    @State private var loadedScoringRules: String? = nil
    @State private var isDirty: Bool = false
    @State private var showUnsavedAlert: Bool = false
    @State private var errorMessage: String?

    init(definition: ThesisDefinition? = nil, definitionId: Int? = nil) {
        self.existingDefinition = definition
        self.definitionId = definitionId ?? definition?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(existingDefinition == nil ? "New Thesis Definition" : "Edit Thesis Definition")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(title: "Core", helper: "Name the thesis and capture the core narrative or summary.")
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Name", text: Binding(
                            get: { name },
                            set: { name = $0; markDirty() }
                        ))
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: Binding(
                            get: { summary },
                            set: { summary = $0; markDirty() }
                        ))
                            .frame(minHeight: 120)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.borderStrong))
                    }

                    sectionHeader(title: "Sections", helper: "Add structured thesis sections with headlines and bullets.")
                    if sections.isEmpty {
                        Text("No sections yet.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(sections.indices, id: \.self) { index in
                        sectionEditor(index: index)
                    }
                    Button("Add Section") { addSection() }
                        .buttonStyle(DSButtonStyle(type: .secondary, size: .small))

                    sectionHeader(title: "Drivers", helper: "Define the key drivers to assess weekly (A–E or any list).")
                    if drivers.isEmpty {
                        Text("No drivers defined.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(drivers.indices, id: \.self) { index in
                        driverEditor(index: index)
                    }
                    Button("Add Driver") { addDriver() }
                        .buttonStyle(DSButtonStyle(type: .secondary, size: .small))

                    sectionHeader(title: "Risks", helper: "List the main risks and how they worsen, improve, or are mitigated.")
                    if risks.isEmpty {
                        Text("No risks defined.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(risks.indices, id: \.self) { index in
                        riskEditor(index: index)
                    }
                    Button("Add Risk") { addRisk() }
                        .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
            .frame(maxHeight: .infinity, alignment: .top)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { attemptDismiss() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                Button("Save") { saveDefinition() }
                    .buttonStyle(DSButtonStyle(type: .primary, size: .small))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 640)
        .onAppear(perform: load)
        .onChange(of: definitionId) { _, _ in load() }
        .interactiveDismissDisabled(isDirty)
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
            Button("Save") { saveDefinition() }
            Button("Discard Changes", role: .destructive) {
                isDirty = false
                dismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Do you want to save them before closing?")
        }
    }

    private func sectionHeader(title: String, helper: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(helper)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func load() {
        let resolvedDefinition: ThesisDefinition?
        if let id = definitionId {
            resolvedDefinition = dbManager.fetchThesisDefinition(id: id) ?? existingDefinition
        } else {
            resolvedDefinition = existingDefinition
        }

        if let definition = resolvedDefinition {
            loadedDefinitionId = definition.id
            loadedScoringRules = definition.defaultScoringRules
            name = definition.name
            summary = definition.summaryCoreThesis ?? ""
            drivers = dbManager.listThesisDrivers(thesisDefId: definition.id)
            risks = dbManager.listThesisRisks(thesisDefId: definition.id)
            sections = dbManager.listThesisSections(thesisDefId: definition.id)
            bulletsBySection = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, dbManager.listThesisBullets(sectionId: $0.id)) })
            nextTempSectionId = -1
        } else {
            loadedDefinitionId = nil
            loadedScoringRules = nil
            name = ""
            summary = ""
            drivers = []
            risks = []
            sections = []
            bulletsBySection = [:]
            nextTempSectionId = -1
        }
        isDirty = false
        errorMessage = nil
    }

    private func saveDefinition() {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ThesisDefinition.isValidName(trimmedName) else {
            errorMessage = "Name is required (max 120 chars)."
            return
        }

        let resolvedExistingId = loadedDefinitionId ?? definitionId ?? existingDefinition?.id
        let savedDefinitionId: Int
        if let existingId = resolvedExistingId {
            let ok = dbManager.updateThesisDefinition(id: existingId, name: trimmedName, summary: summary.trimmingCharacters(in: .whitespacesAndNewlines), scoringRules: loadedScoringRules ?? existingDefinition?.defaultScoringRules)
            if !ok {
                errorMessage = "Failed to update thesis definition."
                return
            }
            savedDefinitionId = existingId
        } else {
            guard let created = dbManager.createThesisDefinition(name: trimmedName, summary: summary.trimmingCharacters(in: .whitespacesAndNewlines), scoringRules: nil) else {
                errorMessage = "Failed to create thesis definition."
                return
            }
            savedDefinitionId = created.id
        }

        guard persistDrivers(thesisDefId: savedDefinitionId),
              persistRisks(thesisDefId: savedDefinitionId),
              persistSections(thesisDefId: savedDefinitionId) else {
            errorMessage = "Failed to save thesis content."
            return
        }

        isDirty = false
        dismiss()
    }

    private func persistDrivers(thesisDefId: Int) -> Bool {
        let existing = dbManager.listThesisDrivers(thesisDefId: thesisDefId)
        let existingIds = Set(existing.map { $0.id })
        var incomingIds: Set<Int> = []
        var sortOrder = 0
        for var driver in drivers {
            let trimmedName = driver.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty { continue }
            driver.name = trimmedName
            driver.thesisDefId = thesisDefId
            driver.sortOrder = sortOrder
            guard let saved = dbManager.upsertThesisDriver(driver) else { return false }
            incomingIds.insert(saved.id)
            sortOrder += 1
        }
        let remove = existingIds.subtracting(incomingIds)
        for id in remove {
            if !dbManager.deleteThesisDriver(id: id) { return false }
        }
        return true
    }

    private func persistRisks(thesisDefId: Int) -> Bool {
        let existing = dbManager.listThesisRisks(thesisDefId: thesisDefId)
        let existingIds = Set(existing.map { $0.id })
        var incomingIds: Set<Int> = []
        var sortOrder = 0
        for var risk in risks {
            let trimmedName = risk.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty { continue }
            risk.name = trimmedName
            risk.thesisDefId = thesisDefId
            risk.sortOrder = sortOrder
            guard let saved = dbManager.upsertThesisRisk(risk) else { return false }
            incomingIds.insert(saved.id)
            sortOrder += 1
        }
        let remove = existingIds.subtracting(incomingIds)
        for id in remove {
            if !dbManager.deleteThesisRisk(id: id) { return false }
        }
        return true
    }

    private func persistSections(thesisDefId: Int) -> Bool {
        let existing = dbManager.listThesisSections(thesisDefId: thesisDefId)
        let existingIds = Set(existing.map { $0.id })
        var incomingIds: Set<Int> = []
        var sortOrder = 0

        for section in sections {
            let originalId = section.id
            let headline = section.headline.trimmingCharacters(in: .whitespacesAndNewlines)
            if headline.isEmpty { continue }
            let description = section.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedDescription = (description?.isEmpty ?? true) ? nil : description
            let sectionToSave = ThesisSection(
                id: section.id <= 0 ? 0 : section.id,
                thesisDefId: thesisDefId,
                sortOrder: sortOrder,
                headline: headline,
                description: normalizedDescription,
                ragDefault: section.ragDefault,
                scoreDefault: section.scoreDefault
            )
            guard let savedSection = dbManager.upsertThesisSection(sectionToSave) else { return false }
            incomingIds.insert(savedSection.id)
            if !persistBullets(sectionId: savedSection.id, bullets: bulletsBySection[originalId] ?? []) { return false }
            sortOrder += 1
        }

        let remove = existingIds.subtracting(incomingIds)
        for id in remove {
            _ = dbManager.deleteThesisSection(id: id)
        }
        return true
    }

    private func persistBullets(sectionId: Int, bullets: [ThesisBullet]) -> Bool {
        if !dbManager.deleteThesisBullets(sectionId: sectionId) { return false }
        var sortOrder = 0
        for bullet in bullets {
            let text = bullet.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            let bulletToSave = ThesisBullet(
                id: 0,
                sectionId: sectionId,
                sortOrder: sortOrder,
                text: text,
                type: bullet.type,
                linkedMetrics: bullet.linkedMetrics,
                linkedEvidence: bullet.linkedEvidence
            )
            guard dbManager.upsertThesisBullet(bulletToSave) != nil else { return false }
            sortOrder += 1
        }
        return true
    }

    private func addSection() {
        let tempId = nextTempSectionId
        nextTempSectionId -= 1
        let section = ThesisSection(id: tempId, thesisDefId: loadedDefinitionId ?? definitionId ?? existingDefinition?.id ?? 0, sortOrder: sections.count, headline: "", description: nil, ragDefault: nil, scoreDefault: nil)
        sections.append(section)
        bulletsBySection[section.id] = []
        markDirty()
    }

    private func addDriver() {
        let nextCode = String(format: "%c", 65 + drivers.count)
        let driver = ThesisDriverDefinition(id: 0, thesisDefId: loadedDefinitionId ?? definitionId ?? existingDefinition?.id ?? 0, code: nextCode, name: "", definition: nil, reviewQuestion: nil, weight: nil, sortOrder: drivers.count)
        drivers.append(driver)
        markDirty()
    }

    private func addRisk() {
        let risk = ThesisRiskDefinition(id: 0, thesisDefId: loadedDefinitionId ?? definitionId ?? existingDefinition?.id ?? 0, name: "", category: "market", whatWorsens: nil, whatImproves: nil, mitigations: nil, weight: nil, sortOrder: risks.count)
        risks.append(risk)
        markDirty()
    }

    private func sectionEditor(index: Int) -> some View {
        let binding = Binding(
            get: { sections[index] },
            set: { sections[index] = $0; markDirty() }
        )
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Headline", text: binding.headline)
                    .textFieldStyle(.roundedBorder)
                Button("Remove") { removeSection(at: index) }
                    .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
            }
            TextEditor(text: Binding(
                get: { binding.description.wrappedValue ?? "" },
                set: { binding.description.wrappedValue = $0 }
            ))
            .frame(minHeight: 80)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DSColor.borderStrong))

            VStack(alignment: .leading, spacing: 6) {
                Text("Bullets")
                    .font(.caption)
                    .foregroundColor(.secondary)
                let bullets = bulletsBySection[sections[index].id] ?? []
                ForEach(bullets.indices, id: \.self) { bulletIndex in
                    bulletEditor(sectionIndex: index, bulletIndex: bulletIndex)
                }
                Button("Add Bullet") { addBullet(to: index) }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
        }
        .padding(8)
        .background(DSColor.surface)
        .cornerRadius(8)
    }

    private func bulletEditor(sectionIndex: Int, bulletIndex: Int) -> some View {
        let sectionId = sections[sectionIndex].id
        let bullets = bulletsBinding(for: sectionId)
        let bulletBinding = Binding(
            get: { bullets.wrappedValue[bulletIndex] },
            set: { bullets.wrappedValue[bulletIndex] = $0; markDirty() }
        )
        return HStack {
            TextField("Bullet text", text: bulletBinding.text)
                .textFieldStyle(.roundedBorder)
            Picker("Type", selection: bulletBinding.type) {
                ForEach(ThesisBulletType.allCases, id: \.self) { item in
                    Text(item.rawValue.capitalized).tag(item)
                }
            }
            .labelsHidden()
            .frame(width: 140)
            Button("Remove") { removeBullet(sectionIndex: sectionIndex, bulletIndex: bulletIndex) }
                .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
        }
    }

    private func driverEditor(index: Int) -> some View {
        let binding = Binding(
            get: { drivers[index] },
            set: { drivers[index] = $0; markDirty() }
        )
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Code", text: binding.code)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                TextField("Name", text: binding.name)
                    .textFieldStyle(.roundedBorder)
                TextField("Weight", text: Binding(
                    get: { binding.weight.wrappedValue.map { String(format: "%.2f", $0) } ?? "" },
                    set: { binding.weight.wrappedValue = Double($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                Button("Remove") {
                    drivers.remove(at: index)
                    markDirty()
                }
                .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
            }
            TextField("Definition", text: Binding(
                get: { binding.definition.wrappedValue ?? "" },
                set: { binding.definition.wrappedValue = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            TextField("Review question", text: Binding(
                get: { binding.reviewQuestion.wrappedValue ?? "" },
                set: { binding.reviewQuestion.wrappedValue = $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .padding(8)
        .background(DSColor.surface)
        .cornerRadius(8)
    }

    private func riskEditor(index: Int) -> some View {
        let binding = Binding(
            get: { risks[index] },
            set: { risks[index] = $0; markDirty() }
        )
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Name", text: binding.name)
                    .textFieldStyle(.roundedBorder)
                TextField("Category", text: binding.category)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                TextField("Weight", text: Binding(
                    get: { binding.weight.wrappedValue.map { String(format: "%.2f", $0) } ?? "" },
                    set: { binding.weight.wrappedValue = Double($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                Button("Remove") {
                    risks.remove(at: index)
                    markDirty()
                }
                .buttonStyle(DSButtonStyle(type: .ghost, size: .small))
            }
            TextField("What worsens", text: Binding(
                get: { binding.whatWorsens.wrappedValue ?? "" },
                set: { binding.whatWorsens.wrappedValue = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            TextField("What improves", text: Binding(
                get: { binding.whatImproves.wrappedValue ?? "" },
                set: { binding.whatImproves.wrappedValue = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            TextField("Mitigations", text: Binding(
                get: { binding.mitigations.wrappedValue ?? "" },
                set: { binding.mitigations.wrappedValue = $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .padding(8)
        .background(DSColor.surface)
        .cornerRadius(8)
    }

    private func removeSection(at index: Int) {
        let sectionId = sections[index].id
        bulletsBySection.removeValue(forKey: sectionId)
        sections.remove(at: index)
        markDirty()
    }

    private func addBullet(to sectionIndex: Int) {
        let sectionId = sections[sectionIndex].id
        var bullets = bulletsBySection[sectionId] ?? []
        bullets.append(ThesisBullet(id: 0, sectionId: sectionId, sortOrder: bullets.count, text: "", type: .claim, linkedMetrics: [], linkedEvidence: []))
        bulletsBySection[sectionId] = bullets
        markDirty()
    }

    private func removeBullet(sectionIndex: Int, bulletIndex: Int) {
        let sectionId = sections[sectionIndex].id
        var bullets = bulletsBySection[sectionId] ?? []
        guard bullets.indices.contains(bulletIndex) else { return }
        bullets.remove(at: bulletIndex)
        bulletsBySection[sectionId] = bullets
        markDirty()
    }

    private func bulletsBinding(for sectionId: Int) -> Binding<[ThesisBullet]> {
        Binding(
            get: { bulletsBySection[sectionId] ?? [] },
            set: { bulletsBySection[sectionId] = $0; markDirty() }
        )
    }

    private func attemptDismiss() {
        if isDirty {
            showUnsavedAlert = true
        } else {
            dismiss()
        }
    }

    private func markDirty() {
        if !isDirty {
            isDirty = true
        }
    }
}
