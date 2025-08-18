import Foundation

/// Executes all registered `HealthCheck`s and publishes their reports.
@MainActor
public final class HealthCheckRunner: ObservableObject {
    /// Checks registered for execution.
    public static var registeredChecks: [HealthCheck] = []

    /// Register a new `HealthCheck`.
    public static func register(_ check: HealthCheck) {
        registeredChecks.append(check)
    }

    @Published private(set) public var reports: [HealthCheckReport] = []
    private let checks: [HealthCheck]

    public init(checks: [HealthCheck]? = nil) {
        self.checks = checks ?? Self.registeredChecks
    }

    /// Runs all checks sequentially and logs a summary.
    public func runAll() async {
        var results: [HealthCheckReport] = []
        for check in checks {
            let outcome = await check.run()
            results.append(HealthCheckReport(name: check.name, result: outcome))
        }
        reports = results
        logSummary()
    }

    private func logSummary() {
        let failures = reports.filter {
            if case .failure = $0.result { return true } else { return false }
        }.count
        let summary = "\(reports.count - failures) success, \(failures) failure"
        LoggingService.shared.log("Startup health checks: \(summary)")
    }
}
