import Foundation
import AppKit
import QuickLookThumbnailing
import CryptoKit

final class ThumbnailService {
    static let shared = ThumbnailService()

    private let attachmentsDir: URL
    private let thumbnailsDir: URL
    private let fm = FileManager.default
    private let thumbnailable: Set<String> = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "pdf"]

    init(attachmentsDir: URL? = nil, thumbnailsDir: URL? = nil) {
        if let dir = attachmentsDir {
            self.attachmentsDir = dir
        } else {
            let base = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/Attachments", isDirectory: true)
            self.attachmentsDir = base
        }
        if let tdir = thumbnailsDir {
            self.thumbnailsDir = tdir
        } else {
            let base = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/Attachments/Thumbnails", isDirectory: true)
            self.thumbnailsDir = base
        }
        try? fm.createDirectory(at: self.thumbnailsDir, withIntermediateDirectories: true)
    }

    func ensureThumbnail(attachment: Attachment) async -> NSImage? {
        let hash = attachment.sha256
        let thumbURL = thumbnailsDir.appendingPathComponent("\(hash).png")
        if let data = try? Data(contentsOf: thumbURL), let img = NSImage(data: data) {
            return img
        }
        guard let ext = attachment.ext?.lowercased(), thumbnailable.contains(ext) else {
            return nil
        }
        let fileURL = attachmentsDir
            .appendingPathComponent(String(hash.prefix(2)), isDirectory: true)
            .appendingPathComponent(hash + ".\(ext)")
        let start = Date()
        do {
            let size = CGSize(width: 160, height: 160)
            let request = QLThumbnailGenerator.Request(fileAt: fileURL, size: size, scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail)
            let rep = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QLThumbnailRepresentation, Error>) in
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                    if let r = representation {
                        cont.resume(returning: r)
                    } else {
                        cont.resume(throwing: error ?? NSError(domain: "Thumb", code: 1))
                    }
                }
            }
            guard let cg = rep.cgImage else { return nil }
            let image = NSImage(cgImage: cg, size: size)
            if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: thumbURL)
            }
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            LoggingService.shared.log("thumb_generate_ok attachmentId=\(attachment.id) sha256=\(hash) elapsedMs=\(ms)", logger: .database)
            return image
        } catch {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            LoggingService.shared.log("thumb_generate_fail attachmentId=\(attachment.id) sha256=\(hash) elapsedMs=\(ms) error=\(error)", type: .error, logger: .database)
            return nil
        }
    }
}
