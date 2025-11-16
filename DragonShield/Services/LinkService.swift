import Foundation
import SQLite3

final class LinkService {
    enum ValidationError: Error {
        case unsupportedScheme
        case invalidURL
        case tooLong
        case missingHost
        case hasWhitespace
        case hasCredentials
    }

    private let dbManager: DatabaseManager
    static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
        dbManager.ensureLinkTable()
    }

    struct NormalizedLink {
        let normalized: String
        let raw: String
    }

    func validateAndNormalize(_ rawURL: String) -> Result<NormalizedLink, ValidationError> {
        guard rawURL.count <= 2048 else { return .failure(.tooLong) }
        guard rawURL.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return .failure(.hasWhitespace) }
        guard let comps = URLComponents(string: rawURL) else { return .failure(.invalidURL) }
        guard let scheme = comps.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return .failure(.unsupportedScheme) }
        guard comps.host != nil else { return .failure(.missingHost) }
        if comps.user != nil || comps.password != nil { return .failure(.hasCredentials) }
        var norm = comps
        norm.scheme = scheme
        norm.host = comps.host?.lowercased()
        norm.fragment = nil
        if (scheme == "http" && norm.port == 80) || (scheme == "https" && norm.port == 443) { norm.port = nil }
        if var path = norm.percentEncodedPath.removingPercentEncoding {
            if path.count > 1 && path.hasSuffix("/") { path.removeLast() }
            norm.percentEncodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        }
        if let query = norm.percentEncodedQuery?.removingPercentEncoding {
            norm.percentEncodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        guard let normalized = norm.string else { return .failure(.invalidURL) }
        return .success(NormalizedLink(normalized: normalized, raw: rawURL))
    }

    func ensureLink(normalized: String, raw: String, actor: String) -> Link? {
        guard let db = dbManager.db else { return nil }
        var stmt: OpaquePointer?
        let selectSQL = "SELECT id, normalized_url, raw_url, title, created_at, created_by FROM Link WHERE normalized_url = ?"
        if sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, normalized, -1, LinkService.sqliteTransient)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let normalizedURL = String(cString: sqlite3_column_text(stmt, 1))
                let rawURL = String(cString: sqlite3_column_text(stmt, 2))
                let title = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let createdAt = String(cString: sqlite3_column_text(stmt, 4))
                let createdBy = String(cString: sqlite3_column_text(stmt, 5))
                sqlite3_finalize(stmt)
                return Link(id: id, normalizedURL: normalizedURL, rawURL: rawURL, title: title, createdAt: createdAt, createdBy: createdBy)
            }
            sqlite3_finalize(stmt)
        }
        let insertSQL = """
        INSERT INTO Link (normalized_url, raw_url, created_at, created_by)
        VALUES (?, ?, STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'), ?)
        """
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, normalized, -1, LinkService.sqliteTransient)
        sqlite3_bind_text(stmt, 2, raw, -1, LinkService.sqliteTransient)
        sqlite3_bind_text(stmt, 3, actor, -1, LinkService.sqliteTransient)
        guard sqlite3_step(stmt) == SQLITE_DONE else { sqlite3_finalize(stmt); return nil }
        sqlite3_finalize(stmt)
        let id = Int(sqlite3_last_insert_rowid(db))
        let createdAtSQL = "SELECT created_at FROM Link WHERE id = ?"
        guard sqlite3_prepare_v2(db, createdAtSQL, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_int(stmt, 1, Int32(id))
        var createdAt = ""
        if sqlite3_step(stmt) == SQLITE_ROW {
            createdAt = String(cString: sqlite3_column_text(stmt, 0))
        }
        sqlite3_finalize(stmt)
        return Link(id: id, normalizedURL: normalized, rawURL: raw, title: nil, createdAt: createdAt, createdBy: actor)
    }

    @discardableResult
    func updateTitle(linkId: Int, title: String?) -> Bool {
        guard let db = dbManager.db else { return false }
        if let t = title, t.count > 200 { return false }
        let sql = "UPDATE Link SET title = ? WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        if let t = title {
            sqlite3_bind_text(stmt, 1, t, -1, LinkService.sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, 1)
        }
        sqlite3_bind_int(stmt, 2, Int32(linkId))
        guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
        return true
    }

    @discardableResult
    func deleteIfUnreferenced(linkId: Int) -> Bool {
        guard let db = dbManager.db else { return false }
        let countSQL = "SELECT COUNT(*) FROM ThemeUpdateLink WHERE link_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, countSQL, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(linkId))
        var count = 0
        if sqlite3_step(stmt) == SQLITE_ROW {
            count = Int(sqlite3_column_int(stmt, 0))
        }
        sqlite3_finalize(stmt)
        if count == 0 {
            let deleteSQL = "DELETE FROM Link WHERE id = ?"
            guard sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK else { return false }
            sqlite3_bind_int(stmt, 1, Int32(linkId))
            let result = sqlite3_step(stmt) == SQLITE_DONE
            sqlite3_finalize(stmt)
            return result
        }
        return false
    }
}
