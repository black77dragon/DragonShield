import Foundation

/// Reads configuration from command line and environment.
struct AppConfiguration {
    static func runStartupHealthChecks(
        args: [String] = CommandLine.arguments,
        env: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard,
        default defaultValue: Bool = true
    ) -> Bool {
        if let idx = args.firstIndex(of: "--runStartupHealthChecks"),
           let value = args.dropFirst(idx + 1).first {
            return value.lowercased() != "false"
        }
        if let value = env["RUN_STARTUP_HEALTH_CHECKS"] {
            return value.lowercased() != "false"
        }
        if defaults.object(forKey: "runStartupHealthChecks") != nil {
            return defaults.bool(forKey: "runStartupHealthChecks")
        }
        return defaultValue
    }

    static func enabledHealthChecks(
        args: [String] = CommandLine.arguments,
        env: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard,
        default defaultValue: Set<String>? = nil
    ) -> Set<String>? {
        if let idx = args.firstIndex(of: "--enabledHealthChecks"),
           let value = args.dropFirst(idx + 1).first {
            return parseList(value)
        }
        if let value = env["ENABLED_HEALTH_CHECKS"] {
            return parseList(value)
        }
        if let string = defaults.string(forKey: "enabledHealthChecks") {
            return parseList(string)
        }
        return defaultValue
    }

    private static func parseList(_ value: String) -> Set<String> {
        Set(value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }
}

