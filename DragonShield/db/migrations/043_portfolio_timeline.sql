-- migrate:up
-- Purpose: Add portfolio timelines and per-portfolio time horizon end dates.

CREATE TABLE IF NOT EXISTS PortfolioTimelines (
    id INTEGER PRIMARY KEY,
    description TEXT NOT NULL,
    time_indication TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
);

INSERT OR IGNORE INTO PortfolioTimelines (id, description, time_indication, sort_order, is_active) VALUES
    (5, 'To be determined', 'TBD', 0, 1),
    (1, 'Short-Term', '0-12m', 1, 1),
    (2, 'Medium-Term', '1-3y', 2, 1),
    (3, 'Long-Term', '3-5y', 3, 1),
    (4, 'Strategic', '5y+', 4, 1);

ALTER TABLE PortfolioTheme
    ADD COLUMN timeline_id INTEGER NOT NULL DEFAULT 5 REFERENCES PortfolioTimelines(id);

ALTER TABLE PortfolioTheme
    ADD COLUMN time_horizon_end_date TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_portfolio_theme_timeline_id ON PortfolioTheme(timeline_id);

-- migrate:down
-- PortfolioTheme column rollback requires DB restore.
DROP TABLE IF EXISTS PortfolioTimelines;
