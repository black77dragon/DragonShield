import Foundation
import AppKit

final class ThumbnailService {
    enum ThumbnailError: Error { case unsupported; case generationFailed }

    private let fm = FileManager.default
    private let attachmentsDir: URL
    private let thumbnailsDir: URL
    private let queue: OperationQueue

    init(attachmentsDir: URL? = nil) {
        if let dir = attachmentsDir {
            self.attachmentsDir = dir
        } else {
            let base = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/Attachments", isDirectory: true)
            self.attachmentsDir = base
        }
        self.thumbnailsDir = attachmentsDir.map { $0.appendingPathComponent("Thumbnails", isDirectory: true) } ?? self.attachmentsDir.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fm.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
        self.queue = OperationQueue()
        self.queue.maxConcurrentOperationCount = 2
    }

    func thumbnailURL(for sha256: String) -> URL {
        thumbnailsDir.appendingPathComponent("\(sha256).png")
    }

    func ensureThumbnail(for attachment: Attachment, completion: @escaping (Result<URL, Error>) -> Void) {
        let dest = thumbnailURL(for: attachment.sha256)
        if fm.fileExists(atPath: dest.path) {
            completion(.success(dest))
            return
        }
        queue.addOperation {
            let start = Date()
            let source = self.attachmentsDir
                .appendingPathComponent(String(attachment.sha256.prefix(2)))
                .appendingPathComponent(attachment.sha256 + (attachment.ext.map { ".\($0)" } ?? ""))
            guard let image = NSImage(contentsOf: source) else {
                LoggingService.shared.log("{\"attachmentId\":\(attachment.id),\"sha256\":\"\(attachment.sha256)\",\"errorKind\":\"unsupported\",\"op\":\"thumb_generate_fail\"}", type: .error, logger: .database)
                OperationQueue.main.addOperation { completion(.failure(ThumbnailError.unsupported)) }
                return
            }
            let maxSide: CGFloat = 160
            let scale = min(1, maxSide / max(image.size.width, image.size.height))
            let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
                LoggingService.shared.log("{\"attachmentId\":\(attachment.id),\"sha256\":\"\(attachment.sha256)\",\"errorKind\":\"bitmap\",\"op\":\"thumb_generate_fail\"}", type: .error, logger: .database)
                OperationQueue.main.addOperation { completion(.failure(ThumbnailError.generationFailed)) }
                return
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()
            image.draw(in: NSRect(origin: .zero, size: size))
            NSGraphicsContext.restoreGraphicsState()
            guard let data = rep.representation(using: .png, properties: [:]) else {
                LoggingService.shared.log("{\"attachmentId\":\(attachment.id),\"sha256\":\"\(attachment.sha256)\",\"errorKind\":\"encode\",\"op\":\"thumb_generate_fail\"}", type: .error, logger: .database)
                OperationQueue.main.addOperation { completion(.failure(ThumbnailError.generationFailed)) }
                return
            }
            do {
                try data.write(to: dest, options: .atomic)
                let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                LoggingService.shared.log("{\"attachmentId\":\(attachment.id),\"sha256\":\"\(attachment.sha256)\",\"sizePx\":160,\"elapsedMs\":\(elapsed),\"op\":\"thumb_generate_ok\"}", logger: .database)
                OperationQueue.main.addOperation { completion(.success(dest)) }
            } catch {
                LoggingService.shared.log("{\"attachmentId\":\(attachment.id),\"sha256\":\"\(attachment.sha256)\",\"errorKind\":\"write\",\"op\":\"thumb_generate_fail\"}", type: .error, logger: .database)
                OperationQueue.main.addOperation { completion(.failure(error)) }
            }
        }
    }
}

