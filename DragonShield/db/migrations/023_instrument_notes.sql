-- migrate:up
-- Purpose: add notes column to Instruments for free-form annotations
-- Assumptions: Instruments table exists and notes column absent
-- Idempotency: SQLite <3.35 lacks ADD COLUMN IF NOT EXISTS; rely on schema versioning
ALTER TABLE Instruments ADD COLUMN notes TEXT;

-- migrate:down
-- No-op: dropping column requires table recreation. Rollback via restore from backup.
