// DragonShield/DatabaseManager+ThesisManagement.swift
// Runtime DDL helpers for Thesis Management persistence

import Foundation
import SQLite3

extension DatabaseManager {
    func ensureThesisTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS Thesis (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            north_star TEXT NOT NULL,
            investment_role TEXT NOT NULL,
            non_goals TEXT NOT NULL,
            tier TEXT NOT NULL CHECK (tier IN ('tier1','tier2')),
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
        );
        CREATE TABLE IF NOT EXISTS ThesisAssumption (
            id TEXT PRIMARY KEY,
            thesis_id TEXT NOT NULL REFERENCES Thesis(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            detail TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_thesis_assumption_thesis ON ThesisAssumption(thesis_id);
        CREATE TABLE IF NOT EXISTS ThesisKillCriterion (
            id TEXT PRIMARY KEY,
            thesis_id TEXT NOT NULL REFERENCES Thesis(id) ON DELETE CASCADE,
            description TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_thesis_kill_thesis ON ThesisKillCriterion(thesis_id);
        CREATE TABLE IF NOT EXISTS ThesisKPIDefinition (
            id TEXT PRIMARY KEY,
            thesis_id TEXT NOT NULL REFERENCES Thesis(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            description TEXT NOT NULL,
            source TEXT NULL,
            is_primary INTEGER NOT NULL CHECK (is_primary IN (0,1)),
            direction TEXT NOT NULL CHECK (direction IN ('higherIsBetter','lowerIsBetter')),
            green_low REAL NOT NULL,
            green_high REAL NOT NULL,
            amber_low REAL NOT NULL,
            amber_high REAL NOT NULL,
            red_low REAL NOT NULL,
            red_high REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_thesis_kpi_thesis ON ThesisKPIDefinition(thesis_id);
        CREATE TABLE IF NOT EXISTS ThesisWeeklyReview (
            id TEXT PRIMARY KEY,
            thesis_id TEXT NOT NULL REFERENCES Thesis(id) ON DELETE CASCADE,
            week TEXT NOT NULL,
            headline TEXT NOT NULL,
            confidence INTEGER NOT NULL,
            decision TEXT NOT NULL,
            status TEXT NOT NULL,
            macro_events_json TEXT NULL,
            micro_events_json TEXT NULL,
            rationale_json TEXT NULL,
            watch_items_json TEXT NULL,
            finalized_at TEXT NULL,
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            patch_id TEXT NULL UNIQUE,
            kill_switch INTEGER NOT NULL DEFAULT 0 CHECK (kill_switch IN (0,1)),
            notes TEXT NULL,
            UNIQUE(thesis_id, week)
        );
        CREATE INDEX IF NOT EXISTS idx_thesis_review_thesis_week ON ThesisWeeklyReview(thesis_id, week);
        CREATE TABLE IF NOT EXISTS ThesisAssumptionStatus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            review_id TEXT NOT NULL REFERENCES ThesisWeeklyReview(id) ON DELETE CASCADE,
            assumption_id TEXT NOT NULL REFERENCES ThesisAssumption(id) ON DELETE CASCADE,
            status TEXT NOT NULL,
            note TEXT NULL,
            UNIQUE(review_id, assumption_id)
        );
        CREATE TABLE IF NOT EXISTS ThesisKillStatus (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            review_id TEXT NOT NULL REFERENCES ThesisWeeklyReview(id) ON DELETE CASCADE,
            kill_id TEXT NOT NULL REFERENCES ThesisKillCriterion(id) ON DELETE CASCADE,
            status TEXT NOT NULL,
            note TEXT NULL,
            UNIQUE(review_id, kill_id)
        );
        CREATE TABLE IF NOT EXISTS ThesisKPIReading (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            review_id TEXT NOT NULL REFERENCES ThesisWeeklyReview(id) ON DELETE CASCADE,
            kpi_id TEXT NOT NULL REFERENCES ThesisKPIDefinition(id) ON DELETE CASCADE,
            value REAL NULL,
            trend TEXT NULL,
            delta_1w REAL NULL,
            delta_4w REAL NULL,
            comment TEXT NULL,
            status TEXT NOT NULL,
            UNIQUE(review_id, kpi_id)
        );
        CREATE INDEX IF NOT EXISTS idx_thesis_kill_status_review ON ThesisKillStatus(review_id);
        CREATE INDEX IF NOT EXISTS idx_thesis_reading_review ON ThesisKPIReading(review_id);
        CREATE TABLE IF NOT EXISTS ThesisKPIPrompt (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            thesis_id TEXT NOT NULL REFERENCES Thesis(id) ON DELETE CASCADE,
            version INTEGER NOT NULL,
            status TEXT NOT NULL CHECK (status IN ('active','inactive','archived')),
            body TEXT NOT NULL,
            notes TEXT NULL,
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            UNIQUE(thesis_id, version)
        );
        CREATE INDEX IF NOT EXISTS idx_thesis_kpi_prompt_thesis ON ThesisKPIPrompt(thesis_id);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_thesis_kpi_prompt_active ON ThesisKPIPrompt(thesis_id) WHERE status = 'active';
        CREATE TABLE IF NOT EXISTS PromptTemplate (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            template_key TEXT NOT NULL CHECK (template_key IN ('thesis_import','weekly_review')),
            version INTEGER NOT NULL,
            status TEXT NOT NULL CHECK (status IN ('active','inactive','archived')),
            body TEXT NOT NULL,
            settings_json TEXT NULL,
            notes TEXT NULL,
            created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
            UNIQUE(template_key, version)
        );
        CREATE INDEX IF NOT EXISTS idx_prompt_template_key ON PromptTemplate(template_key);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_prompt_template_active ON PromptTemplate(template_key) WHERE status = 'active';
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            print("❌ ensureThesisTables failed: \(message)")
        }
        ensureThesisKpiSourceColumn()
    }

    private func ensureThesisKpiSourceColumn() {
        guard let db else { return }
        guard !tableHasColumn("ThesisKPIDefinition", column: "source") else { return }
        let sql = "ALTER TABLE ThesisKPIDefinition ADD COLUMN source TEXT NULL"
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            print("❌ ensureThesisKpiSourceColumn failed: \(message)")
        }
    }
}
