# Dragon Shield Logging Approach

This document explains how Dragon Shield handles logging in the Swift codebase, focusing on persistent OSLog integration and file-based logs.

## Overview

The app uses a hybrid strategy:

1. **OSLog** for fast, structured logging that integrates with macOS's unified logging system.
2. **LoggingService** for writing logs to a local file so they can be viewed after the app exits.

Both mechanisms work together, providing real-time diagnostics in the macOS Console app as well as a persistent log file stored in the user's temporary directory.

## OSLog Categories

`Logger.swift` defines several `OSLog` categories to organize messages:

- `general` – default category for miscellaneous messages.
- `ui` – user interface events.
- `parser` – logs produced while parsing documents.
- `database` – database related activity.

Each category shares the subsystem identifier derived from the application's bundle identifier. Use these static properties when emitting logs, for example:

```swift
Logger.parser.info("Parsed \(rows) rows")
```

## LoggingService

`LoggingService` is a singleton responsible for maintaining a text log file. It exposes `log(_ message:type:logger:)` which:

1. Timestamp the message using ISO 8601 format.
2. Writes the message to the log file asynchronously.
3. Forwards the same text to `OSLog` using the provided logger category and log `OSLogType` (defaulting to `.info`).

Log files are stored in the temporary directory as `import.log`. The service also offers `clearLog()` to reset the file at the start of an import operation and `readLog()` to fetch its contents.

## ImportManager and ZKBXLSXProcessor

When an import is initiated, `ImportManager` clears the log file and forwards parser progress through `LoggingService`. The `ZKBXLSXProcessor` logs individual steps—opening files, reading specific cells, processing each row, and reporting failures—using both OSLog and the progress callback. Recent updates also log the key fields of each parsed record and summarize how many were created.

## Viewing Logs

1. **Console App**: Open `/Applications/Utilities/Console.app`, start streaming, and filter by your bundle identifier to see live OSLog messages.
2. **Log File**: Inspect the `import.log` file in the macOS temporary directory for a persistent record of each import session.

This dual-layer approach ensures robust diagnostics during development and in production environments.
