-- migrate:up
-- Purpose: Introduce PortfolioThemeUpdate table for recording theme-level update timeline entries.
-- Assumptions: PortfolioTheme table exists and uses integer primary keys; no existing update records.
-- Idempotency: use IF NOT EXISTS and CHECK constraints to enforce domain values.
CREATE TABLE IF NOT EXISTS PortfolioThemeUpdate (
  id               INTEGER PRIMARY KEY,
  theme_id         INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  title            TEXT    NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text        TEXT    NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  type             TEXT    NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk')),
  author           TEXT    NOT NULL,
  positions_asof   TEXT    NULL,
  total_value_chf  REAL    NULL,
  created_at       TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at       TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_ptu_theme_order ON PortfolioThemeUpdate(theme_id, created_at DESC);

-- migrate:down
DROP INDEX IF EXISTS idx_ptu_theme_order;
DROP TABLE IF EXISTS PortfolioThemeUpdate;
