import XCTest
@testable import DragonShield

final class HealthCheckTests: XCTestCase {
    struct SuccessCheck: HealthCheck {
        let name = "success"
        func run() async -> HealthCheckResult { .success(message: "ok") }
    }

    struct FailureCheck: HealthCheck {
        let name = "failure"
        func run() async -> HealthCheckResult { .failure(message: "bad") }
    }

    func testRunnerAggregatesReports() async {
        let runner = HealthCheckRunner(checks: [SuccessCheck(), FailureCheck()])
        await runner.runAll()
        XCTAssertEqual(runner.reports.count, 2)
    }

    func testConfigPrecedence() {
        let args = ["app", "--runStartupHealthChecks", "false"]
        let env = ["RUN_STARTUP_HEALTH_CHECKS": "true"]
        XCTAssertFalse(AppConfiguration.runStartupHealthChecks(args: args, env: env))
    }
}
