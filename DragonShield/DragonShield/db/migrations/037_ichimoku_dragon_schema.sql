-- Migration 037: Ichimoku Dragon core tables
-- Creates tables required for the Ichimoku-based market scanner.

BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS ichimoku_tickers (
    ticker_id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL UNIQUE,
    name TEXT,
    index_source TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ichimoku_tickers_index_source
    ON ichimoku_tickers(index_source);

CREATE TABLE IF NOT EXISTS ichimoku_price_history (
    ticker_id INTEGER NOT NULL,
    price_date TEXT NOT NULL,
    open REAL NOT NULL,
    high REAL NOT NULL,
    low REAL NOT NULL,
    close REAL NOT NULL,
    volume REAL,
    source TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ticker_id, price_date),
    FOREIGN KEY (ticker_id) REFERENCES ichimoku_tickers(ticker_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ichimoku_price_history_ticker_date
    ON ichimoku_price_history(ticker_id, datetime(price_date) DESC);

CREATE TABLE IF NOT EXISTS ichimoku_indicators (
    ticker_id INTEGER NOT NULL,
    calc_date TEXT NOT NULL,
    tenkan REAL,
    kijun REAL,
    senkou_a REAL,
    senkou_b REAL,
    chikou REAL,
    tenkan_slope REAL,
    kijun_slope REAL,
    price_to_kijun_ratio REAL,
    tenkan_kijun_distance REAL,
    momentum_score REAL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ticker_id, calc_date),
    FOREIGN KEY (ticker_id) REFERENCES ichimoku_tickers(ticker_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ichimoku_indicators_ticker_date
    ON ichimoku_indicators(ticker_id, datetime(calc_date) DESC);

CREATE TABLE IF NOT EXISTS ichimoku_daily_candidates (
    scan_date TEXT NOT NULL,
    ticker_id INTEGER NOT NULL,
    rank INTEGER NOT NULL,
    momentum_score REAL NOT NULL,
    close_price REAL NOT NULL,
    tenkan REAL,
    kijun REAL,
    tenkan_slope REAL,
    kijun_slope REAL,
    price_to_kijun_ratio REAL,
    tenkan_kijun_distance REAL,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (scan_date, ticker_id),
    FOREIGN KEY (ticker_id) REFERENCES ichimoku_tickers(ticker_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ichimoku_daily_candidates_rank
    ON ichimoku_daily_candidates(scan_date, rank);

CREATE TABLE IF NOT EXISTS ichimoku_positions (
    position_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticker_id INTEGER NOT NULL,
    date_opened TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    confirmed_by_user INTEGER NOT NULL DEFAULT 0,
    last_evaluated TEXT,
    last_close REAL,
    last_kijun REAL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ticker_id) REFERENCES ichimoku_tickers(ticker_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ichimoku_positions_status
    ON ichimoku_positions(status, datetime(date_opened) DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ichimoku_positions_active_unq
    ON ichimoku_positions(ticker_id) WHERE status = 'ACTIVE';

CREATE TABLE IF NOT EXISTS ichimoku_sell_alerts (
    alert_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticker_id INTEGER NOT NULL,
    alert_date TEXT NOT NULL,
    close_price REAL NOT NULL,
    kijun_value REAL,
    reason TEXT NOT NULL,
    resolved_at TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ticker_id) REFERENCES ichimoku_tickers(ticker_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ichimoku_sell_alerts_date
    ON ichimoku_sell_alerts(datetime(alert_date) DESC);

CREATE TABLE IF NOT EXISTS ichimoku_run_log (
    run_id INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at TEXT NOT NULL,
    completed_at TEXT,
    status TEXT NOT NULL,
    message TEXT,
    ticks_processed INTEGER DEFAULT 0,
    candidates_found INTEGER DEFAULT 0,
    alerts_triggered INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Trigger helpers for updated_at maintenance
CREATE TRIGGER IF NOT EXISTS trg_ichimoku_tickers_updated
AFTER UPDATE ON ichimoku_tickers
FOR EACH ROW
BEGIN
    UPDATE ichimoku_tickers SET updated_at = CURRENT_TIMESTAMP WHERE ticker_id = OLD.ticker_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_ichimoku_price_history_updated
AFTER UPDATE ON ichimoku_price_history
FOR EACH ROW
BEGIN
    UPDATE ichimoku_price_history SET updated_at = CURRENT_TIMESTAMP
    WHERE ticker_id = OLD.ticker_id AND price_date = OLD.price_date;
END;

CREATE TRIGGER IF NOT EXISTS trg_ichimoku_indicators_updated
AFTER UPDATE ON ichimoku_indicators
FOR EACH ROW
BEGIN
    UPDATE ichimoku_indicators SET updated_at = CURRENT_TIMESTAMP
    WHERE ticker_id = OLD.ticker_id AND calc_date = OLD.calc_date;
END;

CREATE TRIGGER IF NOT EXISTS trg_ichimoku_positions_updated
AFTER UPDATE ON ichimoku_positions
FOR EACH ROW
BEGIN
    UPDATE ichimoku_positions SET updated_at = CURRENT_TIMESTAMP
    WHERE position_id = OLD.position_id;
END;

COMMIT;
