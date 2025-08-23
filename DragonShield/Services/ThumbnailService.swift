import Foundation
import AppKit
import PDFKit

final class ThumbnailService {
    private let attachmentsDir: URL
    private let thumbnailsDir: URL
    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "ThumbnailService", qos: .userInitiated)
    private let semaphore = DispatchSemaphore(value: 2)
    private var failureIds = Set<Int>()

    init(attachmentsDir: URL? = nil, thumbnailsDir: URL? = nil) {
        let base = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield", isDirectory: true)
        self.attachmentsDir = attachmentsDir ?? base.appendingPathComponent("Attachments", isDirectory: true)
        self.thumbnailsDir = thumbnailsDir ?? base.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fm.createDirectory(at: self.thumbnailsDir, withIntermediateDirectories: true)
    }

    func ensureThumbnail(_ attachment: Attachment) async -> NSImage? {
        if failureIds.contains(attachment.id) { return nil }
        return await withCheckedContinuation { cont in
            queue.async {
                self.semaphore.wait()
                let start = Date()
                let img = self.generate(attachment)
                let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                self.semaphore.signal()
                DispatchQueue.main.async {
                    if img != nil {
                        LoggingService.shared.log("thumb_generate_ok attachmentId:\(attachment.id) sha256:\(attachment.sha256) elapsedMs:\(elapsed)", type: .info, logger: .ui)
                    } else {
                        LoggingService.shared.log("thumb_generate_fail attachmentId:\(attachment.id) sha256:\(attachment.sha256) elapsedMs:\(elapsed)", type: .error, logger: .ui)
                    }
                    cont.resume(returning: img)
                }
            }
        }
    }

    private func generate(_ attachment: Attachment) -> NSImage? {
        let hash = attachment.sha256
        let dest = thumbnailsDir
            .appendingPathComponent(String(hash.prefix(2)), isDirectory: true)
            .appendingPathComponent("\(hash).png")
        if fm.fileExists(atPath: dest.path), let img = NSImage(contentsOf: dest) {
            return img
        }
        let src = attachmentsDir
            .appendingPathComponent(String(hash.prefix(2)), isDirectory: true)
            .appendingPathComponent(hash + (attachment.ext.map { ".\($0)" } ?? ""))
        guard fm.fileExists(atPath: src.path) else {
            failureIds.insert(attachment.id)
            return nil
        }
        guard let ext = attachment.ext?.lowercased() else {
            failureIds.insert(attachment.id)
            return nil
        }
        let thumbnailable = ["png","jpg","jpeg","heic","gif","tiff","pdf"]
        guard thumbnailable.contains(ext) else {
            failureIds.insert(attachment.id)
            return nil
        }
        let image: NSImage?
        if ext == "pdf" {
            let doc = PDFDocument(url: src)
            image = doc?.page(at: 0)?.thumbnail(of: CGSize(width: 160, height: 160), for: .mediaBox)
        } else {
            image = NSImage(contentsOf: src)
        }
        guard let img = image else {
            failureIds.insert(attachment.id)
            return nil
        }
        if let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            do {
                let dir = dest.deletingLastPathComponent()
                if !fm.fileExists(atPath: dir.path) {
                    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                }
                try data.write(to: dest)
            } catch {
                failureIds.insert(attachment.id)
                return img
            }
        }
        return img
    }
}
