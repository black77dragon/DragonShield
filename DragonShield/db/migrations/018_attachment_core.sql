-- migrate:up
-- Purpose: Add Attachment table for theme update file metadata de-duplication.
-- Assumptions: PortfolioThemeUpdate table exists; attachments stored on disk with SHA256 path.
-- Idempotency: use IF NOT EXISTS and UNIQUE constraint on sha256.
CREATE TABLE IF NOT EXISTS Attachment (
  id               INTEGER PRIMARY KEY,
  sha256           TEXT    NOT NULL UNIQUE,
  original_filename TEXT   NOT NULL,
  mime             TEXT    NOT NULL,
  byte_size        INTEGER NOT NULL,
  ext              TEXT    NULL,
  created_at       TEXT    NOT NULL,
  created_by       TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_attachment_sha ON Attachment(sha256);

-- migrate:down
DROP INDEX IF EXISTS idx_attachment_sha;
DROP TABLE IF EXISTS Attachment;
