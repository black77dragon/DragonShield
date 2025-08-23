import Foundation
import CryptoKit
import UniformTypeIdentifiers

struct AttachmentService {
    let dbManager: DatabaseManager
    let baseURL: URL

    init(dbManager: DatabaseManager, baseURL: URL = AttachmentService.defaultBaseURL()) {
        self.dbManager = dbManager
        self.baseURL = baseURL
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    static let allowedTypes: [UTType] = [
        .pdf, .png, .jpeg, .heic, .gif, .plainText, .commaSeparatedText, .markdown,
        UTType(filenameExtension: "docx")!,
        UTType(filenameExtension: "xlsx")!,
        UTType(filenameExtension: "pptx")!
    ]

    enum AttachmentError: Error {
        case typeNotAllowed
        case fileTooLarge
        case emptyFile
        case copyFailed
    }

    func validate(fileURL: URL) -> Result<URL, AttachmentError> {
        guard let type = UTType(filenameExtension: fileURL.pathExtension.lowercased()), Self.allowedTypes.contains(type) else {
            return .failure(.typeNotAllowed)
        }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path), let size = attrs[.size] as? NSNumber else {
            return .failure(.copyFailed)
        }
        let byteSize = size.intValue
        guard byteSize > 0 else { return .failure(.emptyFile) }
        if byteSize > 100 * 1024 * 1024 { return .failure(.fileTooLarge) }
        return .success(fileURL)
    }

    func ingest(fileURL: URL, actor: String) -> Result<Attachment, Error> {
        switch validate(fileURL: fileURL) {
        case .failure(let err): return .failure(err)
        case .success: break
        }
        guard let data = try? Data(contentsOf: fileURL) else { return .failure(AttachmentError.copyFailed) }
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let dir = baseURL.appendingPathComponent(String(sha.prefix(2)), isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(sha)
        if !FileManager.default.fileExists(atPath: dest.path) {
            do { try data.write(to: dest) } catch { return .failure(error) }
        }
        let mime = UTType(filenameExtension: fileURL.pathExtension.lowercased())?.preferredMIMEType ?? "application/octet-stream"
        if let attachment = dbManager.upsertAttachment(sha256: sha, originalFilename: fileURL.lastPathComponent, mime: mime, byteSize: data.count, ext: fileURL.pathExtension, actor: actor) {
            return .success(attachment)
        }
        return .failure(AttachmentError.copyFailed)
    }

    private static func defaultBaseURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("DragonShield/Attachments", isDirectory: true)
    }
}
