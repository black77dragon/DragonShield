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
    static func portfolioAttachmentsEnabled(
        args: [String] = CommandLine.arguments,
        env: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> Bool {
        if let idx = args.firstIndex(of: "--portfolioAttachmentsEnabled"),
           let value = args.dropFirst(idx + 1).first {
            return value.lowercased() != "false"
        }
        if let value = env["PORTFOLIO_ATTACHMENTS_ENABLED"] {
            return value.lowercased() != "false"
        }
        if defaults.object(forKey: UserDefaultsKeys.portfolioAttachmentsEnabled) != nil {
            return defaults.bool(forKey: UserDefaultsKeys.portfolioAttachmentsEnabled)
        }
        return false
    }

    static func portfolioAttachmentThumbnailsEnabled(
        args: [String] = CommandLine.arguments,
        env: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard portfolioAttachmentsEnabled(args: args, env: env, defaults: defaults) else { return false }
        if let idx = args.firstIndex(of: "--portfolioAttachmentThumbnailsEnabled"),
           let value = args.dropFirst(idx + 1).first {
            return value.lowercased() != "false"
        }
        if let value = env["PORTFOLIO_ATTACHMENT_THUMBNAILS_ENABLED"] {
            return value.lowercased() != "false"
        }
        if defaults.object(forKey: UserDefaultsKeys.portfolioAttachmentThumbnailsEnabled) != nil {
            return defaults.bool(forKey: UserDefaultsKeys.portfolioAttachmentThumbnailsEnabled)
        }
        return true
    }
}

