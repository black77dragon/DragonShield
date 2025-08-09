-- 004_add_validation_findings.sql
-- Add ValidationFindings table to store class- and subclass-level validation reasons

BEGIN;

CREATE TABLE IF NOT EXISTS ValidationFindings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL CHECK(entity_type IN('class','subclass')),
    entity_id INTEGER NOT NULL,
    severity TEXT NOT NULL CHECK(severity IN('warning','error')),
    code TEXT NOT NULL,
    message TEXT NOT NULL,
    details_json TEXT,
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(entity_type, entity_id, code)
);

UPDATE Configuration SET value = '4.24' WHERE key = 'db_version';

COMMIT;
