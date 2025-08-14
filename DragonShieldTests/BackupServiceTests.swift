import XCTest
import SQLite3
@testable import DragonShield

final class BackupServiceTests: XCTestCase {
    func testBackupCreatesValidCopy() throws {
        let dbManager = DatabaseManager()
        defer { _ = dbManager.closeConnection() }
        let service = BackupService()
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let backupURL = tmpDir.appendingPathComponent("test_backup.sqlite")
        try? FileManager.default.removeItem(at: backupURL)
        let result = try service.performBackup(dbManager: dbManager, dbPath: dbManager.dbFilePath, to: backupURL, tables: service.fullTables, label: "Full")
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
        var db: OpaquePointer?
        XCTAssertEqual(SQLITE_OK, sqlite3_open_v2(result.path, &db, SQLITE_OPEN_READONLY, nil))
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(SQLITE_OK, sqlite3_prepare_v2(db, "PRAGMA integrity_check;", -1, &stmt, nil))
        defer { sqlite3_finalize(stmt) }
        XCTAssertEqual(SQLITE_ROW, sqlite3_step(stmt))
        XCTAssertEqual("ok", String(cString: sqlite3_column_text(stmt, 0)))
        let movedURL = tmpDir.appendingPathComponent("moved_backup.sqlite")
        try? FileManager.default.removeItem(at: movedURL)
        try FileManager.default.moveItem(at: result, to: movedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: movedURL.path))
    }
}
