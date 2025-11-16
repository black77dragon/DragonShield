import Foundation

/// Registers available `HealthCheck`s and provides filtered access.
public enum HealthCheckRegistry {
    private nonisolated(unsafe) static var checks: [String: HealthCheck] = [:]

    /// Register a new `HealthCheck`.
    public static func register(_ check: HealthCheck) {
        checks[check.name] = check
    }

    /// Returns all registered checks, optionally limited to enabled names.
    public static func checks(enabledNames: Set<String>? = nil) -> [HealthCheck] {
        if let enabled = enabledNames {
            return enabled.compactMap { checks[$0] }
        }
        return Array(checks.values)
    }

    /// Remove all registered checks. Intended for testing only.
    public static func clear() {
        checks.removeAll()
    }
}
