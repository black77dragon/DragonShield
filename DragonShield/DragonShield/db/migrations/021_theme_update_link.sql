-- migrate:up
-- Purpose: Add Link and ThemeUpdateLink tables for theme update URLs
-- Assumptions: PortfolioThemeUpdate table exists
-- Idempotency: use IF NOT EXISTS and content checks where possible
CREATE TABLE IF NOT EXISTS Link (
  id               INTEGER PRIMARY KEY,
  normalized_url   TEXT    NOT NULL UNIQUE,
  raw_url          TEXT    NOT NULL,
  title            TEXT    NULL,
  created_at       TEXT    NOT NULL,
  created_by       TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_link_normalized ON Link(normalized_url);

CREATE TABLE IF NOT EXISTS ThemeUpdateLink (
  id              INTEGER PRIMARY KEY,
  theme_update_id INTEGER NOT NULL
      REFERENCES PortfolioThemeUpdate(id) ON DELETE CASCADE,
  link_id         INTEGER NOT NULL
      REFERENCES Link(id) ON DELETE RESTRICT,
  created_at      TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tul_update ON ThemeUpdateLink(theme_update_id);
CREATE INDEX IF NOT EXISTS idx_tul_link ON ThemeUpdateLink(link_id);

-- migrate:down
DROP INDEX IF EXISTS idx_tul_update;
DROP INDEX IF EXISTS idx_tul_link;
DROP TABLE IF EXISTS ThemeUpdateLink;
DROP INDEX IF EXISTS idx_link_normalized;
DROP TABLE IF EXISTS Link;
