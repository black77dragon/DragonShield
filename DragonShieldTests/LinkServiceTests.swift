import XCTest
import SQLite3
@testable import DragonShield

final class LinkServiceTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?
    var service: LinkService!
    var repo: ThemeUpdateLinkRepository!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioTheme(id) VALUES (1);", nil, nil, nil)
        manager.ensurePortfolioThemeUpdateTable()
        manager.ensureLinkTable()
        manager.ensureThemeUpdateLinkTable()
        service = LinkService(dbManager: manager)
        repo = ThemeUpdateLinkRepository(dbManager: manager)
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        service = nil
        repo = nil
        super.tearDown()
    }

    func testNormalizeAndDedupe() {
        let first = try! service.validateAndNormalize("HTTPS://EXAMPLE.COM/Path/").get()
        let l1 = service.ensureLink(normalized: first.normalized, raw: first.raw, actor: "a")!
        let second = try! service.validateAndNormalize("https://example.com/path").get()
        let l2 = service.ensureLink(normalized: second.normalized, raw: second.raw, actor: "b")!
        XCTAssertEqual(l1.id, l2.id)
    }

    func testDeleteIfUnreferenced() {
        guard let update = manager.createThemeUpdate(themeId: 1, title: "t", bodyMarkdown: "b", type: .General, pinned: false, author: "tester", positionsAsOf: nil, totalValueChf: nil) else {
            XCTFail("update missing"); return
        }
        let norm = try! service.validateAndNormalize("https://example.com").get()
        let link = service.ensureLink(normalized: norm.normalized, raw: norm.raw, actor: "tester")!
        XCTAssertTrue(repo.link(updateId: update.id, linkId: link.id))
        XCTAssertTrue(repo.unlink(updateId: update.id, linkId: link.id))
        XCTAssertTrue(service.deleteIfUnreferenced(linkId: link.id))
    }
}
