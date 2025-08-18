import Foundation

/// Describes a single startup health verification.
public protocol HealthCheck {
    /// Display name for the check.
    var name: String { get }
    /// Execute the check and return a result.
    func run() async -> HealthCheckResult
}

/// Outcome for a `HealthCheck`.
public enum HealthCheckResult {
    case ok(message: String)
    case warning(message: String)
    case error(message: String)
}

/// Summary produced by `HealthCheckRunner`.
public struct HealthCheckReport: Identifiable {
    public var id: String { name }
    public let name: String
    public let result: HealthCheckResult
}
