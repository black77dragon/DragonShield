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

    public var summary: (ok: Int, warning: Int, error: Int) {
        var ok = 0, warn = 0, err = 0
        for report in reports {
            switch report.result {
            case .success:
                ok += 1
            case .warning:
                warn += 1
            case .failure:
                err += 1
            }
        }
        return (ok, warn, err)
    }

    private func logSummary() {
        let s = summary
        let summaryText = "\(s.ok) ok, \(s.warning) warning, \(s.error) error"
        LoggingService.shared.log("Startup health checks: \(summaryText)")
    }
}
