@testable import DragonShield
import SQLite3
import XCTest

final class AttachmentServiceTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?
    var tempDir: URL!
    var service: AttachmentService!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        manager.ensureAttachmentTable()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = AttachmentService(dbManager: manager, attachmentsDir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        service = nil
        super.tearDown()
    }

    func testValidateAndIngest() throws {
        let file = tempDir.appendingPathComponent("note.txt")
        try "hello".data(using: .utf8)?.write(to: file)
        switch service.validate(fileURL: file) {
        case let .failure(err): XCTFail("validate failed: \(err)")
        case let .success(valid):
            XCTAssertEqual(valid.byteSize, 5)
        }
        let att = service.ingest(fileURL: file, actor: "tester")
        XCTAssertNotNil(att)
        XCTAssertEqual(att?.ext, "txt")
        let prefix = String(att!.sha256.prefix(2))
        let stored = tempDir
            .appendingPathComponent(prefix)
            .appendingPathComponent(att!.sha256 + ".txt")
        let exists = FileManager.default.fileExists(atPath: stored.path)
        XCTAssertTrue(exists)
    }

    func testRejectLargeFile() throws {
        let file = tempDir.appendingPathComponent("big.txt")
        let data = Data(count: 101 * 1024 * 1024)
        try data.write(to: file)
        switch service.validate(fileURL: file) {
        case .failure:
            XCTAssertTrue(true)
        case .success:
            XCTFail("Should not validate big file")
        }
    }

    func testQuickLookPdf() throws {
        let file = tempDir.appendingPathComponent("doc.pdf")
        let pdfBytes: [UInt8] = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25, 0x45, 0x4F, 0x46]
        try Data(pdfBytes).write(to: file)
        let att = service.ingest(fileURL: file, actor: "tester")
        XCTAssertNotNil(att)
        XCTAssertEqual(att?.ext, "pdf")
        let opened = service.quickLook(attachmentId: att!.id)
        XCTAssertTrue(opened)
    }

    func testDeleteAttachmentRemovesFileAndRow() throws {
        let file = tempDir.appendingPathComponent("note2.txt")
        try "bye".data(using: .utf8)?.write(to: file)
        guard let att = service.ingest(fileURL: file, actor: "tester") else {
            XCTFail("ingest failed"); return
        }
        let prefix = String(att.sha256.prefix(2))
        let dir = tempDir.appendingPathComponent(prefix)
        let stored = dir.appendingPathComponent(att.sha256 + ".txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: stored.path))
        XCTAssertTrue(service.deleteAttachment(attachmentId: att.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: stored.path))
        let dirExists = FileManager.default.fileExists(atPath: dir.path)
        XCTAssertFalse(dirExists)
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(manager.db, "SELECT COUNT(*) FROM Attachment WHERE id = ?", -1, &stmt, nil)
        sqlite3_bind_int(stmt, 1, Int32(att.id))
        _ = sqlite3_step(stmt)
        let count = sqlite3_column_int(stmt, 0)
        sqlite3_finalize(stmt)
        XCTAssertEqual(count, 0)
    }

    func testCleanupOrphansRespectsBothLinkTables() throws {
        sqlite3_exec(manager.db, "CREATE TABLE PortfolioTheme(id INTEGER PRIMARY KEY);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO PortfolioTheme(id) VALUES (1);", nil, nil, nil)
        sqlite3_exec(manager.db, "CREATE TABLE Instruments(instrument_id INTEGER PRIMARY KEY);", nil, nil, nil)
        sqlite3_exec(manager.db, "INSERT INTO Instruments(instrument_id) VALUES (1);", nil, nil, nil)
        manager.ensurePortfolioThemeUpdateTable()
        manager.ensurePortfolioThemeAssetUpdateTable()
        manager.ensureThemeUpdateAttachmentTable()
        manager.ensureThemeAssetUpdateAttachmentTable()

        let themeUpdate = manager.createThemeUpdate(themeId: 1, title: "t", bodyMarkdown: "b", type: .General, pinned: false, author: "a", positionsAsOf: nil, totalValueChf: nil)!
        let instrumentUpdate = manager.createInstrumentUpdate(themeId: 1, instrumentId: 1, title: "i", bodyMarkdown: "b", type: .General, pinned: false, author: "a")!

        let file1 = tempDir.appendingPathComponent("a.txt")
        try "a".data(using: .utf8)?.write(to: file1)
        let file2 = tempDir.appendingPathComponent("b.txt")
        try "b".data(using: .utf8)?.write(to: file2)
        let att1 = service.ingest(fileURL: file1, actor: "tester")!
        let att2 = service.ingest(fileURL: file2, actor: "tester")!

        let themeRepo = ThemeUpdateRepository(dbManager: manager)
        _ = themeRepo.linkAttachment(updateId: themeUpdate.id, attachmentId: att1.id)
        let assetRepo = ThemeAssetUpdateRepository(dbManager: manager)
        _ = assetRepo.linkAttachment(updateId: instrumentUpdate.id, attachmentId: att2.id)

        XCTAssertEqual(service.cleanupOrphans(), 0)
        _ = themeRepo.unlinkAttachment(updateId: themeUpdate.id, attachmentId: att1.id)
        XCTAssertEqual(service.cleanupOrphans(), 1)
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(manager.db, "SELECT COUNT(*) FROM Attachment WHERE id = ?", -1, &stmt, nil)
        sqlite3_bind_int(stmt, 1, Int32(att1.id))
        _ = sqlite3_step(stmt)
        let c1 = sqlite3_column_int(stmt, 0)
        sqlite3_finalize(stmt)
        XCTAssertEqual(c1, 0)
        sqlite3_prepare_v2(manager.db, "SELECT COUNT(*) FROM Attachment WHERE id = ?", -1, &stmt, nil)
        sqlite3_bind_int(stmt, 1, Int32(att2.id))
        _ = sqlite3_step(stmt)
        let c2 = sqlite3_column_int(stmt, 0)
        sqlite3_finalize(stmt)
        XCTAssertEqual(c2, 1)
    }
}
