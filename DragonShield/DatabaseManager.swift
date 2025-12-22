// DragonShield/DatabaseManager.swift

// MARK: - Version 1.6.0.1

// MARK: - History

// - 1.5 -> 1.6: Expose database path, creation date and modification date via
//               @Published properties.
// - 1.6 -> 1.6.0.1: Use sqlite3_open_v2 with FULLMUTEX and log errors when opening fails.
// - 1.6.0.1 -> 1.6.0.2: Dropped user-configurable table row spacing/padding in favor of DSLayout defaults.
// - 1.3 -> 1.4: Added @Published properties for defaultTimeZone, tableRowSpacing, tableRowPadding.
// - 1.4 -> 1.5: Added dbVersion property and logging of database version.
// - 1.2 -> 1.3: Modified #if DEBUG block to use a UserDefaults setting for forcing DB re-copy.
// - 1.1 -> 1.2: Added a #if DEBUG block to init() to force delete/re-copy database from bundle.

import Foundation
import SQLite3

struct DatabaseFileMetadata {
    let filePath: String
    let fileSize: Int64
    let created: Date?
    let modified: Date?
}

final class DatabaseConnection {
    var db: OpaquePointer?
    private(set) var dbPath: String

    init(dbPath: String) {
        self.dbPath = dbPath
    }

    func updatePath(_ path: String) {
        dbPath = path
    }

    @discardableResult
    func openReadWrite() -> Bool {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK {
            print("✅ Database opened: \(dbPath)")
            sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
            let testQuery = "CREATE TABLE IF NOT EXISTS test_write_permission (id INTEGER);"
            if sqlite3_exec(db, testQuery, nil, nil, nil) == SQLITE_OK {
                sqlite3_exec(db, "DROP TABLE test_write_permission;", nil, nil, nil)
            } else {
                let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
                print("❌ Database write test failed: \(message)")
            }
            return true
        } else {
            let msg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            print("❌ Failed to open database at \(dbPath): \(msg)")
            return false
        }
    }

    @discardableResult
    func openReadOnly() -> Bool {
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK {
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
            print("✅ Opened read-only database at: \(dbPath)")
            return true
        } else {
            let msg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            print("❌ Failed to open read-only DB at \(dbPath): \(msg)")
            return false
        }
    }

    func fileMetadata() -> DatabaseFileMetadata? {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: dbPath)
            let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            return DatabaseFileMetadata(
                filePath: dbPath,
                fileSize: size,
                created: attrs[.creationDate] as? Date,
                modified: attrs[.modificationDate] as? Date
            )
        } catch {
            print("⚠️ Failed to read DB file attributes: \(error)")
            return nil
        }
    }

    @discardableResult
    func close() -> Bool {
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

    func lastSQLErrorMessage() -> String {
        guard let db else { return "database not open" }
        if let cString = sqlite3_errmsg(db) {
            return String(cString: cString)
        }
        return "unknown database error"
    }
}

final class AppPreferences: ObservableObject {
    @Published var baseCurrency: String = "CHF"
    @Published var asOfDate: Date = .init()
    @Published var decimalPrecision: Int = 4
    @Published var defaultTimeZone: String = "Europe/Zurich"
    @Published var dbVersion: String = ""
    @Published var includeDirectRealEstate: Bool = true
    @Published var directRealEstateTargetCHF: Double = 0.0
    @Published var fxAutoUpdateEnabled: Bool = true
    @Published var fxUpdateFrequency: String = "daily"
    @Published var iosSnapshotAutoEnabled: Bool = true
    @Published var iosSnapshotFrequency: String = "daily"
    @Published var iosSnapshotTargetPath: String = ""
    @Published var iosSnapshotTargetBookmark: Data? = nil
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

    func apply(_ snapshot: ConfigurationSnapshot) {
        baseCurrency = snapshot.baseCurrency
        asOfDate = snapshot.asOfDate
        decimalPrecision = snapshot.decimalPrecision
        defaultTimeZone = snapshot.defaultTimeZone
        dbVersion = snapshot.dbVersion
        includeDirectRealEstate = snapshot.includeDirectRealEstate
        directRealEstateTargetCHF = snapshot.directRealEstateTargetCHF
        fxAutoUpdateEnabled = snapshot.fxAutoUpdateEnabled
        fxUpdateFrequency = snapshot.fxUpdateFrequency
        iosSnapshotAutoEnabled = snapshot.iosSnapshotAutoEnabled
        iosSnapshotFrequency = snapshot.iosSnapshotFrequency
        iosSnapshotTargetPath = snapshot.iosSnapshotTargetPath
        iosSnapshotTargetBookmark = snapshot.iosSnapshotTargetBookmark
        institutionsTableFontSize = snapshot.institutionsTableFontSize
        institutionsTableColumnFractions = snapshot.institutionsTableColumnFractions
        instrumentsTableFontSize = snapshot.instrumentsTableFontSize
        instrumentsTableColumnFractions = snapshot.instrumentsTableColumnFractions
        assetSubClassesTableFontSize = snapshot.assetSubClassesTableFontSize
        assetSubClassesTableColumnFractions = snapshot.assetSubClassesTableColumnFractions
        assetClassesTableFontSize = snapshot.assetClassesTableFontSize
        assetClassesTableColumnFractions = snapshot.assetClassesTableColumnFractions
        currenciesTableFontSize = snapshot.currenciesTableFontSize
        currenciesTableColumnFractions = snapshot.currenciesTableColumnFractions
        accountsTableFontSize = snapshot.accountsTableFontSize
        accountsTableColumnFractions = snapshot.accountsTableColumnFractions
        positionsTableFontSize = snapshot.positionsTableFontSize
        positionsTableColumnFractions = snapshot.positionsTableColumnFractions
        portfolioThemesTableFontSize = snapshot.portfolioThemesTableFontSize
        portfolioThemesTableColumnFractions = snapshot.portfolioThemesTableColumnFractions
        transactionTypesTableFontSize = snapshot.transactionTypesTableFontSize
        transactionTypesTableColumnFractions = snapshot.transactionTypesTableColumnFractions
        accountTypesTableFontSize = snapshot.accountTypesTableFontSize
        accountTypesTableColumnFractions = snapshot.accountTypesTableColumnFractions
        todoBoardFontSize = snapshot.todoBoardFontSize
    }
}

enum DatabaseMode: String {
    case production
    case test
}

class DatabaseManager: ObservableObject {
    var db: OpaquePointer? { connection.db }
    var databaseConnection: DatabaseConnection { connection }
    private var dbPath: String {
        get { connection.dbPath }
        set { connection.updatePath(newValue) }
    }
    private let appDir: URL
    private let connection: DatabaseConnection
    let preferences: AppPreferences
    let configurationStore: ConfigurationStore

    @Published var dbMode: DatabaseMode
    @Published var dbFileSize: Int64 = 0

    // Deprecated @Published preferences (use AppPreferences)
    @available(*, deprecated, message: "Use AppPreferences.baseCurrency")
    @Published var baseCurrency: String = "CHF"
    @available(*, deprecated, message: "Use AppPreferences.asOfDate")
    @Published var asOfDate: Date = .init()
    @available(*, deprecated, message: "Use AppPreferences.decimalPrecision")
    @Published var decimalPrecision: Int = 4

    @available(*, deprecated, message: "Use AppPreferences.defaultTimeZone")
    @Published var defaultTimeZone: String = "Europe/Zurich"
    @available(*, deprecated, message: "Use AppPreferences.dbVersion")
    @Published var dbVersion: String = ""
    @Published var dbFilePath: String = ""
    @Published var dbCreated: Date?
    @Published var dbModified: Date?

    @available(*, deprecated, message: "Use AppPreferences.includeDirectRealEstate")
    @Published var includeDirectRealEstate: Bool = true
    @available(*, deprecated, message: "Use AppPreferences.directRealEstateTargetCHF")
    @Published var directRealEstateTargetCHF: Double = 0.0
    // FX Auto Update configuration (defaults)
    @available(*, deprecated, message: "Use AppPreferences.fxAutoUpdateEnabled")
    @Published var fxAutoUpdateEnabled: Bool = true
    /// 'daily' or 'weekly'
    @available(*, deprecated, message: "Use AppPreferences.fxUpdateFrequency")
    @Published var fxUpdateFrequency: String = "daily"
    // iOS Snapshot Export configuration (defaults)
    @available(*, deprecated, message: "Use AppPreferences.iosSnapshotAutoEnabled")
    @Published var iosSnapshotAutoEnabled: Bool = true
    /// 'daily' or 'weekly'
    @available(*, deprecated, message: "Use AppPreferences.iosSnapshotFrequency")
    @Published var iosSnapshotFrequency: String = "daily"
    /// Destination folder for iOS snapshot export
    @available(*, deprecated, message: "Use AppPreferences.iosSnapshotTargetPath")
    @Published var iosSnapshotTargetPath: String = ""
    @available(*, deprecated, message: "Use AppPreferences.iosSnapshotTargetBookmark")
    @Published var iosSnapshotTargetBookmark: Data? = nil
    // Table view personalisation
    @available(*, deprecated, message: "Use AppPreferences.institutionsTableFontSize")
    @Published var institutionsTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.institutionsTableColumnFractions")
    @Published var institutionsTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.instrumentsTableFontSize")
    @Published var instrumentsTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.instrumentsTableColumnFractions")
    @Published var instrumentsTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.assetSubClassesTableFontSize")
    @Published var assetSubClassesTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.assetSubClassesTableColumnFractions")
    @Published var assetSubClassesTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.assetClassesTableFontSize")
    @Published var assetClassesTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.assetClassesTableColumnFractions")
    @Published var assetClassesTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.currenciesTableFontSize")
    @Published var currenciesTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.currenciesTableColumnFractions")
    @Published var currenciesTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.accountsTableFontSize")
    @Published var accountsTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.accountsTableColumnFractions")
    @Published var accountsTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.positionsTableFontSize")
    @Published var positionsTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.positionsTableColumnFractions")
    @Published var positionsTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.portfolioThemesTableFontSize")
    @Published var portfolioThemesTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.portfolioThemesTableColumnFractions")
    @Published var portfolioThemesTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.transactionTypesTableFontSize")
    @Published var transactionTypesTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.transactionTypesTableColumnFractions")
    @Published var transactionTypesTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.accountTypesTableFontSize")
    @Published var accountTypesTableFontSize: String = "medium"
    @available(*, deprecated, message: "Use AppPreferences.accountTypesTableColumnFractions")
    @Published var accountTypesTableColumnFractions: [String: Double] = [:]
    @available(*, deprecated, message: "Use AppPreferences.todoBoardFontSize")
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
            appDir = appSupport.appendingPathComponent("DragonShield")
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

            let savedMode = UserDefaults.standard.string(forKey: UserDefaultsKeys.databaseMode)
            let mode = DatabaseMode(rawValue: savedMode ?? "production") ?? .production
            dbMode = mode
            let initialPath = appDir.appendingPathComponent(DatabaseManager.fileName(for: mode)).path
            connection = DatabaseConnection(dbPath: initialPath)
            configurationStore = ConfigurationStore(connection: connection)
            preferences = AppPreferences()
            dbPath = initialPath

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
            DispatchQueue.main.async { self.preferences.dbVersion = version }
            updateFileMetadata()
            print("📂 Database path: \(dbPath) | version: \(version)")
        #else
            // iOS: app support path placeholder; openReadOnly(at:) will be used to load a snapshot
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            appDir = support.appendingPathComponent("DragonShield")
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            dbMode = .production
            let initialPath = appDir.appendingPathComponent(DatabaseManager.fileName(for: .production)).path
            connection = DatabaseConnection(dbPath: initialPath)
            configurationStore = ConfigurationStore(connection: connection)
            preferences = AppPreferences()
            dbPath = initialPath
        #endif
    }

    // ==============================================================================

    func openDatabase() {
        _ = connection.openReadWrite()
    }

    private func updateFileMetadata() {
        guard let metadata = connection.fileMetadata() else { return }
        DispatchQueue.main.async {
            self.dbFilePath = metadata.filePath
            self.dbFileSize = metadata.fileSize
            self.dbCreated = metadata.created
            self.dbModified = metadata.modified
        }
    }

    @discardableResult
    func closeConnection() -> Bool {
        connection.close()
    }

    func reopenDatabase() {
        closeConnection()
        openDatabase()
        #if os(macOS)
            let version = loadConfiguration()
            DispatchQueue.main.async { self.preferences.dbVersion = version }
            updateFileMetadata()
        #endif
    }

    func lastSQLErrorMessage() -> String {
        connection.lastSQLErrorMessage()
    }

    /// Open a specific SQLite file in read-only mode (used by the iOS app to open a snapshot).
    /// The manager will point to the provided path until reopened or switched.
    @discardableResult
    func openReadOnly(at externalPath: String) -> Bool {
        closeConnection()
        dbPath = externalPath
        if connection.openReadOnly() {
            #if os(macOS)
                let version = loadConfiguration()
                DispatchQueue.main.async { self.preferences.dbVersion = version }
            #else
                // Lightweight: only load db_version if configuration extension isn't linked
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, "SELECT value FROM Configuration WHERE key='db_version'", -1, &stmt, nil) == SQLITE_OK {
                    if sqlite3_step(stmt) == SQLITE_ROW, let cstr = sqlite3_column_text(stmt, 0) {
                        let v = String(cString: cstr)
                        DispatchQueue.main.async { self.preferences.dbVersion = v }
                    }
                }
                sqlite3_finalize(stmt)
            #endif
            updateFileMetadata()
            return true
        } else {
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

    private static func fileName(for _: DatabaseMode) -> String {
        return "dragonshield.sqlite"
    }

    deinit {
        _ = connection.close()
    }
}
