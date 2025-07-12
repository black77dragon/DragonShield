// DragonShield/ImportLogService.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Initial service to persist statement import log entries.

import Foundation
import SwiftUI

class ImportLogService: ObservableObject {
    static let shared = ImportLogService()

    @Published var logMessages: [String]
    private let isoFormatter = ISO8601DateFormatter()

    private init() {
        logMessages = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.statementLog) ?? []
    }

    func appendLog(fileName: String, success: Bool, details: String? = nil) {
        var entry = "[\(isoFormatter.string(from: Date()))] \(fileName) \u{2192} "
        entry += success ? "Success" : "Failed"
        if let details = details { entry += ": \(details)" }
        DispatchQueue.main.async {
            self.logMessages.insert(entry, at: 0)
            if self.logMessages.count > 10 { self.logMessages = Array(self.logMessages.prefix(10)) }
            UserDefaults.standard.set(self.logMessages, forKey: UserDefaultsKeys.statementLog)
        }
    }
}
