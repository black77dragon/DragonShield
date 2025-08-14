import XCTest
@testable import DragonShield
import SQLite3

final class BackupServiceTests: XCTestCase {
    func testUserTablesListsAllUserTables() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("temp.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE Foo(id INTEGER);", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE Bar(id INTEGER);", nil, nil, nil), SQLITE_OK)
        let svc = BackupService()
        let names = svc.userTables(in: dbURL.path)
        XCTAssertTrue(names.contains("Foo"))
        XCTAssertTrue(names.contains("Bar"))
    }
}
