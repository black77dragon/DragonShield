import XCTest
import SQLite3
@testable import Database

final class ValidationStatusTests: XCTestCase {
    private func makeDB() throws -> DatabaseManager {
        let path = NSTemporaryDirectory().appending("test-\(UUID().uuidString).sqlite")
        var rawDB: OpaquePointer?
        guard sqlite3_open(path, &rawDB) == SQLITE_OK else {
            throw XCTSkip("Unable to open sqlite3 database")
        }
        defer { sqlite3_close(rawDB) }
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
        return try DatabaseManager(path: path)
    }

    func testStatusesAndFindingsAggregation() throws {
        let db = try makeDB()
        db.syncValidationStatusTables()
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "compliant")
        XCTAssertEqual(db.fetchSubClassValidationStatuses()[10], "compliant")
        assertTargetStatus(db, classStatus: "compliant", subStatus: "compliant")

        _ = db.execute("INSERT INTO ValidationFindings(entity_type,entity_id,severity,code,message) VALUES('subclass',10,'warning','W1','warn');")
        db.syncValidationStatusTables()
        XCTAssertEqual(db.fetchSubClassValidationStatuses()[10], "warning")
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "warning")
        assertTargetStatus(db, classStatus: "warning", subStatus: "warning")

        _ = db.execute("INSERT INTO ValidationFindings(entity_type,entity_id,severity,code,message) VALUES('class',1,'error','E1','err');")
        db.syncValidationStatusTables()
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "error")
        assertTargetStatus(db, classStatus: "error", subStatus: "warning")

        _ = db.execute("INSERT INTO ValidationFindings(entity_type,entity_id,severity,code,message) VALUES('subclass',10,'error','E2','boom');")
        db.syncValidationStatusTables()
        XCTAssertEqual(db.fetchSubClassValidationStatuses()[10], "error")
        XCTAssertEqual(db.fetchClassValidationStatuses()[1], "error")
        assertTargetStatus(db, classStatus: "error", subStatus: "error")

        let classFindings = db.fetchValidationFindingsForClass(1)
        XCTAssertEqual(classFindings.map { $0.code }, ["E1", "E2", "W1"])
        let subFindings = db.fetchValidationFindingsForSubClass(10)
        XCTAssertEqual(subFindings.map { $0.code }, ["E2", "W1"])
    }

    private func assertTargetStatus(_ db: DatabaseManager, classStatus: String, subStatus: String, file: StaticString = #filePath, line: UInt = #line) {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db.db, "SELECT validation_status FROM ClassTargets WHERE class_id=1;", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        _ = sqlite3_step(stmt)
        let cStatus = String(cString: sqlite3_column_text(stmt, 0))
        XCTAssertEqual(cStatus, classStatus, file: file, line: line)

        var stmt2: OpaquePointer?
        sqlite3_prepare_v2(db.db, "SELECT validation_status FROM SubClassTargets WHERE sub_class_id=10;", -1, &stmt2, nil)
        defer { sqlite3_finalize(stmt2) }
        _ = sqlite3_step(stmt2)
        let sStatus = String(cString: sqlite3_column_text(stmt2, 0))
        XCTAssertEqual(sStatus, subStatus, file: file, line: line)
    }
}

private extension Int32 {
    func unwrap() throws {
        if self != SQLITE_OK { throw NSError(domain: "SQLite", code: Int(self)) }
    }
}

