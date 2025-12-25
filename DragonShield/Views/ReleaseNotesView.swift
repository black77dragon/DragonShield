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
            if let latestLabel = latestReleaseLabel {
                Text(latestLabel)
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
            } else if let result, rows.isEmpty {
                Text("No changes recorded for this release.")
                    .dsBody()
            } else if result != nil {
                Table(rows) {
                    TableColumn("Category") { row in
                        let highlighted = isHighlighted(row.entry)
                        Text(row.entry.category)
                            .dsBodySmall()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(rowBackground(row: row, highlighted: highlighted))
                            .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                    }
                    TableColumn("Change") { row in
                        let highlighted = isHighlighted(row.entry)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(row.entry.description)
                                    .dsBody()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                if highlighted {
                                    LatestBadge()
                                }
                            }
                            if let metadata = metadataLine(for: row.entry) {
                                Text(metadata)
                                    .dsCaption()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(rowBackground(row: row, highlighted: highlighted))
                        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                    }
                    TableColumn("Release") { row in
                        let highlighted = isHighlighted(row.entry)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.releaseVersion)
                                .dsBodySmall()
                            if let releaseDate = row.releaseDate, !releaseDate.isEmpty {
                                Text(releaseDate)
                                    .dsCaption()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(rowBackground(row: row, highlighted: highlighted))
                        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                    }
                }
                .frame(minHeight: 320)
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
        switch ReleaseNotesProvider.loadAll() {
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
        let entries = rows.map(\.entry)
        guard !entries.isEmpty else { return [] }
        let tokens = extractTokens(from: GitInfoProvider.lastChangeSummary)
        if !tokens.isEmpty {
            let matches = entries.filter { entry in
                tokens.contains { token in
                    if let referenceId = entry.referenceId,
                       referenceId.localizedCaseInsensitiveCompare(token) == .orderedSame {
                        return true
                    }
                    return entry.description.localizedCaseInsensitiveContains(token)
                }
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

    private func metadataLine(for entry: ReleaseNotesEntry) -> String? {
        var parts: [String] = []
        if let referenceId = entry.referenceId, !referenceId.isEmpty {
            parts.append("Ref \(referenceId)")
        }
        if let implementationDate = entry.implementationDate, !implementationDate.isEmpty {
            parts.append("Implemented \(implementationDate)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }

    private func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private var latestReleaseLabel: String? {
        guard let section = latestReleaseSection else { return nil }
        return "Latest release: \(sectionHeader(for: section))"
    }

    private var latestReleaseSection: ReleaseNotesSection? {
        guard let sections = result?.sections, !sections.isEmpty else { return nil }
        let datedSections = sections.compactMap { section -> (ReleaseNotesSection, Date)? in
            guard let date = parseReleaseDate(section.date) else { return nil }
            return (section, date)
        }
        if let latest = datedSections.max(by: { $0.1 < $1.1 }) {
            return latest.0
        }
        return sections.first
    }

    private var rows: [ReleaseNotesRow] {
        guard let sections = result?.sections else { return [] }
        var rows: [ReleaseNotesRow] = []
        for (sectionIndex, section) in sections.enumerated() {
            let releaseDateValue = parseReleaseDate(section.date)
            let isUnreleased = section.version.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "unreleased"
            for (entryIndex, entry) in section.entries.enumerated() {
                rows.append(
                    ReleaseNotesRow(
                        id: entry.id,
                        entry: entry,
                        releaseVersion: section.version,
                        releaseDate: section.date,
                        releaseDateValue: releaseDateValue,
                        sectionIndex: sectionIndex,
                        entryIndex: entryIndex,
                        isUnreleased: isUnreleased
                    )
                )
            }
        }
        return rows.sorted { lhs, rhs in
            let lhsDate = sortDate(for: lhs)
            let rhsDate = sortDate(for: rhs)
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            if lhs.sectionIndex != rhs.sectionIndex { return lhs.sectionIndex < rhs.sectionIndex }
            return lhs.entryIndex < rhs.entryIndex
        }
    }

    private func sortDate(for row: ReleaseNotesRow) -> Date {
        if row.isUnreleased { return Date.distantFuture }
        return row.releaseDateValue ?? Date.distantPast
    }

    private func rowBackground(row: ReleaseNotesRow, highlighted: Bool) -> Color {
        if row.isUnreleased {
            return unreleasedBackground
        }
        if isLatestRelease(row: row) {
            return latestReleaseBackground
        }
        if highlighted {
            return DSColor.surfaceHighlight
        }
        return Color.clear
    }

    private func isLatestRelease(row: ReleaseNotesRow) -> Bool {
        guard let latest = latestReleaseDate else { return false }
        guard let rowDate = row.releaseDateValue else { return false }
        return rowDate == latest
    }

    private var latestReleaseDate: Date? {
        guard let sections = result?.sections else { return nil }
        return sections.compactMap { parseReleaseDate($0.date) }.max()
    }

    private func parseReleaseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return Self.releaseDateFormatter.date(from: value)
    }

    private static let releaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var latestReleaseBackground: Color {
        Color(red: 230.0 / 255.0, green: 242.0 / 255.0, blue: 1.0)
    }

    private var unreleasedBackground: Color {
        Color.yellow.opacity(0.15)
    }
}

private struct ReleaseNotesRow: Identifiable {
    let id: UUID
    let entry: ReleaseNotesEntry
    let releaseVersion: String
    let releaseDate: String?
    let releaseDateValue: Date?
    let sectionIndex: Int
    let entryIndex: Int
    let isUnreleased: Bool
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
