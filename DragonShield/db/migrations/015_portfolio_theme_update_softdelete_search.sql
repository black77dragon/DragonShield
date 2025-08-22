-- migrate:up
-- Purpose: Add soft delete columns and search indexes for portfolio theme updates
-- Assumptions: PortfolioThemeUpdate exists without soft delete columns; data kept intact
-- Idempotency: use IF NOT EXISTS and check constraints

ALTER TABLE PortfolioThemeUpdate
  ADD COLUMN soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1));
ALTER TABLE PortfolioThemeUpdate
  ADD COLUMN deleted_at  TEXT NULL;
ALTER TABLE PortfolioThemeUpdate
  ADD COLUMN deleted_by  TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_ptu_theme_active_order
  ON PortfolioThemeUpdate(theme_id, soft_delete, pinned, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ptu_theme_deleted_order
  ON PortfolioThemeUpdate(theme_id, soft_delete, deleted_at DESC);

-- migrate:down
DROP INDEX IF EXISTS idx_ptu_theme_deleted_order;
DROP INDEX IF EXISTS idx_ptu_theme_active_order;
ALTER TABLE PortfolioThemeUpdate DROP COLUMN deleted_by;
ALTER TABLE PortfolioThemeUpdate DROP COLUMN deleted_at;
ALTER TABLE PortfolioThemeUpdate DROP COLUMN soft_delete;
