import XCTest
import SQLite3
@testable import DragonShield

final class AttachmentServiceTests: XCTestCase {
    var manager: DatabaseManager!
    var db: OpaquePointer?
    var service: AttachmentService!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        manager = DatabaseManager()
        sqlite3_open(":memory:", &db)
        manager.db = db
        manager.ensureAttachmentTable()
        service = AttachmentService(dbManager: manager)
        tempDir = FileManager.default.temporaryDirectory
    }

    override func tearDown() {
        sqlite3_close(db)
        db = nil
        manager = nil
        service = nil
        super.tearDown()
    }

    func testIngestCopiesFileAndInsertsRow() throws {
        let fileURL = tempDir.appendingPathComponent("note.txt")
        try "hi".write(to: fileURL, atomically: true, encoding: .utf8)
        let att = try service.ingest(fileURL: fileURL, actor: "tester")
        XCTAssertEqual(att.originalFilename, "note.txt")
        var count: Int32 = 0
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM Attachment", -1, &stmt, nil)
        if sqlite3_step(stmt) == SQLITE_ROW {
            count = sqlite3_column_int(stmt, 0)
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(count, 1)
    }

    func testValidateRejectsLargeFile() throws {
        let bigURL = tempDir.appendingPathComponent("big.pdf")
        FileManager.default.createFile(atPath: bigURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: bigURL)
        try handle.seek(toOffset: UInt64(101 * 1024 * 1024))
        try handle.write(Data([0]))
        XCTAssertThrowsError(try service.validate(fileURL: bigURL))
    }
}
