import XCTest
import SQLite3
@testable import DragonShield

final class AttachmentServiceTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?
    var service: AttachmentService!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        manager.ensureAttachmentTable()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        service = AttachmentService(dbManager: manager, baseURL: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        service = nil
        super.tearDown()
    }

    func testValidateRejectsUnsupportedType() {
        let bad = tempDir.appendingPathComponent("bad.exe")
        FileManager.default.createFile(atPath: bad.path, contents: Data([0x0]), attributes: nil)
        let result = service.validate(fileURL: bad)
        switch result {
        case .failure(let err):
            if case .typeNotAllowed = err { } else { XCTFail("Wrong error") }
        default:
            XCTFail("Should fail")
        }
    }

    func testIngestCopiesAndRecords() {
        let file = tempDir.appendingPathComponent("note.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data("hi".utf8), attributes: nil)
        let result = service.ingest(fileURL: file, actor: "tester")
        switch result {
        case .success(let attachment):
            let stored = tempDir.appendingPathComponent(String(attachment.sha256.prefix(2))).appendingPathComponent(attachment.sha256)
            XCTAssertTrue(FileManager.default.fileExists(atPath: stored.path))
            XCTAssertEqual(attachment.originalFilename, "note.txt")
        default:
            XCTFail("ingest failed")
        }
    }
}
