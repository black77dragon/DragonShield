// DragonShield/DatabaseManager.swift
// MARK: - Version 1.6.0.2
// MARK: - History
// - 1.6.0.1 -> 1.6.0.2: Add feature flag for Portfolio Theme Updates.
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
    @Published var asOfDate: Date = Date()
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
    @Published var includeDirectRealEstate: Bool = true
    @Published var directRealEstateTargetCHF: Double = 0.0
    @Published var portfolioThemeUpdatesEnabled: Bool = false

    // ==============================================================================
    // == CORRECTED INIT METHOD                                                    ==
    // ==============================================================================
    init() {
        // This now correctly and permanently points to the sandboxed container directory.
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let containerPath = "Library/Containers/com.rene.DragonShield/Data/Library/Application Support"
        let appSupport = homeDir.appendingPathComponent(containerPath)
        self.appDir = appSupport.appendingPathComponent("DragonShield")

        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let savedMode = UserDefaults.standard.string(forKey: UserDefaultsKeys.databaseMode)
        let mode = DatabaseMode(rawValue: savedMode ?? "production") ?? .production
        self.dbMode = mode
        self.dbPath = appDir.appendingPathComponent(DatabaseManager.fileName(for: mode)).path
        self.portfolioThemeUpdatesEnabled = (mode == .test)

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
        ensurePortfolioThemeStatusDefault()
        ensurePortfolioThemeTable()
        ensurePortfolioThemeAssetTable()
        ensurePortfolioThemeUpdateTable()
        let version = loadConfiguration()
        self.dbVersion = version
        DispatchQueue.main.async { self.dbVersion = version }
        updateFileMetadata()
        print("📂 Database path: \(dbPath) | version: \(version)")
    }
    // ==============================================================================

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

    @discardableResult
    func closeConnection() -> Bool {
        if let pointer = db {
            let rc = sqlite3_close_v2(pointer)
            if rc == SQLITE_OK {
                db = nil
                print("✅ Database connection closed")
                return true
            } else {
                print("❌ sqlite3_close_v2 failed with code \(rc)")
                return false
            }
        }
        return true
    }

    func reopenDatabase() {
        closeConnection()
        openDatabase()
        let version = loadConfiguration()
        DispatchQueue.main.async { self.dbVersion = version }
        updateFileMetadata()
    }

    func rowCount(table: String) throws -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table)", -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.message("Failed to prepare count: \(String(cString: sqlite3_errmsg(db)))")
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw DatabaseError.message("Failed to step count: \(String(cString: sqlite3_errmsg(db)))")
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    static func fileName(for mode: DatabaseMode) -> String {
        switch mode {
        case .production: return "dragonshield.sqlite"
        case .test: return "dragonshield_test.sqlite"
        }
    }

    enum DatabaseError: Error {
        case message(String)
    }
}
