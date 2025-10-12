-- migrate:up
-- Purpose: Introduce manually managed target amount (CHF) per theme instrument.
-- Adds column `rwk_set_target_chf` to PortfolioThemeAsset for storing a user-defined CHF target.
ALTER TABLE PortfolioThemeAsset
  ADD COLUMN rwk_set_target_chf REAL NULL;

-- migrate:down
-- Purpose: Rollback is a no-op (removing columns in SQLite is non-trivial without rebuild).
-- No-op
