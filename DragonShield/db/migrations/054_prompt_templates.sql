-- migrate:up
-- Purpose: Add versioned prompt templates for thesis import and weekly review.
CREATE TABLE IF NOT EXISTS PromptTemplate (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_key TEXT NOT NULL CHECK (template_key IN ('thesis_import','weekly_review')),
    version INTEGER NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('active','inactive','archived')),
    body TEXT NOT NULL,
    settings_json TEXT NULL,
    notes TEXT NULL,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE(template_key, version)
);
CREATE INDEX IF NOT EXISTS idx_prompt_template_key ON PromptTemplate(template_key);
CREATE UNIQUE INDEX IF NOT EXISTS idx_prompt_template_active ON PromptTemplate(template_key) WHERE status = 'active';

-- migrate:down
DROP TABLE IF EXISTS PromptTemplate;
