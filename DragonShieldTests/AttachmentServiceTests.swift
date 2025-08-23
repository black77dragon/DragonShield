import XCTest
import SQLite3
@testable import DragonShield

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
        case .failure(let err): XCTFail("validate failed: \(err)")
        case .success(let valid):
            XCTAssertEqual(valid.byteSize, 5)
        }
        let att = service.ingest(fileURL: file, actor: "tester")
        XCTAssertNotNil(att)
        let prefix = String(att!.sha256.prefix(2))
        let stored = tempDir.appendingPathComponent(prefix).appendingPathComponent(att!.sha256)
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
}

