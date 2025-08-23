import XCTest
import SQLite3
@testable import DragonShield

final class ThumbnailServiceTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?
    var tempDir: URL!
    var attachService: AttachmentService!
    var thumbService: ThumbnailService!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        manager.ensureAttachmentTable()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        attachService = AttachmentService(dbManager: manager, attachmentsDir: tempDir)
        thumbService = ThumbnailService(attachmentsDir: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        attachService = nil
        thumbService = nil
        super.tearDown()
    }

    func testEnsureThumbnailCreatesFile() throws {
        let file = tempDir.appendingPathComponent("img.png")
        let pngData: [UInt8] = [137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,6,0,0,0,31,21,196,137,0,0,0,12,73,68,65,84,120,156,99,248,15,4,0,9,251,3,253,167,37,143,221,0,0,0,0,73,69,78,68,174,66,96,130]
        try Data(pngData).write(to: file)
        guard let att = attachService.ingest(fileURL: file, actor: "tester") else { XCTFail("ingest failed"); return }
        let exp = expectation(description: "thumb")
        thumbService.ensureThumbnail(attachment: att) { image in
            XCTAssertNotNil(image)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2)
        let thumbFile = tempDir.appendingPathComponent("Thumbnails").appendingPathComponent(att.sha256 + ".png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbFile.path))
    }
}

