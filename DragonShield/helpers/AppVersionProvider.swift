import Foundation

enum AppVersionProvider {
    /// The user-facing marketing version (e.g., "2.1.0").
    static var version: String {
        if let dsVersion = Bundle.main.object(forInfoDictionaryKey: "DS_VERSION") as? String, !dsVersion.isEmpty {
            return dsVersion
        }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }

    /// The internal build number (e.g., "154").
    static var build: String {
        if let dsBuild = Bundle.main.object(forInfoDictionaryKey: "DS_BUILD_NUMBER") as? String, !dsBuild.isEmpty {
            return dsBuild
        }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }

    /// A combined, formatted string for display.
    static var fullVersion: String {
        return "Version \(version) (Build \(build))"
    }
}
