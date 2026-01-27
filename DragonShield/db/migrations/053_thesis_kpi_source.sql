-- migrate:up
-- Purpose: Add KPI source metadata to ThesisKPIDefinition.
-- Assumptions: ThesisKPIDefinition exists; column does not exist yet. Executed once by dbmate.
ALTER TABLE ThesisKPIDefinition
  ADD COLUMN source TEXT NULL;

-- migrate:down
-- Purpose: Reverse of adding source column.
-- Note: SQLite cannot drop columns safely; rollback requires manual table rebuild.
-- No-op
