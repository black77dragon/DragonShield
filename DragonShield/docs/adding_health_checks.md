# Adding Startup Health Checks

This guide explains how to extend Dragon Shield's startup diagnostics.

## Creating a Check

1. Define a type that conforms to `HealthCheck`.
2. Implement `run()` to perform your validation and return a `HealthCheckResult`.

```swift
struct DatabasePingCheck: HealthCheck {
    let name = "DatabasePing"
    func run() async -> HealthCheckResult {
        // perform work
        return .ok(message: "database reachable")
    }
}
```

## Registering

Register the check during application setup:

```swift
HealthCheckRegistry.register(DatabasePingCheck())
```

## Configuration

All checks run by default. To run a subset, provide a comma-separated list of names:

- CLI: `--enabledHealthChecks DatabasePing`
- Environment: `ENABLED_HEALTH_CHECKS=DatabasePing`
- UserDefaults key: `enabledHealthChecks`

Checks not listed are skipped.

## Viewing Results

After startup, open **Health Checks** from Settings to review each check and its message.
