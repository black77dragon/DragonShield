-- migrate:up
-- Purpose: Add Markdown body and pin flag to instrument-level updates.
-- Assumptions: PortfolioThemeAssetUpdate table exists with body_text column.
-- Idempotency: use IF NOT EXISTS and content checks where possible.
ALTER TABLE PortfolioThemeAssetUpdate
  ADD COLUMN body_markdown TEXT NULL;

ALTER TABLE PortfolioThemeAssetUpdate
  ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1));

UPDATE PortfolioThemeAssetUpdate
  SET body_markdown = COALESCE(body_text, '');

CREATE INDEX IF NOT EXISTS idx_ptau_theme_instr_pinned_order
  ON PortfolioThemeAssetUpdate(theme_id, instrument_id, pinned DESC, created_at DESC);

-- migrate:down
-- Purpose: Roll back pin and Markdown fields. SQLite cannot drop columns; restore from backup.
DROP INDEX IF EXISTS idx_ptau_theme_instr_pinned_order;
