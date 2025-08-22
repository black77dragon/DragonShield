-- migrate:up
-- Purpose: Add description and optional institution link to portfolio themes for richer metadata.
-- Assumptions: Existing PortfolioTheme rows have no description or institution reference; Institutions table exists.
-- Idempotency: use IF NOT EXISTS and content checks where possible
ALTER TABLE PortfolioTheme ADD COLUMN description TEXT;
ALTER TABLE PortfolioTheme ADD COLUMN institution_id INTEGER REFERENCES Institutions(institution_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_portfolio_theme_institution_id ON PortfolioTheme(institution_id);
CREATE TRIGGER IF NOT EXISTS trg_portfolio_theme_description_len
BEFORE INSERT ON PortfolioTheme
WHEN NEW.description IS NOT NULL AND LENGTH(NEW.description) > 2000
BEGIN
  SELECT RAISE(ABORT, 'Description exceeds 2000 characters');
END;
CREATE TRIGGER IF NOT EXISTS trg_portfolio_theme_description_len_upd
BEFORE UPDATE ON PortfolioTheme
WHEN NEW.description IS NOT NULL AND LENGTH(NEW.description) > 2000
BEGIN
  SELECT RAISE(ABORT, 'Description exceeds 2000 characters');
END;

-- migrate:down
DROP TRIGGER IF EXISTS trg_portfolio_theme_description_len_upd;
DROP TRIGGER IF EXISTS trg_portfolio_theme_description_len;
DROP INDEX IF EXISTS idx_portfolio_theme_institution_id;
-- SQLite cannot drop columns; rebuild from backup per db management plan.
