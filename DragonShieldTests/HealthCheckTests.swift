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

    override func setUp() {
        super.setUp()
        HealthCheckRegistry.clear()
    }

    func testRunnerAggregatesReports() async {
        let runner = HealthCheckRunner(checks: [OkCheck(), WarningCheck(), ErrorCheck()])
        await runner.runAll()
        XCTAssertEqual(runner.reports.count, 3)
    }

    func testRegistryFiltersEnabledChecks() async {
        HealthCheckRegistry.register(OkCheck())
        HealthCheckRegistry.register(WarningCheck())
        let runner = HealthCheckRunner(enabledNames: ["ok"])
        await runner.runAll()
        XCTAssertEqual(runner.reports.map(\.name), ["ok"])
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

    func testEnabledChecksConfigPrecedence() {
        let args = ["app", "--enabledHealthChecks", "one,two"]
        let env = ["ENABLED_HEALTH_CHECKS": "three"]
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("four", forKey: "enabledHealthChecks")
        let names = AppConfiguration.enabledHealthChecks(args: args, env: env, defaults: defaults)
        XCTAssertEqual(names, ["one", "two"])
    }

    func testEnabledChecksDefaults() {
        let args = ["app"]
        let env: [String: String] = [:]
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("alpha,beta", forKey: "enabledHealthChecks")
        let names = AppConfiguration.enabledHealthChecks(args: args, env: env, defaults: defaults)
        XCTAssertEqual(names, ["alpha", "beta"])
    }

    func testDatabaseFileCheckPassesWhenFileExists() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        let check = DatabaseFileHealthCheck(path: url.path)
        let result = await check.run()
        if case .ok = result { } else { XCTFail("expected ok") }
    }

    func testDatabaseFileCheckFailsWhenMissing() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let check = DatabaseFileHealthCheck(path: url.path)
        let result = await check.run()
        if case .error = result { } else { XCTFail("expected error") }
    }
}

