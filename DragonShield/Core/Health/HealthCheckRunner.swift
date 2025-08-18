import Foundation

/// Executes all registered `HealthCheck`s and publishes their reports.
@MainActor
public final class HealthCheckRunner: ObservableObject {
    /// Checks registered for execution.
    nonisolated(unsafe) public static var registeredChecks: [HealthCheck] = []

    /// Register a new `HealthCheck`.
    nonisolated public static func register(_ check: HealthCheck) {
        registeredChecks.append(check)
    }

    @Published private(set) public var reports: [HealthCheckReport] = []
    private let checks: [HealthCheck]

    public init(checks: [HealthCheck] = HealthCheckRunner.registeredChecks) {
        self.checks = checks
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
        let ok = reports.filter { if case .ok = $0.result { return true } else { return false } }.count
        let warning = reports.filter { if case .warning = $0.result { return true } else { return false } }.count
        let error = reports.filter { if case .error = $0.result { return true } else { return false } }.count
        let summary = "\(ok) ok, \(warning) warning, \(error) error"
        LoggingService.shared.log("Startup health checks: \(summary)")
    }
}
