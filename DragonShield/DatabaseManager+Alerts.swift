import Foundation
import SQLite3

extension DatabaseManager {
    // MARK: - Alerts CRUD
    func listAlerts(includeDisabled: Bool = true) -> [AlertRow] {
        var rows: [AlertRow] = []
        guard let db else { return rows }
        let sql = includeDisabled ?
        """
        SELECT id, name, enabled, severity, scope_type, scope_id, trigger_type_code,
               params_json, near_value, near_unit, hysteresis_value, hysteresis_unit,
               cooldown_seconds, mute_until, schedule_start, schedule_end, notes,
               created_at, updated_at
          FROM Alert
         ORDER BY updated_at DESC, id DESC
        """ :
        """
        SELECT id, name, enabled, severity, scope_type, scope_id, trigger_type_code,
               params_json, near_value, near_unit, hysteresis_value, hysteresis_unit,
               cooldown_seconds, mute_until, schedule_start, schedule_end, notes,
               created_at, updated_at
          FROM Alert
         WHERE enabled = 1
         ORDER BY updated_at DESC, id DESC
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(alertRowFrom(stmt))
            }
        }
        return rows
    }

    private func alertRowFrom(_ stmt: OpaquePointer?) -> AlertRow {
        let id = Int(sqlite3_column_int(stmt, 0))
        let name = String(cString: sqlite3_column_text(stmt, 1))
        let enabled = sqlite3_column_int(stmt, 2) == 1
        let severity = String(cString: sqlite3_column_text(stmt, 3))
        let scopeType = String(cString: sqlite3_column_text(stmt, 4))
        let scopeId = Int(sqlite3_column_int(stmt, 5))
        let trig = String(cString: sqlite3_column_text(stmt, 6))
        let params = String(cString: sqlite3_column_text(stmt, 7))
        let nearVal = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 8)
        let nearUnit = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
        let hystVal = sqlite3_column_type(stmt, 10) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 10)
        let hystUnit = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        let cooldown = sqlite3_column_type(stmt, 12) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 12))
        let muteUntil = sqlite3_column_text(stmt, 13).map { String(cString: $0) }
        let schedStart = sqlite3_column_text(stmt, 14).map { String(cString: $0) }
        let schedEnd = sqlite3_column_text(stmt, 15).map { String(cString: $0) }
        let notes = sqlite3_column_text(stmt, 16).map { String(cString: $0) }
        let createdAt = String(cString: sqlite3_column_text(stmt, 17))
        let updatedAt = String(cString: sqlite3_column_text(stmt, 18))
        return AlertRow(
            id: id,
            name: name,
            enabled: enabled,
            severity: AlertSeverity(rawValue: severity) ?? .info,
            scopeType: AlertScopeType(rawValue: scopeType) ?? .Instrument,
            scopeId: scopeId,
            triggerTypeCode: trig,
            paramsJson: params,
            nearValue: nearVal,
            nearUnit: nearUnit,
            hysteresisValue: hystVal,
            hysteresisUnit: hystUnit,
            cooldownSeconds: cooldown,
            muteUntil: muteUntil,
            scheduleStart: schedStart,
            scheduleEnd: schedEnd,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func createAlert(_ a: AlertRow) -> AlertRow? {
        guard let db else { return nil }
        guard isValidJSON(a.paramsJson) else { return nil }
        let sql = """
        INSERT INTO Alert
            (name, enabled, severity, scope_type, scope_id, trigger_type_code,
             params_json, near_value, near_unit, hysteresis_value, hysteresis_unit,
             cooldown_seconds, mute_until, schedule_start, schedule_end, notes)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, a.name, -1, T)
        sqlite3_bind_int(stmt, 2, a.enabled ? 1 : 0)
        sqlite3_bind_text(stmt, 3, a.severity.rawValue, -1, T)
        sqlite3_bind_text(stmt, 4, a.scopeType.rawValue, -1, T)
        sqlite3_bind_int(stmt, 5, Int32(a.scopeId))
        sqlite3_bind_text(stmt, 6, a.triggerTypeCode, -1, T)
        sqlite3_bind_text(stmt, 7, a.paramsJson, -1, T)
        if let v = a.nearValue { sqlite3_bind_double(stmt, 8, v) } else { sqlite3_bind_null(stmt, 8) }
        if let u = a.nearUnit { sqlite3_bind_text(stmt, 9, u, -1, T) } else { sqlite3_bind_null(stmt, 9) }
        if let v = a.hysteresisValue { sqlite3_bind_double(stmt, 10, v) } else { sqlite3_bind_null(stmt, 10) }
        if let u = a.hysteresisUnit { sqlite3_bind_text(stmt, 11, u, -1, T) } else { sqlite3_bind_null(stmt, 11) }
        if let s = a.cooldownSeconds { sqlite3_bind_int(stmt, 12, Int32(s)) } else { sqlite3_bind_null(stmt, 12) }
        if let s = a.muteUntil { sqlite3_bind_text(stmt, 13, s, -1, T) } else { sqlite3_bind_null(stmt, 13) }
        if let s = a.scheduleStart { sqlite3_bind_text(stmt, 14, s, -1, T) } else { sqlite3_bind_null(stmt, 14) }
        if let s = a.scheduleEnd { sqlite3_bind_text(stmt, 15, s, -1, T) } else { sqlite3_bind_null(stmt, 15) }
        if let n = a.notes { sqlite3_bind_text(stmt, 16, n, -1, T) } else { sqlite3_bind_null(stmt, 16) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
        let id = Int(sqlite3_last_insert_rowid(db))
        return getAlert(id: id)
    }

    func getAlert(id: Int) -> AlertRow? {
        guard let db else { return nil }
        let sql = "SELECT id, name, enabled, severity, scope_type, scope_id, trigger_type_code, params_json, near_value, near_unit, hysteresis_value, hysteresis_unit, cooldown_seconds, mute_until, schedule_start, schedule_end, notes, created_at, updated_at FROM Alert WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        if sqlite3_step(stmt) == SQLITE_ROW {
            return alertRowFrom(stmt)
        }
        return nil
    }

    func updateAlert(_ id: Int, fields: [String: Any?]) -> Bool {
        guard let db else { return false }
        var sets: [String] = []
        var bind: [Any?] = []
        func push(_ k: String, _ v: Any?) { sets.append("\(k) = ?"); bind.append(v) }
        for (k, v) in fields {
            switch k {
            case "name", "severity", "scope_type", "trigger_type_code", "params_json", "near_unit", "hysteresis_unit", "mute_until", "schedule_start", "schedule_end", "notes":
                if k == "params_json", let s = v as? String, !isValidJSON(s) { return false }
                push(k, v)
            case "enabled": push(k, (v as? Bool) == true ? 1 : 0)
            case "scope_id", "cooldown_seconds": push(k, v)
            case "near_value", "hysteresis_value": push(k, v)
            default: continue
            }
        }
        guard !sets.isEmpty else { return true }
        let sql = "UPDATE Alert SET \(sets.joined(separator: ", ")), updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var idx: Int32 = 1
        for v in bind {
            if let s = v as? String { sqlite3_bind_text(stmt, idx, s, -1, T) }
            else if let i = v as? Int { sqlite3_bind_int(stmt, idx, Int32(i)) }
            else if let d = v as? Double { sqlite3_bind_double(stmt, idx, d) }
            else if let b = v as? Bool { sqlite3_bind_int(stmt, idx, b ? 1 : 0) }
            else if v == nil { sqlite3_bind_null(stmt, idx) }
            else { sqlite3_bind_null(stmt, idx) }
            idx += 1
        }
        sqlite3_bind_int(stmt, idx, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    func deleteAlert(id: Int) -> Bool {
        guard let db else { return false }
        let sql = "DELETE FROM Alert WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        sqlite3_bind_int(stmt, 1, Int32(id))
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    // MARK: - Alert Tags
    func listTagsForAlert(alertId: Int) -> [TagRow] {
        guard let db else { return [] }
        let sql = """
        SELECT t.id, t.code, t.display_name, t.color, t.sort_order, t.active
          FROM AlertTag at
          JOIN Tag t ON t.id = at.tag_id
         WHERE at.alert_id = ?
         ORDER BY t.sort_order, t.id
        """
        var stmt: OpaquePointer?
        var rows: [TagRow] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(alertId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let code = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let color = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let order = Int(sqlite3_column_int(stmt, 4))
                let active = sqlite3_column_int(stmt, 5) == 1
                rows.append(TagRow(id: id, code: code, displayName: name, color: color, sortOrder: order, active: active))
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }

    func setAlertTags(alertId: Int, tagIds: [Int]) -> Bool {
        guard let db else { return false }
        // Replace strategy
        var ok = true
        ok = ok && sqlite3_exec(db, "DELETE FROM AlertTag WHERE alert_id = \(alertId)", nil, nil, nil) == SQLITE_OK
        for tid in tagIds {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO AlertTag(alert_id, tag_id) VALUES(?,?)", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(alertId))
                sqlite3_bind_int(stmt, 2, Int32(tid))
                ok = ok && (sqlite3_step(stmt) == SQLITE_DONE)
            } else { ok = false }
            sqlite3_finalize(stmt)
        }
        return ok
    }

    // MARK: - Helpers
    private func isValidJSON(_ s: String) -> Bool {
        guard let data = s.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}

