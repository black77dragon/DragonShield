import XCTest
@testable import DragonShield

final class HealthCheckTests: XCTestCase {
    struct OkCheck: HealthCheck {
        let name = "ok"
        func run() async -> HealthCheckResult { .ok(message: "ok") }
    }

    struct WarningCheck: HealthCheck {
        let name = "warn"
        func run() async -> HealthCheckResult { .warning(message: "warn") }
    }

    struct ErrorCheck: HealthCheck {
        let name = "error"
        func run() async -> HealthCheckResult { .error(message: "bad") }
    }

    func testRunnerAggregatesReports() async {
        let runner = HealthCheckRunner(checks: [OkCheck(), WarningCheck(), ErrorCheck()])
        await runner.runAll()
        XCTAssertEqual(runner.reports.count, 3)
    }

    func testConfigPrecedence() {
        let args = ["app", "--runStartupHealthChecks", "false"]
        let env = ["RUN_STARTUP_HEALTH_CHECKS": "true"]
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        XCTAssertFalse(AppConfiguration.runStartupHealthChecks(args: args, env: env, defaults: defaults))
    }

    func testUserDefaultsOverride() {
        let args = ["app"]
        let env: [String: String] = [:]
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(false, forKey: "runStartupHealthChecks")
        XCTAssertFalse(AppConfiguration.runStartupHealthChecks(args: args, env: env, defaults: defaults))
    }
}
