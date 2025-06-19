// DragonShield/DatabaseManager.swift
// MARK: - Version 1.5
// MARK: - History
// - 1.3 -> 1.4: Added @Published properties for defaultTimeZone, tableRowSpacing, tableRowPadding.
// - 1.4 -> 1.5: Added dbVersion property and logging of database version.
// - 1.2 -> 1.3: Modified #if DEBUG block to use a UserDefaults setting for forcing DB re-copy.
// - 1.1 -> 1.2: Added a #if DEBUG block to init() to force delete/re-copy database from bundle.

import SQLite3
import Foundation

class DatabaseManager: ObservableObject {
    var db: OpaquePointer?
    private var dbPath: String
    
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
    // Add other config items as @Published if they need to be globally observable
    // For fx_api_provider, fx_update_frequency, we might just display them or use TextFields

    init() {
        // ... (init logic remains the same as v1.3) ...
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("DragonShield")
        
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        self.dbPath = appDir.appendingPathComponent("dragonshield.sqlite").path
        
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
        } else {
             print("✅ Using existing database at: \(dbPath)")
        }
        
        openDatabase()
        loadConfiguration()
        print("📂 Database path: \(dbPath) | version: \(dbVersion)")
    }
    
    private func openDatabase() {
        // ... (openDatabase logic remains the same as v1.3) ...
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
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
            print("❌ Failed to open database: \(String(cString: sqlite3_errmsg(db)))")
        }
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
