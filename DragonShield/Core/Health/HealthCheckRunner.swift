import Foundation

/// Executes startup `HealthCheck`s and publishes their reports.
@MainActor
public final class HealthCheckRunner: ObservableObject {
    @Published private(set) public var reports: [HealthCheckReport] = []
    private let checks: [HealthCheck]

    public init(
        checks: [HealthCheck]? = nil,
        enabledNames: Set<String>? = nil
    ) {
        if let provided = checks {
            if let enabled = enabledNames {
                self.checks = provided.filter { enabled.contains($0.name) }
            } else {
                self.checks = provided
            }
        } else {
            self.checks = HealthCheckRegistry.checks(enabledNames: enabledNames)
        }
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

