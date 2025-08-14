import XCTest
import SQLite3
@testable import DragonShield

final class FullRestoreTests: XCTestCase {
    func testUserTablesEnumeratesAll() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("enumerate.db")
        defer { try? FileManager.default.removeItem(at: tmp) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(tmp.path, &db), SQLITE_OK)
        sqlite3_exec(db, "CREATE TABLE Foo(id INTEGER);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE Bar(id INTEGER);", nil, nil, nil)
        sqlite3_close(db)

        let service = BackupService()
        let tables = service.userTables(at: tmp.path)
        XCTAssertTrue(tables.contains("Foo"))
        XCTAssertTrue(tables.contains("Bar"))
    }
}
