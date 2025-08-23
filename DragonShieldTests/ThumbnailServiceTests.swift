import XCTest
import SQLite3
@testable import DragonShield

final class ThumbnailServiceTests: XCTestCase {
    var manager: DatabaseManager!
    var db: OpaquePointer?
    var tempDir: URL!
    var attachmentService: AttachmentService!
    var thumbService: ThumbnailService!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &db)
        manager.db = db
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        manager.ensureAttachmentTable()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        attachmentService = AttachmentService(dbManager: manager, attachmentsDir: tempDir)
        thumbService = ThumbnailService(attachmentsDir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        sqlite3_close(db)
        db = nil
        manager = nil
        attachmentService = nil
        thumbService = nil
        super.tearDown()
    }

    private func writeTestPNG(to url: URL) throws {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAAAElFTkSuQmCC"
        let data = Data(base64Encoded: base64)!
        try data.write(to: url)
    }

    func testGenerateAndDeleteThumbnail() throws {
        let file = tempDir.appendingPathComponent("img.png")
        try writeTestPNG(to: file)
        guard let att = attachmentService.ingest(fileURL: file, actor: "tester") else {
            XCTFail("ingest failed"); return
        }
        let exp = expectation(description: "thumb")
        thumbService.ensureThumbnail(for: att) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            case .failure(let err):
                XCTFail("thumb failed: \(err)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
        let thumbPath = thumbService.thumbnailURL(for: att.sha256).path
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbPath))
        XCTAssertTrue(attachmentService.deleteAttachment(attachmentId: att.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbPath))
    }

    func testCleanupOrphansDeletesThumbnails() throws {
        let file = tempDir.appendingPathComponent("orphan.png")
        try writeTestPNG(to: file)
        guard let att = attachmentService.ingest(fileURL: file, actor: "tester") else {
            XCTFail("ingest failed"); return
        }
        let exp = expectation(description: "thumb")
        thumbService.ensureThumbnail(for: att) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 2)
        let thumbPath = thumbService.thumbnailURL(for: att.sha256).path
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbPath))
        XCTAssertEqual(attachmentService.cleanupOrphans(), 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: thumbPath))
    }
}
