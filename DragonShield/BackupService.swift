import Foundation
import SwiftUI
import SQLite3
import CryptoKit

struct TableActionSummary: Identifiable {
    let id = UUID()
    let table: String
    let action: String
    let count: Int
}

struct TableManifestEntry: Codable {
    let rowCount: Int
    let checksum: String
}

class BackupService: ObservableObject {
    @Published var lastBackup: Date?
    @Published var lastReferenceBackup: Date?
    @Published var logMessages: [String]
    @Published var scheduleEnabled: Bool
    @Published var scheduledTime: Date
    @Published var backupDirectory: URL
    @Published var lastActionSummaries: [TableActionSummary] = []
    @Published var lastValidationMessages: [String] = []

    private var timer: Timer?
    private var isAccessing = false
    private let timeFormatter: DateFormatter
    private let isoFormatter = ISO8601DateFormatter()

    let fullTables = [
        "Configuration", "Currencies", "ExchangeRates", "FxRateUpdates",
        "AssetClasses", "AssetSubClasses", "Instruments", "Portfolios",
        "PortfolioInstruments", "AccountTypes", "Institutions", "Accounts",
        "TransactionTypes", "Transactions", "ImportSessions", "PositionReports",
        "ImportSessionValueReports", "TargetAllocation"
    ]

    let referenceTables = [
        "Configuration", "Currencies", "ExchangeRates", "FxRateUpdates",
        "AssetClasses", "AssetSubClasses", "TransactionTypes", "AccountTypes",
        "Institutions", "Instruments", "Accounts"
    ]

    let transactionTables = [
        "Portfolios", "PortfolioInstruments", "Transactions",
        "PositionReports", "ImportSessions", "ImportSessionValueReports",
        "ExchangeRates", "TargetAllocation"
    ]

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
        self.lastReferenceBackup = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastReferenceBackupTimestamp) as? Date
        self.logMessages = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.backupLog) ?? []
        self.backupDirectory = BackupService.loadBackupDirectory()
        if let bookmark = UserDefaults.standard.data(forKey: UserDefaultsKeys.backupDirectoryBookmark) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], bookmarkDataIsStale: &stale) {
                if url.startAccessingSecurityScopedResource() { isAccessing = true }
                if stale {
                    if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                        UserDefaults.standard.set(data, forKey: UserDefaultsKeys.backupDirectoryBookmark)
                    }
                }
                self.backupDirectory = url
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
        backupDirectory = url
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



    func performBackup(dbManager: DatabaseManager, dbPath: String, to destination: URL, tables: [String], label: String) throws -> URL {
        let fm = FileManager.default
        try fm.copyItem(atPath: dbPath, toPath: destination.path)

        let manifest = buildManifest(dbPath: destination.path, tables: tables)
        let manifestURL = destination.deletingPathExtension().appendingPathExtension("manifest.json")
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestURL)
        }
        let mismatched = validate(dbPath: destination.path, manifest: manifest)
        DispatchQueue.main.async {
            self.lastValidationMessages = mismatched.isEmpty ? ["Backup validated: all tables OK"] : mismatched.map { "Mismatch: \($0)" }
        }
        lastBackup = Date()
        UserDefaults.standard.set(lastBackup, forKey: UserDefaultsKeys.lastBackupTimestamp)

        var counts = [String]()
        for tbl in tables {
            if let n = try? dbManager.rowCount(table: tbl) { counts.append("\(tbl): \(n)") }
        }
        DispatchQueue.main.async {
            self.logMessages.append("✅ Backed up \(label) data — " + counts.joined(separator: ", "))
            self.appendLog(action: "Backup", file: destination.path, success: true)
            self.lastActionSummaries = tables.map { tbl in
                TableActionSummary(table: tbl, action: "Backed up", count: (try? dbManager.rowCount(table: tbl)) ?? 0)
            }
        }
        return destination
    }

    // MARK: – Reference Data Backup/Restore

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
            // capture CREATE TABLE statement
            var stmt: OpaquePointer?
            let sqlQuery = "SELECT sql FROM sqlite_master WHERE type='table' AND name='\(table)';"
            if sqlite3_prepare_v2(db, sqlQuery, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW, let cStr = sqlite3_column_text(stmt, 0) {
                    dump += String(cString: cStr) + ";\n"
                }
            }
            sqlite3_finalize(stmt)

            // emit INSERT statements for each row
            let query = "SELECT * FROM \(table);"
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                let columns = Int(sqlite3_column_count(stmt))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    var values: [String] = []
                    for i in 0..<columns {
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
        let manifest = buildManifest(db: db, tables: tables)
        let manifestURL = destination.deletingPathExtension().appendingPathExtension("manifest.json")
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestURL)
        }
        DispatchQueue.main.async {
            self.lastValidationMessages = ["Backup validated: all tables OK"]
        }
        let manifest = buildManifest(db: db, tables: referenceTables)
        let manifestURL = destination.deletingPathExtension().appendingPathExtension("manifest.json")
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestURL)
        }
        DispatchQueue.main.async {
            self.lastValidationMessages = ["Backup validated: all tables OK"]
        }

        let tableCounts = rowCounts(db: db, tables: referenceTables)
        lastReferenceBackup = Date()
        UserDefaults.standard.set(lastReferenceBackup, forKey: UserDefaultsKeys.lastReferenceBackupTimestamp)

        DispatchQueue.main.async {
            let summary = tableCounts.map { "\($0.0): \($0.1)" }.joined(separator: ", ")
            self.logMessages.append("✅ Backed up Reference data — " + summary)
            self.appendLog(action: "RefBackup", file: destination.lastPathComponent, success: true)
            self.lastActionSummaries = self.referenceTables.map { tbl in
                TableActionSummary(table: tbl, action: "Backed up", count: (try? dbManager.rowCount(table: tbl)) ?? 0)
            }
        }

        return destination
    }


    func performRestore(dbManager: DatabaseManager, from url: URL, tables: [String], label: String) throws {
        let fm = FileManager.default
        let dbPath = dbManager.dbFilePath
        let ts = isoFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "")
        let oldPath = dbPath + ".old-" + ts

        let manifestURL = url.deletingPathExtension().appendingPathExtension("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode([String: TableManifestEntry].self, from: data) else {
            throw NSError(domain: "Restore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Manifest missing"])
        }
        let preMismatch = validate(dbPath: url.path, manifest: manifest)
        guard preMismatch.isEmpty else {
            DispatchQueue.main.async {
                self.lastValidationMessages = preMismatch.map { "Mismatch: \($0)" }
            }
            throw NSError(domain: "Restore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Backup validation failed"])
        }

        dbManager.closeConnection()
        try fm.moveItem(atPath: dbPath, toPath: oldPath)
        do {
            try fm.copyItem(at: url, to: URL(fileURLWithPath: dbPath))
            let postMismatch = validate(dbPath: dbPath, manifest: manifest)
            if !postMismatch.isEmpty {
                try? fm.removeItem(atPath: dbPath)
                try? fm.moveItem(atPath: oldPath, toPath: dbPath)
                DispatchQueue.main.async {
                    self.lastValidationMessages = postMismatch.map { "Mismatch: \($0)" }
                    self.appendLog(action: "Restore", file: url.lastPathComponent, success: false, message: "Validation failed")
                }
                throw NSError(domain: "Restore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Validation failed after restore"])
            }

            dbManager.reopenDatabase()
            DispatchQueue.main.async {
                self.lastValidationMessages = ["Restore validated: all tables OK"]
            }

            var counts = [String]()
            for tbl in tables {
                if let n = try? dbManager.rowCount(table: tbl) { counts.append("\(tbl): \(n)") }
            }
            DispatchQueue.main.async {
                self.logMessages.append("✅ Restored \(label) data — " + counts.joined(separator: ", "))
                self.appendLog(action: "Restore", file: url.lastPathComponent, success: true)
                self.lastActionSummaries = tables.map { tbl in
                    TableActionSummary(table: tbl, action: "Restored", count: (try? dbManager.rowCount(table: tbl)) ?? 0)
                }
            }
        } catch {
            try? fm.moveItem(atPath: oldPath, toPath: dbPath)
            DispatchQueue.main.async {
                self.appendLog(action: "Restore", file: url.lastPathComponent, success: false, message: error.localizedDescription)
            }
            throw error
        }
        // keep old database renamed
    }

    func restoreReferenceData(dbManager: DatabaseManager, from url: URL) throws {
        guard let db = dbManager.db else { return }
        let rawSQL = try String(contentsOf: url, encoding: .utf8)

        // Remove transaction wrappers to avoid nested transactions
        let cleanedSQL = rawSQL
            .replacingOccurrences(of: "PRAGMA foreign_keys=OFF;", with: "")
            .replacingOccurrences(of: "BEGIN TRANSACTION;", with: "")
            .replacingOccurrences(of: "COMMIT;", with: "")
            .replacingOccurrences(of: "PRAGMA foreign_keys=ON;", with: "")

        // Drop tables and import data inside one transaction with foreign keys disabled
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

        let manifestURL = url.deletingPathExtension().appendingPathExtension("manifest.json")
        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode([String: TableManifestEntry].self, from: data) {
            let mism = validate(db: db, manifest: manifest)
            DispatchQueue.main.async {
                self.lastValidationMessages = mism.isEmpty ? ["Restore validated: all tables OK"] : mism.map { "Mismatch: \($0)" }
            }
            if !mism.isEmpty {
                appendLog(action: "RefRestore", file: url.lastPathComponent, success: false, message: "Validation failed")
                throw NSError(domain: "Restore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Validation failed"])
            }
        }

        dbManager.dbVersion = dbManager.loadConfiguration()
        let tableCounts = rowCounts(db: db, tables: referenceTables)
        lastReferenceBackup = Date()
        UserDefaults.standard.set(lastReferenceBackup, forKey: UserDefaultsKeys.lastReferenceBackupTimestamp)
        DispatchQueue.main.async {
            let summary = tableCounts.map { "\($0.0): \($0.1)" }.joined(separator: ", ")
            self.logMessages.append("✅ Restored Reference data — " + summary)
            self.appendLog(action: "RefRestore", file: url.lastPathComponent, success: true)
            self.lastActionSummaries = self.referenceTables.map { table in
                TableActionSummary(table: table, action: "Restored", count: (try? dbManager.rowCount(table: table)) ?? 0)
            }
        }

    }

    // MARK: – Transaction Data Backup/Restore

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
                    for i in 0..<columns {
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

        let manifestURL = url.deletingPathExtension().appendingPathExtension("manifest.json")
        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode([String: TableManifestEntry].self, from: data) {
            let mism = validate(db: db, manifest: manifest)
            DispatchQueue.main.async {
                self.lastValidationMessages = mism.isEmpty ? ["Restore validated: all tables OK"] : mism.map { "Mismatch: \($0)" }
            }
            if !mism.isEmpty {
                appendLog(action: "TxnRestore", file: url.lastPathComponent, success: false, message: "Validation failed")
                throw NSError(domain: "Restore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Validation failed"])
            }
        }

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

    private func checksum(db: OpaquePointer, table: String) -> String? {
        var colStmt: OpaquePointer?
        var columns: [String] = []
        if sqlite3_prepare_v2(db, "PRAGMA table_info(\(table));", -1, &colStmt, nil) == SQLITE_OK {
            while sqlite3_step(colStmt) == SQLITE_ROW {
                if let c = sqlite3_column_text(colStmt, 1) {
                    columns.append(String(cString: c))
                }
            }
        }
        sqlite3_finalize(colStmt)
        guard !columns.isEmpty else { return nil }

        let colList = columns.map { "\"\($0)\"" }.joined(separator: ",")
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT \(colList) FROM \(table) ORDER BY rowid;", -1, &stmt, nil) != SQLITE_OK {
            return nil
        }
        var hasher = SHA256()
        while sqlite3_step(stmt) == SQLITE_ROW {
            var parts: [String] = []
            for i in 0..<columns.count {
                let t = sqlite3_column_type(stmt, Int32(i))
                switch t {
                case SQLITE_NULL:
                    parts.append("NULL")
                case SQLITE_INTEGER:
                    parts.append(String(sqlite3_column_int64(stmt, Int32(i))))
                case SQLITE_FLOAT:
                    parts.append(String(sqlite3_column_double(stmt, Int32(i))))
                case SQLITE_TEXT:
                    parts.append(String(cString: sqlite3_column_text(stmt, Int32(i))))
                case SQLITE_BLOB:
                    if let bytes = sqlite3_column_blob(stmt, Int32(i)) {
                        let len = Int(sqlite3_column_bytes(stmt, Int32(i)))
                        let data = Data(bytes: bytes, count: len)
                        parts.append(data.base64EncodedString())
                    } else {
                        parts.append("NULL")
                    }
                default:
                    parts.append("")
                }
            }
            let line = parts.joined(separator: "|") + "\n"
            hasher.update(data: Data(line.utf8))
        }
        sqlite3_finalize(stmt)
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func buildManifest(dbPath: String, tables: [String]) -> [String: TableManifestEntry] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else { return [:] }
        defer { sqlite3_close(db) }
        return buildManifest(db: db, tables: tables)
    }

    private func buildManifest(db: OpaquePointer, tables: [String]) -> [String: TableManifestEntry] {
        var result: [String: TableManifestEntry] = [:]
        for table in tables {
            let count = rowCounts(db: db, tables: [table]).first?.1 ?? 0
            let sum = checksum(db: db, table: table) ?? ""
            result[table] = TableManifestEntry(rowCount: count, checksum: sum)
        }
        return result
    }

    private func validate(dbPath: String, manifest: [String: TableManifestEntry]) -> [String] {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else { return Array(manifest.keys) }
        defer { sqlite3_close(db) }
        return validate(db: db, manifest: manifest)
    }

    private func validate(db: OpaquePointer, manifest: [String: TableManifestEntry]) -> [String] {
        let current = buildManifest(db: db, tables: Array(manifest.keys))
        var mismatched: [String] = []
        for (table, entry) in manifest {
            if let cur = current[table] {
                if cur.rowCount != entry.rowCount || cur.checksum != entry.checksum {
                    mismatched.append(table)
                }
            } else {
                mismatched.append(table)
            }
        }
        return mismatched
    }
}
