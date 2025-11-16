@testable import DragonShield
import SQLite3
import XCTest

final class ThemeAssetUpdateAttachmentRepositoryTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?
    var repo: ThemeAssetUpdateRepository!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioTheme(id) VALUES (1);", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE Instruments(instrument_id INTEGER PRIMARY KEY);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO Instruments(instrument_id) VALUES (1);", nil, nil, nil)
        manager.ensurePortfolioThemeAssetUpdateTable()
        manager.ensureAttachmentTable()
        manager.ensureThemeAssetUpdateAttachmentTable()
        repo = ThemeAssetUpdateRepository(dbManager: manager)
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        repo = nil
        super.tearDown()
    }

    func testLinkAndUnlink() {
        guard let update = manager.createInstrumentUpdate(themeId: 1, instrumentId: 1, title: "t", bodyMarkdown: "b", type: .General, pinned: false, author: "tester") else {
            XCTFail("update missing"); return
        }
        let insertSQL = """
        INSERT INTO Attachment (sha256, original_filename, mime, byte_size, ext, created_at, created_by)
        VALUES ('abc', 'f.txt', 'text/plain', 3, 'txt', '2024-01-01T00:00:00Z', 'tester');
        """
        sqlite3_exec(manager.db, insertSQL, nil, nil, nil)
        let attachmentId = Int(sqlite3_last_insert_rowid(manager.db))

        XCTAssertTrue(repo.linkAttachment(updateId: update.id, attachmentId: attachmentId))
        var list = repo.listAttachments(updateId: update.id)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.id, attachmentId)

        XCTAssertTrue(repo.unlinkAttachment(updateId: update.id, attachmentId: attachmentId))
        list = repo.listAttachments(updateId: update.id)
        XCTAssertEqual(list.count, 0)
    }

    func testCascadeAndRestrict() {
        guard let update = manager.createInstrumentUpdate(themeId: 1, instrumentId: 1, title: "t", bodyMarkdown: "b", type: .General, pinned: false, author: "tester") else {
            XCTFail("update missing"); return
        }
        let insertSQL = """
        INSERT INTO Attachment (sha256, original_filename, mime, byte_size, ext, created_at, created_by)
        VALUES ('abc', 'f.txt', 'text/plain', 3, 'txt', '2024-01-01T00:00:00Z', 'tester');
        """
        sqlite3_exec(manager.db, insertSQL, nil, nil, nil)
        let attachmentId = Int(sqlite3_last_insert_rowid(manager.db))
        XCTAssertTrue(repo.linkAttachment(updateId: update.id, attachmentId: attachmentId))

        XCTAssertTrue(manager.deleteInstrumentUpdate(id: update.id, actor: "tester"))
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(manager.db, "SELECT COUNT(*) FROM InstrumentNoteAttachment WHERE attachment_id = ?", -1, &stmt, nil)
        sqlite3_bind_int(stmt, 1, Int32(attachmentId))
        _ = sqlite3_step(stmt)
        let count = sqlite3_column_int(stmt, 0)
        sqlite3_finalize(stmt)
        XCTAssertEqual(count, 0)

        let del = "DELETE FROM Attachment WHERE id = ?"
        sqlite3_prepare_v2(manager.db, del, -1, &stmt, nil)
        sqlite3_bind_int(stmt, 1, Int32(attachmentId))
        let step = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        XCTAssertEqual(step, SQLITE_CONSTRAINT)
    }
}
