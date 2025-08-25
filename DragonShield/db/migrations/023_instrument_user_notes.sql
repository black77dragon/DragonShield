-- migrate:up
-- Purpose: allow storing optional user-specific notes for each instrument
-- Assumptions: Instruments table exists and lacks user_note column
-- Idempotency: SQLite does not support IF NOT EXISTS for ADD COLUMN; ensure column is absent before migration
ALTER TABLE Instruments ADD COLUMN user_note TEXT DEFAULT NULL;

-- migrate:down
ALTER TABLE Instruments DROP COLUMN user_note;
