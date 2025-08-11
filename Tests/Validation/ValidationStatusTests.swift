import XCTest
import SQLite3
@testable import Database

final class ValidationStatusTests: XCTestCase {
    private func makeDB() throws -> (DatabaseManager, String) {
        let path = NSTemporaryDirectory().appending("test-\(UUID().uuidString).sqlite")
        var raw: OpaquePointer?
        guard sqlite3_open(path, &raw) == SQLITE_OK else {
            throw XCTSkip("Unable to open sqlite database")
        }
        defer { sqlite3_close(raw) }
        let schema = """
        CREATE TABLE AssetClasses(class_id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE AssetSubClasses(sub_class_id INTEGER PRIMARY KEY, class_id INTEGER, name TEXT);
        CREATE TABLE ClassTargets(class_id INTEGER PRIMARY KEY, validation_status TEXT);
        CREATE TABLE SubClassTargets(sub_class_id INTEGER PRIMARY KEY, class_id INTEGER, validation_status TEXT);
        CREATE TABLE ValidationFindings(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            entity_id INTEGER NOT NULL,
            severity TEXT NOT NULL,
            code TEXT NOT NULL,
            message TEXT NOT NULL,
            details_json TEXT,
            computed_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        """
        guard sqlite3_exec(raw, schema, nil, nil, nil) == SQLITE_OK else {
            throw XCTSkip("Failed to create schema")
        }
        let views = try String(contentsOfFile: "DragonShield/migrations/007_validation_status_views.sql")
            .components(separatedBy: "-- migrate:down").first ?? ""
        guard sqlite3_exec(raw, views, nil, nil, nil) == SQLITE_OK else {
            throw XCTSkip("Failed to create views")
        }
        sqlite3_exec(raw, "INSERT INTO AssetClasses(class_id,name) VALUES(1,'Class');", nil, nil, nil)
        sqlite3_exec(raw, "INSERT INTO AssetSubClasses(sub_class_id,class_id,name) VALUES(10,1,'Sub');", nil, nil, nil)
        sqlite3_exec(raw, "INSERT INTO ClassTargets(class_id,validation_status) VALUES(1,'compliant');", nil, nil, nil)
        sqlite3_exec(raw, "INSERT INTO SubClassTargets(sub_class_id,class_id,validation_status) VALUES(10,1,'compliant');", nil, nil, nil)
        return try (DatabaseManager(path: path), path)
    }

    private func exec(sql: String, at path: String) {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func status(from table: String, id: Int, path: String) -> String {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return "" }
        defer { sqlite3_close(db) }
        let query = "SELECT validation_status FROM \(table) WHERE \(table == "ClassTargets" ? "class_id" : "sub_class_id")=\(id);"
        var stmt: OpaquePointer?
        var result = ""
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
                result = String(cString: c)
            }
        }
        return result
    }

    func testStatusesAndFindingsAggregation() throws {
        let (db, path) = try makeDB()

        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "compliant")
        XCTAssertEqual(status(from: "ClassTargets", id: 1, path: path), "compliant")
        XCTAssertEqual(db.fetchSubClassValidationStatuses()[10], "compliant")
        XCTAssertEqual(status(from: "SubClassTargets", id: 10, path: path), "compliant")

        exec(sql: "INSERT INTO ValidationFindings(entity_type,entity_id,severity,code,message) VALUES('subclass',10,'warning','W1','warn');", at: path)
        XCTAssertEqual(db.fetchSubClassValidationStatuses()[10], "warning")
        XCTAssertEqual(status(from: "SubClassTargets", id: 10, path: path), "warning")
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "warning")
        XCTAssertEqual(status(from: "ClassTargets", id: 1, path: path), "warning")

        exec(sql: "INSERT INTO ValidationFindings(entity_type,entity_id,severity,code,message) VALUES('class',1,'error','E1','err');", at: path)
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "error")
        XCTAssertEqual(status(from: "ClassTargets", id: 1, path: path), "error")

        exec(sql: "INSERT INTO ValidationFindings(entity_type,entity_id,severity,code,message) VALUES('subclass',10,'error','E2','boom');", at: path)
        XCTAssertEqual(db.fetchSubClassValidationStatuses()[10], "error")
        XCTAssertEqual(status(from: "SubClassTargets", id: 10, path: path), "error")
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "error")
        XCTAssertEqual(status(from: "ClassTargets", id: 1, path: path), "error")

        let classFindings = db.fetchValidationFindingsForClass(1)
        XCTAssertEqual(classFindings.map { $0.code }, ["E1", "E2", "W1"])
        XCTAssertEqual(classFindings.first(where: { $0.code == "E2" })?.subClassName, "Sub")
        let subFindings = db.fetchValidationFindingsForSubClass(10)
        XCTAssertEqual(subFindings.map { $0.code }, ["E2", "W1"])
    }
}
