-- migrate:up
-- Purpose: Introduce PortfolioThemeStatus table with default statuses.
-- Assumptions: No existing PortfolioThemeStatus table; uses SQLite.
-- Idempotency: Uses IF NOT EXISTS and INSERT OR IGNORE.

CREATE TABLE IF NOT EXISTS PortfolioThemeStatus (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE CHECK (code GLOB '[A-Z][A-Z0-9_]*'),
    name TEXT NOT NULL UNIQUE,
    color_hex TEXT NOT NULL CHECK (color_hex GLOB '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'),
    is_default BOOLEAN NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_portfolio_theme_status_default
ON PortfolioThemeStatus(is_default) WHERE is_default = 1;

INSERT OR IGNORE INTO PortfolioThemeStatus (code, name, color_hex, is_default) VALUES
 ('DRAFT','Draft','#9AA0A6',1),
 ('ACTIVE','Active','#34A853',0),
 ('ARCHIVED','Archived','#B0BEC5',0);

UPDATE PortfolioThemeStatus
SET is_default = 1
WHERE code = 'DRAFT'
  AND NOT EXISTS (SELECT 1 FROM PortfolioThemeStatus WHERE is_default = 1);

-- migrate:down
DROP TABLE IF EXISTS PortfolioThemeStatus;
