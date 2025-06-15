-- DragonShield/docs/schema.sql
-- Dragon Shield Database Creation Script
-- Version 4.4 - Normalized Account Types
-- Created: 2025-05-24
-- Updated: 2025-06-01
--
-- RECENT HISTORY:
-- - v4.3 -> v4.4: Normalized AccountTypes into a separate table. Updated Accounts table and AccountSummary view.
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
DROP TABLE IF EXISTS Accounts;
DROP TABLE IF EXISTS AccountTypes; -- Dropping new table if it exists
DROP TABLE IF EXISTS PortfolioInstruments;
DROP TABLE IF EXISTS Portfolios;
DROP TABLE IF EXISTS Instruments;
DROP TABLE IF EXISTS InstrumentGroups;
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

INSERT INTO Configuration (key, value, data_type, description) VALUES
('base_currency', 'CHF', 'string', 'Base reporting currency'),
('as_of_date', '2025-05-24', 'date', 'Portfolio cut-off date for calculations'),
('decimal_precision', '4', 'number', 'Decimal precision for financial calculations'),
('auto_fx_update', 'true', 'boolean', 'Enable automatic FX rate updates'),
('fx_api_provider', 'exchangerate-api', 'string', 'FX rate API provider'),
('fx_update_frequency', 'daily', 'string', 'FX rate update frequency'),
('default_timezone', 'Europe/Zurich', 'string', 'Default timezone for the application'),
('table_row_spacing', '1.0', 'number', 'Spacing between table rows in points'),
('table_row_padding', '12.0', 'number', 'Vertical padding inside table rows in points'),
('table_font_size', '14.0', 'number', 'Font size for text in data table rows (in points)');

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

INSERT INTO Currencies (currency_code, currency_name, currency_symbol, api_supported) VALUES
('CHF', 'Swiss Franc', 'CHF', 0),
('EUR', 'Euro', '€', 1),
('USD', 'US Dollar', '$', 1),
('GBP', 'British Pound', '£', 1),
('JPY', 'Japanese Yen', '¥', 1),
('CAD', 'Canadian Dollar', 'C$', 1),
('AUD', 'Australian Dollar', 'A$', 1),
('SEK', 'Swedish Krona', 'SEK', 1),
('NOK', 'Norwegian Krone', 'NOK', 1),
('DKK', 'Danish Krone', 'DKK', 1),
('CNY', 'Chinese Yuan', '¥', 1),
('HKD', 'Hong Kong Dollar', 'HK$', 1),
('SGD', 'Singapore Dollar', 'S$', 1),
('BTC', 'Bitcoin', '₿', 1),
('ETH', 'Ethereum', 'Ξ', 1);

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

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES
('CHF', '2025-05-24', 1.0000, 'manual', 1),
('EUR', '2025-05-24', 0.9200, 'api', 1),
('USD', '2025-05-24', 0.8800, 'api', 1),
('GBP', '2025-05-24', 0.7850, 'api', 1),
('JPY', '2025-05-24', 0.0058, 'api', 1),
('BTC', '2025-05-24', 59280.00, 'api', 1),
('ETH', '2025-05-24', 2890.50, 'api', 1);

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

CREATE TABLE InstrumentGroups (
    group_id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_code TEXT NOT NULL UNIQUE,
    group_name TEXT NOT NULL,
    group_description TEXT,
    sort_order INTEGER DEFAULT 0,
    include_in_portfolio BOOLEAN DEFAULT 1,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO InstrumentGroups (group_code, group_name, group_description, sort_order) VALUES
('EQUITY', 'Equities', 'Individual stocks and equity instruments', 1),
('ETF', 'ETFs', 'Exchange-traded funds', 2),
('BOND', 'Bonds', 'Government and corporate bonds', 3),
('FUND', 'Mutual Funds', 'Mutual funds and investment funds', 4),
('CRYPTO', 'Cryptocurrencies', 'Digital assets and cryptocurrencies', 5),
('REIT', 'REITs', 'Real estate investment trusts', 6),
('COMMODITY', 'Commodities', 'Commodity investments and futures', 7),
('STRUCTURED', 'Structured Products', 'Certificates and structured products', 8),
('CASH', 'Cash & Money Market', 'Cash and money market instruments', 9),
('OTHER', 'Other', 'Other investment instruments', 10);

CREATE TABLE Instruments (
    instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
    isin TEXT UNIQUE,
    ticker_symbol TEXT,
    instrument_name TEXT NOT NULL,
    group_id INTEGER NOT NULL,
    currency TEXT NOT NULL,
    country_code TEXT,
    exchange_code TEXT,
    sector TEXT,
    include_in_portfolio BOOLEAN DEFAULT 1,
    is_active BOOLEAN DEFAULT 1,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id) REFERENCES InstrumentGroups(group_id),
    FOREIGN KEY (currency) REFERENCES Currencies(currency_code)
);

INSERT INTO Instruments (isin, ticker_symbol, instrument_name, group_id, currency, country_code, exchange_code, sector) VALUES
('CH0012032048', 'NESN', 'Nestlé SA', 1, 'CHF', 'CH', 'SWX', 'Consumer Staples'),
('CH0244767585', 'NOVN', 'Novartis AG', 1, 'CHF', 'CH', 'SWX', 'Healthcare'),
('CH0010570759', 'ROG', 'Roche Holding AG', 1, 'CHF', 'CH', 'SWX', 'Healthcare'),
('CH0038863350', 'ABB', 'ABB Ltd', 1, 'CHF', 'CH', 'SWX', 'Industrials'),
('US0378331005', 'AAPL', 'Apple Inc.', 1, 'USD', 'US', 'NASDAQ', 'Technology'),
('US5949181045', 'MSFT', 'Microsoft Corporation', 1, 'USD', 'US', 'NASDAQ', 'Technology'),
('US02079K3059', 'GOOGL', 'Alphabet Inc. Class A', 1, 'USD', 'US', 'NASDAQ', 'Technology'),
('US0231351067', 'AMZN', 'Amazon.com Inc.', 1, 'USD', 'US', 'NASDAQ', 'Consumer Discretionary'),
('IE00B4L5Y983', 'IWDA', 'iShares Core MSCI World UCITS ETF', 2, 'USD', 'IE', 'XETRA', NULL),
('IE00B6R52259', 'IEMM', 'iShares Core MSCI Emerging Markets IMI UCITS ETF', 2, 'USD', 'IE', 'XETRA', NULL),
('US9229087690', 'VTI', 'Vanguard Total Stock Market ETF', 2, 'USD', 'US', 'NYSE', NULL),
('CH0224397213', 'CH0224397213', 'Swiss Confederation 0.5% 2031', 3, 'CHF', 'CH', 'SWX', NULL),
(NULL, 'BTC', 'Bitcoin', 5, 'BTC', NULL, NULL, NULL),
(NULL, 'ETH', 'Ethereum', 5, 'ETH', NULL, NULL, NULL),
(NULL, 'CHF_CASH', 'Swiss Franc Cash', 9, 'CHF', 'CH', NULL, NULL),
(NULL, 'USD_CASH', 'US Dollar Cash', 9, 'USD', 'US', NULL, NULL);

CREATE INDEX idx_instruments_isin ON Instruments(isin);
CREATE INDEX idx_instruments_ticker ON Instruments(ticker_symbol);
CREATE INDEX idx_instruments_group ON Instruments(group_id);
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

INSERT INTO Portfolios (portfolio_code, portfolio_name, portfolio_description, is_default, sort_order) VALUES
('MAIN', 'Main Portfolio', 'Primary investment portfolio', 1, 1),
('PENSION', 'Pension Portfolio', '3rd pillar and pension investments', 0, 2),
('TRADING', 'Trading Portfolio', 'Short-term trading and speculation', 0, 3),
('CRYPTO', 'Crypto Portfolio', 'Cryptocurrency investments', 0, 4),
('CASH', 'Cash Management', 'Cash holdings and money market', 0, 5);

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

INSERT INTO PortfolioInstruments (portfolio_id, instrument_id)
SELECT 1, instrument_id FROM Instruments;
INSERT INTO PortfolioInstruments (portfolio_id, instrument_id)
SELECT 4, instrument_id FROM Instruments WHERE group_id = 5;
INSERT INTO PortfolioInstruments (portfolio_id, instrument_id)
SELECT 5, instrument_id FROM Instruments WHERE group_id = 9;

CREATE INDEX idx_portfolio_instruments_portfolio ON PortfolioInstruments(portfolio_id);
CREATE INDEX idx_portfolio_instruments_instrument ON PortfolioInstruments(instrument_id);

--=============================================================================
-- ACCOUNT MANAGEMENT (MODIFIED)
--=============================================================================

-- NEW TABLE: AccountTypes
CREATE TABLE AccountTypes (
    account_type_id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_code TEXT NOT NULL UNIQUE, -- e.g., 'BANK', 'CUSTODY'
    type_name TEXT NOT NULL,        -- e.g., 'Bank Account', 'Custody Account'
    type_description TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Populate AccountTypes
INSERT INTO AccountTypes (account_type_id, type_code, type_name, type_description) VALUES
(1, 'BANK', 'Bank Account', 'Standard bank checking or savings account'),
(2, 'CUSTODY', 'Custody Account', 'Brokerage or custody account for securities'),
(3, 'CRYPTO', 'Crypto Wallet/Account', 'Account for holding cryptocurrencies'),
(4, 'PENSION', 'Pension Account', 'Retirement or pension savings account'),
(5, 'CASH', 'Cash Account', 'Physical cash or simple cash holdings');

-- MODIFIED TABLE: Accounts
CREATE TABLE Accounts (
    account_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_number TEXT UNIQUE,
    account_name TEXT NOT NULL,
    institution_name TEXT NOT NULL,
    institution_bic TEXT,
    account_type_id INTEGER NOT NULL, -- MODIFIED: Replaces account_type text
    currency_code TEXT NOT NULL,
    is_active BOOLEAN DEFAULT 1,
    include_in_portfolio BOOLEAN DEFAULT 1,
    opening_date DATE,
    closing_date DATE,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_type_id) REFERENCES AccountTypes(account_type_id), -- NEW FK
    FOREIGN KEY (currency_code) REFERENCES Currencies(currency_code)
);

-- Sample accounts (updated for account_type_id)
INSERT INTO Accounts (account_number, account_name, institution_name, institution_bic, account_type_id, currency_code, opening_date, is_active, include_in_portfolio, notes) VALUES
('CH12-3456-7890-1234-5', 'UBS Custody Account', 'UBS Switzerland AG', 'UBSWCHZH80A', 2, 'CHF', '2024-01-15', 1, 1, 'Main custody account for Swiss equities.'),
('CH98-7654-3210-9876-5', 'Credit Suisse Private Banking', 'Credit Suisse (Schweiz) AG', 'CRESCHZZ80A', 1, 'CHF', '2023-06-10', 1, 1, NULL),
('US-IBKR-987654321', 'Interactive Brokers Account', 'Interactive Brokers LLC', NULL, 2, 'USD', '2024-03-01', 1, 1, 'For US stocks and ETFs.'),
('COINBASE-PRO-001', 'Coinbase Pro Account', 'Coinbase', NULL, 3, 'USD', '2024-02-15', 1, 0, 'Trading account, not part of main portfolio value.'),
('LEDGER-WALLET-001', 'Ledger Hardware Wallet', 'Self-Custody', NULL, 3, 'BTC', '2024-01-01', 1, 1, NULL),
('VIAC-3A-12345', 'VIAC 3a Account', 'VIAC', NULL, 4, 'CHF', '2023-01-01', 0, 1, 'Old pension, currently inactive.');

INSERT INTO Accounts (account_number, account_name, institution_name, institution_bic, account_type_id, currency_code, opening_date, closing_date, is_active, include_in_portfolio, notes) VALUES
('OLD-BANK-007', 'Old Savings Account', 'Regional Bank XY', NULL, 1, 'CHF', '2010-01-01', '2023-12-31', 0, 0, 'Account closed end of last year.');

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

INSERT INTO TransactionTypes (type_code, type_name, type_description, affects_position, affects_cash, is_income, sort_order) VALUES
('BUY', 'Purchase', 'Buy securities or assets', 1, 1, 0, 1),
('SELL', 'Sale', 'Sell securities or assets', 1, 1, 0, 2),
('DIVIDEND', 'Dividend', 'Dividend payment received', 0, 1, 1, 3),
('INTEREST', 'Interest', 'Interest payment received', 0, 1, 1, 4),
('FEE', 'Fee', 'Transaction or management fee', 0, 1, 0, 5),
('TAX', 'Tax', 'Withholding tax or other taxes', 0, 1, 0, 6),
('DEPOSIT', 'Cash Deposit', 'Cash deposit to account', 0, 1, 0, 7),
('WITHDRAWAL', 'Cash Withdrawal', 'Cash withdrawal from account', 0, 1, 0, 8),
('TRANSFER_IN', 'Transfer In', 'Securities transferred into account', 1, 0, 0, 9),
('TRANSFER_OUT', 'Transfer Out', 'Securities transferred out of account', 1, 0, 0, 10);

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

INSERT INTO Transactions (account_id, instrument_id, transaction_type_id, portfolio_id, transaction_date, quantity, price, gross_amount, fee, net_amount, transaction_currency, description) VALUES
(1, 1, 1, 1, '2024-01-20', 10, 108.50, 1085.00, 9.95, -1094.95, 'CHF', 'Buy 10 Nestlé shares'),
(1, 2, 1, 1, '2024-01-25', 15, 95.20, 1428.00, 9.95, -1437.95, 'CHF', 'Buy 15 Novartis shares'),
(3, 5, 1, 1, '2024-02-01', 5, 185.25, 926.25, 1.00, -927.25, 'USD', 'Buy 5 Apple shares'),
(3, 6, 1, 1, '2024-02-05', 3, 415.75, 1247.25, 1.00, -1248.25, 'USD', 'Buy 3 Microsoft shares'),
(3, 9, 1, 1, '2024-02-10', 50, 87.45, 4372.50, 1.00, -4373.50, 'USD', 'Buy 50 IWDA ETF shares'),
(4, 13, 1, 4, '2024-02-15', 0.1, 45000, 4500, 25.00, -4525.00, 'USD', 'Buy 0.1 Bitcoin'),
(4, 14, 1, 4, '2024-03-01', 2, 2800, 5600, 20.00, -5620.00, 'USD', 'Buy 2 Ethereum'),
(1, 1, 3, 1, '2024-03-15', 0, 0, 27.50, 0, 27.50, 'CHF', 'Nestlé dividend payment'),
(1, 2, 3, 1, '2024-04-10', 0, 0, 42.75, 0, 42.75, 'CHF', 'Novartis dividend payment'),
(1, NULL, 7, NULL, '2024-01-15', 0, 0, 50000, 0, 50000, 'CHF', 'Initial cash deposit'),
(3, NULL, 7, NULL, '2024-01-30', 0, 0, 25000, 0, 25000, 'USD', 'Cash transfer to USD account'),
(1, NULL, 5, NULL, '2024-12-31', 0, 0, 120, 0, -120, 'CHF', 'Annual custody fee');

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
    file_hash TEXT UNIQUE,
    account_id INTEGER,
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
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id)
);

CREATE TABLE PositionReports (
    position_id INTEGER PRIMARY KEY AUTOINCREMENT,
    import_session_id INTEGER,
    account_id INTEGER NOT NULL,
    instrument_id INTEGER NOT NULL,
    quantity REAL NOT NULL,
    report_date DATE NOT NULL,
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (import_session_id) REFERENCES ImportSessions(import_session_id),
    FOREIGN KEY (account_id) REFERENCES Accounts(account_id),
    FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id)
);

-- Sample import sessions for testing
INSERT INTO ImportSessions (
    import_session_id,
    session_name,
    file_name,
    file_path,
    file_type,
    file_size,
    file_hash,
    account_id,
    import_status,
    total_rows,
    successful_rows,
    failed_rows,
    duplicate_rows,
    processing_notes,
    started_at,
    completed_at
) VALUES
    (1, 'UBS Positions 2024-12-31', 'UBS_Positions_2024-12-31.csv',
        '/uploads/UBS_Positions_2024-12-31.csv', 'CSV', 2048, 'HASH001', 1,
        'COMPLETED', 2, 2, 0, 0, 'Initial import',
        '2025-01-01 08:00:00', '2025-01-01 08:00:10'),
    (2, 'UBS Positions 2025-03-26', 'UBS_Positions_2025-03-26.csv',
        '/uploads/UBS_Positions_2025-03-26.csv', 'CSV', 2050, 'HASH002', 1,
        'COMPLETED', 2, 2, 0, 0, 'Monthly import',
        '2025-03-27 08:00:00', '2025-03-27 08:00:10'),
    (3, 'UBS Positions 2025-05-24', 'UBS_Positions_2025-05-24.csv',
        '/uploads/UBS_Positions_2025-05-24.csv', 'CSV', 2055, 'HASH003', 1,
        'COMPLETED', 2, 2, 0, 0, 'Monthly import',
        '2025-05-25 08:00:00', '2025-05-25 08:00:10'),
    (4, 'IBKR Positions 2024-12-31', 'IBKR_Positions_2024-12-31.csv',
        '/uploads/IBKR_Positions_2024-12-31.csv', 'CSV', 3150, 'HASH004', 3,
        'COMPLETED', 3, 3, 0, 0, 'Initial import',
        '2025-01-02 09:00:00', '2025-01-02 09:00:15'),
    (5, 'IBKR Positions 2025-03-26', 'IBKR_Positions_2025-03-26.csv',
        '/uploads/IBKR_Positions_2025-03-26.csv', 'CSV', 3200, 'HASH005', 3,
        'COMPLETED', 3, 3, 0, 0, 'Monthly import',
        '2025-03-27 09:00:00', '2025-03-27 09:00:15'),
    (6, 'IBKR Positions 2025-05-24', 'IBKR_Positions_2025-05-24.csv',
        '/uploads/IBKR_Positions_2025-05-24.csv', 'CSV', 3250, 'HASH006', 3,
        'COMPLETED', 3, 3, 0, 0, 'Monthly import',
        '2025-05-25 09:00:00', '2025-05-25 09:00:15'),
    (7, 'Coinbase Positions 2024-12-31', 'Coinbase_Positions_2024-12-31.csv',
        '/uploads/Coinbase_Positions_2024-12-31.csv', 'CSV', 1024, 'HASH007', 4,
        'COMPLETED', 2, 2, 0, 0, 'Initial import',
        '2025-01-02 10:00:00', '2025-01-02 10:00:10'),
    (8, 'Coinbase Positions 2025-03-26', 'Coinbase_Positions_2025-03-26.csv',
        '/uploads/Coinbase_Positions_2025-03-26.csv', 'CSV', 1030, 'HASH008', 4,
        'COMPLETED', 2, 2, 0, 0, 'Monthly import',
        '2025-03-27 10:00:00', '2025-03-27 10:00:10'),
    (9, 'Coinbase Positions 2025-05-24', 'Coinbase_Positions_2025-05-24.csv',
        '/uploads/Coinbase_Positions_2025-05-24.csv', 'CSV', 1040, 'HASH009', 4,
        'COMPLETED', 2, 2, 0, 0, 'Monthly import',
        '2025-05-25 10:00:00', '2025-05-25 10:00:10'),
    (10, 'UBS Positions 2025-06-30', 'UBS_Positions_2025-06-30.csv',
        '/uploads/UBS_Positions_2025-06-30.csv', 'CSV', 2060, 'HASH010', 1,
        'COMPLETED', 2, 2, 0, 0, 'Quarter end',
        '2025-07-01 08:00:00', '2025-07-01 08:00:10');

-- Sample position reports for each session
INSERT INTO PositionReports (
    import_session_id,
    account_id,
    instrument_id,
    quantity,
    report_date,
    uploaded_at
) VALUES
    (1, 1, 1, 8, '2024-12-31', '2025-01-01 08:00:10'),
    (1, 1, 2, 12, '2024-12-31', '2025-01-01 08:00:10'),
    (2, 1, 1, 9, '2025-03-26', '2025-03-27 08:00:10'),
    (2, 1, 2, 14, '2025-03-26', '2025-03-27 08:00:10'),
    (3, 1, 1, 10, '2025-05-24', '2025-05-25 08:00:10'),
    (3, 1, 2, 15, '2025-05-24', '2025-05-25 08:00:10'),
    (4, 3, 5, 4, '2024-12-31', '2025-01-02 09:00:15'),
    (4, 3, 6, 2, '2024-12-31', '2025-01-02 09:00:15'),
    (4, 3, 9, 40, '2024-12-31', '2025-01-02 09:00:15'),
    (5, 3, 5, 5, '2025-03-26', '2025-03-27 09:00:15'),
    (5, 3, 6, 3, '2025-03-26', '2025-03-27 09:00:15'),
    (5, 3, 9, 45, '2025-03-26', '2025-03-27 09:00:15'),
    (6, 3, 5, 5, '2025-05-24', '2025-05-25 09:00:15'),
    (6, 3, 6, 3, '2025-05-24', '2025-05-25 09:00:15'),
    (6, 3, 9, 50, '2025-05-24', '2025-05-25 09:00:15'),
    (7, 4, 13, 0.05, '2024-12-31', '2025-01-02 10:00:10'),
    (7, 4, 14, 1.0, '2024-12-31', '2025-01-02 10:00:10'),
    (8, 4, 13, 0.08, '2025-03-26', '2025-03-27 10:00:10'),
    (8, 4, 14, 1.5, '2025-03-26', '2025-03-27 10:00:10'),
    (9, 4, 13, 0.1, '2025-05-24', '2025-05-25 10:00:10'),
    (9, 4, 14, 2.0, '2025-05-24', '2025-05-25 10:00:10'),
    (10, 1, 1, 10, '2025-06-30', '2025-07-01 08:00:10'),
    (10, 1, 2, 15, '2025-06-30', '2025-07-01 08:00:10');
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
    ig.group_name as instrument_group,
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
JOIN InstrumentGroups ig ON i.group_id = ig.group_id
JOIN Accounts a ON t.account_id = a.account_id
JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
LEFT JOIN PortfolioInstruments pi ON i.instrument_id = pi.instrument_id
LEFT JOIN Portfolios p ON pi.portfolio_id = p.portfolio_id
WHERE t.transaction_date <= (SELECT value FROM Configuration WHERE key = 'as_of_date')
  AND i.include_in_portfolio = 1
  AND ig.include_in_portfolio = 1
  AND a.include_in_portfolio = 1
  AND i.is_active = 1
  AND (p.include_in_total = 1 OR p.include_in_total IS NULL)
GROUP BY p.portfolio_id, i.instrument_id, a.account_id
HAVING total_quantity > 0;

CREATE VIEW PortfolioSummary AS
SELECT
    COALESCE(p.portfolio_name, 'Unassigned') as portfolio_name,
    p.instrument_group,
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
GROUP BY p.portfolio_name, p.instrument_group
ORDER BY p.portfolio_name, p.instrument_group;

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
    ig.group_name,
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
JOIN InstrumentGroups ig ON i.group_id = ig.group_id
LEFT JOIN Transactions t ON i.instrument_id = t.instrument_id
    AND t.transaction_date <= (SELECT value FROM Configuration WHERE key = 'as_of_date')
LEFT JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
GROUP BY i.instrument_id, i.instrument_name, i.ticker_symbol, i.isin, ig.group_name, i.currency, i.include_in_portfolio, i.is_active
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