-- migrate:up
-- Purpose: Add theoretical theme budget (CHF) column to PortfolioTheme for planning/analysis.
-- Assumptions: PortfolioTheme table exists; column does not exist yet. Executed once by dbmate.
-- Idempotency: Not strictly idempotent; dbmate guards with versioning.
ALTER TABLE PortfolioTheme
  ADD COLUMN theoretical_budget_chf REAL NULL CHECK (theoretical_budget_chf >= 0);

-- migrate:down
-- Purpose: Reverse of adding theoretical_budget_chf.
-- Note: SQLite historically cannot drop columns safely. If using SQLite >= 3.35.0, a DROP COLUMN may be possible.
-- For safety, we provide a no-op down and advise restoring from backup if rollback is required.
-- No-op
