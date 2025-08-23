import Foundation
import CryptoKit
import UniformTypeIdentifiers
import AppKit
import SQLite3

final class AttachmentService {
    struct ValidatedFile {
        let url: URL
        let filename: String
        let mime: String
        let byteSize: Int
        let ext: String?
    }

    enum ValidationError: Error {
        case typeNotAllowed
        case fileTooLarge(Int)
        case emptyFile
    }

    private let dbManager: DatabaseManager
    private let attachmentsDir: URL
    private let fm = FileManager.default
    private let allowedTypes: [UTType] = [
        .pdf,
        .png,
        .jpeg,
        .heic,
        .gif,
        .plainText,
        .commaSeparatedText,
        UTType("net.daringfireball.markdown")!,
        UTType(filenameExtension: "docx")!,
        UTType(filenameExtension: "xlsx")!,
        UTType(filenameExtension: "pptx")!
    ]
    private let maxFileSize = 100 * 1024 * 1024

    private var thumbnailsDir: URL {
        attachmentsDir.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    init(dbManager: DatabaseManager, attachmentsDir: URL? = nil) {
        self.dbManager = dbManager
        if let dir = attachmentsDir {
            self.attachmentsDir = dir
        } else {
            let base = fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/Attachments", isDirectory: true)
            self.attachmentsDir = base
        }
        try? fm.createDirectory(at: self.attachmentsDir, withIntermediateDirectories: true)
    }

    func validate(fileURL: URL) -> Result<ValidatedFile, Error> {
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .nameKey])
            guard let size = resourceValues.fileSize else { throw ValidationError.emptyFile }
            guard size > 0 else { throw ValidationError.emptyFile }
            guard size <= maxFileSize else { throw ValidationError.fileTooLarge(size) }
            guard let utType = resourceValues.contentType, allowedTypes.contains(utType) else { throw ValidationError.typeNotAllowed }
            let filename = resourceValues.name ?? fileURL.lastPathComponent
            let mime = utType.preferredMIMEType ?? "application/octet-stream"
            return .success(ValidatedFile(url: fileURL, filename: filename, mime: mime, byteSize: size, ext: fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension))
        } catch {
            return .failure(error)
        }
    }

    func ingest(fileURL: URL, actor: String) -> Attachment? {
        switch validate(fileURL: fileURL) {
        case .failure:
            return nil
        case .success(let valid):
            let data: Data
            do {
                data = try Data(contentsOf: valid.url)
            } catch {
                LoggingService.shared.log("Failed to read data for attachment \(valid.url): \(error)", type: .error, logger: .database)
                return nil
            }
            let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            let subdir = attachmentsDir.appendingPathComponent(String(hash.prefix(2)), isDirectory: true)
            let filename = hash + (valid.ext.map { ".\($0)" } ?? "")
            let dest = subdir.appendingPathComponent(filename)
            if !fm.fileExists(atPath: dest.path) {
                do {
                    if !fm.fileExists(atPath: subdir.path) {
                        try fm.createDirectory(at: subdir, withIntermediateDirectories: true)
                    }
                    try fm.copyItem(at: valid.url, to: dest)
                } catch {
                    LoggingService.shared.log("Failed to copy attachment from \(valid.url) to \(dest.path): \(error)", type: .error, logger: .database)
                    return nil
                }
            }
            guard let db = dbManager.db else { return nil }
            let insertSQL = """
            INSERT OR IGNORE INTO Attachment (sha256, original_filename, mime, byte_size, ext, created_at, created_by)
            VALUES (?, ?, ?, ?, ?, STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'), ?)
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_text(stmt, 1, hash, -1, AttachmentService.sqliteTransient)
            sqlite3_bind_text(stmt, 2, valid.filename, -1, AttachmentService.sqliteTransient)
            sqlite3_bind_text(stmt, 3, valid.mime, -1, AttachmentService.sqliteTransient)
            sqlite3_bind_int(stmt, 4, Int32(valid.byteSize))
            if let ext = valid.ext {
                sqlite3_bind_text(stmt, 5, ext, -1, AttachmentService.sqliteTransient)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            sqlite3_bind_text(stmt, 6, actor, -1, AttachmentService.sqliteTransient)
            guard sqlite3_step(stmt) == SQLITE_DONE else { sqlite3_finalize(stmt); return nil }
            sqlite3_finalize(stmt)
            let query = "SELECT id, sha256, original_filename, mime, byte_size, ext, created_at, created_by FROM Attachment WHERE sha256 = ?"
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_text(stmt, 1, hash, -1, AttachmentService.sqliteTransient)
            var result: Attachment?
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let sha = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let mime = String(cString: sqlite3_column_text(stmt, 3))
                let size = Int(sqlite3_column_int(stmt, 4))
                let ext = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                let createdAt = String(cString: sqlite3_column_text(stmt, 6))
                let createdBy = String(cString: sqlite3_column_text(stmt, 7))
                result = Attachment(id: id, sha256: sha, originalFilename: name, mime: mime, byteSize: size, ext: ext, createdAt: createdAt, createdBy: createdBy)
            }
            sqlite3_finalize(stmt)
            if let att = result, FeatureFlags.portfolioAttachmentThumbnailsEnabled() {
                ThumbnailService(attachmentsDir: attachmentsDir).ensureThumbnail(for: att) { _ in }
            }
            return result
        }
    }

    @discardableResult
    func quickLook(attachmentId: Int) -> Bool {
        guard let db = dbManager.db else { return false }
        let sql = "SELECT sha256, ext FROM Attachment WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(attachmentId))
        var sha: String?
        var ext: String?
        if sqlite3_step(stmt) == SQLITE_ROW {
            sha = String(cString: sqlite3_column_text(stmt, 0))
            if let c = sqlite3_column_text(stmt, 1) { ext = String(cString: c) }
        }
        sqlite3_finalize(stmt)
        guard let hash = sha else { return false }
        let file = attachmentsDir
            .appendingPathComponent(String(hash.prefix(2)))
            .appendingPathComponent(hash + (ext.map { ".\($0)" } ?? ""))
        return NSWorkspace.shared.open(file)
    }

    func revealInFinder(attachmentId: Int) {
        guard let db = dbManager.db else { return }
        let sql = "SELECT sha256, ext FROM Attachment WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_int(stmt, 1, Int32(attachmentId))
        var sha: String?
        var ext: String?
        if sqlite3_step(stmt) == SQLITE_ROW {
            sha = String(cString: sqlite3_column_text(stmt, 0))
            if let c = sqlite3_column_text(stmt, 1) { ext = String(cString: c) }
        }
        sqlite3_finalize(stmt)
        guard let hash = sha else { return }
        let file = attachmentsDir
            .appendingPathComponent(String(hash.prefix(2)))
            .appendingPathComponent(hash + (ext.map { ".\($0)" } ?? ""))
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }

    @discardableResult
    func deleteAttachment(attachmentId: Int) -> Bool {
        guard let db = dbManager.db else { return false }
        let sql = "SELECT sha256, ext FROM Attachment WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(attachmentId))
        var sha: String?
        var ext: String?
        if sqlite3_step(stmt) == SQLITE_ROW {
            sha = String(cString: sqlite3_column_text(stmt, 0))
            if let c = sqlite3_column_text(stmt, 1) { ext = String(cString: c) }
        }
        sqlite3_finalize(stmt)
        guard let hash = sha else { return false }

        let unlink1 = "DELETE FROM ThemeUpdateAttachment WHERE attachment_id = ?"
        if sqlite3_prepare_v2(db, unlink1, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(attachmentId))
            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        let unlink2 = "DELETE FROM ThemeAssetUpdateAttachment WHERE attachment_id = ?"
        if sqlite3_prepare_v2(db, unlink2, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(attachmentId))
            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }

        let deleteSQL = "DELETE FROM Attachment WHERE id = ?"
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare deleteAttachment failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(attachmentId))
        let stepResult = sqlite3_step(stmt)
        let changes = sqlite3_changes(db)
        sqlite3_finalize(stmt)
        guard stepResult == SQLITE_DONE && changes == 1 else { return false }

        let file = attachmentsDir
            .appendingPathComponent(String(hash.prefix(2)))
            .appendingPathComponent(hash + (ext.map { ".\($0)" } ?? ""))
        do {
            try fm.removeItem(at: file)
            let parent = file.deletingLastPathComponent()
            if let contents = try? fm.contentsOfDirectory(atPath: parent.path), contents.isEmpty {
                try fm.removeItem(at: parent)
            }
        } catch {
            LoggingService.shared.log("Failed to remove attachment file \(file.path): \(error)", type: .error, logger: .database)
        }
        let thumb = thumbnailsDir.appendingPathComponent("\(hash).png")
        if fm.fileExists(atPath: thumb.path) {
            try? fm.removeItem(at: thumb)
        }
        return true
    }

    func cleanupOrphans() -> Int {
        guard let db = dbManager.db else { return 0 }
        let sql = "SELECT id, sha256, ext FROM Attachment WHERE id NOT IN (SELECT attachment_id FROM ThemeUpdateAttachment UNION SELECT attachment_id FROM ThemeAssetUpdateAttachment)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        var deleted = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let sha = String(cString: sqlite3_column_text(stmt, 1))
            var ext: String?
            if let c = sqlite3_column_text(stmt, 2) { ext = String(cString: c) }
            let file = attachmentsDir
                .appendingPathComponent(String(sha.prefix(2)))
                .appendingPathComponent(sha + (ext.map { ".\($0)" } ?? ""))
            try? fm.removeItem(at: file)
            let parent = file.deletingLastPathComponent()
            if let contents = try? fm.contentsOfDirectory(atPath: parent.path), contents.isEmpty {
                try? fm.removeItem(at: parent)
            }
            let thumb = thumbnailsDir.appendingPathComponent("\(sha).png")
            if fm.fileExists(atPath: thumb.path) {
                try? fm.removeItem(at: thumb)
                LoggingService.shared.log("{\"sha256\":\"\(sha)\",\"op\":\"thumb_cleanup_delete\"}", logger: .database)
            }
            deleteAttachmentRow(id: id, db: db)
            deleted += 1
        }
        sqlite3_finalize(stmt)

        if let thumbFiles = try? fm.contentsOfDirectory(at: thumbnailsDir, includingPropertiesForKeys: nil) {
            for thumb in thumbFiles where thumb.pathExtension == "png" {
                let sha = thumb.deletingPathExtension().lastPathComponent
                let query = "SELECT ext FROM Attachment WHERE sha256 = ?"
                if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, sha, -1, AttachmentService.sqliteTransient)
                    var ext: String?
                    if sqlite3_step(stmt) == SQLITE_ROW {
                        if let c = sqlite3_column_text(stmt, 0) { ext = String(cString: c) }
                    }
                    sqlite3_finalize(stmt)
                    var remove = false
                    if ext == nil {
                        remove = true
                    } else {
                        let orig = attachmentsDir
                            .appendingPathComponent(String(sha.prefix(2)))
                            .appendingPathComponent(sha + (ext.map { ".\($0)" } ?? ""))
                        if !fm.fileExists(atPath: orig.path) {
                            remove = true
                        }
                    }
                    if remove {
                        try? fm.removeItem(at: thumb)
                        LoggingService.shared.log("{\"sha256\":\"\(sha)\",\"op\":\"thumb_cleanup_delete\"}", logger: .database)
                    }
                }
            }
        }
        return deleted
    }

    private func deleteAttachmentRow(id: Int, db: OpaquePointer) {
        let sql = "DELETE FROM Attachment WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) != SQLITE_DONE {
                LoggingService.shared.log("deleteAttachmentRow failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            }
            sqlite3_finalize(stmt)
        }
    }

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

