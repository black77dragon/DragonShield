import XCTest
import AppKit
import CryptoKit
@testable import DragonShield

final class ThumbnailServiceTests: XCTestCase {
    func testEnsureThumbnailGeneratesFile() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let attachmentsDir = tmp.appendingPathComponent("Attachments", isDirectory: true)
        let thumbsDir = tmp.appendingPathComponent("Thumbs", isDirectory: true)
        try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: thumbsDir, withIntermediateDirectories: true)

        // Create a red square PNG
        let img = NSImage(size: NSSize(width: 50, height: 50))
        img.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 50, height: 50)).fill()
        img.unlockFocus()
        let tiff = img.tiffRepresentation!
        let rep = NSBitmapImageRep(data: tiff)!
        let data = rep.representation(using: .png, properties: [:])!
        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        let subdir = attachmentsDir.appendingPathComponent(String(hash.prefix(2)), isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let fileURL = subdir.appendingPathComponent("\(hash).png")
        try data.write(to: fileURL)
        let attachment = Attachment(id: 1, sha256: hash, originalFilename: "test.png", mime: "image/png", byteSize: data.count, ext: "png", createdAt: "", createdBy: "")

        let service = ThumbnailService(attachmentsDir: attachmentsDir, thumbnailsDir: thumbsDir)
        let thumb = await service.ensureThumbnail(attachment: attachment)
        XCTAssertNotNil(thumb)
        let thumbPath = thumbsDir.appendingPathComponent("\(hash).png").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbPath))
    }
}
