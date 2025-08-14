import Foundation
import SwiftUI
import SQLite3

struct TableActionSummary: Identifiable {
    let id = UUID()
    let table: String
    let action: String
    let count: Int
}

struct RestoreDelta: Identifiable {
    let id = UUID()
    let table: String
    let preCount: Int
    let postCount: Int
    var delta: Int { postCount - preCount }
}

final class BackupService: ObservableObject {
    @Published var lastBackup: Date?
    @Published var lastReferenceBackup: Date?
    @Published var logMessages: [String]
    @Published var scheduleEnabled: Bool
    @Published var scheduledTime: Date
    @Published var backupDirectory: URL
    @Published var lastActionSummaries: [TableActionSummary] = []

    private var timer: Timer?
    private var isAccessing = false
    private let timeFormatter: DateFormatter
    private let isoFormatter = ISO8601DateFormatter()

    let referenceTables = [
        "Configuration", "Currencies", "ExchangeRates", "FxRateUpdates",
        "AssetClasses", "AssetSubClasses", "TransactionTypes", "AccountTypes",
        "Institutions", "Instruments", "Accounts"
    ]

    let transactionTables = [
        "Portfolios", "PortfolioInstruments", "Transactions",
        "PositionReports", "ImportSessions", "ImportSessionValueReports",
        "ExchangeRates", "ClassTargets", "SubClassTargets", "TargetChangeLog"
    ]

    init() {
        timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        scheduleEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupsEnabled)
        if let t = UserDefaults.standard.string(forKey: UserDefaultsKeys.automaticBackupTime),
           let d = timeFormatter.date(from: t) {
            scheduledTime = d
        } else {
            scheduledTime = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: Date()) ?? Date()
        }
        lastBackup = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastBackupTimestamp) as? Date
        lastReferenceBackup = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastReferenceBackupTimestamp) as? Date
        logMessages = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.backupLog) ?? []
        backupDirectory = BackupService.loadBackupDirectory()
        if let bookmark = UserDefaults.standard.data(forKey: UserDefaultsKeys.backupDirectoryBookmark) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], bookmarkDataIsStale: &stale) {
                if url.startAccessingSecurityScopedResource() { isAccessing = true }
                if stale {
                    if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                        UserDefaults.standard.set(data, forKey: UserDefaultsKeys.backupDirectoryBookmark)
                    }
                }
                backupDirectory = url
            }
        }
        scheduleTimer()
    }

    deinit {
        if isAccessing { backupDirectory.stopAccessingSecurityScopedResource() }
        timer?.invalidate()
    }

    private static func defaultDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/DragonShieldBackups")
    }

    private static func loadBackupDirectory() -> URL {
        if let url = UserDefaults.standard.url(forKey: UserDefaultsKeys.backupDirectoryURL) {
            return url
        }
        let dir = defaultDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        UserDefaults.standard.set(dir, forKey: UserDefaultsKeys.backupDirectoryURL)
        return dir
    }

    func updateBackupDirectory(to url: URL) throws {
        if isAccessing { backupDirectory.stopAccessingSecurityScopedResource(); isAccessing = false }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        DispatchQueue.main.async { self.backupDirectory = url }
        UserDefaults.standard.set(url, forKey: UserDefaultsKeys.backupDirectoryURL)
        if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.backupDirectoryBookmark)
            if url.startAccessingSecurityScopedResource() { isAccessing = true }
        }
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

    static func defaultFileName(mode: DatabaseMode, version: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmmss"
        let modeTag = mode == .production ? "PROD" : "TEST"
        return "DragonShield-\(modeTag)-v\(version)-\(df.string(from: Date())).db"
    }

    static func defaultReferenceFileName(mode: DatabaseMode, version: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmm"
        let modeTag = mode == .production ? "PROD" : "TEST"
        return "DragonShield_Reference_\(modeTag)_v\(version)_\(df.string(from: Date())).sql"
    }

    static func defaultTransactionFileName(mode: DatabaseMode, version: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmm"
        let modeTag = mode == .production ? "PROD" : "TEST"
        return "DragonShield_Transaction_\(modeTag)_v\(version)_\(df.string(from: Date())).sql"
    }

    // MARK: - Full Backup
    func performBackup(dbManager: DatabaseManager, to destination: URL) throws -> URL {
        appendLog(action: "Backup", message: "Starting backup to \(destination.lastPathComponent)")
        var src: OpaquePointer?
        var dst: OpaquePointer?
        let dbPath = dbManager.dbFilePath
        guard sqlite3_open_v2(dbPath, &src, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let src else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to open source database"])
        }
        defer { sqlite3_close(src) }
        guard sqlite3_open_v2(destination.path, &dst, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let dst else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create backup database"])
        }
        defer { sqlite3_close(dst) }

        guard let backup = sqlite3_backup_init(dst, "main", src, "main") else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "backup init failed"])
        }
        while sqlite3_backup_step(backup, -1) == SQLITE_OK { }
        guard sqlite3_backup_finish(backup) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "backup finish failed"])
        }

        guard checkIntegrity(path: destination.path) else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Integrity check failed"])
        }

        let tableNames = fetchTableNames(db: dst)
        let counts = rowCounts(db: dst, tables: tableNames)

        DispatchQueue.main.async {
            self.lastBackup = Date()
            UserDefaults.standard.set(self.lastBackup, forKey: UserDefaultsKeys.lastBackupTimestamp)
            self.lastActionSummaries = counts.map { TableActionSummary(table: $0.0, action: "Backed up", count: $0.1) }
            self.logMessages.append("✅ Backup complete \(destination.lastPathComponent)")
            self.trimLog()
        }
        appendLog(action: "Backup", message: "Completed backup to \(destination.lastPathComponent)")
        return destination
    }

    // MARK: - Full Restore
    func performRestore(dbManager: DatabaseManager, from url: URL) throws -> [RestoreDelta] {
        appendLog(action: "Restore", message: "Starting restore from \(url.lastPathComponent)")
        let dbPath = dbManager.dbFilePath
        let preTables = fetchTableNames(path: dbPath)
        let preCounts = rowCounts(dbPath: dbPath, tables: preTables)

        guard checkIntegrity(path: url.path) else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Backup integrity check failed"])
        }

        _ = dbManager.closeConnection()

        let fm = FileManager.default
        let dbURL = URL(fileURLWithPath: dbPath)
        let backupURL = dbURL.deletingLastPathComponent().appendingPathComponent(dbURL.lastPathComponent + ".old")
        try? fm.removeItem(at: backupURL)
        try fm.moveItem(at: dbURL, to: backupURL)
        try fm.copyItem(at: url, to: dbURL)

        guard checkIntegrity(path: dbPath) else {
            try? fm.removeItem(at: dbURL)
            try? fm.moveItem(at: backupURL, to: dbURL)
            dbManager.reopenDatabase()
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Restored file failed integrity check"])
        }

        dbManager.reopenDatabase()

        let postTables = fetchTableNames(path: dbPath)
        let postCounts = rowCounts(dbPath: dbPath, tables: postTables)
        let allTables = Array(Set(preTables + postTables)).sorted()

        let deltas: [RestoreDelta] = allTables.map { tbl in
            let pre = preCounts.first { $0.0 == tbl }?.1 ?? 0
            let post = postCounts.first { $0.0 == tbl }?.1 ?? 0
            return RestoreDelta(table: tbl, preCount: pre, postCount: post)
        }

        DispatchQueue.main.async {
            self.logMessages.append("✅ Restore complete \(url.lastPathComponent)")
            self.lastActionSummaries = deltas.map { TableActionSummary(table: $0.table, action: "Restored", count: $0.postCount) }
            self.trimLog()
        }
        appendLog(action: "Restore", message: "Completed restore from \(url.lastPathComponent)")
        return deltas
    }

    // MARK: - Disabled placeholders
    func backupReferenceData(dbManager: DatabaseManager, to destination: URL) throws -> URL {
        throw NSError(domain: "BackupService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Reference backup disabled"])
    }

    func restoreReferenceData(dbManager: DatabaseManager, from url: URL) throws {
        throw NSError(domain: "BackupService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Reference restore disabled"])
    }

    func backupTransactionData(dbManager: DatabaseManager, to destination: URL, tables: [String]) throws -> URL {
        throw NSError(domain: "BackupService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Transaction backup disabled"])
    }

    func restoreTransactionData(dbManager: DatabaseManager, from url: URL, tables: [String]) throws {
        throw NSError(domain: "BackupService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Transaction restore disabled"])
    }

    // MARK: - Helpers
    private func fetchTableNames(path: String) -> [String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else { return [] }
        defer { sqlite3_close(db) }
        return fetchTableNames(db: db)
    }

    private func fetchTableNames(db: OpaquePointer) -> [String] {
        var names: [String] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW, let cStr = sqlite3_column_text(stmt, 0) {
                names.append(String(cString: cStr))
            }
        }
        sqlite3_finalize(stmt)
        return names.sorted()
    }

    private func rowCounts(dbPath: String, tables: [String]) -> [(String, Int)] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else { return [] }
        defer { sqlite3_close(db) }
        return rowCounts(db: db, tables: tables)
    }

    private func rowCounts(db: OpaquePointer, tables: [String]) -> [(String, Int)] {
        var result: [(String, Int)] = []
        var stmt: OpaquePointer?
        for table in tables {
            if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table);", -1, &stmt, nil) == SQLITE_OK,
               sqlite3_step(stmt) == SQLITE_ROW {
                result.append((table, Int(sqlite3_column_int(stmt, 0))))
            }
            sqlite3_finalize(stmt)
            stmt = nil
        }
        return result
    }

    private func checkIntegrity(path: String) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else { return false }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, "PRAGMA integrity_check;", -1, &stmt, nil) != SQLITE_OK { return false }
        guard sqlite3_step(stmt) == SQLITE_ROW, let cStr = sqlite3_column_text(stmt, 0) else { return false }
        return String(cString: cStr) == "ok"
    }

    private func appendLog(action: String, message: String) {
        let entry = "[\(isoFormatter.string(from: Date()))] \(action) \(message)"
        DispatchQueue.main.async {
            self.logMessages.insert(entry, at: 0)
            self.trimLog()
        }
    }

    private func trimLog() {
        if logMessages.count > 50 { logMessages = Array(logMessages.prefix(50)) }
        UserDefaults.standard.set(logMessages, forKey: UserDefaultsKeys.backupLog)
    }
}

