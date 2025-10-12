-- migrate:up
-- Purpose: Link attachments to instrument updates
-- Assumptions: PortfolioThemeAssetUpdate and Attachment tables exist
-- Idempotency: use IF NOT EXISTS and content checks where possible
CREATE TABLE IF NOT EXISTS ThemeAssetUpdateAttachment (
  id                     INTEGER PRIMARY KEY,
  theme_asset_update_id  INTEGER NOT NULL
      REFERENCES PortfolioThemeAssetUpdate(id) ON DELETE CASCADE,
  attachment_id          INTEGER NOT NULL
      REFERENCES Attachment(id) ON DELETE RESTRICT,
  created_at             TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_taua_update ON ThemeAssetUpdateAttachment(theme_asset_update_id);
CREATE INDEX IF NOT EXISTS idx_taua_attachment ON ThemeAssetUpdateAttachment(attachment_id);

-- migrate:down
DROP INDEX IF EXISTS idx_taua_update;
DROP INDEX IF EXISTS idx_taua_attachment;
DROP TABLE IF EXISTS ThemeAssetUpdateAttachment;
