import Foundation

struct ReleaseNotesVersionHealthCheck: HealthCheck {
    let name: String = "Release Notes"
    private let appVersionProvider: () -> String

    init(appVersionProvider: @escaping () -> String = { AppVersionProvider.version }) {
        self.appVersionProvider = appVersionProvider
    }

    func run() async -> HealthCheckResult {
        let appVersion = appVersionProvider()

        switch ReleaseNotesProvider.loadAll() {
        case .success(let result):
            let target = normalizeVersion(appVersion)
            guard !target.isEmpty, target.lowercased() != "n/a" else {
                return .warning(message: "App version unavailable; release notes version check skipped.")
            }

            let match = result.sections.contains { section in
                normalizeVersion(section.version).localizedCaseInsensitiveCompare(target) == .orderedSame
            }
            if match {
                return .ok(message: "Release notes found for v\(target).")
            }

            if let latestVersion = latestReleasedVersion(from: result.sections) {
                return .warning(message: "App version \(appVersion) not found in CHANGELOG.md (latest: \(latestVersion)).")
            }
            return .warning(message: "App version \(appVersion) not found in CHANGELOG.md.")
        case .failure(let error):
            return .warning(message: "Release notes check skipped: \(error.localizedDescription)")
        }
    }

    private func latestReleasedVersion(from sections: [ReleaseNotesSection]) -> String? {
        for section in sections {
            let normalized = normalizeVersion(section.version)
            if normalized.lowercased() == "unreleased" { continue }
            if !normalized.isEmpty {
                return section.version
            }
        }
        return nil
    }

    private func normalizeVersion(_ value: String) -> String {
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
