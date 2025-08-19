-- migrate:up
-- Purpose: Introduce PortfolioTheme table to store user-defined portfolio themes.
-- Assumptions: PortfolioThemeStatus table exists with default rows; SQLite database.
-- Idempotency: Uses IF NOT EXISTS and partial unique indexes.

CREATE TABLE IF NOT EXISTS PortfolioTheme (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL CHECK (LENGTH(name) BETWEEN 1 AND 64),
    code TEXT NOT NULL CHECK (code GLOB '[A-Z][A-Z0-9_]*' AND LENGTH(code) BETWEEN 2 AND 31),
    status_id INTEGER NOT NULL REFERENCES PortfolioThemeStatus(id),
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    archived_at TEXT NULL,
    soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_portfolio_theme_name_unique
ON PortfolioTheme(LOWER(name))
WHERE soft_delete = 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_portfolio_theme_code_unique
ON PortfolioTheme(LOWER(code))
WHERE soft_delete = 0;

-- migrate:down
DROP TABLE IF EXISTS PortfolioTheme;
