import Foundation
#if canImport(QuickLookThumbnailing)
import QuickLookThumbnailing
import AppKit
#endif

/// Generates and caches attachment thumbnails.
final class ThumbnailService {
    private let attachmentsDir: URL
    private let thumbnailsDir: URL
    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "ThumbnailService", qos: .utility, attributes: .concurrent)

    init(attachmentsDir: URL? = nil) {
        if let dir = attachmentsDir {
            self.attachmentsDir = dir
        } else {
            let base = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/Attachments", isDirectory: true)
            self.attachmentsDir = base
        }
        self.thumbnailsDir = self.attachmentsDir.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fm.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
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
        let original = attachmentsDir
            .appendingPathComponent(String(attachment.sha256.prefix(2)), isDirectory: true)
            .appendingPathComponent(attachment.sha256 + (attachment.ext.map { ".\($0)" } ?? ""))
        queue.async {
            do {
                #if canImport(QuickLookThumbnailing)
                let req = QLThumbnailGenerator.Request(fileAt: original, size: CGSize(width: 160, height: 160), scale: 1, representationTypes: .thumbnail)
                let gen = QLThumbnailGenerator.shared
                let sem = DispatchSemaphore(value: 0)
                var rep: QLThumbnailRepresentation?
                var err: Error?
                gen.generateBestRepresentation(for: req) { r, e in
                    rep = r
                    err = e
                    sem.signal()
                }
                sem.wait()
                if let rep = rep, let image = rep.nsImage, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .png, properties: [:]) {
                    try data.write(to: dest, options: .atomic)
                    LoggingService.shared.log("{\"attachmentId\":\(attachment.id),\"sha256\":\"\(attachment.sha256)\",\"sizePx\":160,\"elapsedMs\":0,\"op\":\"thumb_generate_ok\"}", logger: .database)
                    completion(.success(dest))
                } else if let e = err {
                    throw e
                } else {
                    throw NSError(domain: "ThumbnailService", code: 1)
                }
                #else
                try self.fm.copyItem(at: original, to: dest)
                LoggingService.shared.log("{\"attachmentId\":\(attachment.id),\"sha256\":\"\(attachment.sha256)\",\"sizePx\":160,\"elapsedMs\":0,\"op\":\"thumb_generate_ok\"}", logger: .database)
                completion(.success(dest))
                #endif
            } catch {
                LoggingService.shared.log("{\"attachmentId\":\(attachment.id),\"sha256\":\"\(attachment.sha256)\",\"errorKind\":\"\(error)\",\"op\":\"thumb_generate_fail\"}", type: .error, logger: .database)
                completion(.failure(error))
            }
        }
    }
}
