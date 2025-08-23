import Foundation
#if canImport(QuickLookThumbnailing)
import QuickLookThumbnailing
import CoreGraphics
#endif

final class ThumbnailService {
    private let attachmentsDir: URL
    private let thumbnailsDir: URL
    private let fm = FileManager.default

    init(attachmentsDir: URL) {
        self.attachmentsDir = attachmentsDir
        self.thumbnailsDir = attachmentsDir.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fm.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
    }

    func thumbnailURL(for sha256: String) -> URL {
        thumbnailsDir.appendingPathComponent("\(sha256).png")
    }

    func ensureThumbnail(for attachment: Attachment, completion: @escaping (Result<URL, Error>) -> Void) {
#if canImport(QuickLookThumbnailing)
        let url = thumbnailURL(for: attachment.sha256)
        if fm.fileExists(atPath: url.path) {
            completion(.success(url))
            return
        }
        let original = attachmentsDir
            .appendingPathComponent(String(attachment.sha256.prefix(2)))
            .appendingPathComponent(attachment.sha256 + (attachment.ext.map { ".\($0)" } ?? ""))
        let size = CGSize(width: 160, height: 160)
        let request = QLThumbnailGenerator.Request(fileAt: original, size: size, scale: 1, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumb, _, error in
            if let thumb, let data = thumb.pngRepresentation {
                do {
                    try data.write(to: url, options: .atomic)
                    completion(.success(url))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(error ?? NSError(domain: "ThumbnailService", code: 1)))
            }
        }
#else
        completion(.failure(NSError(domain: "ThumbnailService", code: 0)))
#endif
    }

    func deleteThumbnail(for sha256: String) {
        let url = thumbnailURL(for: sha256)
        if fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: url)
        }
    }
}
