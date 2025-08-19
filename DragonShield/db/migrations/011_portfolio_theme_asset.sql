-- migrate:up
-- Purpose: Introduce PortfolioThemeAsset table linking themes to instruments with target percentages.
-- Assumptions: PortfolioTheme and Instruments tables exist; SQLite database with dbmate migrations.
-- Idempotency: Uses IF NOT EXISTS and CHECK constraints.

CREATE TABLE IF NOT EXISTS PortfolioThemeAsset (
    theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE RESTRICT,
    instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE RESTRICT,
    research_target_pct REAL NOT NULL DEFAULT 0.0 CHECK(research_target_pct >= 0.0 AND research_target_pct <= 100.0),
    user_target_pct REAL NOT NULL DEFAULT 0.0 CHECK(user_target_pct >= 0.0 AND user_target_pct <= 100.0),
    notes TEXT NULL,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    PRIMARY KEY (theme_id, instrument_id)
);

CREATE INDEX IF NOT EXISTS idx_portfolio_theme_asset_instrument ON PortfolioThemeAsset(instrument_id);

-- migrate:down
DROP TABLE IF EXISTS PortfolioThemeAsset;
