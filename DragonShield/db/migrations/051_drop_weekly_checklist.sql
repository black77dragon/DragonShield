-- migrate:up
-- Purpose: Remove weekly checklist feature (tables + theme flags).

DROP TABLE IF EXISTS WeeklyChecklist;

ALTER TABLE PortfolioTheme RENAME TO PortfolioTheme_old;

CREATE TABLE PortfolioTheme (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL CHECK (LENGTH(name) BETWEEN 1 AND 64),
    code TEXT NOT NULL CHECK (code GLOB '[A-Z][A-Z0-9_]*' AND LENGTH(code) BETWEEN 2 AND 31),
    status_id INTEGER NOT NULL REFERENCES PortfolioThemeStatus(id),
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    archived_at TEXT NULL,
    soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1)),
    description TEXT NULL,
    institution_id INTEGER REFERENCES Institutions(institution_id) ON DELETE SET NULL,
    theoretical_budget_chf REAL NULL CHECK (theoretical_budget_chf >= 0),
    time_horizon_end_date TEXT NULL,
    timeline_id INTEGER NOT NULL DEFAULT 5 REFERENCES PortfolioTimelines(id)
);

INSERT INTO PortfolioTheme (
    id,
    name,
    code,
    status_id,
    created_at,
    updated_at,
    archived_at,
    soft_delete,
    description,
    institution_id,
    theoretical_budget_chf,
    time_horizon_end_date,
    timeline_id
)
SELECT
    id,
    name,
    code,
    status_id,
    created_at,
    updated_at,
    archived_at,
    soft_delete,
    description,
    institution_id,
    theoretical_budget_chf,
    time_horizon_end_date,
    timeline_id
FROM PortfolioTheme_old;

DROP TABLE PortfolioTheme_old;

CREATE UNIQUE INDEX idx_portfolio_theme_name_unique
    ON PortfolioTheme(LOWER(name))
    WHERE soft_delete = 0;
CREATE UNIQUE INDEX idx_portfolio_theme_code_unique
    ON PortfolioTheme(LOWER(code))
    WHERE soft_delete = 0;
CREATE INDEX idx_portfolio_theme_institution_id ON PortfolioTheme(institution_id);
CREATE INDEX idx_portfolio_theme_timeline_id ON PortfolioTheme(timeline_id);

CREATE TRIGGER trg_portfolio_theme_description_len
BEFORE INSERT ON PortfolioTheme
WHEN NEW.description IS NOT NULL AND LENGTH(NEW.description) > 2000
BEGIN
  SELECT RAISE(ABORT, 'Description exceeds 2000 characters');
END;
CREATE TRIGGER trg_portfolio_theme_description_len_upd
BEFORE UPDATE ON PortfolioTheme
WHEN NEW.description IS NOT NULL AND LENGTH(NEW.description) > 2000
BEGIN
  SELECT RAISE(ABORT, 'Description exceeds 2000 characters');
END;

-- migrate:down
-- Recreate weekly checklist tables + flags.

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

ALTER TABLE PortfolioTheme RENAME TO PortfolioTheme_old;

CREATE TABLE PortfolioTheme (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL CHECK (LENGTH(name) BETWEEN 1 AND 64),
    code TEXT NOT NULL CHECK (code GLOB '[A-Z][A-Z0-9_]*' AND LENGTH(code) BETWEEN 2 AND 31),
    status_id INTEGER NOT NULL REFERENCES PortfolioThemeStatus(id),
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    archived_at TEXT NULL,
    soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1)),
    description TEXT NULL,
    institution_id INTEGER REFERENCES Institutions(institution_id) ON DELETE SET NULL,
    theoretical_budget_chf REAL NULL CHECK (theoretical_budget_chf >= 0),
    weekly_checklist_enabled INTEGER NOT NULL DEFAULT 1 CHECK (weekly_checklist_enabled IN (0,1)),
    time_horizon_end_date TEXT NULL,
    timeline_id INTEGER NOT NULL DEFAULT 5 REFERENCES PortfolioTimelines(id),
    weekly_checklist_high_priority INTEGER NOT NULL DEFAULT 0 CHECK (weekly_checklist_high_priority IN (0,1))
);

INSERT INTO PortfolioTheme (
    id,
    name,
    code,
    status_id,
    created_at,
    updated_at,
    archived_at,
    soft_delete,
    description,
    institution_id,
    theoretical_budget_chf,
    weekly_checklist_enabled,
    time_horizon_end_date,
    timeline_id,
    weekly_checklist_high_priority
)
SELECT
    id,
    name,
    code,
    status_id,
    created_at,
    updated_at,
    archived_at,
    soft_delete,
    description,
    institution_id,
    theoretical_budget_chf,
    1,
    time_horizon_end_date,
    timeline_id,
    0
FROM PortfolioTheme_old;

DROP TABLE PortfolioTheme_old;

CREATE UNIQUE INDEX idx_portfolio_theme_name_unique
    ON PortfolioTheme(LOWER(name))
    WHERE soft_delete = 0;
CREATE UNIQUE INDEX idx_portfolio_theme_code_unique
    ON PortfolioTheme(LOWER(code))
    WHERE soft_delete = 0;
CREATE INDEX idx_portfolio_theme_institution_id ON PortfolioTheme(institution_id);
CREATE INDEX idx_portfolio_theme_timeline_id ON PortfolioTheme(timeline_id);

CREATE TRIGGER trg_portfolio_theme_description_len
BEFORE INSERT ON PortfolioTheme
WHEN NEW.description IS NOT NULL AND LENGTH(NEW.description) > 2000
BEGIN
  SELECT RAISE(ABORT, 'Description exceeds 2000 characters');
END;
CREATE TRIGGER trg_portfolio_theme_description_len_upd
BEFORE UPDATE ON PortfolioTheme
WHEN NEW.description IS NOT NULL AND LENGTH(NEW.description) > 2000
BEGIN
  SELECT RAISE(ABORT, 'Description exceeds 2000 characters');
END;
