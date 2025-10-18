import Foundation

struct AppVersionProvider {
    /// The user-facing marketing version (e.g., "2.1.0").
    static var version: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
    }
    
    /// The internal build number (e.g., "154").
    static var build: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
    }
    
    /// A combined, formatted string for display.
    static var fullVersion: String {
        return "Version \(version) (Build \(build))"
    }
}
