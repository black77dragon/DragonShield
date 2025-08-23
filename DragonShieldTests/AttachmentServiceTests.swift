import XCTest
import SQLite3
@testable import DragonShield

final class AttachmentServiceTests: XCTestCase {
    var manager: DatabaseManager!
    var memdb: OpaquePointer?
    var service: AttachmentService!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &memdb)
        manager.db = memdb
        sqlite3_exec(manager.db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        manager.ensureAttachmentTable()
        service = AttachmentService(dbManager: manager, rootDir: FileManager.default.temporaryDirectory)
    }

    override func tearDown() {
        sqlite3_close(memdb)
        memdb = nil
        manager = nil
        service = nil
        super.tearDown()
    }

    func testIngestValidFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "hello".data(using: .utf8)!.write(to: tmp)
        let att = try service.ingest(fileURL: tmp, actor: "tester")
        XCTAssertGreaterThan(att.id, 0)
        let stored = service.rootDir.appendingPathComponent(String(att.sha256.prefix(2))).appendingPathComponent(att.sha256)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stored.path))
    }

    func testRejectLargeFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("large.txt")
        let data = Data(count: 101 * 1024 * 1024)
        try data.write(to: tmp)
        switch service.validate(fileURL: tmp) {
        case .success:
            XCTFail("should fail")
        case .failure:
            break
        }
    }
}
