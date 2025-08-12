-- migrate:up

CREATE TABLE Configuration (
    config_id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    data_type TEXT NOT NULL CHECK (data_type IN ('string','number','boolean','date')),
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

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
    rate_source TEXT DEFAULT 'manual' CHECK (rate_source IN ('manual','api','import')),
    api_provider TEXT,
    is_latest BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (currency_code) REFERENCES Currencies(currency_code),
    UNIQUE(currency_code, rate_date)
);

CREATE INDEX idx_exchange_rates_date ON ExchangeRates(rate_date);
CREATE INDEX idx_exchange_rates_currency ON ExchangeRates(currency_code);
CREATE INDEX idx_exchange_rates_latest
    ON ExchangeRates(currency_code, is_latest) WHERE is_latest = 1;

CREATE TABLE FxRateUpdates (
    update_id INTEGER PRIMARY KEY AUTOINCREMENT,
    update_date DATE NOT NULL,
    api_provider TEXT NOT NULL,
    currencies_updated TEXT,
    status TEXT CHECK (status IN ('SUCCESS','PARTIAL','FAILED')),
    error_message TEXT,
    rates_count INTEGER DEFAULT 0,
    execution_time_ms INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (portfolio_id,instrument_id),
    FOREIGN KEY (portfolio_id) REFERENCES Portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id) ON DELETE CASCADE
);

CREATE INDEX idx_portfolio_instruments_instrument
    ON PortfolioInstruments(instrument_id);

CREATE TABLE ClassTargets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_class_id INTEGER NOT NULL REFERENCES AssetClasses(class_id),
    target_kind TEXT NOT NULL CHECK(target_kind IN('percent','amount')),
    target_percent REAL DEFAULT 0,
    target_amount_chf REAL DEFAULT 0,
    tolerance_percent REAL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_class_nonneg CHECK(target_percent >= 0 AND target_amount_chf >= 0),
    CONSTRAINT uq_class UNIQUE(asset_class_id)
);

CREATE TABLE SubClassTargets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_target_id INTEGER NOT NULL REFERENCES ClassTargets(id) ON DELETE CASCADE,
    asset_sub_class_id INTEGER NOT NULL REFERENCES AssetSubClasses(sub_class_id),
    target_kind TEXT NOT NULL CHECK(target_kind IN('percent','amount')),
    target_percent REAL DEFAULT 0,
    target_amount_chf REAL DEFAULT 0,
    tolerance_percent REAL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_sub_nonneg CHECK(target_percent >= 0 AND target_amount_chf >= 0),
    CONSTRAINT uq_sub UNIQUE(class_target_id,asset_sub_class_id)
);

CREATE TABLE TargetChangeLog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    target_type TEXT NOT NULL CHECK(target_type IN('class','subclass')),
    target_id INTEGER NOT NULL,
    field_name TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    changed_by TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE AccountTypes (
    account_type_id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_code TEXT NOT NULL UNIQUE,
    type_name TEXT NOT NULL,
    type_description TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Institutions (
    institution_id INTEGER PRIMARY KEY AUTOINCREMENT,
    institution_name TEXT NOT NULL,
    institution_type TEXT,
    bic TEXT,
    website TEXT,
    contact_info TEXT,
    default_currency TEXT CHECK(LENGTH(default_currency)=3),
    country_code TEXT CHECK(LENGTH(country_code)=2),
    notes TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

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
    import_source TEXT DEFAULT 'manual' CHECK(import_source IN('manual','csv','xlsx','pdf','api')),
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

CREATE TABLE ImportSessions (
    import_session_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_name TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_path TEXT,
    file_type TEXT NOT NULL CHECK(file_type IN('CSV','XLSX','PDF')),
    file_size INTEGER,
    file_hash TEXT,
    institution_id INTEGER,
    import_status TEXT DEFAULT 'PENDING' CHECK(import_status IN('PENDING','PROCESSING','COMPLETED','FAILED','CANCELLED')),
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

CREATE TABLE ImportSessionValueReports (
    report_id INTEGER PRIMARY KEY AUTOINCREMENT,
    import_session_id INTEGER NOT NULL,
    instrument_name TEXT NOT NULL,
    currency TEXT NOT NULL,
    value_orig REAL NOT NULL,
    value_chf REAL NOT NULL,
    FOREIGN KEY (import_session_id) REFERENCES ImportSessions(import_session_id)
);

CREATE TRIGGER tr_calculate_chf_amount
AFTER INSERT ON Transactions
WHEN NEW.amount_chf IS NULL
BEGIN
    UPDATE Transactions
    SET
        amount_chf = NEW.net_amount *
          COALESCE(
            (SELECT rate_to_chf FROM ExchangeRates
             WHERE currency_code = NEW.transaction_currency
               AND rate_date <= NEW.transaction_date
             ORDER BY rate_date DESC LIMIT 1),
             1.0
          ),
        exchange_rate_to_chf = COALESCE(
            (SELECT rate_to_chf FROM ExchangeRates
             WHERE currency_code = NEW.transaction_currency
               AND rate_date <= NEW.transaction_date
             ORDER BY rate_date DESC LIMIT 1),
             1.0
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

-- migrate:down
-- (baseline is irreversible)
