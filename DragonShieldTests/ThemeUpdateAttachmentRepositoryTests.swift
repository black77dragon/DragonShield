@testable import DragonShield
import SQLite3
import XCTest

final class ThemeUpdateAttachmentRepositoryTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?
    var repo: ThemeUpdateRepository!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioTheme(id) VALUES (1);", nil, nil, nil)
        manager.ensurePortfolioThemeUpdateTable()
        manager.ensureAttachmentTable()
        manager.ensureThemeUpdateAttachmentTable()
        repo = ThemeUpdateRepository(dbManager: manager)
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        repo = nil
        super.tearDown()
    }

    func testLinkAndUnlink() {
        guard let update = manager.createThemeUpdate(themeId: 1, title: "t", bodyMarkdown: "b", type: .General, pinned: false, author: "tester", positionsAsOf: nil, totalValueChf: nil) else {
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

    func testGetAttachmentCounts() {
        guard let update = manager.createThemeUpdate(themeId: 1, title: "t", bodyMarkdown: "b", type: .General, pinned: false, author: "tester", positionsAsOf: nil, totalValueChf: nil) else {
            XCTFail("update missing"); return
        }
        let insertSQL = """
        INSERT INTO Attachment (sha256, original_filename, mime, byte_size, ext, created_at, created_by)
        VALUES ('abc', 'f.txt', 'text/plain', 3, 'txt', '2024-01-01T00:00:00Z', 'tester');
        """
        sqlite3_exec(manager.db, insertSQL, nil, nil, nil)
        let attachmentId = Int(sqlite3_last_insert_rowid(manager.db))
        XCTAssertTrue(repo.linkAttachment(updateId: update.id, attachmentId: attachmentId))
        let counts = manager.getAttachmentCounts(for: [update.id])
        XCTAssertEqual(counts[update.id], 1)
    }
}
