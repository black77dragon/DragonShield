import SwiftUI

struct ThesisDefinitionDetailView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @Environment(\.dismiss) private var dismiss

    let thesisDefId: Int

    @State private var definition: ThesisDefinition?
    @State private var sections: [ThesisSection] = []
    @State private var bulletsBySection: [Int: [ThesisBullet]] = [:]
    @State private var drivers: [ThesisDriverDefinition] = []
    @State private var risks: [ThesisRiskDefinition] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(definition?.name ?? "Thesis")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let summary = definition?.summaryCoreThesis, !summary.isEmpty {
                        DSCard(padding: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Core Thesis")
                                    .font(.headline)
                                Text(summary)
                                    .font(.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !sections.isEmpty {
                        DSCard(padding: 12) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Sections")
                                    .font(.headline)
                                ForEach(sections) { section in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(section.headline)
                                            .font(.subheadline.weight(.semibold))
                                        if let description = section.description, !description.isEmpty {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        let bullets = bulletsBySection[section.id] ?? []
                                        ForEach(bullets) { bullet in
                                            HStack(alignment: .top, spacing: 8) {
                                                Text(bullet.type.rawValue.capitalized)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 70, alignment: .leading)
                                                Text(bullet.text)
                                                    .font(.body)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !drivers.isEmpty {
                        DSCard(padding: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Drivers")
                                    .font(.headline)
                                ForEach(drivers) { driver in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(driver.code) • \(driver.name)")
                                            .font(.subheadline.weight(.semibold))
                                        if let definition = driver.definition, !definition.isEmpty {
                                            Text(definition)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let question = driver.reviewQuestion, !question.isEmpty {
                                            Text("Q: \(question)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !risks.isEmpty {
                        DSCard(padding: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Risks")
                                    .font(.headline)
                                ForEach(risks) { risk in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(risk.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(risk.category.capitalized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let worsens = risk.whatWorsens, !worsens.isEmpty {
                                            Text("Worsens: \(worsens)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let improves = risk.whatImproves, !improves.isEmpty {
                                            Text("Improves: \(improves)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let mitigations = risk.mitigations, !mitigations.isEmpty {
                                            Text("Mitigations: \(mitigations)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 640)
        .onAppear(perform: load)
    }

    private func load() {
        definition = dbManager.fetchThesisDefinition(id: thesisDefId)
        sections = dbManager.listThesisSections(thesisDefId: thesisDefId)
        bulletsBySection = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, dbManager.listThesisBullets(sectionId: $0.id)) })
        drivers = dbManager.listThesisDrivers(thesisDefId: thesisDefId)
        risks = dbManager.listThesisRisks(thesisDefId: thesisDefId)
    }
}
