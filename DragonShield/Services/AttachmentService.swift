import Foundation
import CryptoKit
import UniformTypeIdentifiers
import SQLite3

final class AttachmentService {
    private let dbManager: DatabaseManager
    private let fileManager = FileManager.default
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private let maxFileSize = 100 * 1024 * 1024 // 100 MB

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
        dbManager.ensureAttachmentTable()
    }

    struct ValidatedFile {
        let url: URL
        let size: Int
        let mime: String
        let originalFilename: String
        let ext: String?
    }

    enum ValidationError: Error, LocalizedError {
        case typeNotAllowed
        case fileTooLarge
        case emptyFile

        var errorDescription: String? {
            switch self {
            case .typeNotAllowed: return "Type not allowed"
            case .fileTooLarge: return "File too large"
            case .emptyFile: return "File is empty"
            }
        }
    }

    func validate(fileURL: URL) throws -> ValidatedFile {
        let values = try fileURL.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey, .nameKey])
        guard let size = values.fileSize else { throw ValidationError.emptyFile }
        if size == 0 { throw ValidationError.emptyFile }
        if size > maxFileSize { throw ValidationError.fileTooLarge }
        guard let type = values.contentType else { throw ValidationError.typeNotAllowed }
        let allowed: [UTType] = [
            .pdf, .png, .jpeg, .heic, .gif, .plainText,
            UTType("public.comma-separated-values-text"), .markdown,
            UTType(filenameExtension: "docx"),
            UTType(filenameExtension: "xlsx"),
            UTType(filenameExtension: "pptx")
        ].compactMap { $0 }
        guard allowed.contains(where: { type.conforms(to: $0) }) else { throw ValidationError.typeNotAllowed }
        let mime = type.preferredMIMEType ?? "application/octet-stream"
        let name = values.name ?? fileURL.lastPathComponent
        let ext = fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension
        return ValidatedFile(url: fileURL, size: size, mime: mime, originalFilename: name, ext: ext)
    }

    func ingest(fileURL: URL, actor: String) throws -> Attachment {
        let validated = try validate(fileURL: fileURL)
        let data = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: data)
        let sha = hash.map { String(format: "%02x", $0) }.joined()
        let base = try attachmentsDirectory()
        let subdir = base.appendingPathComponent(String(sha.prefix(2)), isDirectory: true)
        try fileManager.createDirectory(at: subdir, withIntermediateDirectories: true)
        let dest = subdir.appendingPathComponent(sha)
        if !fileManager.fileExists(atPath: dest.path) {
            try fileManager.copyItem(at: fileURL, to: dest)
        }
        guard let db = dbManager.db else { throw ValidationError.emptyFile }
        var stmt: OpaquePointer?
        let selectSQL = "SELECT id, sha256, original_filename, mime, byte_size, ext, created_at, created_by FROM Attachment WHERE sha256 = ? LIMIT 1"
        if sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, sha, -1, AttachmentService.sqliteTransient)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let mime = String(cString: sqlite3_column_text(stmt, 3))
                let size = Int(sqlite3_column_int(stmt, 4))
                let ext = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                let createdAt = String(cString: sqlite3_column_text(stmt, 6))
                let createdBy = String(cString: sqlite3_column_text(stmt, 7))
                sqlite3_finalize(stmt)
                return Attachment(id: id, sha256: sha, originalFilename: name, mime: mime, byteSize: size, ext: ext, createdAt: createdAt, createdBy: createdBy)
            }
        }
        sqlite3_finalize(stmt)
        let insertSQL = """
        INSERT INTO Attachment (sha256, original_filename, mime, byte_size, ext, created_at, created_by)
        VALUES (?, ?, ?, ?, ?, STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'), ?)
        """
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else { throw ValidationError.emptyFile }
        sqlite3_bind_text(stmt, 1, sha, -1, AttachmentService.sqliteTransient)
        sqlite3_bind_text(stmt, 2, validated.originalFilename, -1, AttachmentService.sqliteTransient)
        sqlite3_bind_text(stmt, 3, validated.mime, -1, AttachmentService.sqliteTransient)
        sqlite3_bind_int(stmt, 4, Int32(validated.size))
        if let ext = validated.ext {
            sqlite3_bind_text(stmt, 5, ext, -1, AttachmentService.sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_text(stmt, 6, actor, -1, AttachmentService.sqliteTransient)
        guard sqlite3_step(stmt) == SQLITE_DONE else { sqlite3_finalize(stmt); throw ValidationError.emptyFile }
        sqlite3_finalize(stmt)
        let id = Int(sqlite3_last_insert_rowid(db))
        let createdAt = ISO8601DateFormatter().string(from: Date())
        return Attachment(id: id, sha256: sha, originalFilename: validated.originalFilename, mime: validated.mime, byteSize: validated.size, ext: validated.ext, createdAt: createdAt, createdBy: actor)
    }

    private func attachmentsDirectory() throws -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DragonShield/Attachments", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}

