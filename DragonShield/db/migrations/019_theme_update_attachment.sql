-- migrate:up
-- Purpose: Link attachments to PortfolioThemeUpdate records.
-- Assumptions: Attachment and PortfolioThemeUpdate tables exist.
-- Idempotency: use IF NOT EXISTS on table and indexes.
CREATE TABLE IF NOT EXISTS ThemeUpdateAttachment (
  id               INTEGER PRIMARY KEY,
  theme_update_id  INTEGER NOT NULL
      REFERENCES PortfolioThemeUpdate(id) ON DELETE CASCADE,
  attachment_id    INTEGER NOT NULL
      REFERENCES Attachment(id) ON DELETE RESTRICT,
  created_at       TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tua_update ON ThemeUpdateAttachment(theme_update_id);
CREATE INDEX IF NOT EXISTS idx_tua_attachment ON ThemeUpdateAttachment(attachment_id);

-- migrate:down
DROP INDEX IF EXISTS idx_tua_update;
DROP INDEX IF EXISTS idx_tua_attachment;
DROP TABLE IF EXISTS ThemeUpdateAttachment;
