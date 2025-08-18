import Foundation

/// Verifies that the application's database file exists on disk.
struct DatabaseFileHealthCheck: HealthCheck {
    let name = "DatabaseFile"
    private let path: String

    init(path: String) {
        self.path = path
    }

    func run() async -> HealthCheckResult {
        if FileManager.default.fileExists(atPath: path) {
            return .ok(message: "database file present")
        } else {
            return .error(message: "database file missing")
        }
    }
}
