# Dragon Shield Logging Guidelines

**Version 1.0** | June 22, 2025

These guidelines outline a robust, structured logging system for both the Swift front-end and Python back-end of Dragon Shield.

## Architecture Layers
- **Application Layer**: Use a shared logging interface instead of direct print statements.
- **Logging Middleware**: Attach context (request ID, user ID, environment) and handle formatting.
- **Logging Backends**: Support console output, rotating log files, and optional remote services (e.g., Sentry, Loki).

## Best Practices
1. **Use a Library**
   - Swift: `os.log` or `SwiftyBeaver`
   - Python: `structlog` or `logging`
2. **Structured Logging**
   - Emit logs as JSON for easy filtering and search.
3. **Log Levels**
   - TRACE, DEBUG, INFO, WARNING, ERROR, CRITICAL
4. **Context Enrichment**
   - Include request IDs, user IDs, and environment automatically.
5. **Error Reporting**
   - Capture stack traces and integrate with crash reporting tools when available.
6. **Log Rotation & Retention**
   - Rotate files daily or by size and keep local logs for about two weeks.
7. **Sensitive Data Handling**
   - Redact secrets such as passwords or tokens before logging.
8. **Asynchronous Logging**
   - Buffer log writes so they don't block the main thread.
9. **Dynamic Log Level**
   - Allow runtime adjustment of the log level for debugging.

## Example Usage (Swift with SwiftyBeaver)
```swift
import SwiftyBeaver
let log = SwiftyBeaver.self
let console = ConsoleDestination()
let file = FileDestination()
log.addDestination(console)
log.addDestination(file)
log.info("User signed in", context: ["user_id": user.id])
log.error("Payment failed", context: ["error": err.localizedDescription])
```

## Version History
- 1.0: Initial logging design document.
