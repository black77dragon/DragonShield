import Foundation

/// Reads configuration from command line and environment.
struct AppConfiguration {
    static func runStartupHealthChecks(
        args: [String] = CommandLine.arguments,
        env: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard,
        default defaultValue: Bool = true
    ) -> Bool {
        if let idx = args.firstIndex(of: "--runStartupHealthChecks"),
           let value = args.dropFirst(idx + 1).first {
            return value.lowercased() != "false"
        }
        if let value = env["RUN_STARTUP_HEALTH_CHECKS"] {
            return value.lowercased() != "false"
        }
        if userDefaults.object(forKey: "runStartupHealthChecks") != nil {
            return userDefaults.bool(forKey: "runStartupHealthChecks")
        }
        return defaultValue
    }
}
