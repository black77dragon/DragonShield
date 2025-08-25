-- migrate:up
-- Purpose: add notes column to Instruments for free-form annotations
-- Assumptions: Instruments table exists; column absent
-- Idempotency: uses IF NOT EXISTS clause supported since SQLite 3.35
ALTER TABLE Instruments ADD COLUMN IF NOT EXISTS notes TEXT;

-- migrate:down
-- No-op: dropping column requires table recreation. Rollback via restore from backup.
