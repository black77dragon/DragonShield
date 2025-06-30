# DragonShield - Logging Architecture

| | |
|---|---|
| **Document ID:** | `LoggingArchitecture.md` |
| **Version:** | `1.0` |
| **Date:** | `2025-06-30` |
| **Author:** | `RWK` |
| **Status:** | `Final` |

---
## Document History

| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2025-06-30 | RWK | Initial creation of the logging architecture document. |

---

## 1. Philosophy

This document outlines the unified logging strategy for the DragonShield application. Our approach prioritizes **performance, structure, and flexibility**. We treat logging as a decoupled, cross-cutting concern, not a feature-specific implementation.

The core principles are:
-   **A Single API:** All application modules use one consistent API for emitting log messages.
-   **Configurable Backends:** The destination of logs (Console, file, network) is determined at application startup, not at the call site.
-   **Structured Data:** Logs should capture not just a string, but key-value metadata for powerful filtering and diagnostics.
-   **Performance First:** Logging should have a minimal performance impact, achieved by leveraging Apple's Unified Logging system (`OSLog`).

## 2. Core Technology: `swift-log`

We will use Apple's [swift-log](https://github.com/apple/swift-log) as the single logging API throughout the DragonShield codebase.

**Rationale:** `swift-log` is a logging *facade*. It provides the `Logger` API that your code will interact with, but it doesn't handle the log *storage*. Instead, one or more `LogHandler` backends are configured to process and store the logs. This decouples your code from the concrete logging implementation, which is a critical best practice.

## 3. Architecture

The system is bootstrapped once at application launch with a multiplexing handler that directs logs to two destinations simultaneously:

1.  **`OSLog` Backend:** A handler that forwards all log messages to Apple's Unified Logging system. This provides high-performance, low-overhead logging with rich metadata, viewable live in the **Console.app**.
2.  **File Backend:** A handler that writes formatted logs to a persistent, rotating text file. This provides an easily accessible log archive for debugging user-reported issues without requiring them to use complex tools.

![DragonShield Logging Architecture](https://i.imgur.com/G5gDkS1.png)

This architecture eliminates the redundancy of the previous approach where a service both wrote to a file and manually called `OSLog`. Here, you log once, and the framework handles distribution.

## 4. Usage

### Getting a Logger

Do **not** use static, predefined loggers. Instead, instantiate a `Logger` with a `label` that identifies its context. The label should follow a reverse-DNS convention.

```swift
// In your parsing module
let logger = Logger(label: "com.dragonshield.parser")

// In a UI component
let logger = Logger(label: "com.dragonshield.ui.settingsview")

// In a database service
let logger = Logger(label: "com.dragonshield.database.service")
