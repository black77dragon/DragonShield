-- migrate:up
-- Purpose: Add Markdown body and pin flag to PortfolioThemeUpdate, backfilling existing text.
-- Assumptions: PortfolioThemeUpdate from 6A with body_text column.
-- Idempotency: use IF NOT EXISTS and content checks where possible
ALTER TABLE PortfolioThemeUpdate ADD COLUMN body_markdown TEXT NULL;
ALTER TABLE PortfolioThemeUpdate ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1));
UPDATE PortfolioThemeUpdate SET body_markdown = COALESCE(body_text, '');
CREATE INDEX IF NOT EXISTS idx_ptu_theme_pinned_order ON PortfolioThemeUpdate(theme_id, pinned DESC, created_at DESC);

-- migrate:down
DROP INDEX IF EXISTS idx_ptu_theme_pinned_order;
-- Columns remain for rollback; recreate table from backup if needed.
