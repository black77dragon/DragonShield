import Foundation
import AppKit

final class ThumbnailService {
    private let attachmentsDir: URL
    private let thumbsDir: URL
    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "ThumbnailService", qos: .utility)

    init(attachmentsDir: URL? = nil) {
        if let dir = attachmentsDir {
            self.attachmentsDir = dir
        } else {
            self.attachmentsDir = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/Attachments", isDirectory: true)
        }
        self.thumbsDir = attachmentsDir?.appendingPathComponent("Thumbnails", isDirectory: true) ?? self.attachmentsDir.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fm.createDirectory(at: self.thumbsDir, withIntermediateDirectories: true)
    }

    func ensureThumbnail(attachment: Attachment, size: CGSize = CGSize(width: 160, height: 160), completion: @escaping (NSImage?) -> Void) {
        queue.async {
            let start = Date()
            let hash = attachment.sha256
            let original = self.attachmentsDir
                .appendingPathComponent(String(hash.prefix(2)), isDirectory: true)
                .appendingPathComponent(hash + (attachment.ext.map { ".\($0)" } ?? ""))
            let dest = self.thumbsDir.appendingPathComponent(hash + ".png")
            var image: NSImage?
            if self.fm.fileExists(atPath: dest.path) {
                image = NSImage(contentsOf: dest)
            } else if self.isThumbnailable(attachment: attachment),
                      let orig = NSImage(contentsOf: original) {
                let thumb = self.resize(image: orig, target: size)
                if let data = thumb.pngData {
                    try? data.write(to: dest)
                    image = thumb
                    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                    LoggingService.shared.log("thumb_generate_ok attachmentId: \(attachment.id) sha256: \(hash) elapsedMs: \(elapsed)", logger: .ui)
                } else {
                    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                    LoggingService.shared.log("thumb_generate_fail attachmentId: \(attachment.id) sha256: \(hash) elapsedMs: \(elapsed)", type: .error, logger: .ui)
                }
            } else {
                let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                LoggingService.shared.log("thumb_generate_fail attachmentId: \(attachment.id) sha256: \(hash) elapsedMs: \(elapsed)", type: .error, logger: .ui)
            }
            DispatchQueue.main.async { completion(image) }
        }
    }

    private func isThumbnailable(attachment: Attachment) -> Bool {
        guard let ext = attachment.ext?.lowercased() else { return false }
        return ["png","jpg","jpeg","heic","gif","tiff","pdf"].contains(ext)
    }

    private func resize(image: NSImage, target: CGSize) -> NSImage {
        let newImage = NSImage(size: target)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

