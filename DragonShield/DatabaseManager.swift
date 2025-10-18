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
    @Published var asOfDate: Date = Date()
    @Published var decimalPrecision: Int = 4

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
    // FX Auto Update configuration (defaults)
    @Published var fxAutoUpdateEnabled: Bool = true
    /// 'daily' or 'weekly'
    @Published var fxUpdateFrequency: String = "daily"
    // iOS Snapshot Export configuration (defaults)
    @Published var iosSnapshotAutoEnabled: Bool = true
    /// 'daily' or 'weekly'
    @Published var iosSnapshotFrequency: String = "daily"
    /// Destination folder for iOS snapshot export
    @Published var iosSnapshotTargetPath: String = ""
    @Published var iosSnapshotTargetBookmark: Data? = nil
    // Table view personalisation
    @Published var institutionsTableFontSize: String = "medium"
    @Published var institutionsTableColumnFractions: [String: Double] = [:]
    @Published var instrumentsTableFontSize: String = "medium"
    @Published var instrumentsTableColumnFractions: [String: Double] = [:]
    @Published var assetSubClassesTableFontSize: String = "medium"
    @Published var assetSubClassesTableColumnFractions: [String: Double] = [:]
    @Published var assetClassesTableFontSize: String = "medium"
    @Published var assetClassesTableColumnFractions: [String: Double] = [:]
    @Published var currenciesTableFontSize: String = "medium"
    @Published var currenciesTableColumnFractions: [String: Double] = [:]
    @Published var accountsTableFontSize: String = "medium"
    @Published var accountsTableColumnFractions: [String: Double] = [:]
    @Published var positionsTableFontSize: String = "medium"
    @Published var positionsTableColumnFractions: [String: Double] = [:]
    @Published var portfolioThemesTableFontSize: String = "medium"
    @Published var portfolioThemesTableColumnFractions: [String: Double] = [:]
    @Published var transactionTypesTableFontSize: String = "medium"
    @Published var transactionTypesTableColumnFractions: [String: Double] = [:]
    @Published var accountTypesTableFontSize: String = "medium"
    @Published var accountTypesTableColumnFractions: [String: Double] = [:]
    @Published var todoBoardFontSize: String = "medium"
    // Last trade error for UI feedback
    @Published var lastTradeErrorMessage: String? = nil

    // ==============================================================================
    // == CORRECTED INIT METHOD                                                    ==
    // ==============================================================================
    init() {
        #if os(macOS)
        // macOS app container directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let containerPath = "Library/Containers/com.rene.DragonShield/Data/Library/Application Support"
        let appSupport = homeDir.appendingPathComponent(containerPath)
        self.appDir = appSupport.appendingPathComponent("DragonShield")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let savedMode = UserDefaults.standard.string(forKey: UserDefaultsKeys.databaseMode)
        let mode = DatabaseMode(rawValue: savedMode ?? "production") ?? .production
        self.dbMode = mode
        self.dbPath = appDir.appendingPathComponent(DatabaseManager.fileName(for: mode)).path

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
        // Table setup and migrations are only needed on macOS (authoring environment).
        // The iOS app opens a read-only snapshot and does not create/modify schema.
        ensurePortfolioThemeStatusDefault()
        ensurePortfolioThemeTable()
        ensurePortfolioThemeAssetTable()
        ensurePortfolioThemeUpdateTable()
        ensurePortfolioThemeAssetUpdateTable()
        ensureAttachmentTable()
        ensureThemeUpdateAttachmentTable()
        ensureThemeAssetUpdateAttachmentTable()
        ensureAlertReferenceTables()
        // Trades schema now provisioned via db/migrations (dbmate). No runtime DDL here.
        let version = loadConfiguration()
        self.dbVersion = version
        DispatchQueue.main.async { self.dbVersion = version }
        updateFileMetadata()
        print("📂 Database path: \(dbPath) | version: \(version)")
        #else
        // iOS: app support path placeholder; openReadOnly(at:) will be used to load a snapshot
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appDir = support.appendingPathComponent("DragonShield")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.dbMode = .production
        self.dbPath = appDir.appendingPathComponent(DatabaseManager.fileName(for: .production)).path
        #endif
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
        #if os(macOS)
        let version = loadConfiguration()
        DispatchQueue.main.async { self.dbVersion = version }
        updateFileMetadata()
        #endif
    }

    func lastSQLErrorMessage() -> String {
        guard let db else { return "database not open" }
        if let cString = sqlite3_errmsg(db) {
            return String(cString: cString)
        }
        return "unknown database error"
    }

    /// Open a specific SQLite file in read-only mode (used by the iOS app to open a snapshot).
    /// The manager will point to the provided path until reopened or switched.
    @discardableResult
    func openReadOnly(at externalPath: String) -> Bool {
        closeConnection()
        self.dbPath = externalPath
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK {
            // It's fine to enable foreign keys pragma in RO; it is ignored if not applicable
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
            #if os(macOS)
            let version = loadConfiguration()
            DispatchQueue.main.async { self.dbVersion = version }
            #else
            // Lightweight: only load db_version if configuration extension isn't linked
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT value FROM Configuration WHERE key='db_version'", -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW, let cstr = sqlite3_column_text(stmt, 0) {
                    let v = String(cString: cstr)
                    DispatchQueue.main.async { self.dbVersion = v }
                }
            }
            sqlite3_finalize(stmt)
            #endif
            updateFileMetadata()
            print("✅ Opened read-only database at: \(dbPath)")
            return true
        } else {
            let msg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            print("❌ Failed to open read-only DB at \(dbPath): \(msg)")
            return false
        }
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
        #if os(macOS)
        UserDefaults.standard.set(dbMode.rawValue, forKey: UserDefaultsKeys.databaseMode)
        #endif
        dbPath = appDir.appendingPathComponent(DatabaseManager.fileName(for: dbMode)).path

        #if os(macOS)
        if !FileManager.default.fileExists(atPath: dbPath) {
            if let bundlePath = Bundle.main.path(forResource: "dragonshield", ofType: "sqlite") {
                try? FileManager.default.copyItem(atPath: bundlePath, toPath: dbPath)
            }
        }
        reopenDatabase()
        #endif
    }

    func runMigrations() {
        // Placeholder for future migration logic
        print("ℹ️ runMigrations called - no migrations to apply")
    }

    private static func fileName(for mode: DatabaseMode) -> String {
        return "dragonshield.sqlite"
    }
    
    deinit {
        if let dbPointer = db {
            sqlite3_close_v2(dbPointer)
            print("✅ Database connection closed in deinit.")
            self.db = nil
        } else {
            print("ℹ️ Database connection was already nil in deinit.")
        }
    }
}
