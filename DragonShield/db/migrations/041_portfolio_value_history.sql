-- migrate:up
-- Purpose: Persist daily total portfolio value (CHF) snapshots for historic performance charts.
-- Assumptions: Dates are stored as yyyy-MM-dd (UTC) and one snapshot is kept per day.
CREATE TABLE IF NOT EXISTS PortfolioValueHistory (
    value_date TEXT NOT NULL PRIMARY KEY,
    total_value_chf REAL NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- migrate:down
DROP TABLE IF EXISTS PortfolioValueHistory;
