import Foundation
import SwiftUI

struct ReleaseNotesView: View {
    let version: String

    @Environment(\.dismiss) private var dismiss
    @State private var result: ReleaseNotesLoadResult?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                header
                content
                footer
            }
            .padding(DSLayout.spaceL)
        }
        .frame(minWidth: 760, minHeight: 520)
        .onAppear(perform: load)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Release Notes")
                .dsHeaderSmall()
            if let section = result?.section {
                Text(sectionHeader(for: section))
                    .dsCaption()
            } else {
                Text("Version \(version)")
                    .dsCaption()
            }
            if let source = result?.sourceLabel {
                Text(source)
                    .dsCaption()
            }
            if let note = result?.note {
                Text(note)
                    .dsCaption()
            }
        }
    }

    private var content: some View {
        Group {
            if let errorMessage {
                Text(errorMessage)
                    .dsBody()
                    .foregroundColor(DSColor.accentError)
            } else if let section = result?.section {
                if section.entries.isEmpty {
                    Text("No changes recorded for this release.")
                        .dsBody()
                } else {
                    Table(section.entries) {
                        TableColumn("Category") { entry in
                            let highlighted = isHighlighted(entry)
                            Text(entry.category)
                                .dsBodySmall()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(highlighted ? DSColor.surfaceHighlight : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                        }
                        TableColumn("Change") { entry in
                            let highlighted = isHighlighted(entry)
                            HStack(spacing: 8) {
                                Text(entry.description)
                                    .dsBody()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                if highlighted {
                                    LatestBadge()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(highlighted ? DSColor.surfaceHighlight : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                        }
                    }
                    .frame(minHeight: 320)
                }
            } else {
                ProgressView("Loading release notes...")
                    .progressViewStyle(.circular)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(role: .cancel) { dismiss() } label: {
                Label("Close", systemImage: "xmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.gray)
            .foregroundColor(.white)
            .keyboardShortcut("w", modifiers: .command)
        }
    }

    private func load() {
        switch ReleaseNotesProvider.load(for: version) {
        case .success(let data):
            result = data
            errorMessage = nil
        case .failure(let error):
            result = nil
            errorMessage = error.localizedDescription
        }
    }

    private func sectionHeader(for section: ReleaseNotesSection) -> String {
        if let date = section.date, !date.isEmpty {
            return "Version \(section.version) - \(date)"
        }
        return "Version \(section.version)"
    }

    private func isHighlighted(_ entry: ReleaseNotesEntry) -> Bool {
        highlightedEntryIds.contains(entry.id)
    }

    private var highlightedEntryIds: Set<UUID> {
        guard let entries = result?.section.entries, !entries.isEmpty else { return [] }
        let tokens = extractTokens(from: GitInfoProvider.lastChangeSummary)
        if !tokens.isEmpty {
            let matches = entries.filter { entry in
                tokens.contains { token in entry.description.localizedCaseInsensitiveContains(token) }
            }
            if !matches.isEmpty {
                return Set(matches.map(\.id))
            }
        }

        var seenCategories = Set<String>()
        var ids: [UUID] = []
        for entry in entries {
            if seenCategories.contains(entry.category) { continue }
            seenCategories.insert(entry.category)
            ids.append(entry.id)
        }
        return Set(ids)
    }

    private func extractTokens(from summary: String?) -> [String] {
        guard let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var tokens: [String] = []
        tokens.append(contentsOf: matches(pattern: "\\bDS-\\d+\\b", in: summary))
        tokens.append(contentsOf: matches(pattern: "#\\d+\\b", in: summary))
        return Array(Set(tokens))
    }

    private func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}

private struct LatestBadge: View {
    var body: some View {
        Text("Latest")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DSColor.surfaceSecondary)
            .foregroundStyle(DSColor.textSecondary)
            .clipShape(Capsule())
    }
}
