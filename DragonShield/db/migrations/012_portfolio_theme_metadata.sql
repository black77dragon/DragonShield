-- migrate:up
-- Purpose: Add description and optional institution link to portfolio themes for richer metadata.
-- Assumptions: Existing PortfolioTheme rows have no description or institution reference; Institutions table exists.
-- Idempotency: use IF NOT EXISTS and content checks where possible
ALTER TABLE PortfolioTheme ADD COLUMN description TEXT CHECK (LENGTH(description) <= 2000);
ALTER TABLE PortfolioTheme ADD COLUMN institution_id INTEGER REFERENCES Institutions(institution_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_portfolio_theme_institution_id ON PortfolioTheme(institution_id);

-- migrate:down
DROP INDEX IF EXISTS idx_portfolio_theme_institution_id;
-- SQLite cannot drop columns; rebuild from backup per db management plan.
