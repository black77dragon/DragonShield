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

    @Published var baseCurrency: String = "CHF"
    @Published var asOfDate: Date = Date()
    @Published var decimalPrecision: Int = 4
    @Published var autoFxUpdate: Bool = true

    @Published var defaultTimeZone: String = "Europe/Zurich"
    @Published var tableRowSpacing: Double = 1.0
    @Published var tableRowPadding: Double = 12.0
    @Published var dbVersion: String = ""
    @Published var dbFilePath: String = ""
    @Published var dbCreated: Date?
    @Published var dbModified: Date?
    @Published var includeDirectRealEstate: Bool = true
    @Published var directRealEstateTargetCHF: Double = 0.0

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appDir = appSupport.appendingPathComponent("DragonShield")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let savedMode = UserDefaults.standard.string(forKey: UserDefaultsKeys.databaseMode)
        let mode = DatabaseMode(rawValue: savedMode ?? "production") ?? .production
        self.dbMode = mode
        self.dbPath = appDir.appendingPathComponent(DatabaseManager.fileName(for: mode)).path

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
            print("ℹ️ Creating new database at: \(dbPath)")
        } else {
            print("✅ Using existing database at: \(dbPath)")
        }

        openDatabase()
        updateFileMetadata()
        print("📂 Database path: \(dbPath) | version: \(dbVersion)")
    }

    func openDatabase() {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK {
            print("✅ Database opened: \(dbPath)")
            sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA busy_timeout = 5000;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA wal_autocheckpoint = 1000;", nil, nil, nil)
            let testQuery = "CREATE TABLE IF NOT EXISTS test_write_permission (id INTEGER);"
            if sqlite3_exec(db, testQuery, nil, nil, nil) == SQLITE_OK {
                sqlite3_exec(db, "DROP TABLE test_write_permission;", nil, nil, nil)
            } else {
                print("❌ Database write test failed: \(String(cString: sqlite3_errmsg(db)))")
            }
            _ = try? DatabaseMigrator.applyMigrations(db: db, migrationsDirectory: Self.migrationsDirectory())
            _ = loadConfiguration()
            DispatchQueue.main.async { self.dbVersion = String(self.schemaVersion()) }
        } else {
            let msg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            print("❌ Failed to open database at \(dbPath): \(msg)")
        }
    }

    private func schemaVersion() -> Int {
        var stmt: OpaquePointer?
        var version: Int32 = 0
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                version = sqlite3_column_int(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        return Int(version)
    }

    private static func migrationsDirectory(file: String = #file) -> URL {
        if let url = Bundle.main.url(forResource: "db/migrations", withExtension: nil) {
            return url
        }
        let sourceURL = URL(fileURLWithPath: file).deletingLastPathComponent()
        return sourceURL.appendingPathComponent("db/migrations")
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
        updateFileMetadata()
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
        dbPath = appDir.appendingPathComponent(DatabaseManager.fileName(for: dbMode)).path
        if !FileManager.default.fileExists(atPath: dbPath) {
            print("ℹ️ Creating new database for mode \(dbMode)")
        }
        reopenDatabase()
    }

    private static func fileName(for mode: DatabaseMode) -> String {
        mode == .production ? "dragonshield.sqlite" : "dragonshield_test.sqlite"
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
