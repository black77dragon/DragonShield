-- migrate:up
-- Purpose: Add weekly checklist entries per portfolio theme and a per-theme enable toggle.
-- Assumptions: PortfolioTheme exists and dbmate manages schema_migrations.

CREATE TABLE IF NOT EXISTS WeeklyChecklist (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
    week_start_date TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('draft','completed','skipped')),
    answers_json TEXT,
    completed_at TEXT,
    skipped_at TEXT,
    skip_comment TEXT,
    last_edited_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    revision INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_weekly_checklist_theme_week
    ON WeeklyChecklist(theme_id, week_start_date);

CREATE INDEX IF NOT EXISTS idx_weekly_checklist_theme_status
    ON WeeklyChecklist(theme_id, status);

CREATE INDEX IF NOT EXISTS idx_weekly_checklist_week
    ON WeeklyChecklist(week_start_date);

ALTER TABLE PortfolioTheme
    ADD COLUMN weekly_checklist_enabled INTEGER NOT NULL DEFAULT 1 CHECK(weekly_checklist_enabled IN (0,1));

-- migrate:down
-- Drop checklist table; PortfolioTheme column rollback requires DB restore.
DROP TABLE IF EXISTS WeeklyChecklist;
