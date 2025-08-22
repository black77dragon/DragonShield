-- migrate:up
-- Purpose: Introduce PortfolioThemeAssetUpdate table for instrument-level update timelines.
-- Assumptions: PortfolioTheme and Instruments tables exist with integer primary keys.
-- Idempotency: use IF NOT EXISTS and CHECK constraints to enforce domain values.
CREATE TABLE IF NOT EXISTS PortfolioThemeAssetUpdate (
  id               INTEGER PRIMARY KEY,
  theme_id         INTEGER NOT NULL
                     REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  instrument_id    INTEGER NOT NULL
                     REFERENCES Instruments(instrument_id) ON DELETE SET NULL,
  title            TEXT    NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text        TEXT    NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  type             TEXT    NOT NULL
                     CHECK (type IN ('General','Research','Rebalance','Risk')),
  author           TEXT    NOT NULL,
  positions_asof   TEXT    NULL,
  value_chf        REAL    NULL,
  actual_percent   REAL    NULL,
  created_at       TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at       TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_order
  ON PortfolioThemeAssetUpdate(theme_id, instrument_id, created_at DESC);

-- migrate:down
DROP INDEX IF EXISTS idx_ptau_theme_instr_order;
DROP TABLE IF EXISTS PortfolioThemeAssetUpdate;
