import Foundation
import SQLite3

struct TradingProfileRow: Identifiable, Hashable {
    let id: Int
    let name: String
    let type: String
    let primaryObjective: String?
    let tradingStrategyExecutiveSummary: String?
    let lastReviewDate: String?
    let nextReviewText: String?
    let activeRegime: String?
    let regimeConfidence: String?
    let riskState: String?
    let isDefault: Bool
    let isActive: Bool
}

struct TradingProfileCoordinateRow: Identifiable, Hashable {
    let id: Int
    let profileId: Int
    var title: String
    var weightPercent: Double
    var value: Double
    var sortOrder: Int
    var isLocked: Bool
}

struct TradingProfileDominanceRow: Identifiable, Hashable {
    let id: Int
    let profileId: Int
    let category: String
    let text: String
    let sortOrder: Int
}

struct TradingProfileDominanceInput: Hashable {
    let category: String
    let text: String
    let sortOrder: Int
}

struct TradingProfileRegimeSignalRow: Identifiable, Hashable {
    let id: Int
    let profileId: Int
    let signalType: String
    let text: String
    let sortOrder: Int
}

struct TradingProfileStrategyFitRow: Identifiable, Hashable {
    let id: Int
    let profileId: Int
    let name: String
    let statusLabel: String
    let statusTone: String
    let reason: String?
    let sortOrder: Int
}

struct TradingProfileRiskSignalRow: Identifiable, Hashable {
    let id: Int
    let profileId: Int
    let signalType: String
    let text: String
    let sortOrder: Int
}

struct TradingProfileRuleRow: Identifiable, Hashable {
    let id: Int
    let profileId: Int
    let text: String
    let sortOrder: Int
}

struct TradingProfileViolationRow: Identifiable, Hashable {
    let id: Int
    let profileId: Int
    let date: String
    let ruleText: String
    let resolutionText: String
}

struct TradingProfileReviewLogRow: Identifiable, Hashable {
    let id: Int
    let profileId: Int
    let date: String
    let event: String
    let decision: String
    let confidence: String
    let notes: String?
}

final class TradingProfileRepository {
    private let connection: DatabaseConnection
    private var db: OpaquePointer? { connection.db }

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    convenience init(dbManager: DatabaseManager) {
        self.init(connection: dbManager.databaseConnection)
    }

    func fetchProfiles(includeInactive: Bool = true) -> [TradingProfileRow] {
        var rows: [TradingProfileRow] = []
        guard let db else { return rows }
        let sql = includeInactive
            ? """
                SELECT profile_id, profile_name, profile_type, primary_objective, trading_strategy_executive_summary,
                       last_review_date, next_review_text, active_regime, regime_confidence, risk_state, is_default, is_active
                  FROM TradingProfiles
                 ORDER BY is_default DESC, profile_id;
                """
            : """
                SELECT profile_id, profile_name, profile_type, primary_objective, trading_strategy_executive_summary,
                       last_review_date, next_review_text, active_regime, regime_confidence, risk_state, is_default, is_active
                  FROM TradingProfiles
                 WHERE is_active = 1
                 ORDER BY is_default DESC, profile_id;
                """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let type = String(cString: sqlite3_column_text(stmt, 2))
                let objective = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let summary = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                let lastReview = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                let nextReview = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                let activeRegime = sqlite3_column_text(stmt, 7).map { String(cString: $0) }
                let confidence = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
                let riskState = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
                let isDefault = sqlite3_column_int(stmt, 10) == 1
                let isActive = sqlite3_column_int(stmt, 11) == 1
                rows.append(
                    TradingProfileRow(
                        id: id,
                        name: name,
                        type: type,
                        primaryObjective: objective,
                        tradingStrategyExecutiveSummary: summary,
                        lastReviewDate: lastReview,
                        nextReviewText: nextReview,
                        activeRegime: activeRegime,
                        regimeConfidence: confidence,
                        riskState: riskState,
                        isDefault: isDefault,
                        isActive: isActive
                    )
                )
            }
        }
        return rows
    }

    func fetchDefaultProfile() -> TradingProfileRow? {
        fetchProfiles(includeInactive: false).first
    }

    func createProfile(name: String,
                       type: String,
                       primaryObjective: String?,
                       tradingStrategyExecutiveSummary: String?,
                       lastReviewDate: String?,
                       nextReviewText: String?,
                       activeRegime: String?,
                       regimeConfidence: String?,
                       riskState: String?,
                       isDefault: Bool,
                       isActive: Bool) -> TradingProfileRow?
    {
        guard let db else { return nil }
        if isDefault {
            _ = setDefaultProfile(id: nil)
        }
        let sql = """
            INSERT INTO TradingProfiles
                (profile_name, profile_type, primary_objective, trading_strategy_executive_summary, last_review_date, next_review_text, active_regime, regime_confidence, risk_state, is_default, is_active)
            VALUES (?,?,?,?,?,?,?,?,?,?,?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, name, -1, t)
        sqlite3_bind_text(stmt, 2, type, -1, t)
        if let primaryObjective { sqlite3_bind_text(stmt, 3, primaryObjective, -1, t) } else { sqlite3_bind_null(stmt, 3) }
        if let tradingStrategyExecutiveSummary { sqlite3_bind_text(stmt, 4, tradingStrategyExecutiveSummary, -1, t) } else { sqlite3_bind_null(stmt, 4) }
        if let lastReviewDate { sqlite3_bind_text(stmt, 5, lastReviewDate, -1, t) } else { sqlite3_bind_null(stmt, 5) }
        if let nextReviewText { sqlite3_bind_text(stmt, 6, nextReviewText, -1, t) } else { sqlite3_bind_null(stmt, 6) }
        if let activeRegime { sqlite3_bind_text(stmt, 7, activeRegime, -1, t) } else { sqlite3_bind_null(stmt, 7) }
        if let regimeConfidence { sqlite3_bind_text(stmt, 8, regimeConfidence, -1, t) } else { sqlite3_bind_null(stmt, 8) }
        if let riskState { sqlite3_bind_text(stmt, 9, riskState, -1, t) } else { sqlite3_bind_null(stmt, 9) }
        sqlite3_bind_int(stmt, 10, isDefault ? 1 : 0)
        sqlite3_bind_int(stmt, 11, isActive ? 1 : 0)
        guard sqlite3_step(stmt) == SQLITE_DONE else { return nil }
        let id = Int(sqlite3_last_insert_rowid(db))
        return TradingProfileRow(
            id: id,
            name: name,
            type: type,
            primaryObjective: primaryObjective,
            tradingStrategyExecutiveSummary: tradingStrategyExecutiveSummary,
            lastReviewDate: lastReviewDate,
            nextReviewText: nextReviewText,
            activeRegime: activeRegime,
            regimeConfidence: regimeConfidence,
            riskState: riskState,
            isDefault: isDefault,
            isActive: isActive
        )
    }

    func updateProfile(id: Int,
                       name: String?,
                       type: String?,
                       primaryObjective: String?,
                       tradingStrategyExecutiveSummary: String?,
                       lastReviewDate: String?,
                       nextReviewText: String?,
                       activeRegime: String?,
                       regimeConfidence: String?,
                       riskState: String?,
                       isDefault: Bool?,
                       isActive: Bool?) -> Bool
    {
        guard let db else { return false }
        var sets: [String] = []
        var bind: [Any?] = []
        if let name { sets.append("profile_name = ?"); bind.append(name) }
        if let type { sets.append("profile_type = ?"); bind.append(type) }
        if let primaryObjective { sets.append("primary_objective = ?"); bind.append(primaryObjective) }
        if let tradingStrategyExecutiveSummary { sets.append("trading_strategy_executive_summary = ?"); bind.append(tradingStrategyExecutiveSummary) }
        if let lastReviewDate { sets.append("last_review_date = ?"); bind.append(lastReviewDate) }
        if let nextReviewText { sets.append("next_review_text = ?"); bind.append(nextReviewText) }
        if let activeRegime { sets.append("active_regime = ?"); bind.append(activeRegime) }
        if let regimeConfidence { sets.append("regime_confidence = ?"); bind.append(regimeConfidence) }
        if let riskState { sets.append("risk_state = ?"); bind.append(riskState) }
        if let isDefault { sets.append("is_default = ?"); bind.append(isDefault ? 1 : 0) }
        if let isActive { sets.append("is_active = ?"); bind.append(isActive ? 1 : 0) }
        guard !sets.isEmpty else { return true }
        let sql = "UPDATE TradingProfiles SET \(sets.joined(separator: ", ")) WHERE profile_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var idx: Int32 = 1
        for value in bind {
            if let s = value as? String { sqlite3_bind_text(stmt, idx, s, -1, t) }
            else if let b = value as? Int { sqlite3_bind_int(stmt, idx, Int32(b)) }
            else { sqlite3_bind_null(stmt, idx) }
            idx += 1
        }
        sqlite3_bind_int(stmt, idx, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    func setDefaultProfile(id: Int?) -> Bool {
        guard let db else { return false }
        var ok = sqlite3_exec(db, "UPDATE TradingProfiles SET is_default = 0", nil, nil, nil) == SQLITE_OK
        guard let id else { return ok }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "UPDATE TradingProfiles SET is_default = 1 WHERE profile_id = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            ok = ok && sqlite3_step(stmt) == SQLITE_DONE
        } else {
            ok = false
        }
        sqlite3_finalize(stmt)
        return ok
    }

    func fetchCoordinates(profileId: Int) -> [TradingProfileCoordinateRow] {
        var rows: [TradingProfileCoordinateRow] = []
        guard let db else { return rows }
        let sql = """
            SELECT coordinate_id, profile_id, title, weight_percent, value, sort_order, is_locked
              FROM TradingProfileCoordinates
             WHERE profile_id = ?
             ORDER BY sort_order, coordinate_id;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(profileId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(stmt, 0))
            let pId = Int(sqlite3_column_int(stmt, 1))
            let title = String(cString: sqlite3_column_text(stmt, 2))
            let weight = sqlite3_column_double(stmt, 3)
            let value = sqlite3_column_double(stmt, 4)
            let sortOrder = Int(sqlite3_column_int(stmt, 5))
            let isLocked = sqlite3_column_int(stmt, 6) == 1
            rows.append(
                TradingProfileCoordinateRow(
                    id: id,
                    profileId: pId,
                    title: title,
                    weightPercent: weight,
                    value: value,
                    sortOrder: sortOrder,
                    isLocked: isLocked
                )
            )
        }
        return rows
    }

    func updateCoordinate(id: Int,
                          title: String?,
                          weightPercent: Double?,
                          value: Double?,
                          sortOrder: Int?,
                          isLocked: Bool?) -> Bool
    {
        guard let db else { return false }
        var sets: [String] = []
        var bind: [Any?] = []
        if let title { sets.append("title = ?"); bind.append(title) }
        if let weightPercent { sets.append("weight_percent = ?"); bind.append(weightPercent) }
        if let value { sets.append("value = ?"); bind.append(value) }
        if let sortOrder { sets.append("sort_order = ?"); bind.append(sortOrder) }
        if let isLocked { sets.append("is_locked = ?"); bind.append(isLocked ? 1 : 0) }
        guard !sets.isEmpty else { return true }
        let sql = "UPDATE TradingProfileCoordinates SET \(sets.joined(separator: ", ")) WHERE coordinate_id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var idx: Int32 = 1
        for value in bind {
            if let s = value as? String { sqlite3_bind_text(stmt, idx, s, -1, t) }
            else if let d = value as? Double { sqlite3_bind_double(stmt, idx, d) }
            else if let i = value as? Int { sqlite3_bind_int(stmt, idx, Int32(i)) }
            else { sqlite3_bind_null(stmt, idx) }
            idx += 1
        }
        sqlite3_bind_int(stmt, idx, Int32(id))
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    func fetchDominance(profileId: Int) -> [TradingProfileDominanceRow] {
        var rows: [TradingProfileDominanceRow] = []
        guard let db else { return rows }
        let sql = """
            SELECT dominance_id, profile_id, category, text, sort_order
              FROM TradingProfileDominance
             WHERE profile_id = ?
             ORDER BY sort_order, dominance_id;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(profileId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(
                TradingProfileDominanceRow(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    profileId: Int(sqlite3_column_int(stmt, 1)),
                    category: String(cString: sqlite3_column_text(stmt, 2)),
                    text: String(cString: sqlite3_column_text(stmt, 3)),
                    sortOrder: Int(sqlite3_column_int(stmt, 4))
                )
            )
        }
        return rows
    }

    func replaceDominance(profileId: Int, items: [TradingProfileDominanceInput]) -> Bool {
        guard let db else { return false }
        var ok = sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) == SQLITE_OK
        if ok {
            var deleteStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "DELETE FROM TradingProfileDominance WHERE profile_id = ?", -1, &deleteStmt, nil) == SQLITE_OK {
                sqlite3_bind_int(deleteStmt, 1, Int32(profileId))
                ok = sqlite3_step(deleteStmt) == SQLITE_DONE
            } else {
                ok = false
            }
            sqlite3_finalize(deleteStmt)
        }

        if ok {
            var insertStmt: OpaquePointer?
            let insertSQL = "INSERT INTO TradingProfileDominance (profile_id, category, text, sort_order) VALUES (?,?,?,?)"
            if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK {
                let t = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                for item in items {
                    sqlite3_bind_int(insertStmt, 1, Int32(profileId))
                    sqlite3_bind_text(insertStmt, 2, item.category, -1, t)
                    sqlite3_bind_text(insertStmt, 3, item.text, -1, t)
                    sqlite3_bind_int(insertStmt, 4, Int32(item.sortOrder))
                    if sqlite3_step(insertStmt) != SQLITE_DONE {
                        ok = false
                        break
                    }
                    sqlite3_reset(insertStmt)
                    sqlite3_clear_bindings(insertStmt)
                }
            } else {
                ok = false
            }
            sqlite3_finalize(insertStmt)
        }

        if ok {
            ok = sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK
        } else {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
        }
        return ok
    }

    func fetchRegimeSignals(profileId: Int) -> [TradingProfileRegimeSignalRow] {
        var rows: [TradingProfileRegimeSignalRow] = []
        guard let db else { return rows }
        let sql = """
            SELECT signal_id, profile_id, signal_type, text, sort_order
              FROM TradingProfileRegimeSignals
             WHERE profile_id = ?
             ORDER BY sort_order, signal_id;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(profileId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(
                TradingProfileRegimeSignalRow(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    profileId: Int(sqlite3_column_int(stmt, 1)),
                    signalType: String(cString: sqlite3_column_text(stmt, 2)),
                    text: String(cString: sqlite3_column_text(stmt, 3)),
                    sortOrder: Int(sqlite3_column_int(stmt, 4))
                )
            )
        }
        return rows
    }

    func fetchStrategyFits(profileId: Int) -> [TradingProfileStrategyFitRow] {
        var rows: [TradingProfileStrategyFitRow] = []
        guard let db else { return rows }
        let sql = """
            SELECT strategy_id, profile_id, strategy_name, status_label, status_tone, reason, sort_order
              FROM TradingProfileStrategyFit
             WHERE profile_id = ?
             ORDER BY sort_order, strategy_id;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(profileId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(
                TradingProfileStrategyFitRow(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    profileId: Int(sqlite3_column_int(stmt, 1)),
                    name: String(cString: sqlite3_column_text(stmt, 2)),
                    statusLabel: String(cString: sqlite3_column_text(stmt, 3)),
                    statusTone: String(cString: sqlite3_column_text(stmt, 4)),
                    reason: sqlite3_column_text(stmt, 5).map { String(cString: $0) },
                    sortOrder: Int(sqlite3_column_int(stmt, 6))
                )
            )
        }
        return rows
    }

    func fetchRiskSignals(profileId: Int) -> [TradingProfileRiskSignalRow] {
        var rows: [TradingProfileRiskSignalRow] = []
        guard let db else { return rows }
        let sql = """
            SELECT risk_signal_id, profile_id, signal_type, text, sort_order
              FROM TradingProfileRiskSignals
             WHERE profile_id = ?
             ORDER BY sort_order, risk_signal_id;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(profileId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(
                TradingProfileRiskSignalRow(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    profileId: Int(sqlite3_column_int(stmt, 1)),
                    signalType: String(cString: sqlite3_column_text(stmt, 2)),
                    text: String(cString: sqlite3_column_text(stmt, 3)),
                    sortOrder: Int(sqlite3_column_int(stmt, 4))
                )
            )
        }
        return rows
    }

    func fetchRules(profileId: Int) -> [TradingProfileRuleRow] {
        var rows: [TradingProfileRuleRow] = []
        guard let db else { return rows }
        let sql = """
            SELECT rule_id, profile_id, rule_text, sort_order
              FROM TradingProfileRules
             WHERE profile_id = ?
             ORDER BY sort_order, rule_id;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(profileId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(
                TradingProfileRuleRow(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    profileId: Int(sqlite3_column_int(stmt, 1)),
                    text: String(cString: sqlite3_column_text(stmt, 2)),
                    sortOrder: Int(sqlite3_column_int(stmt, 3))
                )
            )
        }
        return rows
    }

    func fetchViolations(profileId: Int) -> [TradingProfileViolationRow] {
        var rows: [TradingProfileViolationRow] = []
        guard let db else { return rows }
        let sql = """
            SELECT violation_id, profile_id, violation_date, rule_text, resolution_text
              FROM TradingProfileRuleViolations
             WHERE profile_id = ?
             ORDER BY violation_date DESC, violation_id DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(profileId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(
                TradingProfileViolationRow(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    profileId: Int(sqlite3_column_int(stmt, 1)),
                    date: String(cString: sqlite3_column_text(stmt, 2)),
                    ruleText: String(cString: sqlite3_column_text(stmt, 3)),
                    resolutionText: String(cString: sqlite3_column_text(stmt, 4))
                )
            )
        }
        return rows
    }

    func fetchReviewLogs(profileId: Int) -> [TradingProfileReviewLogRow] {
        var rows: [TradingProfileReviewLogRow] = []
        guard let db else { return rows }
        let sql = """
            SELECT review_id, profile_id, review_date, event, decision, confidence, notes
              FROM TradingProfileReviewLog
             WHERE profile_id = ?
             ORDER BY review_date DESC, review_id DESC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(profileId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(
                TradingProfileReviewLogRow(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    profileId: Int(sqlite3_column_int(stmt, 1)),
                    date: String(cString: sqlite3_column_text(stmt, 2)),
                    event: String(cString: sqlite3_column_text(stmt, 3)),
                    decision: String(cString: sqlite3_column_text(stmt, 4)),
                    confidence: String(cString: sqlite3_column_text(stmt, 5)),
                    notes: sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                )
            )
        }
        return rows
    }
}
