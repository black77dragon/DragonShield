-- migrate:up
-- Purpose: Store global portfolio performance events for chart annotations.
CREATE TABLE IF NOT EXISTS PortfolioPerformanceEvents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_date TEXT NOT NULL,
    event_type TEXT NOT NULL,
    short_description TEXT NOT NULL,
    long_description TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_portfolio_performance_events_date
    ON PortfolioPerformanceEvents(event_date);

-- migrate:down
DROP INDEX IF EXISTS idx_portfolio_performance_events_date;
DROP TABLE IF EXISTS PortfolioPerformanceEvents;
