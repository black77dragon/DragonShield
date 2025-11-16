@testable import DragonShield
import SQLite3
import XCTest

final class ThemeUpdateLinkRepositoryTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?
    var repo: ThemeUpdateLinkRepository!
    var service: LinkService!

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
        repo = ThemeUpdateLinkRepository(dbManager: manager)
        service = LinkService(dbManager: manager)
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        repo = nil
        service = nil
        super.tearDown()
    }

    func testLinkAndUnlink() {
        guard let update = manager.createThemeUpdate(themeId: 1, title: "t", bodyMarkdown: "b", type: .General, pinned: false, author: "tester", positionsAsOf: nil, totalValueChf: nil) else {
            XCTFail("update missing"); return
        }
        let norm = service.validateAndNormalize("https://example.com").getOrElse { _ in XCTFail() }
        guard let link = service.ensureLink(normalized: norm.normalized, raw: norm.raw, actor: "tester") else {
            XCTFail("link missing"); return
        }
        XCTAssertTrue(repo.link(updateId: update.id, linkId: link.id))
        var list = repo.listLinks(updateId: update.id)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.id, link.id)

        XCTAssertTrue(repo.unlink(updateId: update.id, linkId: link.id))
        list = repo.listLinks(updateId: update.id)
        XCTAssertEqual(list.count, 0)
    }

    func testGetLinkCounts() {
        guard let update = manager.createThemeUpdate(themeId: 1, title: "t", bodyMarkdown: "b", type: .General, pinned: false, author: "tester", positionsAsOf: nil, totalValueChf: nil) else {
            XCTFail("update missing"); return
        }
        let norm = service.validateAndNormalize("https://example.com").getOrElse { _ in XCTFail() }
        let link = service.ensureLink(normalized: norm.normalized, raw: norm.raw, actor: "tester")!
        XCTAssertTrue(repo.link(updateId: update.id, linkId: link.id))
        let counts = manager.getLinkCounts(for: [update.id])
        XCTAssertEqual(counts[update.id], 1)
    }
}

private extension Result {
    func getOrElse(_ failure: (Failure) -> Void) -> Success {
        switch self {
        case let .success(s): return s
        case let .failure(f):
            failure(f)
            fatalError()
        }
    }
}
