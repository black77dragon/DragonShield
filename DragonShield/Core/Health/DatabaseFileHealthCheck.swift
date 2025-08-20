import Foundation

/// Verifies that the application's database file exists on disk.
struct DatabaseFileHealthCheck: HealthCheck {
    let name = "DatabaseFile"
    private let pathProvider: () -> String

    init(pathProvider: @escaping () -> String) {
        self.pathProvider = pathProvider
    }

    func run() async -> HealthCheckResult {
        let path = pathProvider()
        if FileManager.default.fileExists(atPath: path) {
            return .ok(message: "database file present")
        } else {
            return .error(message: "database file missing at \(path)")
        }
    }
}
