import Foundation

struct ReleaseNotesEntry: Identifiable {
    let id = UUID()
    let category: String
    let description: String
    let referenceId: String?
    let implementationDate: String?
}

struct ReleaseNotesSection {
    let version: String
    let date: String?
    let entries: [ReleaseNotesEntry]
}

struct ReleaseNotesLoadResult {
    let sections: [ReleaseNotesSection]
    let sourceLabel: String
    let note: String?
}

enum ReleaseNotesProviderError: LocalizedError {
    case changelogNotFound
    case versionNotFound(String)

    var errorDescription: String? {
        switch self {
        case .changelogNotFound:
        return "CHANGELOG.md not found. Add it to the app bundle or run from the repository root."
        case .versionNotFound(let version):
            return "No release notes found for version \(version)."
        }
    }
}

enum ReleaseNotesProvider {
    static func loadAll() -> Result<ReleaseNotesLoadResult, ReleaseNotesProviderError> {
        guard let (text, sourceLabel) = loadChangelogText() else {
            return .failure(.changelogNotFound)
        }
        let sections = parse(text)
        return .success(ReleaseNotesLoadResult(sections: sections, sourceLabel: sourceLabel, note: nil))
    }

    static func load(for version: String) -> Result<ReleaseNotesLoadResult, ReleaseNotesProviderError> {
        guard let (text, sourceLabel) = loadChangelogText() else {
            return .failure(.changelogNotFound)
        }
        let sections = parse(text)
        let target = normalizeVersion(version)

        let isUnknown = target.isEmpty || target.lowercased() == "n/a"

        if !isUnknown, let section = sections.first(where: { matches($0.version, target: target) }) {
            return .success(ReleaseNotesLoadResult(sections: [section], sourceLabel: sourceLabel, note: nil))
        }

        if let section = sections.first(where: { normalizeVersion($0.version).lowercased() == "unreleased" }) {
            let note: String? = isUnknown
                ? "Showing Unreleased because the app version is unavailable."
                : "Showing Unreleased because version \(version) was not found in CHANGELOG.md."
            return .success(ReleaseNotesLoadResult(sections: [section], sourceLabel: sourceLabel, note: note))
        }

        return .failure(.versionNotFound(version))
    }

    private static func loadChangelogText() -> (String, String)? {
        if let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return (text, "CHANGELOG.md (bundle)")
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates: [(URL, String)] = [
            (cwd.appendingPathComponent("CHANGELOG.md"), "CHANGELOG.md (cwd)"),
            (cwd.appendingPathComponent("Archive/CHANGELOG-ARCHIVE.md"), "Archive/CHANGELOG-ARCHIVE.md (cwd)")
        ]

        for (url, label) in candidates {
            if FileManager.default.fileExists(atPath: url.path),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return (text, label)
            }
        }

        return nil
    }

    private static func parse(_ text: String) -> [ReleaseNotesSection] {
        var sections: [ReleaseNotesSection] = []
        var currentVersion: String?
        var currentDate: String?
        var currentCategory: String?
        var entries: [ReleaseNotesEntry] = []

        func flush() {
            guard let version = currentVersion else { return }
            sections.append(ReleaseNotesSection(version: version, date: currentDate, entries: entries))
            entries = []
        }

        let lines = text.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flush()
                currentCategory = nil
                let header = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let parsed = parseHeader(header)
                currentVersion = parsed.version
                currentDate = parsed.date
                continue
            }

            if line.hasPrefix("### ") {
                currentCategory = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard line.hasPrefix("- ") || line.hasPrefix("* ") else { continue }
            guard let category = currentCategory else { continue }
            let desc = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            guard !desc.isEmpty else { continue }
            guard let entry = parseEntry(category: category, rawDescription: desc) else { continue }
            entries.append(entry)
        }

        flush()
        return sections
    }

    private static func parseHeader(_ header: String) -> (version: String, date: String?) {
        var versionPart = header
        var datePart: String? = nil

        if let range = header.range(of: " - ") {
            versionPart = String(header[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            datePart = String(header[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        if versionPart.hasPrefix("[") && versionPart.hasSuffix("]") {
            versionPart = String(versionPart.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }

        return (version: versionPart, date: datePart)
    }

    private static func matches(_ version: String, target: String) -> Bool {
        normalizeVersion(version).lowercased() == normalizeVersion(target).lowercased()
    }

    private static func parseEntry(category: String, rawDescription: String) -> ReleaseNotesEntry? {
        var description = rawDescription
        let referenceId = extractReferenceId(from: description)
        if let referenceId {
            description = stripReferenceId(referenceId, from: description)
        }
        let implementationDate = extractImplementationDate(from: description)
        if implementationDate != nil {
            description = stripImplementationDate(from: description)
        }
        description = cleanupDescription(description)
        guard !description.isEmpty else { return nil }
        return ReleaseNotesEntry(
            category: category,
            description: description,
            referenceId: referenceId,
            implementationDate: implementationDate
        )
    }

    private static func extractReferenceId(from text: String) -> String? {
        firstMatch(pattern: "\\bDS-\\d+\\b", in: text, options: [.caseInsensitive])
    }

    private static func extractImplementationDate(from text: String) -> String? {
        firstCapture(
            pattern: "\\bimplemented\\s*[:\\-]?\\s*(\\d{4}-\\d{2}-\\d{2})\\b",
            in: text,
            options: [.caseInsensitive]
        )
    }

    private static func stripReferenceId(_ referenceId: String, from text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: referenceId)
        var stripped = text
        stripped = replacing(pattern: "\\[\\s*\(escaped)\\s*\\]", in: stripped, options: [.caseInsensitive])
        stripped = replacing(pattern: "\\b\(escaped)\\b", in: stripped, options: [.caseInsensitive])
        return stripped
    }

    private static func stripImplementationDate(from text: String) -> String {
        replacing(
            pattern: "\\s*\\(?\\bimplemented\\s*[:\\-]?\\s*\\d{4}-\\d{2}-\\d{2}\\b\\)?\\s*",
            in: text,
            options: [.caseInsensitive]
        )
    }

    private static func cleanupDescription(_ text: String) -> String {
        var cleaned = replacing(pattern: "\\s+", in: text, options: [])
        cleaned = replacing(pattern: "\\(\\s*\\)", in: cleaned, options: [])
        cleaned = replacing(pattern: "\\s+", in: cleaned, options: [])
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range, in: text) else { return nil }
        return String(text[matchRange])
    }

    private static func firstCapture(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let matchRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[matchRange])
    }

    private static func replacing(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ")
    }

    private static func normalizeVersion(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            trimmed = String(trimmed.dropFirst().dropLast())
        }
        if trimmed.lowercased().hasPrefix("version ") {
            trimmed = String(trimmed.dropFirst("version ".count))
        }
        if trimmed.lowercased().hasPrefix("v") {
            trimmed = String(trimmed.dropFirst())
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
