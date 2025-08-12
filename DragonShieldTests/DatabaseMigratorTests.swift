import XCTest
import SQLite3
@testable import DragonShield

final class DatabaseMigratorTests: XCTestCase {
    func testAppliesMigrationsAndSetsVersion() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(tmp.path, &db), SQLITE_OK)
        defer {
            sqlite3_close(db)
            try? FileManager.default.removeItem(at: tmp)
        }
        let migrationsURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Tests directory
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("DragonShield/db/migrations")
        let latest = try DatabaseMigrator.applyMigrations(db: db, migrationsDirectory: migrationsURL)
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil)
        var version: Int32 = 0
        if sqlite3_step(stmt) == SQLITE_ROW {
            version = sqlite3_column_int(stmt, 0)
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(version, Int32(latest))
        sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table' AND name='Configuration';", -1, &stmt, nil)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        sqlite3_finalize(stmt)
    }
}
