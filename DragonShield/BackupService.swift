import Foundation
import SwiftUI

class BackupService: ObservableObject {
    @Published var lastBackup: Date?
    @Published var logMessages: [String]
    @Published var scheduleEnabled: Bool
    @Published var scheduledTime: Date

    private var timer: Timer?
    private let timeFormatter: DateFormatter
    private let isoFormatter = ISO8601DateFormatter()

    init() {
        self.timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        self.scheduleEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupsEnabled)
        if let timeStr = UserDefaults.standard.string(forKey: UserDefaultsKeys.automaticBackupTime),
           let date = timeFormatter.date(from: timeStr) {
            self.scheduledTime = date
        } else {
            self.scheduledTime = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: Date()) ?? Date()
        }
        self.lastBackup = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastBackupTimestamp) as? Date
        self.logMessages = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.backupLog) ?? []
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        guard scheduleEnabled else { return }
        let now = Date()
        var comps = Calendar.current.dateComponents([.hour, .minute], from: scheduledTime)
        comps.day = Calendar.current.component(.day, from: now)
        comps.month = Calendar.current.component(.month, from: now)
        comps.year = Calendar.current.component(.year, from: now)
        var fire = Calendar.current.date(from: comps) ?? now
        if fire <= now { fire = Calendar.current.date(byAdding: .day, value: 1, to: fire)! }
        timer = Timer(fireAt: fire, interval: 86400, target: self, selector: #selector(runScheduledBackup), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func runScheduledBackup() {
        NotificationCenter.default.post(name: .init("PerformDatabaseBackup"), object: nil)
    }

    func updateSchedule(enabled: Bool, time: Date) {
        scheduleEnabled = enabled
        scheduledTime = time
        UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.automaticBackupsEnabled)
        UserDefaults.standard.set(timeFormatter.string(from: time), forKey: UserDefaultsKeys.automaticBackupTime)
        scheduleTimer()
    }

    func performBackup(dbPath: String) throws -> URL {
        let fm = FileManager.default
        let backupDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DragonShield/Backups")
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmmss"
        let name = "backup-\(df.string(from: Date())).db"
        let dest = backupDir.appendingPathComponent(name)
        try fm.copyItem(atPath: dbPath, toPath: dest.path)
        lastBackup = Date()
        UserDefaults.standard.set(lastBackup, forKey: UserDefaultsKeys.lastBackupTimestamp)
        appendLog(action: "Backup", file: name, success: true)
        return dest
    }

    func performRestore(dbManager: DatabaseManager, from url: URL) throws {
        let fm = FileManager.default
        let dbPath = dbManager.dbFilePath
        let temp = dbPath + ".inprogress"
        dbManager.closeConnection()
        try fm.moveItem(atPath: dbPath, toPath: temp)
        do {
            try fm.copyItem(at: url, to: URL(fileURLWithPath: dbPath))
            dbManager.reopenDatabase()
            appendLog(action: "Restore", file: url.lastPathComponent, success: true)
        } catch {
            try? fm.moveItem(atPath: temp, toPath: dbPath)
            appendLog(action: "Restore", file: url.lastPathComponent, success: false, message: error.localizedDescription)
            throw error
        }
        try? fm.removeItem(atPath: temp)
    }

    private func appendLog(action: String, file: String, success: Bool, message: String? = nil) {
        var entry = "[\(isoFormatter.string(from: Date()))] \(action) \(file) \(success ? "Success" : "Error")"
        if let message = message { entry += " - \(message)" }
        logMessages.insert(entry, at: 0)
        if logMessages.count > 10 { logMessages = Array(logMessages.prefix(10)) }
        UserDefaults.standard.set(logMessages, forKey: UserDefaultsKeys.backupLog)
    }
}
