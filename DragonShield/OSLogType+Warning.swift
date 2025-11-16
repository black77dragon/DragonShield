// DragonShield/OSLogType+Warning.swift

// MARK: - Version 1.0.0.0

// MARK: - History

// - 0.0.0.0 -> 1.0.0.0: Introduce warning log level convenience.

import OSLog

extension OSLogType {
    /// Warning log level for non-fatal issues.
    static let warning = OSLogType(rawValue: 0x12)
}
