-- migrate:up
CREATE TABLE IF NOT EXISTS ThesisKPIPrompt (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    thesis_id TEXT NOT NULL REFERENCES Thesis(id) ON DELETE CASCADE,
    version INTEGER NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('active','inactive','archived')),
    body TEXT NOT NULL,
    notes TEXT NULL,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE(thesis_id, version)
);
CREATE INDEX IF NOT EXISTS idx_thesis_kpi_prompt_thesis ON ThesisKPIPrompt(thesis_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_thesis_kpi_prompt_active ON ThesisKPIPrompt(thesis_id) WHERE status = 'active';

-- migrate:down
DROP INDEX IF EXISTS idx_thesis_kpi_prompt_active;
DROP INDEX IF EXISTS idx_thesis_kpi_prompt_thesis;
DROP TABLE IF EXISTS ThesisKPIPrompt;
