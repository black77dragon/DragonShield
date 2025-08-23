import XCTest
import SQLite3
import AppKit
@testable import DragonShield

final class ThumbnailServiceTests: XCTestCase {
    func testGeneratesThumbnailForPng() async throws {
        let manager = DatabaseManager()
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        manager.db = db
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        manager.ensureAttachmentTable()
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let attachmentService = AttachmentService(dbManager: manager, attachmentsDir: temp)
        let pngURL = temp.appendingPathComponent("img.png")
        let img = NSImage(size: NSSize(width: 2, height: 2))
        img.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
        img.unlockFocus()
        let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
        try rep.representation(using: .png, properties: [:])!.write(to: pngURL)
        guard let att = attachmentService.ingest(fileURL: pngURL, actor: "t") else {
            XCTFail("ingest failed"); return
        }
        let thumbDir = temp.appendingPathComponent("thumbs")
        let service = ThumbnailService(attachmentsDir: temp, thumbnailsDir: thumbDir)
        let thumb = await service.ensureThumbnail(att)
        XCTAssertNotNil(thumb)
        sqlite3_close(db)
        try? FileManager.default.removeItem(at: temp)
    }
}
