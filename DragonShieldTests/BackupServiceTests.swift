import XCTest
import SQLite3
@testable import DragonShield

final class BackupServiceTests: XCTestCase {
    func testPerformBackupProducesValidFile() throws {
        let dbManager = DatabaseManager()
        let backupService = BackupService()
        let tempDir = FileManager.default.temporaryDirectory
        let dest = tempDir.appendingPathComponent("test_backup.db")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        _ = try backupService.performBackup(dbManager: dbManager,
                                            dbPath: dbManager.dbFilePath,
                                            to: dest,
                                            tables: [],
                                            label: "Test")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dest.path, &db), SQLITE_OK)
        var stmt: OpaquePointer?
        defer {
            sqlite3_finalize(stmt)
            sqlite3_close(db)
        }
        XCTAssertEqual(sqlite3_prepare_v2(db, "PRAGMA integrity_check;", -1, &stmt, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        let result = String(cString: sqlite3_column_text(stmt, 0))
        XCTAssertEqual(result, "ok")
        XCTAssertNoThrow(try FileManager.default.removeItem(at: dest))
    }
}
