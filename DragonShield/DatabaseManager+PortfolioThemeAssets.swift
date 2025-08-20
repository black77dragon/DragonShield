import Foundation
import SQLite3

extension DatabaseManager {
    func ensurePortfolioThemeAssetTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS PortfolioThemeAsset (
            theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE RESTRICT,
            instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE RESTRICT,
            research_target_pct REAL NOT NULL DEFAULT 0.0 CHECK (research_target_pct >= 0.0 AND research_target_pct <= 100.0),
            user_target_pct REAL NOT NULL DEFAULT 0.0 CHECK (user_target_pct >= 0.0 AND user_target_pct <= 100.0),
            notes TEXT NULL,
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            PRIMARY KEY (theme_id, instrument_id)
        );
        CREATE INDEX IF NOT EXISTS idx_theme_asset_instrument ON PortfolioThemeAsset(instrument_id);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            LoggingService.shared.log("ensurePortfolioThemeAssetTable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
        }
    }

    private func themeEditable(themeId: Int) -> Bool {
        let sql = "SELECT archived_at, soft_delete FROM PortfolioTheme WHERE id = ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare themeEditable failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return false
        }

        sqlite3_bind_int(stmt, 1, Int32(themeId))

        if sqlite3_step(stmt) == SQLITE_ROW {
            let archived = sqlite3_column_text(stmt, 0)
            let softDelete = sqlite3_column_int(stmt, 1) == 1
            return archived == nil && !softDelete
        }

        return false
    }

    private func instrumentExists(_ instrumentId: Int) -> Bool {
        let sql = "SELECT 1 FROM Instruments WHERE instrument_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
            exists = sqlite3_step(stmt) == SQLITE_ROW
        }
        sqlite3_finalize(stmt)
        return exists
    }

    func createThemeAsset(themeId: Int, instrumentId: Int, researchPct: Double, userPct: Double? = nil, notes: String? = nil) -> PortfolioThemeAsset? {
        guard PortfolioThemeAsset.isValidPercentage(researchPct),
              PortfolioThemeAsset.isValidPercentage(userPct ?? researchPct) else {
            LoggingService.shared.log("Invalid percentage bounds", type: .info, logger: .database)
            return nil
        }
        guard themeEditable(themeId: themeId) else {
            LoggingService.shared.log("Theme \(themeId) not editable", type: .info, logger: .database)
            return nil
        }
        guard instrumentExists(instrumentId) else {
            LoggingService.shared.log("Instrument \(instrumentId) missing", type: .info, logger: .database)
            return nil
        }
        let uPct = userPct ?? researchPct
        let sql = """
            INSERT INTO PortfolioThemeAsset (theme_id, instrument_id, research_target_pct, user_target_pct, notes)
            VALUES (?,?,?,?,?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            LoggingService.shared.log("prepare createThemeAsset failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            return nil
        }
        sqlite3_bind_int(stmt, 1, Int32(themeId))
        sqlite3_bind_int(stmt, 2, Int32(instrumentId))
        sqlite3_bind_double(stmt, 3, researchPct)
        sqlite3_bind_double(stmt, 4, uPct)
        if let notes = notes {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 5, notes, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        if sqlite3_step(stmt) != SQLITE_DONE {
            LoggingService.shared.log("createThemeAsset failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        sqlite3_finalize(stmt)
        return getThemeAsset(themeId: themeId, instrumentId: instrumentId)
    }

    func getThemeAsset(themeId: Int, instrumentId: Int) -> PortfolioThemeAsset? {
        let sql = """
            SELECT theme_id, instrument_id, research_target_pct, user_target_pct, notes, created_at, updated_at
            FROM PortfolioThemeAsset WHERE theme_id = ? AND instrument_id = ?
        """
        var stmt: OpaquePointer?
        var asset: PortfolioThemeAsset?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            sqlite3_bind_int(stmt, 2, Int32(instrumentId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let themeId = Int(sqlite3_column_int(stmt, 0))
                let instrId = Int(sqlite3_column_int(stmt, 1))
                let research = sqlite3_column_double(stmt, 2)
                let user = sqlite3_column_double(stmt, 3)
                let notes = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                let createdAt = String(cString: sqlite3_column_text(stmt, 5))
                let updatedAt = String(cString: sqlite3_column_text(stmt, 6))
                asset = PortfolioThemeAsset(themeId: themeId, instrumentId: instrId, researchTargetPct: research, userTargetPct: user, notes: notes, createdAt: createdAt, updatedAt: updatedAt)
            }
        }
        sqlite3_finalize(stmt)
        return asset
    }

    func listThemeAssets(themeId: Int) -> [PortfolioThemeAsset] {
        var assets: [PortfolioThemeAsset] = []
        let sql = """
            SELECT theme_id, instrument_id, research_target_pct, user_target_pct, notes, created_at, updated_at
            FROM PortfolioThemeAsset WHERE theme_id = ? ORDER BY instrument_id
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let themeId = Int(sqlite3_column_int(stmt, 0))
                let instrId = Int(sqlite3_column_int(stmt, 1))
                let research = sqlite3_column_double(stmt, 2)
                let user = sqlite3_column_double(stmt, 3)
                let notes = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                let createdAt = String(cString: sqlite3_column_text(stmt, 5))
                let updatedAt = String(cString: sqlite3_column_text(stmt, 6))
                assets.append(PortfolioThemeAsset(themeId: themeId, instrumentId: instrId, researchTargetPct: research, userTargetPct: user, notes: notes, createdAt: createdAt, updatedAt: updatedAt))
            }
        }
        sqlite3_finalize(stmt)
        return assets
    }

    func updateThemeAsset(themeId: Int, instrumentId: Int, researchPct: Double?, userPct: Double?, notes: String?) -> PortfolioThemeAsset? {
        guard themeEditable(themeId: themeId) else {
            LoggingService.shared.log("Theme \(themeId) not editable", type: .info, logger: .database)
            return nil
        }
        if let r = researchPct, !PortfolioThemeAsset.isValidPercentage(r) { return nil }
        if let u = userPct, !PortfolioThemeAsset.isValidPercentage(u) { return nil }
        let sql = """
            UPDATE PortfolioThemeAsset
            SET research_target_pct = COALESCE(?, research_target_pct),
                user_target_pct = COALESCE(?, user_target_pct),
                notes = COALESCE(?, notes),
                updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
            WHERE theme_id = ? AND instrument_id = ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        if let r = researchPct { sqlite3_bind_double(stmt, 1, r) } else { sqlite3_bind_null(stmt, 1) }
        if let u = userPct { sqlite3_bind_double(stmt, 2, u) } else { sqlite3_bind_null(stmt, 2) }
        if let notes = notes {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 3, notes, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }
        sqlite3_bind_int(stmt, 4, Int32(themeId))
        sqlite3_bind_int(stmt, 5, Int32(instrumentId))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            LoggingService.shared.log("updateThemeAsset failed: \(String(cString: sqlite3_errmsg(db)))", type: .error, logger: .database)
            sqlite3_finalize(stmt)
            return nil
        }
        sqlite3_finalize(stmt)
        return getThemeAsset(themeId: themeId, instrumentId: instrumentId)
    }

    func removeThemeAsset(themeId: Int, instrumentId: Int) -> Bool {
        guard themeEditable(themeId: themeId) else {
            LoggingService.shared.log("Theme \(themeId) not editable", type: .info, logger: .database)
            return false
        }
        let sql = "DELETE FROM PortfolioThemeAsset WHERE theme_id = ? AND instrument_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(themeId))
        sqlite3_bind_int(stmt, 2, Int32(instrumentId))
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }

    func countThemeAssets(themeId: Int) -> Int {
        let sql = "SELECT COUNT(*) FROM PortfolioThemeAsset WHERE theme_id = ?"
        var stmt: OpaquePointer?
        var result = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(themeId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
}
