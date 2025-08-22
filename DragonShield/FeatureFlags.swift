import Foundation

enum FeatureFlags {
    static func portfolioInstrumentUpdatesEnabled(
        args: [String] = CommandLine.arguments,
        env: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> Bool {
        if let idx = args.firstIndex(of: "--portfolioInstrumentUpdatesEnabled"),
           let value = args.dropFirst(idx + 1).first {
            return value.lowercased() != "false"
        }
        if let value = env["PORTFOLIO_INSTRUMENT_UPDATES_ENABLED"] {
            return value.lowercased() != "false"
        }
        if defaults.object(forKey: "portfolioInstrumentUpdatesEnabled") != nil {
            return defaults.bool(forKey: "portfolioInstrumentUpdatesEnabled")
        }
        return true
    }
}

