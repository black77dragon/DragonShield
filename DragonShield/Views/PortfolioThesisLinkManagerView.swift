import SwiftUI

struct PortfolioThesisLinkManagerView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    let themeId: Int

    private struct ThesisEditorContext: Identifiable {
        let id = UUID()
        let definition: ThesisDefinition?
        let definitionId: Int?
    }

    @State private var links: [PortfolioThesisLinkRow] = []
    @State private var definitions: [ThesisDefinition] = []
    @State private var selectedDefinitionId: Int = 0
    @State private var thesisEditorContext: ThesisEditorContext? = nil
    @State private var showExposureEditor = false
    @State private var exposureContext: PortfolioThesisLinkRow? = nil
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Thesis Links")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            linkSection
            definitionSection

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                Button("Save") { saveLinks() }
                    .buttonStyle(DSButtonStyle(type: .primary, size: .small))
            }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 520)
        .onAppear(perform: load)
        .sheet(item: $thesisEditorContext, onDismiss: load) { context in
            ThesisDefinitionEditorView(definition: context.definition, definitionId: context.definitionId)
                .environmentObject(dbManager)
        }
        .sheet(isPresented: $showExposureEditor, onDismiss: load) {
            if let context = exposureContext {
                ThesisExposureRuleEditorView(portfolioThesisId: context.link.id, thesisName: context.thesisName)
                    .environmentObject(dbManager)
            }
        }
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linked theses")
                .font(.headline)
            if links.isEmpty {
                Text("No linked theses yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach($links) { $row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(row.thesisName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Toggle("Primary", isOn: Binding(
                                get: { row.link.isPrimary },
                                set: { newValue in
                                    if newValue { setPrimary(row.link.id) }
                                    row.link.isPrimary = newValue
                                }
                            ))
                            .toggleStyle(.switch)
                            Button("Edit") { openDefinitionEditor(thesisDefId: row.link.thesisDefId) }
                                .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                            Button("Exposure Rules") { openExposureEditor(row) }
                                .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                            Button("Unlink") { removeLink(row.link.id) }
                                .buttonStyle(DSButtonStyle(type: .destructive, size: .small))
                        }
                        HStack(spacing: 12) {
                            Picker("Status", selection: Binding(
                                get: { row.link.status },
                                set: { row.link.status = $0 }
                            )) {
                                ForEach(ThesisLinkStatus.allCases, id: \.self) { status in
                                    Text(status.rawValue.capitalized).tag(status)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                            TextField("Review frequency", text: Binding(
                                get: { row.link.reviewFrequency },
                                set: { row.link.reviewFrequency = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            TextField("Notes", text: Binding(
                                get: { row.link.notes ?? "" },
                                set: { row.link.notes = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        if let summary = row.thesisSummary, !summary.isEmpty {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(DSColor.surfaceSubtle)
                    .cornerRadius(8)
                }
            }
            HStack(spacing: 12) {
                Picker("Add thesis", selection: $selectedDefinitionId) {
                    Text("Select...").tag(0)
                    ForEach(availableDefinitions) { definition in
                        Text(definition.name).tag(definition.id)
                    }
                }
                .frame(width: 240)
                Button("Link Thesis") { addLink() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
        }
    }

    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Definitions")
                .font(.headline)
            HStack(spacing: 12) {
                Button("Create Definition") { openDefinitionEditor(thesisDefId: nil) }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                Button("Refresh") { load() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }
        }
    }

    private var availableDefinitions: [ThesisDefinition] {
        let linked = Set(links.map { $0.link.thesisDefId })
        return definitions.filter { !linked.contains($0.id) }
    }

    private func load() {
        errorMessage = nil
        definitions = dbManager.listThesisDefinitions()
        let details = dbManager.listPortfolioThesisLinkDetails(themeId: themeId)
        links = details.map { PortfolioThesisLinkRow(link: $0.link, thesisName: $0.thesisName, thesisSummary: $0.thesisSummary) }
        if let first = availableDefinitions.first {
            selectedDefinitionId = first.id
        } else {
            selectedDefinitionId = 0
        }
    }

    private func addLink() {
        guard selectedDefinitionId != 0 else { return }
        if dbManager.createPortfolioThesisLink(themeId: themeId, thesisDefId: selectedDefinitionId) != nil {
            load()
        } else {
            errorMessage = "Failed to link thesis."
        }
    }

    private func removeLink(_ id: Int) {
        if dbManager.deletePortfolioThesisLink(id: id) {
            load()
        } else {
            errorMessage = "Failed to unlink thesis."
        }
    }

    private func saveLinks() {
        errorMessage = nil
        for row in links {
            if !dbManager.updatePortfolioThesisLink(row.link) {
                errorMessage = "Failed to save thesis links."
                return
            }
        }
        load()
        dismiss()
    }

    private func setPrimary(_ id: Int) {
        for index in links.indices {
            links[index].link.isPrimary = links[index].link.id == id
        }
    }

    private func openDefinitionEditor(thesisDefId: Int?) {
        let definition = thesisDefId.flatMap { id in
            definitions.first { $0.id == id } ?? dbManager.fetchThesisDefinition(id: id)
        }
        thesisEditorContext = ThesisEditorContext(definition: definition, definitionId: thesisDefId ?? definition?.id)
    }

    private func openExposureEditor(_ row: PortfolioThesisLinkRow) {
        exposureContext = row
        showExposureEditor = true
    }
}

private struct PortfolioThesisLinkRow: Identifiable {
    var link: PortfolioThesisLink
    let thesisName: String
    let thesisSummary: String?

    var id: Int { link.id }
}
