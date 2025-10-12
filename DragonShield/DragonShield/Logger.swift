// DragonShield/Logger.swift
// MARK: - Version 1.0.0.0
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Provide OSLog categories for the app.

import Foundation
import OSLog

extension Logger {
    /// Subsystem identifier for DragonShield logs.
    private static var subsystem = Bundle.main.bundleIdentifier ?? "DragonShield"

    /// General purpose logs.
    static let general = Logger(subsystem: subsystem, category: "general")
    /// Logs related to user interface components.
    static let ui = Logger(subsystem: subsystem, category: "ui")
    /// Logs produced during parsing operations.
    static let parser = Logger(subsystem: subsystem, category: "parser")
    /// Logs emitted by database operations.
    static let database = Logger(subsystem: subsystem, category: "database")
    /// Logs for network/HTTP traffic.
    static let network = Logger(subsystem: subsystem, category: "network")
}
