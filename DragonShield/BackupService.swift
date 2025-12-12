import Foundation
import SQLite3
import SwiftUI

// MARK: - Supporting Structs

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

struct BackupManifest: Codable {
    let backupInfo: BackupInfo
    let rowCounts: [String: Int]
    let validationReport: ValidationReport

    struct BackupInfo: Codable {
        let backupFile: String
    }

    struct ValidationReport: Codable {
        let hasCriticalIssues: Bool
        let hasWarnings: Bool
        let totalIssues: Int
    }
}

struct InstrumentValidationReport: Decodable {
    struct Summary: Decodable {
        let tableName: String?
        let totalRecords: Int?
        let validRecords: Int?
        let invalidRecords: Int?
        let pendingRecords: Int?
        let duplicateConflicts: Int?
    }

    let summary: Summary?
    let validationIssues: [ValidationIssue]?
    let duplicateConflicts: [DuplicateConflict]?
    let foreignKeyViolations: [ForeignKeyViolation]?
    let hasCriticalIssues: Bool
    let hasWarnings: Bool
    let totalIssues: Int

    struct ValidationIssue: Decodable {
        let instrumentId: Int?
        let instrumentName: String?
        let validationStatus: String?
    }

    struct DuplicateConflict: Decodable {
        let conflictType: String?
        let conflictingValue: String?
        let duplicateCount: Int?
    }

    struct ForeignKeyViolation: Decodable {
        let table: String?
        let parentTable: String?
    }
}

struct InstrumentValidationResult {
    let report: InstrumentValidationReport?
    let rawOutput: String
    let exitCode: Int32
}

// MARK: - Backup Service Class

class BackupService: ObservableObject {
    @Published var lastBackup: Date?
    @Published var lastReferenceBackup: Date?
    @Published var logMessages: [String]
    @Published var scheduleEnabled: Bool
    @Published var scheduledTime: Date
    @Published var backupDirectory: URL
    @Published var lastActionSummaries: [TableActionSummary] = []

    private var timer: Timer?
    private var isAccessing = false
    private var cachedScriptURL: URL?
    private let timeFormatter: DateFormatter
    private let isoFormatter = ISO8601DateFormatter()

    let referenceTables = [
        "Configuration", "Currencies", "ExchangeRates", "FxRateUpdates",
        "AssetClasses", "AssetSubClasses", "TransactionTypes", "AccountTypes",
        "Institutions", "Instruments", "Accounts",
    ]

    let transactionTables = [
        "Portfolios", "PortfolioInstruments", "Transactions",
        "PositionReports", "ImportSessions", "ImportSessionValueReports",
        "ExchangeRates", "ClassTargets", "SubClassTargets", "TargetChangeLog",
    ]

    var fullTables: [String] {
        Array(Set(referenceTables + transactionTables)).sorted()
    }

    init() {
        timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        scheduleEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupsEnabled)
        if let timeStr = UserDefaults.standard.string(forKey: UserDefaultsKeys.automaticBackupTime),
           let date = timeFormatter.date(from: timeStr)
        {
            scheduledTime = date
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

    private func scriptCacheDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport.appendingPathComponent("DragonShield/python_scripts", isDirectory: true)
    }

    private func scriptLookupCandidates() -> [URL] {
        let envPath = ProcessInfo.processInfo.environment["DS_BACKUP_RESTORE_SCRIPT"]
        let bundleRoot = Bundle.main.resourceURL
        let devRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let cacheDir = scriptCacheDirectory()

        return [
            envPath.flatMap { URL(fileURLWithPath: $0) },
            cacheDir.appendingPathComponent("backup_restore.py"),
            Bundle.main.url(forResource: "backup_restore", withExtension: "py"),
            bundleRoot?.appendingPathComponent("python_scripts/backup_restore.py"),
            bundleRoot?.appendingPathComponent("backup_restore.py"),
            devRoot.appendingPathComponent("python_scripts/backup_restore.py"),
            cwd.appendingPathComponent("DragonShield/python_scripts/backup_restore.py"),
            cwd.appendingPathComponent("python_scripts/backup_restore.py"),
        ].compactMap { $0 }
    }

    private func materializeBundledScript(into destination: URL) -> URL? {
        let fm = FileManager.default
        let bundleSources = [
            Bundle.main.url(forResource: "backup_restore", withExtension: "py"),
            Bundle.main.resourceURL?.appendingPathComponent("python_scripts/backup_restore.py"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("python_scripts/backup_restore.py"),
        ].compactMap { $0 }

        guard let source = bundleSources.first(where: { fm.fileExists(atPath: $0.path) }) else {
            return nil
        }

        do {
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    private func resolveBackupRestoreScript() -> URL? {
        let fm = FileManager.default

        if let cachedScriptURL, fm.fileExists(atPath: cachedScriptURL.path) {
            return cachedScriptURL
        }

        for candidate in scriptLookupCandidates() where fm.fileExists(atPath: candidate.path) {
            cachedScriptURL = candidate
            return candidate
        }

        let cacheDestination = scriptCacheDirectory().appendingPathComponent("backup_restore.py")
        if let materialized = materializeBundledScript(into: cacheDestination), fm.fileExists(atPath: materialized.path) {
            cachedScriptURL = materialized
            return materialized
        }

        return nil
    }

    private func runPython(arguments: [String], allowNonZeroExit: Bool) throws -> (String, Int32) {
        guard let scriptURL = resolveBackupRestoreScript() else {
            throw NSError(
                domain: "BackupServiceError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey:
                    """
                    Python helper not found. Expected backup_restore.py at one of:
                    \(scriptLookupCandidates().map { "• \($0.path)" }.joined(separator: "\n"))
                    You can also set DS_BACKUP_RESTORE_SCRIPT to the full path of the script.
                    """
                ]
            )
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptURL.path] + arguments
        process.environment = PythonEnvironment.enrichedEnvironment(anchorFile: #filePath)
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0, !allowNonZeroExit {
            throw NSError(
                domain: "BackupServiceError",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        }

        return (output, process.terminationStatus)
    }

    private func runPythonScript(arguments: [String]) throws -> String {
        try runPython(arguments: arguments, allowNonZeroExit: false).0
    }

    private func runPythonScriptWithStatus(arguments: [String]) throws -> (String, Int32) {
        try runPython(arguments: arguments, allowNonZeroExit: true)
    }

    func validateInstruments(dbManager: DatabaseManager) throws -> InstrumentValidationResult {
        let dbPath = dbManager.dbFilePath
        let (output, status) = try runPythonScriptWithStatus(arguments: ["validate", dbPath])
        let report = parseValidationReport(from: output)

        if status != 0, report == nil {
            throw NSError(
                domain: "BackupServiceError",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        }

        return InstrumentValidationResult(report: report, rawOutput: output, exitCode: status)
    }

    private func parseValidationReport(from output: String) -> InstrumentValidationReport? {
        guard let start = output.firstIndex(of: "{"), let end = output.lastIndex(of: "}") else { return nil }
        let jsonString = String(output[start ... end])
        guard let data = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(InstrumentValidationReport.self, from: data)
    }

    func performBackup(dbManager: DatabaseManager, to destination: URL) throws {
        let dbPath = dbManager.dbFilePath
        let destDir = destination.deletingLastPathComponent().path
        let env = dbManager.dbMode == .production ? "prod" : "test"

        let output = try runPythonScript(arguments: ["backup", "--env", env, dbPath, destDir])

        DispatchQueue.main.async {
            self.logMessages.insert(output, at: 0)
            self.appendLog(action: "Full Backup", file: destination.lastPathComponent, success: true)
        }

        let manifestURL = destination.appendingPathExtension("manifest.json")
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(BackupManifest.self, from: data)
            let report = manifest.validationReport

            if report.hasCriticalIssues || report.hasWarnings {
                let message = "Backup completed with \(report.totalIssues) issues (Critical: \(report.hasCriticalIssues)). See manifest for details."
                DispatchQueue.main.async {
                    self.logMessages.insert("⚠️ \(message)", at: 0)
                }
            }
        }
    }

    // ==============================================================================
    // == REWRITTEN SAFER RESTORE METHOD                                           ==
    // ==============================================================================
    func performRestore(dbManager: DatabaseManager, from backupURL: URL) throws -> [RestoreDelta] {
        let dbPath = dbManager.dbFilePath

        // --- Stage 1: Python prepares a temporary, validated restore file ---
        let pythonOutput = try runPythonScript(arguments: ["restore", dbPath, backupURL.path])

        // The Python script prints the path of the temporary file as its last line.
        guard let tempPath = pythonOutput.split(separator: "\n").last.map(String.init),
              FileManager.default.fileExists(atPath: tempPath)
        else {
            throw NSError(domain: "BackupServiceError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Python script failed to create a temporary restore file."])
        }

        let tempURL = URL(fileURLWithPath: tempPath)
        defer {
            // Clean up the temporary file when we're done.
            try? FileManager.default.removeItem(at: tempURL)
        }

        // --- Stage 2: Swift performs a live, atomic restore using SQLite's Backup API ---

        // Get pre-restore counts from the live database
        let preCounts = rowCounts(db: dbManager.db!, tables: fullTables)

        var pBackup: OpaquePointer?
        var pSrc: OpaquePointer?

        // Open a connection to the temporary source database
        guard sqlite3_open(tempPath, &pSrc) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not open temporary restore database."])
        }
        defer { sqlite3_close(pSrc) }

        // Initialize the backup process from the temp file ("main") to the live DB ("main")
        pBackup = sqlite3_backup_init(dbManager.db!, "main", pSrc, "main")
        guard pBackup != nil else {
            let msg = String(cString: sqlite3_errmsg(dbManager.db!))
            throw NSError(domain: "SQLite", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize restore: \(msg)"])
        }

        // Perform the restore in one step (-1 means copy all pages)
        let result = sqlite3_backup_step(pBackup, -1)
        if result != SQLITE_DONE {
            let msg = String(cString: sqlite3_errmsg(dbManager.db!))
            sqlite3_backup_finish(pBackup)
            throw NSError(domain: "SQLite", code: 5, userInfo: [NSLocalizedDescriptionKey: "Restore failed during copy step: \(msg) (Code: \(result))"])
        }

        // Finalize the backup process
        sqlite3_backup_finish(pBackup)

        // Get post-restore counts and create the delta summary
        let postCounts = rowCounts(db: dbManager.db!, tables: fullTables)

        var deltas: [RestoreDelta] = []
        let allTables = Set(preCounts.map { $0.0 } + postCounts.map { $0.0 })
        for table in allTables.sorted() {
            let pre = preCounts.first { $0.0 == table }?.1 ?? 0
            let post = postCounts.first { $0.0 == table }?.1 ?? 0
            deltas.append(RestoreDelta(table: table, preCount: pre, postCount: post))
        }

        DispatchQueue.main.async {
            self.logMessages.insert(pythonOutput, at: 0)
            self.appendLog(action: "Full Restore", file: backupURL.lastPathComponent, success: true)
        }

        // Reload app state after successful restore
        dbManager.reopenDatabase()

        return deltas
    }

    private func parseRestoreDeltas(from output: String) -> [RestoreDelta] {
        var deltas: [RestoreDelta] = []
        let lines = output.split(separator: "\n")
        guard let summaryIndex = lines.firstIndex(where: { $0.contains("Restore Summary") }) else { return [] }

        for line in lines.suffix(from: summaryIndex + 2) {
            let components = line.split(whereSeparator: \.isWhitespace)
            if components.count >= 4 {
                let table = String(components[0])
                let preCount = Int(components[1]) ?? 0
                let postCount = Int(components[2]) ?? 0
                deltas.append(RestoreDelta(table: table, preCount: preCount, postCount: postCount))
            }
        }
        return deltas
    }

    func backupReferenceData(dbManager: DatabaseManager, to destination: URL) throws -> URL {
        let dbPath = dbManager.dbFilePath
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        defer { sqlite3_close(db) }

        var dump = "PRAGMA foreign_keys=OFF;\nBEGIN TRANSACTION;\n"

        for table in referenceTables {
            var stmt: OpaquePointer?
            let sqlQuery = "SELECT sql FROM sqlite_master WHERE type='table' AND name='\(table)';"
            if sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW, let cStr = sqlite3_column_text(stmt, 0) {
                    dump += String(cString: cStr) + ";\n"
                }
            }
            sqlite3_finalize(stmt)

            let query = "SELECT * FROM \(table);"
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                let columns = Int(sqlite3_column_count(stmt))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    var values: [String] = []
                    for i in 0 ..< columns {
                        if let text = sqlite3_column_text(stmt, Int32(i)) {
                            let val = escape(String(cString: text))
                            values.append("'\(val)'")
                        } else {
                            values.append("NULL")
                        }
                    }
                    dump += "INSERT INTO \(table) VALUES (\(values.joined(separator: ", ")));\n"
                }
            }
            sqlite3_finalize(stmt)
        }

        dump += "COMMIT;\nPRAGMA foreign_keys=ON;\n"

        try dump.write(to: destination, atomically: true, encoding: .utf8)

        let tableCounts = rowCounts(db: db, tables: referenceTables)
        let tsRef = Date()
        UserDefaults.standard.set(tsRef, forKey: UserDefaultsKeys.lastReferenceBackupTimestamp)

        DispatchQueue.main.async {
            self.lastReferenceBackup = tsRef
            let summary = tableCounts.map { "\($0.0): \($0.1)" }.joined(separator: ", ")
            self.logMessages.append("✅ Backed up Reference data — " + summary)
            self.appendLog(action: "RefBackup", file: destination.lastPathComponent, success: true)
            self.lastActionSummaries = self.referenceTables.map { tbl in
                TableActionSummary(table: tbl, action: "Backed up", count: (try? dbManager.rowCount(table: tbl)) ?? 0)
            }
        }

        return destination
    }

    func restoreReferenceData(dbManager: DatabaseManager, from url: URL) throws {
        guard let db = dbManager.db else { return }
        let rawSQL = try String(contentsOf: url, encoding: .utf8)

        let cleanedSQL = rawSQL
            .replacingOccurrences(of: "PRAGMA foreign_keys=OFF;", with: "")
            .replacingOccurrences(of: "BEGIN TRANSACTION;", with: "")
            .replacingOccurrences(of: "COMMIT;", with: "")
            .replacingOccurrences(of: "PRAGMA foreign_keys=ON;", with: "")

        try execute("PRAGMA foreign_keys=OFF;", on: db)
        try execute("BEGIN TRANSACTION;", on: db)

        for table in referenceTables {
            try execute("DROP TABLE IF EXISTS \(table);", on: db)
        }

        if sqlite3_exec(db, cleanedSQL, nil, nil, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
            appendLog(action: "RefRestore", file: url.lastPathComponent, success: false, message: msg)
            throw NSError(domain: "Restore", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        try execute("COMMIT;", on: db)
        try execute("PRAGMA foreign_keys=ON;", on: db)

        dbManager.dbVersion = dbManager.loadConfiguration()
        let tableCounts = rowCounts(db: db, tables: referenceTables)
        let tsRef = Date()
        UserDefaults.standard.set(tsRef, forKey: UserDefaultsKeys.lastReferenceBackupTimestamp)
        DispatchQueue.main.async {
            self.lastReferenceBackup = tsRef
            let summary = tableCounts.map { "\($0.0): \($0.1)" }.joined(separator: ", ")
            self.logMessages.append("✅ Restored Reference data — " + summary)
            self.appendLog(action: "RefRestore", file: url.lastPathComponent, success: true)
            self.lastActionSummaries = self.referenceTables.map { table in
                TableActionSummary(table: table, action: "Restored", count: (try? dbManager.rowCount(table: table)) ?? 0)
            }
        }
    }

    func backupTransactionData(dbManager: DatabaseManager, to destination: URL, tables: [String]) throws -> URL {
        let dbPath = dbManager.dbFilePath
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        defer { sqlite3_close(db) }

        var dump = "PRAGMA foreign_keys=OFF;\nBEGIN TRANSACTION;\n"
        for table in tables {
            var stmt: OpaquePointer?
            let sqlQuery = "SELECT sql FROM sqlite_master WHERE type='table' AND name='\(table)';"
            if sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW, let cStr = sqlite3_column_text(stmt, 0) {
                    dump += String(cString: cStr) + ";\n"
                }
            }
            sqlite3_finalize(stmt)

            let query = "SELECT * FROM \(table);"
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                let columns = Int(sqlite3_column_count(stmt))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    var values: [String] = []
                    for i in 0 ..< columns {
                        if let text = sqlite3_column_text(stmt, Int32(i)) {
                            let val = escape(String(cString: text))
                            values.append("'\(val)'")
                        } else {
                            values.append("NULL")
                        }
                    }
                    dump += "INSERT INTO \(table) VALUES (\(values.joined(separator: ", ")));\n"
                }
            }
            sqlite3_finalize(stmt)
        }

        dump += "COMMIT;\nPRAGMA foreign_keys=ON;\n"

        try dump.write(to: destination, atomically: true, encoding: .utf8)

        var counts = [String]()
        for tbl in tables {
            if let n = try? dbManager.rowCount(table: tbl) { counts.append("\(tbl): \(n)") }
        }
        DispatchQueue.main.async {
            self.logMessages.append("✅ Backed up Transaction data — " + counts.joined(separator: ", "))
            self.appendLog(action: "TxnBackup", file: destination.lastPathComponent, success: true)
            self.lastActionSummaries = tables.map { table in
                TableActionSummary(table: table, action: "Backed up", count: (try? dbManager.rowCount(table: table)) ?? 0)
            }
        }

        return destination
    }

    func restoreTransactionData(dbManager: DatabaseManager, from url: URL, tables: [String]) throws {
        guard let db = dbManager.db else { return }
        let rawSQL = try String(contentsOf: url, encoding: .utf8)

        let cleanedSQL = rawSQL
            .replacingOccurrences(of: "PRAGMA foreign_keys=OFF;", with: "")
            .replacingOccurrences(of: "BEGIN TRANSACTION;", with: "")
            .replacingOccurrences(of: "COMMIT;", with: "")
            .replacingOccurrences(of: "PRAGMA foreign_keys=ON;", with: "")

        try execute("PRAGMA foreign_keys=OFF;", on: db)
        try execute("BEGIN TRANSACTION;", on: db)

        for table in tables {
            try execute("DROP TABLE IF EXISTS \(table);", on: db)
        }

        if sqlite3_exec(db, cleanedSQL, nil, nil, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
            appendLog(action: "TxnRestore", file: url.lastPathComponent, success: false, message: msg)
            throw NSError(domain: "Restore", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        try execute("COMMIT;", on: db)
        try execute("PRAGMA foreign_keys=ON;", on: db)

        var counts = [String]()
        for tbl in tables {
            if let n = try? dbManager.rowCount(table: tbl) { counts.append("\(tbl): \(n)") }
        }
        DispatchQueue.main.async {
            self.logMessages.append("✅ Restored Transaction data — " + counts.joined(separator: ", "))
            self.appendLog(action: "TxnRestore", file: url.lastPathComponent, success: true)
            self.lastActionSummaries = tables.map { table in
                TableActionSummary(table: table, action: "Restored", count: (try? dbManager.rowCount(table: table)) ?? 0)
            }
        }
    }

    private func execute(_ sql: String, on db: OpaquePointer) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private func appendLog(action: String, file: String, success: Bool, message: String? = nil) {
        var entry = "[\(isoFormatter.string(from: Date()))] \(action) \(file) \(success ? "Success" : "Error")"
        if let message = message { entry += " - \(message)" }
        DispatchQueue.main.async {
            self.logMessages.insert(entry, at: 0)
            if self.logMessages.count > 10 { self.logMessages = Array(self.logMessages.prefix(10)) }
            UserDefaults.standard.set(self.logMessages, forKey: UserDefaultsKeys.backupLog)
        }
    }

    private func rowCounts(dbPath: String, tables: [String]) -> [(String, Int)] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else { return [] }
        defer { sqlite3_close(db) }
        return rowCounts(db: db, tables: tables)
    }

    private func rowCounts(db: OpaquePointer, tables: [String]) -> [(String, Int)] {
        var result: [(String, Int)] = []
        var stmt: OpaquePointer?
        for table in tables {
            if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table);", -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    result.append((table, Int(sqlite3_column_int(stmt, 0))))
                }
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
}
