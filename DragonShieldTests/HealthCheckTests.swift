import XCTest
@testable import DragonShield

final class HealthCheckTests: XCTestCase {
    struct SuccessCheck: HealthCheck {
        let name = "success"
        func run() async -> HealthCheckResult { .success(message: "ok") }
    }

    struct WarningCheck: HealthCheck {
        let name = "warning"
        func run() async -> HealthCheckResult { .warning(message: "meh") }
    }

    struct FailureCheck: HealthCheck {
        let name = "failure"
        func run() async -> HealthCheckResult { .failure(message: "bad") }
    }

    func testRunnerAggregatesReports() async {
        let runner = HealthCheckRunner(checks: [SuccessCheck(), WarningCheck(), FailureCheck()])
        await runner.runAll()
        XCTAssertEqual(runner.reports.count, 3)
        let s = runner.summary
        XCTAssertEqual(s.ok, 1)
        XCTAssertEqual(s.warning, 1)
        XCTAssertEqual(s.error, 1)
    }

    func testConfigPrecedence() {
        let args = ["app", "--runStartupHealthChecks", "false"]
        let env = ["RUN_STARTUP_HEALTH_CHECKS": "true"]
        let ud = UserDefaults(suiteName: "HealthCheckTestsConfig")!
        ud.set(true, forKey: "runStartupHealthChecks")
        XCTAssertFalse(AppConfiguration.runStartupHealthChecks(args: args, env: env, userDefaults: ud))
    }

    func testUserDefaultFallback() {
        let ud = UserDefaults(suiteName: "HealthCheckTestsUserDefault")!
        ud.set(false, forKey: "runStartupHealthChecks")
        XCTAssertFalse(AppConfiguration.runStartupHealthChecks(args: [], env: [:], userDefaults: ud))
    }
}
