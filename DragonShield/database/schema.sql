-- DragonShield/docs/schema.sql
-- Dragon Shield Database Creation Script
-- Version 4.16 - Add TargetAllocation table
-- Created: 2025-05-24
-- Updated: 2025-07-13
--
-- RECENT HISTORY:
-- - v4.7 -> v4.8: Added Institutions table and linked Accounts to it.
-- - v4.6 -> v4.7: Added db_version configuration row in seed data.
-- - v4.5 -> v4.6: Extracted seed data into schema.txt for easier migrations.
-- - v4.6 -> v4.7: Added db_version configuration entry.
-- - v4.4 -> v4.5: Added PositionReports table, renamed CurrentHoldings view to
--   Positions, updated PortfolioSummary and AccountSummary views.
-- - v4.3 -> v4.4: Normalized AccountTypes into a separate table. Updated Accounts table and AccountSummary view.
-- - v4.8 -> v4.9: Introduced AssetClasses and AssetSubClasses tables.
-- - v4.10 -> v4.11: Expanded Institutions with contact info and currency fields.
-- - v4.11 -> v4.12: Added notes column to PositionReports table.
-- - (Previous history for v4.3 and earlier...)
--

PRAGMA foreign_keys = OFF;

DROP VIEW IF EXISTS DataIntegrityCheck;
DROP VIEW IF EXISTS InstrumentPerformance;
DROP VIEW IF EXISTS LatestExchangeRates;
DROP VIEW IF EXISTS AccountSummary;
DROP VIEW IF EXISTS PortfolioSummary;
DROP VIEW IF EXISTS Positions;

DROP TABLE IF EXISTS PositionReports;
DROP TABLE IF EXISTS ImportSessions;
DROP TABLE IF EXISTS Transactions;
DROP TABLE IF EXISTS TransactionTypes;
DROP TABLE IF EXISTS Institutions;
DROP TABLE IF EXISTS Accounts;
DROP TABLE IF EXISTS AccountTypes; -- Dropping new table if it exists
DROP TABLE IF EXISTS PortfolioInstruments;
DROP TABLE IF EXISTS Portfolios;
DROP TABLE IF EXISTS Instruments;
DROP TABLE IF EXISTS AssetSubClasses;
DROP TABLE IF EXISTS AssetClasses;
DROP TABLE IF EXISTS FxRateUpdates;
DROP TABLE IF EXISTS ExchangeRates;
DROP TABLE IF EXISTS Currencies;
DROP TABLE IF EXISTS Configuration;

PRAGMA foreign_keys = ON;

--=============================================================================
-- CONFIGURATION AND STATIC DATA TABLES
--=============================================================================

CREATE TABLE Configuration (
    config_id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    data_type TEXT NOT NULL CHECK (data_type IN ('string', 'number', 'boolean', 'date')),
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


--=============================================================================
-- CURRENCY AND EXCHANGE RATE MANAGEMENT
--=============================================================================

CREATE TABLE Currencies (
    currency_code TEXT PRIMARY KEY,
    currency_name TEXT NOT NULL,
    currency_symbol TEXT,
    is_active BOOLEAN DEFAULT 1,
    api_supported BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE ExchangeRates (
    rate_id INTEGER PRIMARY KEY AUTOINCREMENT,
    currency_code TEXT NOT NULL,
    rate_date DATE NOT NULL,
    rate_to_chf REAL NOT NULL CHECK (rate_to_chf > 0),
    rate_source TEXT DEFAULT 'manual' CHECK (rate_source IN ('manual', 'api', 'import')),
    api_provider TEXT,
    is_latest BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (currency_code) REFERENCES Currencies(currency_code),
    UNIQUE(currency_code, rate_date)
);


CREATE TABLE FxRateUpdates (
    update_id INTEGER PRIMARY KEY AUTOINCREMENT,
    update_date DATE NOT NULL,
    api_provider TEXT NOT NULL,
    currencies_updated TEXT,
    status TEXT CHECK (status IN ('SUCCESS', 'PARTIAL', 'FAILED')),
    error_message TEXT,
    rates_count INTEGER DEFAULT 0,
    execution_time_ms INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_exchange_rates_date ON ExchangeRates(rate_date);
CREATE INDEX idx_exchange_rates_currency ON ExchangeRates(currency_code);
CREATE INDEX idx_exchange_rates_latest ON ExchangeRates(currency_code, is_latest) WHERE is_latest = 1;

--=============================================================================
-- ASSET MANAGEMENT
--=============================================================================


CREATE TABLE AssetClasses (
    class_id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_code TEXT NOT NULL UNIQUE,
    class_name TEXT NOT NULL,
    class_description TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE AssetSubClasses (
    sub_class_id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_id INTEGER NOT NULL,
    sub_class_code TEXT NOT NULL UNIQUE,
    sub_class_name TEXT NOT NULL,
    sub_class_description TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES AssetClasses(class_id)
);


CREATE TABLE Instruments (
    instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
    isin TEXT UNIQUE,
    valor_nr TEXT UNIQUE,
    ticker_symbol TEXT,
    instrument_name TEXT NOT NULL,
    sub_class_id INTEGER NOT NULL,
    currency TEXT NOT NULL,
    country_code TEXT,
    exchange_code TEXT,
    sector TEXT,
    include_in_portfolio BOOLEAN DEFAULT 1,
    is_active BOOLEAN DEFAULT 1,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sub_class_id) REFERENCES AssetSubClasses(sub_class_id),
    FOREIGN KEY (currency) REFERENCES Currencies(currency_code)
);


CREATE INDEX idx_instruments_isin ON Instruments(isin);
CREATE INDEX idx_instruments_ticker ON Instruments(ticker_symbol);
CREATE INDEX idx_instruments_sub_class ON Instruments(sub_class_id);
CREATE INDEX idx_instruments_currency ON Instruments(currency);

--=============================================================================
-- PORTFOLIO MANAGEMENT
--=============================================================================

CREATE TABLE Portfolios (
    portfolio_id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_code TEXT NOT NULL UNIQUE,
    portfolio_name TEXT NOT NULL,
    portfolio_description TEXT,
    is_default BOOLEAN DEFAULT 0,
    include_in_total BOOLEAN DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE PortfolioInstruments (
    portfolio_id INTEGER NOT NULL,
    instrument_id INTEGER NOT NULL,
    assigned_date DATE DEFAULT CURRENT_DATE,
    target_allocation_percent REAL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (portfolio_id, instrument_id),
    FOREIGN KEY (portfolio_id) REFERENCES Portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id) ON DELETE CASCADE
);

CREATE INDEX idx_portfolio_instruments_instrument ON PortfolioInstruments(instrument_id);
CREATE TABLE TargetAllocation (
    allocation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_class_id INTEGER NOT NULL,
    sub_class_id INTEGER,
    target_percent REAL,
    target_amount_chf REAL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(asset_class_id, sub_class_id),
    FOREIGN KEY (asset_class_id) REFERENCES AssetClasses(class_id),
    FOREIGN KEY (sub_class_id) REFERENCES AssetSubClasses(sub_class_id)
);

--=============================================================================
-- ACCOUNT MANAGEMENT (MODIFIED)
--=============================================================================

-- NEW TABLE: AccountTypes
CREATE TABLE AccountTypes (
    account_type_id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_code TEXT NOT NULL UNIQUE, -- e.g., 'BANK', 'CUSTODY'
    type_name TEXT NOT NULL,        -- e.g., 'Bank Account', 'Account'
    type_description TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Populate AccountTypes

-- NEW TABLE: Institutions
CREATE TABLE Institutions (
    institution_id INTEGER PRIMARY KEY AUTOINCREMENT,
    institution_name TEXT NOT NULL,
    institution_type TEXT,
    bic TEXT,
    website TEXT,
    contact_info TEXT,
    default_currency TEXT CHECK (LENGTH(default_currency) = 3),
    country_code TEXT CHECK (LENGTH(country_code) = 2),
    notes TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- MODIFIED TABLE: Accounts
CREATE TABLE Accounts (
    account_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_number TEXT UNIQUE,
    account_name TEXT NOT NULL,
    institution_id INTEGER NOT NULL,
    account_type_id INTEGER NOT NULL,
    currency_code TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    include_in_portfolio BOOLEAN DEFAULT 1,
    opening_date DATE,
    closing_date DATE,
    earliest_instrument_last_updated_at DATE,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (institution_id) REFERENCES Institutions(institution_id),
    FOREIGN KEY (account_type_id) REFERENCES AccountTypes(account_type_id),
    FOREIGN KEY (currency_code) REFERENCES Currencies(currency_code)
);

-- Sample accounts (updated for account_type_id)


--=============================================================================
-- TRANSACTION MANAGEMENT
--=============================================================================

CREATE TABLE TransactionTypes (
    transaction_type_id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_code TEXT NOT NULL UNIQUE,
    type_name TEXT NOT NULL,
    type_description TEXT,
    affects_position BOOLEAN DEFAULT 1,
    affects_cash BOOLEAN DEFAULT 1,
    is_income BOOLEAN DEFAULT 0,
    sort_order INTEGER DEFAULT 0
);


CREATE TABLE Transactions (
    transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    instrument_id INTEGER,
    transaction_type_id INTEGER NOT NULL,
    portfolio_id INTEGER,
    transaction_date DATE NOT NULL,
    value_date DATE,
    booking_date DATE,
    quantity REAL DEFAULT 0,
    price REAL DEFAULT 0,
    gross_amount REAL DEFAULT 0,
    fee REAL DEFAULT 0,
    tax REAL DEFAULT 0,
    net_amount REAL NOT NULL,
    transaction_currency TEXT NOT NULL,
    exchange_rate_to_chf REAL DEFAULT 1.0,
    amount_chf REAL,
    import_source TEXT DEFAULT 'manual' CHECK (import_source IN ('manual', 'csv', 'xlsx', 'pdf', 'api')),
    import_session_id INTEGER,
    external_reference TEXT,
    order_reference TEXT,
    description TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id),
    FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id),
    FOREIGN KEY (transaction_type_id) REFERENCES TransactionTypes(transaction_type_id),
    FOREIGN KEY (portfolio_id) REFERENCES Portfolios(portfolio_id),
    FOREIGN KEY (transaction_currency) REFERENCES Currencies(currency_code)
);


CREATE INDEX idx_transactions_date ON Transactions(transaction_date);
CREATE INDEX idx_transactions_account ON Transactions(account_id);
CREATE INDEX idx_transactions_instrument ON Transactions(instrument_id);
CREATE INDEX idx_transactions_portfolio ON Transactions(portfolio_id);
CREATE INDEX idx_transactions_type ON Transactions(transaction_type_id);
CREATE INDEX idx_transactions_currency ON Transactions(transaction_currency);

--=============================================================================
-- IMPORT MANAGEMENT
--=============================================================================

CREATE TABLE ImportSessions (
    import_session_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_name TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_path TEXT,
    file_type TEXT NOT NULL CHECK (file_type IN ('CSV', 'XLSX', 'PDF')),
    file_size INTEGER,
    file_hash TEXT,
    institution_id INTEGER,
    import_status TEXT DEFAULT 'PENDING' CHECK (import_status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    total_rows INTEGER DEFAULT 0,
    successful_rows INTEGER DEFAULT 0,
    failed_rows INTEGER DEFAULT 0,
    duplicate_rows INTEGER DEFAULT 0,
    error_log TEXT,
    processing_notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    started_at DATETIME,
    completed_at DATETIME,
    FOREIGN KEY (institution_id) REFERENCES Institutions(institution_id)
);

CREATE TABLE PositionReports (
    position_id INTEGER PRIMARY KEY AUTOINCREMENT,
    import_session_id INTEGER,
    account_id INTEGER NOT NULL,
    institution_id INTEGER NOT NULL,
    instrument_id INTEGER NOT NULL,
    quantity REAL NOT NULL,
    purchase_price REAL,
    current_price REAL,
    instrument_updated_at DATE,
    notes TEXT,
    report_date DATE NOT NULL,
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (import_session_id) REFERENCES ImportSessions(import_session_id),
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id),
    FOREIGN KEY (institution_id) REFERENCES Institutions(institution_id),
    FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id)
);

-- Sample import sessions for testing

-- Sample position reports for each session
--=============================================================================
-- TRIGGERS FOR AUTOMATIC CALCULATIONS
--=============================================================================

CREATE TRIGGER tr_calculate_chf_amount
AFTER INSERT ON Transactions
WHEN NEW.amount_chf IS NULL
BEGIN
    UPDATE Transactions
    SET
        amount_chf = NEW.net_amount * COALESCE(
            (SELECT rate_to_chf FROM ExchangeRates
             WHERE currency_code = NEW.transaction_currency
             AND rate_date <= NEW.transaction_date
             ORDER BY rate_date DESC LIMIT 1), 1.0
        ),
        exchange_rate_to_chf = COALESCE(
            (SELECT rate_to_chf FROM ExchangeRates
             WHERE currency_code = NEW.transaction_currency
             AND rate_date <= NEW.transaction_date
             ORDER BY rate_date DESC LIMIT 1), 1.0
        )
    WHERE transaction_id = NEW.transaction_id;
END;

CREATE TRIGGER tr_config_updated_at
AFTER UPDATE ON Configuration
BEGIN
    UPDATE Configuration
    SET updated_at = CURRENT_TIMESTAMP
    WHERE config_id = NEW.config_id;
END;

CREATE TRIGGER tr_instruments_updated_at
AFTER UPDATE ON Instruments
BEGIN
    UPDATE Instruments
    SET updated_at = CURRENT_TIMESTAMP
    WHERE instrument_id = NEW.instrument_id;
END;

--=============================================================================
-- PORTFOLIO CALCULATION VIEWS (AccountSummary MODIFIED)
--=============================================================================

CREATE VIEW Positions AS
SELECT
    p.portfolio_id,
    p.portfolio_name,
    i.instrument_id,
    i.instrument_name,
    i.isin,
    i.ticker_symbol,
    ac.class_name as asset_class,
    asc.sub_class_name as asset_sub_class,
    a.account_id,
    a.account_name,
    i.currency as instrument_currency,
    SUM(CASE
        WHEN tt.type_code = 'BUY' OR tt.type_code = 'TRANSFER_IN' THEN t.quantity
        WHEN tt.type_code = 'SELL' OR tt.type_code = 'TRANSFER_OUT' THEN -t.quantity
        ELSE 0
    END) as total_quantity,
    CASE
        WHEN SUM(CASE WHEN tt.type_code = 'BUY' THEN t.quantity ELSE 0 END) > 0
        THEN SUM(CASE WHEN tt.type_code = 'BUY' THEN ABS(t.amount_chf) ELSE 0 END) /
             SUM(CASE WHEN tt.type_code = 'BUY' THEN t.quantity ELSE 0 END)
        ELSE 0
    END as avg_cost_chf_per_unit,
    SUM(CASE WHEN tt.type_code = 'BUY' THEN ABS(t.amount_chf) ELSE 0 END) as total_invested_chf,
    SUM(CASE WHEN tt.type_code = 'SELL' THEN t.amount_chf ELSE 0 END) as total_sold_chf,
    SUM(CASE WHEN tt.type_code = 'DIVIDEND' THEN t.amount_chf ELSE 0 END) as total_dividends_chf,
    SUM(CASE WHEN tt.type_code = 'FEE' THEN t.amount_chf ELSE 0 END) as total_fees_chf,
    COUNT(t.transaction_id) as transaction_count,
    MIN(t.transaction_date) as first_transaction_date,
    MAX(t.transaction_date) as last_transaction_date
FROM Transactions t
JOIN Instruments i ON t.instrument_id = i.instrument_id
JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
JOIN AssetClasses ac ON asc.class_id = ac.class_id
JOIN Accounts a ON t.account_id = a.account_id
JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
LEFT JOIN PortfolioInstruments pi ON i.instrument_id = pi.instrument_id
LEFT JOIN Portfolios p ON pi.portfolio_id = p.portfolio_id
WHERE t.transaction_date <= (SELECT value FROM Configuration WHERE key = 'as_of_date')
  AND i.include_in_portfolio = 1
  AND a.include_in_portfolio = 1
  AND i.is_active = 1
  AND (p.include_in_total = 1 OR p.include_in_total IS NULL)
  AND asc.sub_class_code != 'CASH'
GROUP BY p.portfolio_id, i.instrument_id, a.account_id
HAVING total_quantity > 0;

CREATE VIEW PortfolioSummary AS
SELECT
    COALESCE(p.portfolio_name, 'Unassigned') as portfolio_name,
    p.asset_class,
    COUNT(DISTINCT p.instrument_id) as instrument_count,
    SUM(p.transaction_count) as total_transactions,
    SUM(p.total_quantity * p.avg_cost_chf_per_unit) as current_market_value_chf,
    SUM(p.total_invested_chf) as total_invested_chf,
    SUM(p.total_sold_chf) as total_sold_chf,
    SUM(p.total_dividends_chf) as total_dividends_chf,
    SUM(p.total_fees_chf) as total_fees_chf,
    ROUND(
        (SUM(p.total_quantity * p.avg_cost_chf_per_unit) - SUM(p.total_invested_chf) + SUM(p.total_sold_chf)) /
        NULLIF(SUM(p.total_invested_chf), 0) * 100, 2
    ) as unrealized_return_percent,
    ROUND(
        SUM(p.total_dividends_chf) / NULLIF(SUM(p.total_invested_chf), 0) * 100, 2
    ) as dividend_yield_percent
FROM Positions p
WHERE p.asset_sub_class != 'Cash'
GROUP BY p.portfolio_name, p.asset_class
ORDER BY p.portfolio_name, p.asset_class;

-- MODIFIED VIEW: AccountSummary
CREATE VIEW AccountSummary AS
SELECT
    a.account_id,
    a.account_name,
    a.institution_name,
    act.type_name as account_type, -- MODIFIED: Get type_name from AccountTypes
    a.currency_code as account_currency, -- RENAMED for clarity from original schema's 'currency'
    COUNT(DISTINCT t.instrument_id) as instruments_count,
    COUNT(t.transaction_id) as transactions_count,
    SUM(CASE WHEN tt.type_code IN ('DEPOSIT', 'DIVIDEND', 'INTEREST') THEN t.amount_chf ELSE 0 END) as total_inflows_chf,
    SUM(CASE WHEN tt.type_code IN ('WITHDRAWAL', 'FEE', 'TAX') THEN ABS(t.amount_chf) ELSE 0 END) as total_outflows_chf,
    SUM(CASE WHEN tt.type_code = 'BUY' THEN ABS(t.amount_chf) ELSE 0 END) as total_purchases_chf,
    SUM(CASE WHEN tt.type_code = 'SELL' THEN t.amount_chf ELSE 0 END) as total_sales_chf,
    MIN(t.transaction_date) as first_transaction_date,
    MAX(t.transaction_date) as last_transaction_date
FROM Accounts a
JOIN AccountTypes act ON a.account_type_id = act.account_type_id -- NEW JOIN
LEFT JOIN Transactions t ON a.account_id = t.account_id
LEFT JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
WHERE a.is_active = 1
  AND (t.transaction_date IS NULL OR t.transaction_date <= (SELECT value FROM Configuration WHERE key = 'as_of_date'))
GROUP BY a.account_id, a.account_name, a.institution_name, act.type_name, a.currency_code
ORDER BY a.account_name;

CREATE VIEW LatestExchangeRates AS
SELECT
    c.currency_code,
    c.currency_name,
    c.currency_symbol,
    COALESCE(er.rate_to_chf, 1.0) as current_rate_to_chf,
    COALESCE(er.rate_date, CURRENT_DATE) as rate_date,
    COALESCE(er.rate_source, 'manual') as rate_source
FROM Currencies c
LEFT JOIN ExchangeRates er ON c.currency_code = er.currency_code
    AND er.rate_date = (
        SELECT MAX(rate_date)
        FROM ExchangeRates er2
        WHERE er2.currency_code = c.currency_code
    )
WHERE c.is_active = 1
ORDER BY c.currency_code;

CREATE VIEW InstrumentPerformance AS
SELECT
    i.instrument_id,
    i.instrument_name,
    i.ticker_symbol,
    i.isin,
    ac.class_name,
    i.currency,
    COALESCE(SUM(CASE
        WHEN tt.type_code = 'BUY' OR tt.type_code = 'TRANSFER_IN' THEN t.quantity
        WHEN tt.type_code = 'SELL' OR tt.type_code = 'TRANSFER_OUT' THEN -t.quantity
        ELSE 0
    END), 0) as current_quantity,
    CASE
        WHEN SUM(CASE WHEN tt.type_code = 'BUY' THEN t.quantity ELSE 0 END) > 0
        THEN SUM(CASE WHEN tt.type_code = 'BUY' THEN ABS(t.amount_chf) ELSE 0 END) /
             SUM(CASE WHEN tt.type_code = 'BUY' THEN t.quantity ELSE 0 END)
        ELSE 0
    END as avg_cost_basis_chf,
    COALESCE(SUM(CASE WHEN tt.type_code = 'BUY' THEN ABS(t.amount_chf) ELSE 0 END), 0) as total_invested_chf,
    COALESCE(SUM(CASE WHEN tt.type_code = 'SELL' THEN t.amount_chf ELSE 0 END), 0) as total_sold_chf,
    COALESCE(SUM(CASE WHEN tt.type_code = 'DIVIDEND' THEN t.amount_chf ELSE 0 END), 0) as total_dividends_chf,
    COUNT(CASE WHEN t.transaction_id IS NOT NULL THEN 1 END) as transaction_count,
    MIN(t.transaction_date) as first_purchase_date,
    MAX(t.transaction_date) as last_transaction_date,
    i.include_in_portfolio,
    i.is_active
FROM Instruments i
JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
JOIN AssetClasses ac ON asc.class_id = ac.class_id
LEFT JOIN Transactions t ON i.instrument_id = t.instrument_id
    AND t.transaction_date <= (SELECT value FROM Configuration WHERE key = 'as_of_date')
LEFT JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
GROUP BY i.instrument_id, i.instrument_name, i.ticker_symbol, i.isin, ac.class_name, i.currency, i.include_in_portfolio, i.is_active
ORDER BY i.instrument_name;

CREATE VIEW DataIntegrityCheck AS
SELECT
    'Missing FX Rates' as issue_type,
    'Currency: ' || t.transaction_currency || ', Date: ' || t.transaction_date as issue_description,
    COUNT(*) as occurrence_count
FROM Transactions t
LEFT JOIN ExchangeRates er ON t.transaction_currency = er.currency_code
    AND er.rate_date <= t.transaction_date
WHERE er.rate_id IS NULL
  AND t.transaction_currency != 'CHF'
GROUP BY t.transaction_currency, t.transaction_date
UNION ALL
SELECT
    'Instruments without Portfolio Assignment' as issue_type,
    'Instrument: ' || i.instrument_name as issue_description,
    1 as occurrence_count
FROM Instruments i
LEFT JOIN PortfolioInstruments pi ON i.instrument_id = pi.instrument_id
WHERE pi.portfolio_id IS NULL
  AND i.is_active = 1
UNION ALL
SELECT
    'Transactions without CHF Amount' as issue_type,
    'Transaction ID: ' || t.transaction_id as issue_description,
    1 as occurrence_count
FROM Transactions t
WHERE t.amount_chf IS NULL OR t.amount_chf = 0
UNION ALL
SELECT
    'Negative Positions' as issue_type,
    'Instrument: ' || i.instrument_name || ', Quantity: ' || SUM(CASE
        WHEN tt.type_code = 'BUY' THEN t.quantity
        WHEN tt.type_code = 'SELL' THEN -t.quantity
        ELSE 0
    END) as issue_description,
    1 as occurrence_count
FROM Transactions t
JOIN Instruments i ON t.instrument_id = i.instrument_id
JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
GROUP BY i.instrument_id, i.instrument_name
HAVING SUM(CASE
           WHEN tt.type_code = 'BUY' THEN t.quantity
           WHEN tt.type_code = 'SELL' THEN -t.quantity
           ELSE 0
       END) < 0;

--=============================================================================
-- FINAL DATABASE SETUP AND OPTIMIZATION
--=============================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
ANALYZE;

--=============================================================================
-- DATABASE CREATION COMPLETED SUCCESSFULLY
--=============================================================================