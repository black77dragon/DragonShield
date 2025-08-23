import Foundation
import CryptoKit
import UniformTypeIdentifiers
import SQLite3

struct ValidatedFile {
    let url: URL
    let size: Int
    let mime: String
    let ext: String?
}

enum AttachmentError: Error, LocalizedError {
    case unsupportedType
    case fileTooLarge
    case emptyFile
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unsupportedType: return "Type not allowed"
        case .fileTooLarge: return "File is too large"
        case .emptyFile: return "File is empty"
        case .unreadable: return "Could not read file"
        }
    }
}

final class AttachmentService {
    private let dbManager: DatabaseManager
    let rootDir: URL
    private let maxFileSize = 100 * 1024 * 1024
    private let allowedTypes: [UTType] = [
        .pdf, .png, .jpeg, .heic, .gif, .plainText, .commaSeparatedText, .markdown,
        UTType(filenameExtension: "docx")!,
        UTType(filenameExtension: "xlsx")!,
        UTType(filenameExtension: "pptx")!
    ]
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(dbManager: DatabaseManager, rootDir: URL? = nil) {
        self.dbManager = dbManager
        if let rootDir = rootDir {
            self.rootDir = rootDir
        } else {
            self.rootDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/Attachments", isDirectory: true)
        }
    }

    func validate(fileURL: URL) -> Result<ValidatedFile, Error> {
        do {
            let values = try fileURL.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
            guard let size = values.fileSize else { return .failure(AttachmentError.unreadable) }
            guard size > 0 else { return .failure(AttachmentError.emptyFile) }
            guard size <= maxFileSize else { return .failure(AttachmentError.fileTooLarge) }
            guard let type = values.contentType, allowedTypes.contains(type) else { return .failure(AttachmentError.unsupportedType) }
            let mime = type.preferredMIMEType ?? "application/octet-stream"
            let ext = fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension
            return .success(ValidatedFile(url: fileURL, size: size, mime: mime, ext: ext))
        } catch {
            return .failure(error)
        }
    }

    func ingest(fileURL: URL, actor: String) throws -> Attachment {
        let vf = try validate(fileURL: fileURL).get()
        let data = try Data(contentsOf: vf.url)
        let hash = SHA256.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
        let subdir = String(hash.prefix(2))
        let destDir = rootDir.appendingPathComponent(subdir, isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appendingPathComponent(hash)
        if !FileManager.default.fileExists(atPath: destURL.path) {
            try data.write(to: destURL)
        }
        guard let db = dbManager.db else { throw AttachmentError.unreadable }
        let insert = """
        INSERT OR IGNORE INTO Attachment (sha256, original_filename, mime, byte_size, ext, created_at, created_by)
        VALUES (?, ?, ?, ?, ?, STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'), ?);
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insert, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, hash, -1, AttachmentService.sqliteTransient)
            sqlite3_bind_text(stmt, 2, vf.url.lastPathComponent, -1, AttachmentService.sqliteTransient)
            sqlite3_bind_text(stmt, 3, vf.mime, -1, AttachmentService.sqliteTransient)
            sqlite3_bind_int(stmt, 4, Int32(vf.size))
            if let ext = vf.ext {
                sqlite3_bind_text(stmt, 5, ext, -1, AttachmentService.sqliteTransient)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            sqlite3_bind_text(stmt, 6, actor, -1, AttachmentService.sqliteTransient)
            _ = sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        let select = "SELECT id, created_at FROM Attachment WHERE sha256 = ?"
        var stmt2: OpaquePointer?
        var result: Attachment?
        if sqlite3_prepare_v2(db, select, -1, &stmt2, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt2, 1, hash, -1, AttachmentService.sqliteTransient)
            if sqlite3_step(stmt2) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt2, 0))
                let createdAt = String(cString: sqlite3_column_text(stmt2, 1))
                result = Attachment(id: id, sha256: hash, originalFilename: vf.url.lastPathComponent, mime: vf.mime, byteSize: vf.size, ext: vf.ext, createdAt: createdAt, createdBy: actor)
            }
        }
        sqlite3_finalize(stmt2)
        guard let attachment = result else { throw AttachmentError.unreadable }
        return attachment
    }
}
