-- 036_system_job_runs.sql
-- Adds SystemJobRuns table to persist status history for background jobs (FX updates, iOS snapshot exports, etc.).

CREATE TABLE IF NOT EXISTS SystemJobRuns (
    run_id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_key TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('SUCCESS','PARTIAL','FAILED')),
    message TEXT,
    metadata_json TEXT,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    duration_ms INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_system_job_runs_job_key ON SystemJobRuns(job_key);
CREATE INDEX IF NOT EXISTS idx_system_job_runs_job_key_finished ON SystemJobRuns(job_key, finished_at);
