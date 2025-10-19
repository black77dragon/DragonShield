import Foundation

enum GitInfoProvider {
    private static func info(_ key: String) -> String? {
        return Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private static var canRunGitCommands: Bool {
        #if os(macOS)
        return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil
        #else
        return false
        #endif
    }

    /// Best-effort branch name. Prefers Info.plist key `GIT_BRANCH` if present, otherwise tries Git in DEBUG.
    static var branch: String? {
        if let b = info("GIT_BRANCH"), !b.isEmpty { return b }
        #if DEBUG
        if let out = runGit(["rev-parse", "--abbrev-ref", "HEAD"]) { return out }
        #endif
        return nil
    }

    /// Best-effort latest tag. Prefers Info.plist key `GIT_TAG` if present, otherwise tries Git in DEBUG.
    static var tag: String? {
        if let t = info("GIT_TAG"), !t.isEmpty { return t }
        #if DEBUG
        if let out = runGit(["describe", "--tags", "--abbrev=0"]) { return out }
        #endif
        return nil
    }

    /// Short commit hash if available.
    static var commitShort: String? {
        if let c = info("GIT_COMMIT"), !c.isEmpty { return c }
        #if DEBUG
        if let out = runGit(["rev-parse", "--short", "HEAD"]) { return out }
        #endif
        return nil
    }

    /// Last change summary captured during CI.
    static var lastChangeSummary: String? {
        if let summary = info("DS_LAST_CHANGE"), !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        #if DEBUG
        if let out = runGit(["log", "-1", "--pretty=%s"]) { return out }
        #endif
        return nil
    }

    /// Returns a "Version" string that prefers git tag when available, otherwise CFBundleShortVersionString.
    static var displayVersion: String {
        let plistVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let ver = tag ?? plistVersion ?? "N/A"
        var pieces: [String] = []
        if let b = build, !b.isEmpty {
            pieces.append("Version \(ver) (Build \(b))")
        } else {
            pieces.append("Version \(ver)")
        }
        if let summary = lastChangeSummary, !summary.isEmpty {
            pieces.append("Last change: \(summary)")
        }
        return pieces.joined(separator: " • ")
    }

    #if DEBUG
    static func debugDump() {
        let bundlePath = Bundle.main.bundlePath
        let plistVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "(nil)"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "(nil)"
        let tagKey = Bundle.main.object(forInfoDictionaryKey: "GIT_TAG") as? String ?? "(nil)"
        let branchKey = Bundle.main.object(forInfoDictionaryKey: "GIT_BRANCH") as? String ?? "(nil)"
        let commitKey = Bundle.main.object(forInfoDictionaryKey: "GIT_COMMIT") as? String ?? "(nil)"
        let lastChangeKey = Bundle.main.object(forInfoDictionaryKey: "DS_LAST_CHANGE") as? String ?? "(nil)"
        print("[GitInfoProvider] bundle=\(bundlePath) plistVersion=\(plistVersion) build=\(build)")
        print("[GitInfoProvider] Info.plist keys → GIT_TAG=\(tagKey) GIT_BRANCH=\(branchKey) GIT_COMMIT=\(commitKey) DS_LAST_CHANGE=\(lastChangeKey)")
        print("[GitInfoProvider] Derived → tag=\(tag ?? "(nil)") branch=\(branch ?? "(nil)") commit=\(commitShort ?? "(nil)") lastChange=\(lastChangeSummary ?? "(nil)") displayVersion=\(displayVersion)")
    }
    #endif

    private static func runGit(_ args: [String]) -> String? {
        guard canRunGitCommands else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["git"] + args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
        } catch {
            return nil
        }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !out.isEmpty else { return nil }
        return out
    }
}
