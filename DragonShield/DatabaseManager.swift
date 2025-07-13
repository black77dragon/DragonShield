// DragonShield/DatabaseManager.swift
// MARK: - Version 1.6.0.1
// MARK: - History
// - 1.5 -> 1.6: Expose database path, creation date and modification date via
//               @Published properties.
// - 1.6 -> 1.6.0.1: Use sqlite3_open_v2 with FULLMUTEX and log errors when opening fails.
// - 1.3 -> 1.4: Added @Published properties for defaultTimeZone, tableRowSpacing, tableRowPadding.
// - 1.4 -> 1.5: Added dbVersion property and logging of database version.
// - 1.2 -> 1.3: Modified #if DEBUG block to use a UserDefaults setting for forcing DB re-copy.
// - 1.1 -> 1.2: Added a #if DEBUG block to init() to force delete/re-copy database from bundle.

import SQLite3
import Foundation

enum DatabaseMode: String {
    case production
    case test
}

class DatabaseManager: ObservableObject {
    var db: OpaquePointer?
    private var dbPath: String
    private let appDir: URL

    @Published var dbMode: DatabaseMode
    @Published var dbFileSize: Int64 = 0
    
    // Existing @Published properties
    @Published var baseCurrency: String = "CHF"
    @Published var asOfDate: Date = Date() // This is loaded, but not typically user-editable in settings in the same way
    @Published var decimalPrecision: Int = 4
    @Published var autoFxUpdate: Bool = true

    // New @Published properties from Configuration table
    @Published var defaultTimeZone: String = "Europe/Zurich"
    @Published var tableRowSpacing: Double = 1.0
    @Published var tableRowPadding: Double = 12.0
    @Published var dbVersion: String = ""
    @Published var dbFilePath: String = ""
    @Published var dbCreated: Date?
    @Published var dbModified: Date?
    @Published var productionDBPath: String = ""
    @Published var testDBPath: String = ""

    private let configURL: URL

struct DBPaths: Codable {
    var production_db_path: String
    var test_db_path: String
}

private var dbConfig: DBPaths

    private static func loadConfig(at url: URL, defaultProd: String, defaultTest: String) -> DBPaths {
        if let data = try? Data(contentsOf: url),
           let cfg = try? JSONDecoder().decode(DBPaths.self, from: data) {
            return cfg
        }
        let cfg = DBPaths(production_db_path: defaultProd, test_db_path: defaultTest)
        if let data = try? JSONEncoder().encode(cfg) {
            try? data.write(to: url, options: .atomic)
        }
        return cfg
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(dbConfig) {
            try? data.write(to: configURL, options: .atomic)
        }
    }
    // Add other config items as @Published if they need to be globally observable
    // For fx_api_provider, fx_update_frequency, we might just display them or use TextFields

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appDir = appSupport.appendingPathComponent("DragonShield")

        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.configURL = appDir.appendingPathComponent("config.json")

        let savedMode = UserDefaults.standard.string(forKey: UserDefaultsKeys.databaseMode)
        let mode = DatabaseMode(rawValue: savedMode ?? "production") ?? .production
        self.dbMode = mode

        let defaultProd = appDir.appendingPathComponent(DatabaseManager.fileName(for: .production)).path
        let defaultTest = appDir.appendingPathComponent(DatabaseManager.fileName(for: .test)).path
        self.dbConfig = DatabaseManager.loadConfig(at: configURL, defaultProd: defaultProd, defaultTest: defaultTest)
        self.productionDBPath = dbConfig.production_db_path
        self.testDBPath = dbConfig.test_db_path

        self.dbPath = mode == .production ? dbConfig.production_db_path : dbConfig.test_db_path

        
        #if DEBUG
        let shouldForceReCopy = UserDefaults.standard.bool(forKey: UserDefaultsKeys.forceOverwriteDatabaseOnDebug)
        if shouldForceReCopy && FileManager.default.fileExists(atPath: dbPath) {
            do {
                try FileManager.default.removeItem(atPath: dbPath)
                print("🗑️ [DEBUG] Deleted existing database at: \(dbPath) (Force Re-Copy Setting is ON)")
            } catch {
                print("⚠️ [DEBUG] Could not delete existing database for re-copy: \(error)")
            }
        }
        #endif
        
        if !FileManager.default.fileExists(atPath: dbPath) {
            if let bundlePath = Bundle.main.path(forResource: "dragonshield", ofType: "sqlite") {
                do {
                    try FileManager.default.copyItem(atPath: bundlePath, toPath: dbPath)
                    print("✅ Copied database from bundle to: \(dbPath)")
                } catch {
                    print("❌ Failed to copy database from bundle: \(error)")
                }
            } else {
                print("⚠️ Database 'dragonshield.sqlite' not found in app bundle.")
            }
        }

        openDatabase()
        migrateLegacyPathConfig()
        loadConfiguration()

        print("✅ Using database at: \(dbPath)")

        updateFileMetadata()
        print("📂 Database path: \(dbPath) | version: \(dbVersion)")
    }
    
    func openDatabase() {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK {
            print("✅ Database opened: \(dbPath)")
            sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
            let testQuery = "CREATE TABLE IF NOT EXISTS test_write_permission (id INTEGER);"
            if sqlite3_exec(db, testQuery, nil, nil, nil) == SQLITE_OK {
                sqlite3_exec(db, "DROP TABLE test_write_permission;", nil, nil, nil)
            } else {
                print("❌ Database write test failed: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            let msg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            print("❌ Failed to open database at \(dbPath): \(msg)")
        }
    }

    private func updateFileMetadata() {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: dbPath)
            DispatchQueue.main.async {
                self.dbFilePath = self.dbPath
                if let size = attrs[.size] as? NSNumber {
                    self.dbFileSize = size.int64Value
                }
                self.dbCreated = attrs[.creationDate] as? Date
                self.dbModified = attrs[.modificationDate] as? Date
            }
        } catch {
            print("⚠️ Failed to read DB file attributes: \(error)")
        }
    }

    func closeConnection() {
        if let pointer = db {
            sqlite3_close(pointer)
            db = nil
            print("✅ Database connection closed")
        }
    }

    func reopenDatabase() {
        closeConnection()
        openDatabase()
        loadConfiguration()
        updateFileMetadata()
    }

    func reopenDatabase(atPath path: String) {
        dbPath = path
        reopenDatabase()
    }

    func updateDBPath(_ path: String, isProduction: Bool) {
        if isProduction {
            productionDBPath = path
            dbConfig.production_db_path = path
        } else {
            testDBPath = path
            dbConfig.test_db_path = path
        }
        saveConfig()
    }

    func rowCount(table: String) throws -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT COUNT(*) FROM \(table);"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    func switchMode() {
        dbMode = dbMode == .production ? .test : .production
        UserDefaults.standard.set(dbMode.rawValue, forKey: UserDefaultsKeys.databaseMode)
        dbPath = dbMode == .production ? productionDBPath : testDBPath
        if !FileManager.default.fileExists(atPath: dbPath), let bundlePath = Bundle.main.path(forResource: "dragonshield", ofType: "sqlite") {
            try? FileManager.default.copyItem(atPath: bundlePath, toPath: dbPath)
        }

        reopenDatabase()
    }

    private func migrateLegacyPathConfig() {
        var statement: OpaquePointer?
        let sql = "SELECT key, value FROM Configuration WHERE key IN ('production_db_path','test_db_path');"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }

        var migrated = false
        while sqlite3_step(statement) == SQLITE_ROW {
            if let keyPtr = sqlite3_column_text(statement, 0),
               let valuePtr = sqlite3_column_text(statement, 1) {
                let key = String(cString: keyPtr)
                let value = String(cString: valuePtr)
                if !value.isEmpty {
                    if key == "production_db_path" {
                        productionDBPath = value
                        dbConfig.production_db_path = value
                    } else if key == "test_db_path" {
                        testDBPath = value
                        dbConfig.test_db_path = value
                    }
                    migrated = true
                }
            }
        }
        sqlite3_finalize(statement)

        if migrated {
            saveConfig()
            sqlite3_exec(db, "DELETE FROM Configuration WHERE key IN ('production_db_path','test_db_path');", nil, nil, nil)
            print("ℹ️ Migrated legacy database paths to config file")
        }
    }

    func runMigrations() {
        // Placeholder for future migration logic
        print("ℹ️ runMigrations called - no migrations to apply")
    }

    private static func fileName(for mode: DatabaseMode) -> String {
        mode == .production ? "dragonshield.sqlite" : "dragonshield_test.sqlite"
    }
    
    deinit {
        // ... (deinit logic remains the same as v1.3) ...
        if let dbPointer = db {
            sqlite3_close(dbPointer)
            print("✅ Database connection closed in deinit.")
            self.db = nil
        } else {
            print("ℹ️ Database connection was already nil in deinit.")
        }
    }
}
