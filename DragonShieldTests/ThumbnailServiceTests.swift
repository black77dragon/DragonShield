import XCTest
import AppKit
@testable import DragonShield

final class ThumbnailServiceTests: XCTestCase {
    func testLoadImageFromDisk() async throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        let hash = "abcdef1234567890"
        let sub = temp.appendingPathComponent(String(hash.prefix(2)))
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        let file = sub.appendingPathComponent(hash + ".png")
        let img = NSImage(size: NSSize(width: 10, height: 10))
        img.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        img.unlockFocus()
        let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
        let data = rep.representation(using: .png, properties: [:])!
        try data.write(to: file)
        let att = Attachment(id: 1, sha256: hash, originalFilename: "t.png", mime: "image/png", byteSize: data.count, ext: "png", createdAt: "", createdBy: "")
        let service = ThumbnailService(attachmentsDir: temp)
        let loaded = await service.loadImage(for: att)
        XCTAssertNotNil(loaded)
    }
}
