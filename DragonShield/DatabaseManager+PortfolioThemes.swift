// DragonShield/DatabaseManager+PortfolioThemes.swift
// MARK: - Version 1.0
// MARK: - History
// - Initial creation: CRUD helpers for PortfolioTheme.

import SQLite3
import Foundation

extension DatabaseManager {
    struct ThemeAllocationRow: Identifiable {
        let id: Int
        let name: String
        let instrumentCount: Int
        let allocatedUserPct: Double
    }

    func listThemeAllocations(includeSoftDeleted: Bool = false) -> [ThemeAllocationRow] {
        var rows: [ThemeAllocationRow] = []
        var sql = """
            SELECT pt.id,
                   pt.name,
                   COUNT(pta.instrument_id) AS instrument_count,
                   IFNULL(SUM(pta.user_target_pct), 0) AS allocated_user_pct
              FROM PortfolioTheme pt
              LEFT JOIN PortfolioThemeAsset pta ON pta.theme_id = pt.id
             WHERE 1=1
        """
        if !includeSoftDeleted { sql += " AND pt.soft_delete = 0" }
        sql += " GROUP BY pt.id, pt.name ORDER BY allocated_user_pct DESC, pt.name"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let count = Int(sqlite3_column_int(stmt, 2))
            let alloc = sqlite3_column_double(stmt, 3)
            rows.append(ThemeAllocationRow(id: id, name: name, instrumentCount: count, allocatedUserPct: alloc))
        }
        return rows
    }
    func ensurePortfolioThemeTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS PortfolioTheme (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL CHECK (LENGTH(name) BETWEEN 1 AND 64),
            code TEXT NOT NULL CHECK (code GLOB '[A-Z][A-Z0-9_]*' AND LENGTH(code) BETWEEN 2 AND 31),
            description TEXT NULL CHECK (LENGTH(description) <= 2000),
            institution_id INTEGER NULL REFERENCES Institutions(institution_id) ON DELETE SET NULL,
            status_id INTEGER NOT NULL REFERENCES PortfolioThemeStatus(id),
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            archived_at TEXT NULL,
            soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1))
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_portfolio_theme_name_unique ON PortfolioTheme(LOWER(name)) WHERE soft_delete = 0;
        CREATE UNIQUE INDEX IF NOT EXISTS idx_portfolio_theme_code_unique ON PortfolioTheme(LOWER(code)) WHERE soft_delete = 0;
        CREATE INDEX IF NOT EXISTS idx_portfolio_theme_institution_id ON PortfolioTheme(institution_id);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensurePortfolioThemeTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    /// Normalize legacy archived_at values: some older DBs stored empty string instead of NULL.
    /// This migration is safe and idempotent.
    func normalizeThemeArchivedMarkers() {
        var hasArchived = false
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(PortfolioTheme);", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let nameC = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: nameC)
                    if name.caseInsensitiveCompare("archived_at") == .orderedSame { hasArchived = true; break }
                }
            }
        }
        sqlite3_finalize(stmt)
        guard hasArchived else { return }
        let sql = "UPDATE PortfolioTheme SET archived_at = NULL WHERE archived_at IS NOT NULL AND LENGTH(TRIM(archived_at)) = 0;"
        if sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK {
            LoggingService.shared.log("Normalized empty archived_at markers to NULL", logger: .database)
        }
    }
    private func singleIntQuery(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) -> Int? {
        var stmt: OpaquePointer?
        var result: Int?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if let bind = bind { bind(stmt!) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    func defaultThemeStatusId() -> Int? {
        singleIntQuery("SELECT id FROM PortfolioThemeStatus WHERE is_default = 1 LIMIT 1")
    }

    private func archivedThemeStatusId() -> Int? {
        singleIntQuery("SELECT id FROM PortfolioThemeStatus WHERE code = ? LIMIT 1") { stmt in
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, PortfolioThemeStatus.archivedCode, -1, SQLITE_TRANSIENT)
        }
    }

    // Lookup status id by code (e.g., "DRAFT")
    private func statusId(code: String) -> Int? {
        singleIntQuery("SELECT id FROM PortfolioThemeStatus WHERE code = ? LIMIT 1") { stmt in
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, code, -1, SQLITE_TRANSIENT)
        }
    }

    /// Set or clear soft delete flag on a theme.
    func setThemeSoftDelete(id: Int, softDelete: Bool) -> Bool {
        guard tableHasColumn(table: "PortfolioTheme", column: "soft_delete") else { return false }
        let sql = "UPDATE PortfolioTheme SET soft_delete = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare setThemeSoftDelete failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, softDelete ? 1 : 0)
        sqlite3_bind_int(stmt, 2, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE { LoggingService.shared.log("setThemeSoftDelete id=\(id) -> \(softDelete)", logger: .database); return true }
        LoggingService.shared.log("setThemeSoftDelete failed id=\(id): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        return false
    }

    /// Full restore: clears soft delete, unarchives, and sets status to DRAFT (fallback to default if missing).
    func fullRestoreTheme(id: Int) -> Bool {
        let draft = statusId(code: "DRAFT")
        let targetStatus = draft ?? defaultThemeStatusId()
        guard let statusId = targetStatus else {
            LoggingService.shared.log("fullRestoreTheme failed: no DRAFT or default status found", type: .error, logger: .database)
            return false
        }
        let hasSoft = tableHasColumn(table: "PortfolioTheme", column: "soft_delete")
        let sql = hasSoft
            ? "UPDATE PortfolioTheme SET status_id = ?, archived_at = NULL, soft_delete = 0, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
            : "UPDATE PortfolioTheme SET status_id = ?, archived_at = NULL, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare fullRestoreTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(statusId))
        sqlite3_bind_int(stmt, 2, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE { LoggingService.shared.log("Full restored theme id=\(id) -> status=\(statusId)", logger: .database); return true }
        LoggingService.shared.log("fullRestoreTheme failed id=\(id): \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        return false
    }

    private func tableHasColumn(table: String, column: String) -> Bool {
        var stmt: OpaquePointer?
        var exists = false
        let sql = "PRAGMA table_info(\(table))"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let nameC = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: nameC)
                    if name.caseInsensitiveCompare(column) == .orderedSame { exists = true; break }
                }
            }
        }
        sqlite3_finalize(stmt)
        return exists
    }

    private func tableExists(_ name: String) -> Bool {
        var stmt: OpaquePointer?
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND LOWER(name)=LOWER(?) LIMIT 1"
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
            exists = (sqlite3_step(stmt) == SQLITE_ROW)
        }
        sqlite3_finalize(stmt)
        return exists
    }

    func fetchPortfolioThemes(includeArchived: Bool = true, includeSoftDeleted: Bool = false, search: String? = nil) -> [PortfolioTheme] {
        var themes: [PortfolioTheme] = []
        guard tableExists("PortfolioTheme") else {
            LoggingService.shared.log("PortfolioTheme table missing in database — returning empty list", type: .info, logger: .database)
            return []
        }
        // Optional: avoid prepare error if asset table is absent in snapshot
        let hasAssetTable = tableExists("PortfolioThemeAsset")
        let hasBudget = tableHasColumn(table: "PortfolioTheme", column: "theoretical_budget_chf")
        let hasSoftDelete = tableHasColumn(table: "PortfolioTheme", column: "soft_delete")
        let hasArchivedAt = tableHasColumn(table: "PortfolioTheme", column: "archived_at")

        var sql = "SELECT pt.id,pt.name,pt.code,pt.description,pt.institution_id,pt.status_id,pt.created_at,pt.updated_at,"
        sql += (hasArchivedAt ? "pt.archived_at" : "NULL")
        sql += ","
        sql += (hasSoftDelete ? "pt.soft_delete" : "0")
        if hasBudget { sql += ",pt.theoretical_budget_chf" }
        if hasAssetTable {
            sql += ",(SELECT COUNT(*) FROM PortfolioThemeAsset pta WHERE pta.theme_id = pt.id)"
        } else {
            sql += ",0"
        }
        sql += " FROM PortfolioTheme pt WHERE 1=1"
        if !includeArchived, hasArchivedAt { sql += " AND archived_at IS NULL" }
        if !includeSoftDeleted, hasSoftDelete { sql += " AND soft_delete = 0" }
        if let s = search, !s.isEmpty {
            sql += " AND (name LIKE ? OR code LIKE ?)"
        }
        sql += " ORDER BY updated_at DESC"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if let s = search, !s.isEmpty {
                let like = "%" + s + "%"
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(stmt, 1, like, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, like, -1, SQLITE_TRANSIENT)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let code = String(cString: sqlite3_column_text(stmt, 2))
                let desc = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let instId = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
                let statusId = Int(sqlite3_column_int(stmt, 5))
                let createdAt = String(cString: sqlite3_column_text(stmt, 6))
                let updatedAt = String(cString: sqlite3_column_text(stmt, 7))
                let archivedRaw = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                let archivedAt = (archivedRaw?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) ? nil : archivedRaw
                let softDelete = sqlite3_column_int(stmt, 9) == 1
                var idx = 10
                let budget: Double?
                if hasBudget {
                    budget = sqlite3_column_type(stmt, Int32(idx)) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, Int32(idx))
                    idx += 1
                } else {
                    budget = nil
                }
                let count = Int(sqlite3_column_int(stmt, Int32(idx)))
                themes.append(PortfolioTheme(id: id, name: name, code: code, description: desc, institutionId: instId, statusId: statusId, createdAt: createdAt, updatedAt: updatedAt, archivedAt: archivedAt, softDelete: softDelete, theoreticalBudgetChf: budget, totalValueBase: nil, instrumentCount: count))
            }
        } else {
            LoggingService.shared.log("Failed to prepare fetchPortfolioThemes: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return themes
    }

    func createPortfolioTheme(name: String, code: String, description: String? = nil, institutionId: Int? = nil, statusId: Int? = nil) -> PortfolioTheme? {
        let upperCode = code.uppercased()
        guard PortfolioTheme.isValidName(name) else {
            LoggingService.shared.log("Invalid theme name", type: .info, logger: .database)
            return nil
        }
        guard PortfolioTheme.isValidCode(upperCode) else {
            LoggingService.shared.log("Invalid theme code", type: .info, logger: .database)
            return nil
        }
        let trimmedDesc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = trimmedDesc, d.count > 2000 {
            LoggingService.shared.log("Description too long", type: .info, logger: .database)
            return nil
        }
        if let inst = institutionId {
            let exists = singleIntQuery("SELECT institution_id FROM Institutions WHERE institution_id = ? LIMIT 1") { stmt in
                sqlite3_bind_int(stmt, 1, Int32(inst))
            }
            guard exists != nil else {
                LoggingService.shared.log("Invalid institution id=\(inst)", type: .error, logger: .database)
                return nil
            }
        }
        let status = statusId ?? defaultThemeStatusId()
        guard let status = status else {
            LoggingService.shared.log("No default Theme Status found", type: .error, logger: .database)
            return nil
        }
        let sql = "INSERT INTO PortfolioTheme (name, code, description, institution_id, status_id) VALUES (?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare createPortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, upperCode, -1, SQLITE_TRANSIENT)
        if let d = trimmedDesc, !d.isEmpty {
            sqlite3_bind_text(stmt, 3, d, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        if let inst = institutionId {
            sqlite3_bind_int(stmt, 4, Int32(inst))
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        sqlite3_bind_int(stmt, 5, Int32(status))
        if sqlite3_step(stmt) != SQLITE_DONE {
            LoggingService.shared.log("createPortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        sqlite3_finalize(stmt)
        let id = Int(sqlite3_last_insert_rowid(db))
        LoggingService.shared.log("createTheme id=\(id) description nil->\(trimmedDesc ?? "nil") institution nil->\(institutionId.map(String.init) ?? "nil")", logger: .database)
        return getPortfolioTheme(id: id)
    }

    func getPortfolioTheme(id: Int) -> PortfolioTheme? {
        let hasBudget = tableHasColumn(table: "PortfolioTheme", column: "theoretical_budget_chf")
        var sql = "SELECT pt.id,pt.name,pt.code,pt.description,pt.institution_id,pt.status_id,pt.created_at,pt.updated_at,pt.archived_at,pt.soft_delete"
        if hasBudget { sql += ",pt.theoretical_budget_chf" }
        sql += ",(SELECT COUNT(*) FROM PortfolioThemeAsset pta WHERE pta.theme_id = pt.id) FROM PortfolioTheme pt WHERE id = ? AND soft_delete = 0"
        var stmt: OpaquePointer?
        var theme: PortfolioTheme?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let code = String(cString: sqlite3_column_text(stmt, 2))
                let desc = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let instId = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 4))
                let statusId = Int(sqlite3_column_int(stmt, 5))
                let createdAt = String(cString: sqlite3_column_text(stmt, 6))
                let updatedAt = String(cString: sqlite3_column_text(stmt, 7))
                let archivedRaw = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                let archivedAt = (archivedRaw?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) ? nil : archivedRaw
                let softDelete = sqlite3_column_int(stmt, 9) == 1
                var idx = 10
                let budget: Double?
                if hasBudget {
                    budget = sqlite3_column_type(stmt, Int32(idx)) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, Int32(idx))
                    idx += 1
                } else {
                    budget = nil
                }
                let count = Int(sqlite3_column_int(stmt, Int32(idx)))
                theme = PortfolioTheme(id: id, name: name, code: code, description: desc, institutionId: instId, statusId: statusId, createdAt: createdAt, updatedAt: updatedAt, archivedAt: archivedAt, softDelete: softDelete, theoreticalBudgetChf: budget, totalValueBase: nil, instrumentCount: count)
            }
        }
        sqlite3_finalize(stmt)
        return theme
    }

    func updatePortfolioTheme(id: Int, name: String, description: String?, institutionId: Int?, statusId: Int, archivedAt: String?) -> Bool {
        // Disallow any changes when theme is archived or soft-deleted
        var guardStmt: OpaquePointer?
        var locked = false
        if sqlite3_prepare_v2(db, "SELECT archived_at, COALESCE(soft_delete, 0) FROM PortfolioTheme WHERE id = ?", -1, &guardStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(guardStmt, 1, Int32(id))
            if sqlite3_step(guardStmt) == SQLITE_ROW {
                let archived = sqlite3_column_text(guardStmt, 0) != nil
                let soft = sqlite3_column_int(guardStmt, 1) == 1
                locked = archived || soft
            }
        }
        sqlite3_finalize(guardStmt)
        if locked {
            LoggingService.shared.log("no changes possible, restore theme first", type: .info, logger: .database)
            return false
        }
        let trimmedDesc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = trimmedDesc, d.count > 2000 {
            LoggingService.shared.log("Description too long", type: .info, logger: .database)
            return false
        }
        if let inst = institutionId {
            let exists = singleIntQuery("SELECT institution_id FROM Institutions WHERE institution_id = ? LIMIT 1") { stmt in
                sqlite3_bind_int(stmt, 1, Int32(inst))
            }
            guard exists != nil else {
                LoggingService.shared.log("Invalid institution id=\(inst)", type: .error, logger: .database)
                return false
            }
        }
        var prevDesc: String?
        var prevInst: Int?
        var sel: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT description, institution_id FROM PortfolioTheme WHERE id = ?", -1, &sel, nil) == SQLITE_OK {
            sqlite3_bind_int(sel, 1, Int32(id))
            if sqlite3_step(sel) == SQLITE_ROW {
                prevDesc = sqlite3_column_text(sel, 0).map { String(cString: $0) }
                prevInst = sqlite3_column_type(sel, 1) == SQLITE_NULL ? nil : Int(sqlite3_column_int(sel, 1))
            }
        }
        sqlite3_finalize(sel)
        let sql = "UPDATE PortfolioTheme SET name = ?, description = ?, institution_id = ?, status_id = ?, archived_at = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare updatePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        if let d = trimmedDesc, !d.isEmpty {
            sqlite3_bind_text(stmt, 2, d, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 2)
        }
        if let inst = institutionId {
            sqlite3_bind_int(stmt, 3, Int32(inst))
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_int(stmt, 4, Int32(statusId))
        if let archivedAt = archivedAt {
            sqlite3_bind_text(stmt, 5, archivedAt, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_int(stmt, 6, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("updateTheme id=\(id) description \(prevDesc ?? "nil")->\(trimmedDesc ?? "nil") institution \(prevInst.map(String.init) ?? "nil")->\(institutionId.map(String.init) ?? "nil")", logger: .database)
            return true
        } else {
            LoggingService.shared.log("updatePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
    }

    func setPortfolioThemeUpdatedAt(id: Int, isoString: String) -> Bool {
        let sql = "UPDATE PortfolioTheme SET updated_at = ? WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare setPortfolioThemeUpdatedAt failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, isoString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 2, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        if !ok {
            LoggingService.shared.log("setPortfolioThemeUpdatedAt failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return ok
    }

    @discardableResult
    func touchPortfolioThemeUpdatedAt(id: Int) -> Bool {
        let sql = "UPDATE PortfolioTheme SET updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare touchPortfolioThemeUpdatedAt failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        if !ok {
            LoggingService.shared.log("touchPortfolioThemeUpdatedAt failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
        sqlite3_finalize(stmt)
        return ok
    }

    func archivePortfolioTheme(id: Int) -> Bool {
        guard let archivedId = archivedThemeStatusId() else {
            LoggingService.shared.log("\(PortfolioThemeStatus.archivedCode) status id not found", type: .error, logger: .database)
            return false
        }
        let sql = "UPDATE PortfolioTheme SET status_id = ?, archived_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'), updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare archivePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(archivedId))
        sqlite3_bind_int(stmt, 2, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("Archived theme id=\(id)", type: .info, logger: .database)
            return true
        }
        LoggingService.shared.log("archivePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        return false
    }

    func unarchivePortfolioTheme(id: Int, statusId: Int) -> Bool {
        // Validate status exists to avoid FK failures
        var check: OpaquePointer?
        var valid = false
        if sqlite3_prepare_v2(db, "SELECT 1 FROM PortfolioThemeStatus WHERE id = ?", -1, &check, nil) == SQLITE_OK {
            sqlite3_bind_int(check, 1, Int32(statusId))
            valid = (sqlite3_step(check) == SQLITE_ROW)
        }
        sqlite3_finalize(check)
        let finalStatusId: Int
        if valid { finalStatusId = statusId }
        else if let def = defaultThemeStatusId() { finalStatusId = def }
        else { finalStatusId = statusId } // last resort

        let sql = "UPDATE PortfolioTheme SET status_id = ?, archived_at = NULL, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare unarchivePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(finalStatusId))
        sqlite3_bind_int(stmt, 2, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("Unarchived theme id=\(id)", type: .info, logger: .database)
            return true
        }
        let err = String(cString: sqlite3_errmsg(db))
        LoggingService.shared.log("unarchivePortfolioTheme failed id=\(id) statusId=\(finalStatusId): \(err)", type: .error, logger: .database)
        return false
    }

    func clearPortfolioThemeInstitution(id: Int) -> Bool {
        var prevInst: Int?
        var sel: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT institution_id FROM PortfolioTheme WHERE id = ?", -1, &sel, nil) == SQLITE_OK {
            sqlite3_bind_int(sel, 1, Int32(id))
            if sqlite3_step(sel) == SQLITE_ROW {
                prevInst = sqlite3_column_type(sel, 0) == SQLITE_NULL ? nil : Int(sqlite3_column_int(sel, 0))
            }
        }
        sqlite3_finalize(sel)
        let sql = "UPDATE PortfolioTheme SET institution_id = NULL, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare clearPortfolioThemeInstitution failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("clearThemeInstitution id=\(id) institution \(prevInst.map(String.init) ?? "nil")->nil", logger: .database)
            return true
        }
        LoggingService.shared.log("clearPortfolioThemeInstitution failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        return false
    }

    func softDeletePortfolioTheme(id: Int) -> Bool {
        let checkSql = "SELECT archived_at FROM PortfolioTheme WHERE id = ?"
        var checkStmt: OpaquePointer?
        var archived: Bool = false
        if sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(checkStmt, 1, Int32(id))
            if sqlite3_step(checkStmt) == SQLITE_ROW {
                archived = sqlite3_column_text(checkStmt, 0) != nil
            }
        } else {
            LoggingService.shared.log("prepare softDeletePortfolioTheme check failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(checkStmt)
            return false
        }
        sqlite3_finalize(checkStmt)
        if !archived {
            LoggingService.shared.log("Soft delete requires the theme to be Archived first.", type: .info, logger: .database)
            return false
        }
        let sql = "UPDATE PortfolioTheme SET soft_delete = 1, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare softDeletePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("Soft deleted theme id=\(id)", type: .info, logger: .database)
            return true
        }
        LoggingService.shared.log("softDeletePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        return false
    }

    // MARK: - Hard delete (only if no attachments)
    func canHardDeletePortfolioTheme(id: Int) -> (ok: Bool, reason: String) {
        // Count direct links to provide actionable guidance
        let assetLinks = singleIntQuery("SELECT COUNT(*) FROM PortfolioThemeAsset WHERE theme_id = ?") { stmt in sqlite3_bind_int(stmt, 1, Int32(id)) } ?? 0
        let themeUpdates = singleIntQuery("SELECT COUNT(*) FROM PortfolioThemeUpdate WHERE theme_id = ? AND soft_delete = 0") { stmt in sqlite3_bind_int(stmt, 1, Int32(id)) } ?? 0
        var instrumentUpdates = 0
        if tableExists("PortfolioThemeAssetUpdate") {
            instrumentUpdates = singleIntQuery("SELECT COUNT(*) FROM PortfolioThemeAssetUpdate WHERE theme_id = ?") { stmt in sqlite3_bind_int(stmt, 1, Int32(id)) } ?? 0
        }
        if assetLinks > 0 || themeUpdates > 0 || instrumentUpdates > 0 {
            // Build a precise message with only non-zero categories
            var parts: [String] = []
            if assetLinks > 0 { parts.append("instruments=\(assetLinks)") }
            if themeUpdates > 0 { parts.append("notes/updates=\(themeUpdates)") }
            if instrumentUpdates > 0 { parts.append("instrument-updates=\(instrumentUpdates)") }
            let details = parts.joined(separator: ", ")
            let msg = "Linked data prevents deletion: \(details). Remove these links (or archive/soft delete) and try again."
            return (false, msg)
        }
        return (true, "OK")
    }

    func hardDeletePortfolioTheme(id: Int) -> Bool {
        let chk = canHardDeletePortfolioTheme(id: id)
        guard chk.ok else {
            LoggingService.shared.log("hardDeletePortfolioTheme denied id=\(id): \(chk.reason)", type: .info, logger: .database)
            return false
        }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM PortfolioTheme WHERE id = ?", -1, &stmt, nil) != SQLITE_OK {
            LoggingService.shared.log("prepare hardDeletePortfolioTheme failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }
        sqlite3_bind_int(stmt, 1, Int32(id))
        let rc = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        if rc == SQLITE_DONE {
            LoggingService.shared.log("Hard deleted theme id=\(id)", type: .info, logger: .database)
            return true
        }
        LoggingService.shared.log("hardDeletePortfolioTheme step failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        return false
    }

    // MARK: - Theme Budget
    private func ensureThemeBudgetColumn() {
        guard !tableHasColumn(table: "PortfolioTheme", column: "theoretical_budget_chf") else { return }
        let sql = "ALTER TABLE PortfolioTheme ADD COLUMN theoretical_budget_chf REAL NULL CHECK (theoretical_budget_chf >= 0)"
        if sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK {
            LoggingService.shared.log("Added PortfolioTheme.theoretical_budget_chf column via ALTER TABLE", logger: .database)
        } else {
            LoggingService.shared.log("Failed to add theoretical_budget_chf: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    @discardableResult
    func updateThemeBudget(themeId: Int, budgetChf: Double?) -> Bool {
        // Ensure column exists (auto-migrate if needed)
        ensureThemeBudgetColumn()
        guard tableHasColumn(table: "PortfolioTheme", column: "theoretical_budget_chf") else { return false }
        let sql = "UPDATE PortfolioTheme SET theoretical_budget_chf = ?, updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        if let b = budgetChf { sqlite3_bind_double(stmt, 1, b) } else { sqlite3_bind_null(stmt, 1) }
        sqlite3_bind_int(stmt, 2, Int32(themeId))
        return sqlite3_step(stmt) == SQLITE_DONE
    }
}
