import Foundation

struct ReleaseNotesEntry: Identifiable {
    let id = UUID()
    let category: String
    let description: String
}

struct ReleaseNotesSection {
    let version: String
    let date: String?
    let entries: [ReleaseNotesEntry]
}

struct ReleaseNotesLoadResult {
    let section: ReleaseNotesSection
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
    static func load(for version: String) -> Result<ReleaseNotesLoadResult, ReleaseNotesProviderError> {
        guard let (text, sourceLabel) = loadChangelogText() else {
            return .failure(.changelogNotFound)
        }
        let sections = parse(text)
        let target = normalizeVersion(version)

        let isUnknown = target.isEmpty || target.lowercased() == "n/a"

        if !isUnknown, let section = sections.first(where: { matches($0.version, target: target) }) {
            return .success(ReleaseNotesLoadResult(section: section, sourceLabel: sourceLabel, note: nil))
        }

        if let section = sections.first(where: { normalizeVersion($0.version).lowercased() == "unreleased" }) {
            let note: String? = isUnknown
                ? "Showing Unreleased because the app version is unavailable."
                : "Showing Unreleased because version \(version) was not found in CHANGELOG.md."
            return .success(ReleaseNotesLoadResult(section: section, sourceLabel: sourceLabel, note: note))
        }

        return .failure(.versionNotFound(version))
    }

    private static func loadChangelogText() -> (String, String)? {
        if let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
           let text = try? String(contentsOf: url) {
            return (text, "CHANGELOG.md (bundle)")
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates: [(URL, String)] = [
            (cwd.appendingPathComponent("CHANGELOG.md"), "CHANGELOG.md (cwd)"),
            (cwd.appendingPathComponent("Archive/CHANGELOG-ARCHIVE.md"), "Archive/CHANGELOG-ARCHIVE.md (cwd)")
        ]

        for (url, label) in candidates {
            if FileManager.default.fileExists(atPath: url.path),
               let text = try? String(contentsOf: url) {
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
            entries.append(ReleaseNotesEntry(category: category, description: desc))
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
