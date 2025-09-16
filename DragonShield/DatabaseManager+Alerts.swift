import Foundation
import SQLite3

extension DatabaseManager {
    // MARK: - Alerts CRUD
    func listAlerts(includeDisabled: Bool = true) -> [AlertRow] {
        var rows: [AlertRow] = []
        guard let db else { return rows }
        let sql = includeDisabled ?
        """
        SELECT id, name, enabled, severity, scope_type, scope_id, subject_type, subject_reference,
               trigger_type_code,
               params_json, near_value, near_unit, hysteresis_value, hysteresis_unit,
               cooldown_seconds, mute_until, schedule_start, schedule_end, notes,
               created_at, updated_at
          FROM Alert
         ORDER BY updated_at DESC, id DESC
        """ :
        """
        SELECT id, name, enabled, severity, scope_type, scope_id, subject_type, subject_reference,
               trigger_type_code,
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
        let subjectTypeStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let subjectRef = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
        let trig = String(cString: sqlite3_column_text(stmt, 8))
        let params = String(cString: sqlite3_column_text(stmt, 9))
        let nearVal = sqlite3_column_type(stmt, 10) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 10)
        let nearUnit = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        let hystVal = sqlite3_column_type(stmt, 12) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 12)
        let hystUnit = sqlite3_column_text(stmt, 13).map { String(cString: $0) }
        let cooldown = sqlite3_column_type(stmt, 14) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 14))
        let muteUntil = sqlite3_column_text(stmt, 15).map { String(cString: $0) }
        let schedStart = sqlite3_column_text(stmt, 16).map { String(cString: $0) }
        let schedEnd = sqlite3_column_text(stmt, 17).map { String(cString: $0) }
        let notes = sqlite3_column_text(stmt, 18).map { String(cString: $0) }
        let createdAt = String(cString: sqlite3_column_text(stmt, 19))
        let updatedAt = String(cString: sqlite3_column_text(stmt, 20))
        let resolvedSubjectType = subjectTypeStr.flatMap { AlertSubjectType(rawValue: $0) } ?? AlertSubjectType(rawValue: scopeType) ?? .Instrument
        let resolvedSubjectRef: String?
        if let subjectRef {
            resolvedSubjectRef = subjectRef
        } else if scopeId != 0 {
            resolvedSubjectRef = String(scopeId)
        } else {
            resolvedSubjectRef = nil
        }
        return AlertRow(
            id: id,
            name: name,
            enabled: enabled,
            severity: AlertSeverity(rawValue: severity) ?? .info,
            scopeType: resolvedSubjectType,
            scopeId: scopeId,
            subjectReference: resolvedSubjectRef,
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
            (name, enabled, severity, scope_type, scope_id, subject_type, subject_reference,
             trigger_type_code,
             params_json, near_value, near_unit, hysteresis_value, hysteresis_unit,
             cooldown_seconds, mute_until, schedule_start, schedule_end, notes)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, a.name, -1, T)
        sqlite3_bind_int(stmt, 2, a.enabled ? 1 : 0)
        sqlite3_bind_text(stmt, 3, a.severity.rawValue, -1, T)
        sqlite3_bind_text(stmt, 4, a.scopeType.storageScopeTypeValue, -1, T)
        sqlite3_bind_int(stmt, 5, Int32(a.scopeType.storageScopeIdValue(a.scopeId)))
        sqlite3_bind_text(stmt, 6, a.scopeType.rawValue, -1, T)
        if let subjRef = a.subjectReference { sqlite3_bind_text(stmt, 7, subjRef, -1, T) } else { sqlite3_bind_null(stmt, 7) }
        sqlite3_bind_text(stmt, 8, a.triggerTypeCode, -1, T)
        sqlite3_bind_text(stmt, 9, a.paramsJson, -1, T)
        if let v = a.nearValue { sqlite3_bind_double(stmt, 10, v) } else { sqlite3_bind_null(stmt, 10) }
        if let u = a.nearUnit { sqlite3_bind_text(stmt, 11, u, -1, T) } else { sqlite3_bind_null(stmt, 11) }
        if let v = a.hysteresisValue { sqlite3_bind_double(stmt, 12, v) } else { sqlite3_bind_null(stmt, 12) }
        if let u = a.hysteresisUnit { sqlite3_bind_text(stmt, 13, u, -1, T) } else { sqlite3_bind_null(stmt, 13) }
        if let s = a.cooldownSeconds { sqlite3_bind_int(stmt, 14, Int32(s)) } else { sqlite3_bind_null(stmt, 14) }
        if let s = a.muteUntil { sqlite3_bind_text(stmt, 15, s, -1, T) } else { sqlite3_bind_null(stmt, 15) }
        if let s = a.scheduleStart { sqlite3_bind_text(stmt, 16, s, -1, T) } else { sqlite3_bind_null(stmt, 16) }
        if let s = a.scheduleEnd { sqlite3_bind_text(stmt, 17, s, -1, T) } else { sqlite3_bind_null(stmt, 17) }
        if let n = a.notes { sqlite3_bind_text(stmt, 18, n, -1, T) } else { sqlite3_bind_null(stmt, 18) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
        let id = Int(sqlite3_last_insert_rowid(db))
        return getAlert(id: id)
    }

    func getAlert(id: Int) -> AlertRow? {
        guard let db else { return nil }
        let sql = "SELECT id, name, enabled, severity, scope_type, scope_id, subject_type, subject_reference, trigger_type_code, params_json, near_value, near_unit, hysteresis_value, hysteresis_unit, cooldown_seconds, mute_until, schedule_start, schedule_end, notes, created_at, updated_at FROM Alert WHERE id = ?"
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
        var fields = fields
        if let subjectTypeString = fields["subject_type"] as? String, let subjectType = AlertSubjectType(rawValue: subjectTypeString) {
            fields["scope_type"] = subjectType.storageScopeTypeValue
            if !subjectType.requiresNumericScope { fields["scope_id"] = 0 }
        } else if let scopeTypeString = fields["scope_type"] as? String, let scopeType = AlertSubjectType(rawValue: scopeTypeString) {
            fields["subject_type"] = scopeType.rawValue
            fields["scope_type"] = scopeType.storageScopeTypeValue
            if !scopeType.requiresNumericScope { fields["scope_id"] = 0 }
        }
        var sets: [String] = []
        var bind: [Any?] = []
        func push(_ k: String, _ v: Any?) { sets.append("\(k) = ?"); bind.append(v) }
        for (k, v) in fields {
            switch k {
            case "name", "severity", "scope_type", "subject_type", "subject_reference", "trigger_type_code", "params_json", "near_unit", "hysteresis_unit", "mute_until", "schedule_start", "schedule_end", "notes":
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

    // MARK: - Evaluation (Phase 1: date alerts)
    /// Evaluate a single alert now. Returns (createdEvent, message).
    @discardableResult
    func evaluateAlertNow(alertId: Int) -> (Bool, String) {
        guard let alert = getAlert(id: alertId) else { return (false, "Alert not found") }
        switch alert.triggerTypeCode {
        case "date":
            return evaluateDateAlertNow(alert: alert)
        case "calendar_event":
            return evaluateCalendarEventAlertNow(alert: alert)
        default:
            return (false, "Evaluate Now supports date and calendar_event alerts in this phase")
        }
    }

    private func evaluateDateAlertNow(alert: AlertRow) -> (Bool, String) {
        // Parse params_json expecting { "date": "YYYY-MM-DD" }
        guard let data = alert.paramsJson.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let dateStr = obj["date"] as? String, !dateStr.isEmpty else {
            return (false, "Missing date in params_json")
        }
        // Validate date format strictly yyyy-MM-dd
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        guard let triggerDate = df.date(from: dateStr) else { return (false, "Invalid date format (use YYYY-MM-DD)") }

        // Respect schedule_start / schedule_end (date-only if provided)
        if let s = alert.scheduleStart, let start = df.date(from: s), Date() < start { return (false, "Not within schedule window (starts \(s))") }
        if let e = alert.scheduleEnd, let end = df.date(from: e), Date() > end.addingTimeInterval(86_400 - 1) { return (false, "Not within schedule window (ended \(e))") }
        // Mute until
        if let m = alert.muteUntil, let mut = df.date(from: m), Date() < mut.addingTimeInterval(86_400) {
            return (false, "Muted until \(m)")
        }

        // Fire if today >= triggerDate (date alerts that fire in days)
        // Convert now to date-only in UTC to compare.
        let todayStr = df.string(from: Date())
        guard let today = df.date(from: todayStr) else { return (false, "Date parse error") }
        guard today >= triggerDate else { return (false, "Not due yet") }

        // De-dupe: if an event exists today, skip creating another
        if hasTriggeredEventToday(alertId: alert.id, day: today) {
            return (false, "Already triggered today")
        }

        // Create event
        let measured: [String: Any] = ["kind": "date", "date": dateStr, "evaluated_at": ISO8601DateFormatter().string(from: Date())]
        let msg = "Date reached: \(dateStr)"
        let created = insertAlertEvent(alertId: alert.id, status: "triggered", message: msg, measured: measured)
        return created ? (true, msg) : (false, "Failed to create event")
    }

    private func evaluateCalendarEventAlertNow(alert: AlertRow) -> (Bool, String) {
        guard let data = alert.paramsJson.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let eventCode = obj["event_code"] as? String, !eventCode.isEmpty else {
            return (false, "Missing event_code in params_json")
        }
        guard let event = getEventCalendar(code: eventCode) else {
            return (false, "Event \(eventCode) not found in EventCalendar")
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        guard let eventDate = df.date(from: event.eventDate) else {
            return (false, "Invalid event_date format for \(eventCode)")
        }
        let warnDays: [Int] = (obj["warn_days"] as? [Any])?.compactMap {
            if let n = $0 as? NSNumber { return n.intValue }
            if let s = $0 as? String, let v = Int(s) { return v }
            return nil
        } ?? []
        let todayStr = df.string(from: Date())
        guard let today = df.date(from: todayStr) else {
            return (false, "Date parse error")
        }
        let secondsDiff = eventDate.timeIntervalSince(today)
        let diffDays = Int(floor(secondsDiff / 86_400.0))
        if diffDays < 0 {
            return (false, "Event already occurred on \(event.eventDate)")
        }
        if diffDays > 0 && !warnDays.contains(diffDays) {
            return (false, "Event is in \(diffDays) day(s); no warn_days match")
        }
        if hasTriggeredEventToday(alertId: alert.id, day: today) {
            return (false, "Already triggered today")
        }
        var measured: [String: Any] = [
            "kind": "calendar_event",
            "event_code": event.code,
            "title": event.title,
            "category": event.category,
            "event_date": event.eventDate,
            "status": event.status
        ]
        if let tz = event.timezone { measured["timezone"] = tz }
        if let t = event.eventTime { measured["event_time"] = t }
        if diffDays > 0 { measured["days_until"] = diffDays }
        let msg = diffDays == 0 ? "Event today: \(event.title)" : "Event in \(diffDays) day(s): \(event.title)"
        let created = insertAlertEvent(alertId: alert.id, status: "triggered", message: msg, measured: measured)
        return created ? (true, msg) : (false, "Failed to create event")
    }

    private func hasTriggeredEventToday(alertId: Int, day: Date) -> Bool {
        guard let db else { return false }
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(secondsFromGMT: 0); df.dateFormat = "yyyy-MM-dd"
        let dayStart = df.string(from: day) + "T00:00:00Z"
        let nextStart = df.string(from: day.addingTimeInterval(86_400)) + "T00:00:00Z"
        let sql = "SELECT 1 FROM AlertEvent WHERE alert_id = ? AND status = 'triggered' AND occurred_at >= ? AND occurred_at < ? LIMIT 1"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(alertId))
        sqlite3_bind_text(stmt, 2, dayStart, -1, T)
        sqlite3_bind_text(stmt, 3, nextStart, -1, T)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    // MARK: - UI helpers
    func hasTriggeredEventOnDay(alertId: Int, day: Date) -> Bool {
        guard let db else { return false }
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(secondsFromGMT: 0); df.dateFormat = "yyyy-MM-dd"
        let dayStart = df.string(from: day) + "T00:00:00Z"
        let nextStart = df.string(from: day.addingTimeInterval(86_400)) + "T00:00:00Z"
        let sql = "SELECT 1 FROM AlertEvent WHERE alert_id = ? AND status = 'triggered' AND occurred_at >= ? AND occurred_at < ? LIMIT 1"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(alertId))
        sqlite3_bind_text(stmt, 2, dayStart, -1, T)
        sqlite3_bind_text(stmt, 3, nextStart, -1, T)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    @discardableResult
    func deleteTriggeredEventsOnDay(alertId: Int, day: Date) -> Int {
        guard let db else { return 0 }
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(secondsFromGMT: 0); df.dateFormat = "yyyy-MM-dd"
        let dayStart = df.string(from: day) + "T00:00:00Z"
        let nextStart = df.string(from: day.addingTimeInterval(86_400)) + "T00:00:00Z"
        let sql = "DELETE FROM AlertEvent WHERE alert_id = ? AND status = 'triggered' AND occurred_at >= ? AND occurred_at < ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(alertId))
        sqlite3_bind_text(stmt, 2, dayStart, -1, T)
        sqlite3_bind_text(stmt, 3, nextStart, -1, T)
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_DONE {
            return Int(sqlite3_changes(db))
        }
        return 0
    }

    private func insertAlertEvent(alertId: Int, status: String, message: String?, measured: [String: Any]?) -> Bool {
        guard let db else { return false }
        let sql = "INSERT INTO AlertEvent (alert_id, occurred_at, status, message, measured_json) VALUES (?,?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(alertId))
        let nowIso = ISO8601DateFormatter().string(from: Date())
        sqlite3_bind_text(stmt, 2, nowIso, -1, T)
        sqlite3_bind_text(stmt, 3, status, -1, T)
        if let m = message { sqlite3_bind_text(stmt, 4, m, -1, T) } else { sqlite3_bind_null(stmt, 4) }
        if let measured, let data = try? JSONSerialization.data(withJSONObject: measured), let str = String(data: data, encoding: .utf8) {
            sqlite3_bind_text(stmt, 5, str, -1, T)
        } else { sqlite3_bind_null(stmt, 5) }
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    // MARK: - Events listing
    func listAlertEvents(limit: Int = 200) -> [(id: Int, alertId: Int, alertName: String, severity: String, occurredAt: String, status: String, message: String?)] {
        guard let db else { return [] }
        let sql = """
        SELECT e.id, e.alert_id, a.name, a.severity, e.occurred_at, e.status, e.message
          FROM AlertEvent e
          JOIN Alert a ON a.id = e.alert_id
         ORDER BY e.occurred_at DESC
         LIMIT ?
        """
        var stmt: OpaquePointer?
        var out: [(Int, Int, String, String, String, String, String?)] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let aid = Int(sqlite3_column_int(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                let sev = String(cString: sqlite3_column_text(stmt, 3))
                let occurred = String(cString: sqlite3_column_text(stmt, 4))
                let status = String(cString: sqlite3_column_text(stmt, 5))
                let msg = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                out.append((id, aid, name, sev, occurred, status, msg))
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    // Upcoming: date alerts with a future or today trigger date
    func listUpcomingDateAlerts(limit: Int = 200) -> [(alertId: Int, alertName: String, severity: String, upcomingDate: String)] {
        let alerts = listAlerts(includeDisabled: false)
        var dateTriggers = Set(listAlertTriggerTypes(includeInactive: false).filter { $0.requiresDate }.map { $0.code })
        if dateTriggers.isEmpty {
            dateTriggers = ["date", "calendar_event", "macro_indicator_threshold"]
        } else {
            dateTriggers.formUnion(["date", "calendar_event", "macro_indicator_threshold"])
        }
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(secondsFromGMT: 0); df.dateFormat = "yyyy-MM-dd"
        guard let today = df.date(from: df.string(from: Date())) else { return [] }
        var out: [(Int, String, String, String)] = []
        for a in alerts where dateTriggers.contains(a.triggerTypeCode) {
            guard let data = a.paramsJson.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let dateStr = obj["date"] as? String,
                  let d = df.date(from: dateStr) else { continue }
            if let e = a.scheduleEnd, let end = df.date(from: e), d > end { continue }
            if d >= today {
                if d == today, hasTriggeredEventToday(alertId: a.id, day: today) { continue }
                out.append((a.id, a.name, a.severity.rawValue, dateStr))
            }
        }
        out.sort { $0.3 < $1.3 }
        return out.count > limit ? Array(out.prefix(limit)) : out
    }
}
