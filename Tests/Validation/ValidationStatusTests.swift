import XCTest
import SQLite3
@testable import Database

final class ValidationStatusTests: XCTestCase {
    private func makeDB() throws -> (DatabaseManager, String) {
        let path = NSTemporaryDirectory().appending("test-\(UUID().uuidString).sqlite")
        var rawDB: OpaquePointer?
        guard sqlite3_open(path, &rawDB) == SQLITE_OK else {
            throw XCTSkip("Unable to open sqlite3 database")
        }
        let schema = """
        CREATE TABLE AssetClasses(class_id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE AssetSubClasses(sub_class_id INTEGER PRIMARY KEY, class_id INTEGER, name TEXT);
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
        CREATE TABLE ClassTargets(class_id INTEGER PRIMARY KEY, validation_status TEXT);
        CREATE TABLE SubClassTargets(sub_class_id INTEGER PRIMARY KEY, class_id INTEGER, validation_status TEXT);
        """
        guard sqlite3_exec(rawDB, schema, nil, nil, nil) == SQLITE_OK else {
            throw XCTSkip("Failed to create schema")
        }
        let views = """
        CREATE VIEW IF NOT EXISTS V_SubClassValidationStatus AS
        WITH sub_err AS (
          SELECT entity_id AS sub_class_id FROM ValidationFindings
          WHERE entity_type='subclass' AND severity='error'
        ),
        sub_warn AS (
          SELECT entity_id AS sub_class_id FROM ValidationFindings
          WHERE entity_type='subclass' AND severity='warning'
        )
        SELECT s.sub_class_id,
               CASE
                 WHEN EXISTS(SELECT 1 FROM sub_err e WHERE e.sub_class_id=s.sub_class_id) THEN 'error'
                 WHEN EXISTS(SELECT 1 FROM sub_warn w WHERE w.sub_class_id=s.sub_class_id) THEN 'warning'
                 ELSE 'compliant'
               END AS validation_status,
               (SELECT COUNT(*) FROM ValidationFindings vf
                 WHERE vf.entity_type='subclass' AND vf.entity_id=s.sub_class_id) AS findings_count
        FROM AssetSubClasses s;

        CREATE VIEW IF NOT EXISTS V_ClassValidationStatus AS
        WITH class_err AS (
          SELECT ac.class_id FROM AssetClasses ac
          WHERE EXISTS (SELECT 1 FROM ValidationFindings vf
                          WHERE vf.entity_type='class'
                            AND vf.entity_id=ac.class_id
                            AND vf.severity='error')
             OR EXISTS (SELECT 1 FROM ValidationFindings vf
                          JOIN AssetSubClasses s ON s.sub_class_id=vf.entity_id
                         WHERE vf.entity_type='subclass'
                           AND s.class_id=ac.class_id
                           AND vf.severity='error')
        ),
        class_warn AS (
          SELECT ac.class_id FROM AssetClasses ac
          WHERE EXISTS (SELECT 1 FROM ValidationFindings vf
                          WHERE vf.entity_type='class'
                            AND vf.entity_id=ac.class_id
                            AND vf.severity='warning')
             OR EXISTS (SELECT 1 FROM ValidationFindings vf
                          JOIN AssetSubClasses s ON s.sub_class_id=vf.entity_id
                         WHERE vf.entity_type='subclass'
                           AND s.class_id=ac.class_id
                           AND vf.severity='warning')
        )
        SELECT ac.class_id,
               CASE
                 WHEN EXISTS (SELECT 1 FROM class_err e WHERE e.class_id=ac.class_id) THEN 'error'
                 WHEN EXISTS (SELECT 1 FROM class_warn w WHERE w.class_id=ac.class_id) THEN 'warning'
                 ELSE 'compliant'
               END AS validation_status,
               (
                 SELECT COUNT(*) FROM ValidationFindings vf
                 WHERE (vf.entity_type='class' AND vf.entity_id=ac.class_id)
                    OR (vf.entity_type='subclass' AND vf.entity_id IN (
                         SELECT sub_class_id FROM AssetSubClasses s WHERE s.class_id=ac.class_id
                       ))
               ) AS findings_count
        FROM AssetClasses ac;
        """
        guard sqlite3_exec(rawDB, views, nil, nil, nil) == SQLITE_OK else {
            throw XCTSkip("Failed to create views")
        }
        try sqlite3_exec(rawDB, "INSERT INTO AssetClasses(class_id,name) VALUES (1,'Class');", nil, nil, nil).unwrap()
        try sqlite3_exec(rawDB, "INSERT INTO AssetSubClasses(sub_class_id,class_id,name) VALUES (10,1,'Sub');", nil, nil, nil).unwrap()
        try sqlite3_exec(rawDB, "INSERT INTO ClassTargets(class_id,validation_status) VALUES (1,'compliant');", nil, nil, nil).unwrap()
        try sqlite3_exec(rawDB, "INSERT INTO SubClassTargets(sub_class_id,class_id,validation_status) VALUES (10,1,'compliant');", nil, nil, nil).unwrap()
        sqlite3_close(rawDB)
        return (try DatabaseManager(path: path), path)
    }

    func testStatusesAndFindingsAggregation() throws {
        let (db, path) = try makeDB()
        // Initial: compliant
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "compliant")
        XCTAssertEqual(db.fetchSubClassValidationStatuses()[10], "compliant")

        // Warning on subclass
        try execute("INSERT INTO ValidationFindings(entity_type,entity_id,severity,code,message) VALUES('subclass',10,'warning','W1','warn');", at: path)
        XCTAssertEqual(db.fetchSubClassValidationStatuses()[10], "warning")
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "warning")
        XCTAssertEqual(try status("ClassTargets", idColumn: "class_id", id: 1, at: path), "warning")
        XCTAssertEqual(try status("SubClassTargets", idColumn: "sub_class_id", id: 10, at: path), "warning")

        // Error on class
        try execute("INSERT INTO ValidationFindings(entity_type,entity_id,severity,code,message) VALUES('class',1,'error','E1','err');", at: path)
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "error")
        XCTAssertEqual(try status("ClassTargets", idColumn: "class_id", id: 1, at: path), "error")

        // Error on subclass dominates
        try execute("INSERT INTO ValidationFindings(entity_type,entity_id,severity,code,message) VALUES('subclass',10,'error','E2','boom');", at: path)
        XCTAssertEqual(db.fetchSubClassValidationStatuses()[10], "error")
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "error")
        XCTAssertEqual(try status("SubClassTargets", idColumn: "sub_class_id", id: 10, at: path), "error")

        let classFindings = db.fetchValidationFindingsForClass(1)
        XCTAssertEqual(classFindings.map { $0.code }, ["E1", "E2", "W1"])
        let subFindings = db.fetchValidationFindingsForSubClass(10)
        XCTAssertEqual(subFindings.map { $0.code }, ["E2", "W1"])
    }
}

private func execute(_ sql: String, at path: String) throws {
    var db: OpaquePointer?
    try sqlite3_open(path, &db).unwrap()
    defer { sqlite3_close(db) }
    try sqlite3_exec(db, sql, nil, nil, nil).unwrap()
}

private func status(_ table: String, idColumn: String, id: Int, at path: String) throws -> String? {
    var db: OpaquePointer?
    try sqlite3_open(path, &db).unwrap()
    defer { sqlite3_close(db) }
    let query = "SELECT validation_status FROM \(table) WHERE \(idColumn)=?;"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
    sqlite3_bind_int(stmt, 1, Int32(id))
    defer { sqlite3_finalize(stmt) }
    if sqlite3_step(stmt) == SQLITE_ROW {
        return String(cString: sqlite3_column_text(stmt, 0))
    }
    return nil
}

private extension Int32 {
    func unwrap() throws {
        if self != SQLITE_OK { throw NSError(domain: "SQLite", code: Int(self)) }
    }
}
