import XCTest
@testable import DragonShield
import SQLite3

final class BackupServiceTests: XCTestCase {
    func testUserTablesListsAllNonSystemTables() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("test.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(SQLITE_OK, sqlite3_open(dbURL.path, &db))
        defer { sqlite3_close(db) }
        XCTAssertEqual(SQLITE_OK, sqlite3_exec(db, "CREATE TABLE A(id INTEGER);", nil, nil, nil))
        XCTAssertEqual(SQLITE_OK, sqlite3_exec(db, "CREATE TABLE B(id INTEGER);", nil, nil, nil))
        // System tables prefixed with sqlite_ should be ignored
        let service = BackupService()
        let tables = service.userTables(at: dbURL.path)
        XCTAssertEqual(tables, ["A", "B"])
    }
}
