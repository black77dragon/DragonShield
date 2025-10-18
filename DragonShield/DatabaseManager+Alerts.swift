import Foundation
import SQLite3

extension DatabaseManager {
    struct AlertEventSummary: Identifiable, Hashable {
        let id: Int
        let alertId: Int
        let alertName: String
        let severity: String
        let occurredAt: String
        let status: String
        let message: String?
        let measuredJson: String?
    }

    struct HoldingAbsSnapshot: Identifiable, Hashable {
        let id: Int
        let alert: AlertRow
        let instrumentId: Int
        let instrumentName: String
        let currency: String
        let currentValue: Double
        let thresholdValue: Double
        let difference: Double
        let percent: Double?
        let quantity: Double
        let calculatedAt: Date

        var isExceeded: Bool { difference >= 0 }
        var isNear: Bool { !isExceeded && percent.map { abs($0) <= 0.05 } ?? false }
    }

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
        case "holding_abs":
            return evaluateHoldingAbsAlertNow(alert: alert)
        default:
            return (false, "Evaluate Now supports date, calendar_event, and holding_abs alerts in this phase")
        }
    }

    func isAlertNear(_ alert: AlertRow, dateWindowDays: Int = 7, absoluteTolerance: Double = 0.05) -> Bool {
        switch alert.triggerTypeCode {
        case "date":
            guard let data = alert.paramsJson.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let dateStr = obj["date"] as? String,
                  let triggerDate = DateFormatter.iso8601DateOnly.date(from: dateStr) else {
                return false
            }
            let today = DateFormatter.iso8601DateOnly.date(from: DateFormatter.iso8601DateOnly.string(from: Date())) ?? Date()
            let diff = Calendar(identifier: .iso8601).dateComponents([.day], from: today, to: triggerDate).day ?? Int.max
            return diff >= 0 && diff <= dateWindowDays

        case "holding_abs":
            guard let metrics = holdingAbsMetrics(for: alert) else { return false }
            if metrics.comparisonValue >= metrics.thresholdComparison { return false }
            let tolerance = metrics.thresholdComparison * absoluteTolerance
            return abs(metrics.comparisonValue - metrics.thresholdComparison) <= tolerance

        default:
            return false
        }
    }

    func isAlertExceeded(_ alert: AlertRow) -> Bool {
        switch alert.triggerTypeCode {
        case "holding_abs":
            guard let metrics = holdingAbsMetrics(for: alert) else { return false }
            return metrics.comparisonValue >= metrics.thresholdComparison
        default:
            return false
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

    private func evaluateHoldingAbsAlertNow(alert: AlertRow) -> (Bool, String) {
        if let reason = scheduleOrMuteBlock(for: alert) {
            return (false, reason)
        }
        guard let metrics = holdingAbsMetrics(for: alert) else {
            return (false, "Unable to evaluate holding value")
        }

        if let cooldown = alert.cooldownSeconds, cooldown > 0, let last = latestAlertTriggerDate(alertId: alert.id) {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < Double(cooldown) {
                let remaining = Int(Double(cooldown) - elapsed)
                return (false, "In cooldown for another \(remaining) seconds")
            }
        }

        let dateFormatter = DateFormatter.iso8601DateOnly
        guard let today = dateFormatter.date(from: dateFormatter.string(from: Date())) else {
            return (false, "Date parse error")
        }
        if hasTriggeredEventToday(alertId: alert.id, day: today) {
            return (false, "Already triggered today")
        }

        if metrics.comparisonValue < metrics.thresholdComparison {
            let valueStr = formatCurrency(metrics.comparisonValue, currency: metrics.comparisonCurrency)
            let thresholdStr = formatCurrency(metrics.thresholdComparison, currency: metrics.comparisonCurrency)
            return (false, "\(metrics.instrumentName): holding value \(valueStr) below threshold \(thresholdStr)")
        }

        let valueMessage = formatCurrency(metrics.comparisonValue, currency: metrics.comparisonCurrency)
        let thresholdMessage = formatCurrency(metrics.thresholdComparison, currency: metrics.comparisonCurrency)
        let message = "\(metrics.instrumentName): holding value \(valueMessage) ≥ threshold \(thresholdMessage)"

        var measured: [String: Any] = [
            "kind": "holding_abs",
            "instrument_id": metrics.instrumentId,
            "instrument_name": metrics.instrumentName,
            "quantity_signed": metrics.quantitySigned,
            "quantity_abs": metrics.quantityAbs,
            "price": metrics.price,
            "price_currency": metrics.priceCurrency,
            "value_instrument": metrics.valueInInstrument,
            "instrument_currency": metrics.priceCurrency,
            "currency_mode": metrics.currencyMode,
            "comparison_currency": metrics.comparisonCurrency,
            "threshold": metrics.rawThreshold
        ]

        if metrics.currencyMode == "base" {
            measured["value_base"] = metrics.comparisonValue
            measured["base_currency"] = metrics.comparisonCurrency
            measured["threshold_base"] = metrics.thresholdComparison
        } else if let conversion = convertValueToBase(value: metrics.valueInInstrument, from: metrics.priceCurrency, baseCurrency: baseCurrency.uppercased()) {
            measured["value_base"] = conversion.value
            measured["base_currency"] = baseCurrency.uppercased()
        }

        if let fx = metrics.fxInstrument {
            measured["fx_rate_source_to_chf"] = fx.rate
            measured["fx_rate_source_date"] = DateFormatter.iso8601DateOnly.string(from: fx.date)
        }
        if let fx = metrics.fxBase {
            measured["fx_rate_base_to_chf"] = fx.rate
            measured["fx_rate_base_date"] = DateFormatter.iso8601DateOnly.string(from: fx.date)
        }

        let created = insertAlertEvent(alertId: alert.id, status: "triggered", message: message, measured: measured)
        return created ? (true, message) : (false, "Failed to create event")
    }

    private struct HoldingAbsMetrics {
        let instrumentId: Int
        let instrumentName: String
        let price: Double
        let priceCurrency: String
        let valueInInstrument: Double
        let comparisonValue: Double
        let thresholdComparison: Double
        let comparisonCurrency: String
        let rawThreshold: Double
        let currencyMode: String
        let quantitySigned: Double
        let quantityAbs: Double
        let fxInstrument: (rate: Double, date: Date)?
        let fxBase: (rate: Double, date: Date)?
    }

    private func holdingAbsMetrics(for alert: AlertRow) -> HoldingAbsMetrics? {
        guard alert.triggerTypeCode == "holding_abs" else { return nil }

        var instrumentId = alert.scopeId
        if instrumentId <= 0, let reference = alert.subjectReference, let parsed = Int(reference) {
            instrumentId = parsed
        }
        guard instrumentId > 0, let instrument = fetchInstrumentDetails(id: instrumentId) else { return nil }

        guard let data = alert.paramsJson.data(using: .utf8),
              let params = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }

        guard let rawThreshold = (params["threshold_chf"] as? Double) ?? (params["threshold"] as? Double), rawThreshold > 0 else { return nil }
        let currencyMode = (params["currency_mode"] as? String ?? "instrument").lowercased()

        let quantitySigned = totalInstrumentHoldingQuantity(instrumentId: instrumentId)
        let quantityAbs = abs(quantitySigned)

        guard let priceInfo = getLatestPrice(instrumentId: instrumentId) else { return nil }
        let price = priceInfo.price
        let priceCurrency = priceInfo.currency.uppercased()
        let valueInInstrument = quantityAbs * price

        let baseCode = baseCurrency.uppercased()
        var comparisonValue = valueInInstrument
        var comparisonCurrency = priceCurrency
        var thresholdComparison = rawThreshold
        var fxInstrument: (Double, Date)? = nil
        var fxBase: (Double, Date)? = nil

        if currencyMode == "base" {
            comparisonCurrency = baseCode
            guard let conversion = convertValueToBase(value: valueInInstrument, from: priceCurrency, baseCurrency: baseCode) else { return nil }
            comparisonValue = conversion.value
            fxInstrument = conversion.fxInstrument
            fxBase = conversion.fxBase

            guard let thresholdConversion = convertValueToBase(value: rawThreshold, from: priceCurrency, baseCurrency: baseCode) else { return nil }
            thresholdComparison = thresholdConversion.value
        }

        return HoldingAbsMetrics(instrumentId: instrumentId,
                                 instrumentName: instrument.name,
                                 price: price,
                                 priceCurrency: priceCurrency,
                                 valueInInstrument: valueInInstrument,
                                 comparisonValue: comparisonValue,
                                 thresholdComparison: thresholdComparison,
                                 comparisonCurrency: comparisonCurrency,
                                 rawThreshold: rawThreshold,
                                 currencyMode: currencyMode,
                                 quantitySigned: quantitySigned,
                                 quantityAbs: quantityAbs,
                                 fxInstrument: fxInstrument,
                                 fxBase: fxBase)
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

    func totalInstrumentHoldingQuantity(instrumentId: Int, upTo date: Date = Date()) -> Double {
        guard let db else { return 0 }
        let sql = """
            SELECT COALESCE(SUM(l.delta_quantity), 0)
              FROM TradeLeg l
              JOIN Trade t ON t.trade_id = l.trade_id
             WHERE l.leg_type = 'INSTRUMENT'
               AND l.instrument_id = ?
               AND t.trade_date <= ?
        """
        var stmt: OpaquePointer?
        var total: Double = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(instrumentId))
            sqlite3_bind_text(stmt, 2, DateFormatter.iso8601DateOnly.string(from: date), -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                total = sqlite3_column_double(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        if abs(total) < 1e-9 {
            let fallbackSql = """
                SELECT COALESCE(SUM(quantity), 0)
                  FROM PositionReports
                 WHERE instrument_id = ?
                   AND report_date = (
                        SELECT MAX(report_date)
                          FROM PositionReports
                         WHERE instrument_id = ?
                   )
            """
            var s: OpaquePointer?
            if sqlite3_prepare_v2(db, fallbackSql, -1, &s, nil) == SQLITE_OK {
                sqlite3_bind_int(s, 1, Int32(instrumentId))
                sqlite3_bind_int(s, 2, Int32(instrumentId))
                if sqlite3_step(s) == SQLITE_ROW {
                    total = sqlite3_column_double(s, 0)
                }
            }
            sqlite3_finalize(s)
        }
        return total
    }

    func convertValueToBase(value: Double, from sourceCurrency: String, baseCurrency: String) -> (value: Double, fxInstrument: (rate: Double, date: Date)?, fxBase: (rate: Double, date: Date)?)? {
        let source = sourceCurrency.uppercased()
        let base = baseCurrency.uppercased()
        if source == base {
            return (value, nil, nil)
        }

        var valueChf = value
        var fxInstrument: (Double, Date)? = nil
        if source != "CHF" {
            guard let rate = fetchLatestExchangeRate(currencyCode: source) else { return nil }
            valueChf = value * rate.rateToChf
            fxInstrument = (rate.rateToChf, rate.rateDate)
        }

        if base == "CHF" {
            return (valueChf, fxInstrument, nil)
        }

        guard let baseRate = fetchLatestExchangeRate(currencyCode: base) else { return nil }
        let valueBase = valueChf / baseRate.rateToChf
        let fxBase = (baseRate.rateToChf, baseRate.rateDate)
        return (valueBase, fxInstrument, fxBase)
    }

    func holdingValueSnapshot(instrumentId: Int) -> (currency: String, quantity: Double, value: Double?)? {
        guard let instrument = fetchInstrumentDetails(id: instrumentId) else { return nil }
        let currency = instrument.currency.uppercased()
        let quantity = totalInstrumentHoldingQuantity(instrumentId: instrumentId)
        if abs(quantity) < 1e-9 {
            return (currency, quantity, 0)
        }
        guard let priceInfo = getLatestPrice(instrumentId: instrumentId) else {
            return (currency, quantity, nil)
        }
        let value = quantity * priceInfo.price
        return (currency, quantity, value)
    }

    private func scheduleOrMuteBlock(for alert: AlertRow) -> String? {
        let now = Date()
        if let startStr = alert.scheduleStart, let (startDate, isDateOnly) = parseScheduleDate(startStr) {
            let effectiveStart = isDateOnly ? startDate : startDate
            if now < effectiveStart { return "Not within schedule window (starts \(startStr))" }
        }
        if let endStr = alert.scheduleEnd, let (endDate, isDateOnly) = parseScheduleDate(endStr) {
            let effectiveEnd = isDateOnly ? endDate.addingTimeInterval(86_400 - 1) : endDate
            if now > effectiveEnd { return "Not within schedule window (ended \(endStr))" }
        }
        if let muteStr = alert.muteUntil, let (muteDate, isDateOnly) = parseScheduleDate(muteStr) {
            let effectiveMute = isDateOnly ? muteDate.addingTimeInterval(86_400) : muteDate
            if now < effectiveMute { return "Muted until \(muteStr)" }
        }
        return nil
    }

    private func parseScheduleDate(_ string: String) -> (Date, Bool)? {
        if let date = DateFormatter.iso8601DateOnly.date(from: string) {
            return (date, true)
        }
        if let date = parseISODateFlexible(string) {
            return (date, false)
        }
        return nil
    }

    private func latestAlertTriggerDate(alertId: Int) -> Date? {
        guard let db else { return nil }
        let sql = "SELECT occurred_at FROM AlertEvent WHERE alert_id = ? ORDER BY occurred_at DESC LIMIT 1"
        var stmt: OpaquePointer?
        var date: Date? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(alertId))
            if sqlite3_step(stmt) == SQLITE_ROW, let ptr = sqlite3_column_text(stmt, 0) {
                let str = String(cString: ptr)
                date = parseISODateFlexible(str)
            }
        }
        sqlite3_finalize(stmt)
        return date
    }

    private func parseISODateFlexible(_ string: String) -> Date? {
        let isoFraction = ISO8601DateFormatter()
        isoFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFraction.date(from: string) { return date }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }
        if let date = DateFormatter.iso8601DateTime.date(from: string) { return date }
        return DateFormatter.iso8601DateOnly.date(from: string)
    }

    private func formatCurrency(_ value: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    // MARK: - Events listing
    func listAlertEvents(limit: Int = 200) -> [AlertEventSummary] {
        guard let db else { return [] }
        let sql = """
        SELECT e.id, e.alert_id, a.name, a.severity, e.occurred_at, e.status, e.message, e.measured_json
          FROM AlertEvent e
          JOIN Alert a ON a.id = e.alert_id
         ORDER BY e.occurred_at DESC
         LIMIT ?
        """
        var stmt: OpaquePointer?
        var out: [AlertEventSummary] = []
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
                let measured = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                out.append(AlertEventSummary(id: id,
                                             alertId: aid,
                                             alertName: name,
                                             severity: sev,
                                             occurredAt: occurred,
                                             status: status,
                                             message: msg,
                                             measuredJson: measured))
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    func listHoldingAbsSnapshots(includeDisabled: Bool = false) -> [HoldingAbsSnapshot] {
        let alerts = listAlerts(includeDisabled: includeDisabled)
        var snapshots: [HoldingAbsSnapshot] = []
        let timestamp = Date()
        for alert in alerts where alert.triggerTypeCode == "holding_abs" {
            if !includeDisabled && !alert.enabled { continue }
            guard let metrics = holdingAbsMetrics(for: alert) else { continue }
            let difference = metrics.comparisonValue - metrics.thresholdComparison
            let percent = metrics.thresholdComparison != 0 ? difference / metrics.thresholdComparison : nil
            let snapshot = HoldingAbsSnapshot(id: alert.id,
                                              alert: alert,
                                              instrumentId: metrics.instrumentId,
                                              instrumentName: metrics.instrumentName,
                                              currency: metrics.comparisonCurrency,
                                              currentValue: metrics.comparisonValue,
                                              thresholdValue: metrics.thresholdComparison,
                                              difference: difference,
                                              percent: percent,
                                              quantity: metrics.quantitySigned,
                                              calculatedAt: timestamp)
            snapshots.append(snapshot)
        }
        return snapshots
    }

    // Upcoming: date alerts with a future or today trigger date (optionally includes overdue)
    func listUpcomingDateAlerts(limit: Int = 200, includeOverdue: Bool = false) -> [(alertId: Int, alertName: String, severity: String, upcomingDate: String)] {
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
            } else if includeOverdue {
                out.append((a.id, a.name, a.severity.rawValue, dateStr))
            }
        }
        out.sort { $0.3 < $1.3 }
        return out.count > limit ? Array(out.prefix(limit)) : out
    }
}
