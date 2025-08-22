-- migrate:up
-- Purpose: Add Markdown body and pin flag with NOT NULL constraint, backfilling existing text.
-- Assumptions: PortfolioThemeUpdate from 6A with body_text column and idx_ptu_theme_order index.
-- Idempotency: use IF NOT EXISTS and temp table recreation.
CREATE TABLE IF NOT EXISTS PortfolioThemeUpdate_new (
  id INTEGER PRIMARY KEY,
  theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type TEXT NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk')),
  author TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
  positions_asof TEXT NULL,
  total_value_chf REAL NULL,
  created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
INSERT INTO PortfolioThemeUpdate_new (id, theme_id, title, body_text, body_markdown, type, author, pinned, positions_asof, total_value_chf, created_at, updated_at)
  SELECT id, theme_id, title, body_text, COALESCE(body_text, ''), type, author, 0, positions_asof, total_value_chf, created_at, updated_at
  FROM PortfolioThemeUpdate;
DROP TABLE PortfolioThemeUpdate;
ALTER TABLE PortfolioThemeUpdate_new RENAME TO PortfolioThemeUpdate;
CREATE INDEX IF NOT EXISTS idx_ptu_theme_order ON PortfolioThemeUpdate(theme_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptu_theme_pinned_order ON PortfolioThemeUpdate(theme_id, pinned DESC, created_at DESC);

-- migrate:down
-- Revert to 6A schema without Markdown or pinned flag.
CREATE TABLE IF NOT EXISTS PortfolioThemeUpdate_old (
  id INTEGER PRIMARY KEY,
  theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  type TEXT NOT NULL CHECK (type IN ('General','Research','Rebalance','Risk')),
  author TEXT NOT NULL,
  positions_asof TEXT NULL,
  total_value_chf REAL NULL,
  created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
INSERT INTO PortfolioThemeUpdate_old (id, theme_id, title, body_text, type, author, positions_asof, total_value_chf, created_at, updated_at)
  SELECT id, theme_id, title, body_markdown, type, author, positions_asof, total_value_chf, created_at, updated_at
  FROM PortfolioThemeUpdate;
DROP TABLE PortfolioThemeUpdate;
ALTER TABLE PortfolioThemeUpdate_old RENAME TO PortfolioThemeUpdate;
CREATE INDEX IF NOT EXISTS idx_ptu_theme_order ON PortfolioThemeUpdate(theme_id, created_at DESC);
