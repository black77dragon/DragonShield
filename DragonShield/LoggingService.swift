// DragonShield/LoggingService.swift
// MARK: - Version 1.0.1.0
// MARK: - History
// - 0.0.0.0 -> 1.0.0.0: Initial logging service writing messages to a log file.
// - 1.0.0.0 -> 1.0.1.0: Also forward messages to OSLog with categories.

import Foundation
import OSLog

final class LoggingService {
    static let shared = LoggingService()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "LoggingService")
    private let formatter: ISO8601DateFormatter

    private init() {
        let dir = FileManager.default.temporaryDirectory
        self.fileURL = dir.appendingPathComponent("import.log")
        self.formatter = ISO8601DateFormatter()
    }

    func clearLog() {
        queue.sync {
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    func log(_ message: String, logger: Logger = .general) {
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        logger.info("\(message, privacy: .public)")
        queue.async {
            if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) {
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? line.write(to: self.fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    func readLog() -> String {
        queue.sync {
            (try? String(contentsOf: fileURL)) ?? ""
        }
    }
}
