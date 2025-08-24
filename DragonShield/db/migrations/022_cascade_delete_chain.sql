-- migrate:up
-- Purpose: enforce cascading deletes from asset classes down to position reports
-- Assumptions: existing records have valid foreign-key relations; triggers and indexes will be recreated
-- Idempotency: recreates tables using temporary names; safe to run once

-- Drop dependent views before table recreation
DROP VIEW IF EXISTS PortfolioSummary;
DROP VIEW IF EXISTS Positions;
DROP VIEW IF EXISTS InstrumentPerformance;
DROP VIEW IF EXISTS DataIntegrityCheck;
DROP VIEW IF EXISTS V_ClassValidationStatus;
DROP VIEW IF EXISTS V_SubClassValidationStatus;
DROP VIEW IF EXISTS RestoreValidationSummary;
DROP VIEW IF EXISTS InstrumentsValidationReport;
DROP VIEW IF EXISTS InstrumentsDuplicateCheck;

-- Recreate AssetSubClasses with cascade on class_id
CREATE TABLE AssetSubClasses_new (
    sub_class_id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_id INTEGER NOT NULL,
    sub_class_code TEXT NOT NULL UNIQUE,
    sub_class_name TEXT NOT NULL,
    sub_class_description TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES AssetClasses(class_id) ON DELETE CASCADE
);
INSERT INTO AssetSubClasses_new SELECT * FROM AssetSubClasses;
DROP TABLE AssetSubClasses;
ALTER TABLE AssetSubClasses_new RENAME TO AssetSubClasses;

-- Recreate Instruments with cascade on sub_class_id
CREATE TABLE Instruments_new (
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
    isin_original TEXT,
    valor_original TEXT,
    validation_status TEXT DEFAULT 'valid' CHECK(validation_status IN ('valid','invalid','pending_validation')),
    restore_source TEXT DEFAULT 'original',
    restore_timestamp DATETIME,
    is_deleted BOOLEAN DEFAULT 0,
    deleted_at DATETIME,
    deleted_reason TEXT,
    FOREIGN KEY (sub_class_id) REFERENCES AssetSubClasses(sub_class_id) ON DELETE CASCADE,
    FOREIGN KEY (currency) REFERENCES Currencies(currency_code)
);
INSERT INTO Instruments_new SELECT * FROM Instruments;
DROP TABLE Instruments;
ALTER TABLE Instruments_new RENAME TO Instruments;

CREATE INDEX idx_instruments_isin ON Instruments(isin);
CREATE INDEX idx_instruments_ticker ON Instruments(ticker_symbol);
CREATE INDEX idx_instruments_sub_class ON Instruments(sub_class_id);
CREATE INDEX idx_instruments_currency ON Instruments(currency);

CREATE TRIGGER tr_instruments_updated_at
AFTER UPDATE ON Instruments
BEGIN
    UPDATE Instruments
       SET updated_at = CURRENT_TIMESTAMP
     WHERE instrument_id = NEW.instrument_id;
END;

-- Recreate PositionReports with cascade on instrument_id
CREATE TABLE PositionReports_new (
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
    FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id) ON DELETE CASCADE
);
INSERT INTO PositionReports_new SELECT * FROM PositionReports;
DROP TABLE PositionReports;
ALTER TABLE PositionReports_new RENAME TO PositionReports;

DELETE FROM sqlite_sequence WHERE name IN ('AssetSubClasses','Instruments','PositionReports');
INSERT INTO sqlite_sequence(name, seq) SELECT 'AssetSubClasses', IFNULL(MAX(sub_class_id),0) FROM AssetSubClasses;
INSERT INTO sqlite_sequence(name, seq) SELECT 'Instruments', IFNULL(MAX(instrument_id),0) FROM Instruments;
INSERT INTO sqlite_sequence(name, seq) SELECT 'PositionReports', IFNULL(MAX(position_id),0) FROM PositionReports;

-- Recreate dropped views
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

CREATE VIEW V_ClassValidationStatus AS
WITH class_err AS (
  SELECT ac.class_id FROM AssetClasses ac
  WHERE EXISTS (SELECT 1 FROM ValidationFindings vf
                  WHERE vf.entity_type='class'
                    AND vf.entity_id=ac.class_id
                    AND vf.severity='error')
     OR EXISTS (SELECT 1 FROM ValidationFindings vf
                  JOIN AssetSubClasses s ON s.sub_class_id=vf.entity_id
                 WHERE vf.entity_type='subclass'
                   AND s.class_id=ac.class_id
                   AND vf.severity='error')
),
class_warn AS (
  SELECT ac.class_id FROM AssetClasses ac
  WHERE EXISTS (SELECT 1 FROM ValidationFindings vf
                  WHERE vf.entity_type='class'
                    AND vf.entity_id=ac.class_id
                    AND vf.severity='warning')
     OR EXISTS (SELECT 1 FROM ValidationFindings vf
                  JOIN AssetSubClasses s ON s.sub_class_id=vf.entity_id
                 WHERE vf.entity_type='subclass'
                   AND s.class_id=ac.class_id
                   AND vf.severity='warning')
)
SELECT ac.class_id,
       CASE
         WHEN EXISTS (SELECT 1 FROM class_err e WHERE e.class_id=ac.class_id) THEN 'error'
         WHEN EXISTS (SELECT 1 FROM class_warn w WHERE w.class_id=ac.class_id) THEN 'warning'
         ELSE 'compliant'
       END AS validation_status,
       (
         SELECT COUNT(*) FROM ValidationFindings vf
         WHERE (vf.entity_type='class' AND vf.entity_id=ac.class_id)
            OR (vf.entity_type='subclass' AND vf.entity_id IN (
                 SELECT sub_class_id FROM AssetSubClasses s WHERE s.class_id=ac.class_id
               ))
       ) AS findings_count
FROM AssetClasses ac;

CREATE VIEW V_SubClassValidationStatus AS
WITH sub_err AS (
  SELECT entity_id AS sub_class_id FROM ValidationFindings
  WHERE entity_type='subclass' AND severity='error'
),
sub_warn AS (
  SELECT entity_id AS sub_class_id FROM ValidationFindings
  WHERE entity_type='subclass' AND severity='warning'
)
SELECT s.sub_class_id,
       CASE
         WHEN EXISTS(SELECT 1 FROM sub_err e WHERE e.sub_class_id=s.sub_class_id) THEN 'error'
         WHEN EXISTS(SELECT 1 FROM sub_warn w WHERE w.sub_class_id=s.sub_class_id) THEN 'warning'
         ELSE 'compliant'
       END AS validation_status,
       (SELECT COUNT(*) FROM ValidationFindings vf
         WHERE vf.entity_type='subclass' AND vf.entity_id=s.sub_class_id) AS findings_count
FROM AssetSubClasses s;

CREATE VIEW InstrumentsDuplicateCheck AS
SELECT
    'ISIN' as conflict_type,
    isin as conflicting_value,
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(instrument_id) as affected_instruments
FROM Instruments
WHERE isin IS NOT NULL
GROUP BY isin
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'VALOR' as conflict_type,
    valor_nr as conflicting_value,
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(instrument_id) as affected_instruments
FROM Instruments
WHERE valor_nr IS NOT NULL
GROUP BY valor_nr
HAVING COUNT(*) > 1;

CREATE VIEW InstrumentsValidationReport AS
SELECT
    i.instrument_id,
    i.instrument_name,
    i.isin,
    i.valor_nr,
    i.validation_status,
    CASE
        WHEN asc.sub_class_id IS NULL THEN 'MISSING_SUBCLASS: ' || i.sub_class_id
        ELSE NULL
    END as subclass_issue,
    CASE
        WHEN c.currency_code IS NULL THEN 'MISSING_CURRENCY: ' || i.currency
        ELSE NULL
    END as currency_issue,
    i.restore_source,
    i.restore_timestamp
FROM Instruments i
LEFT JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
LEFT JOIN Currencies c ON i.currency = c.currency_code
WHERE i.validation_status != 'valid'
   OR asc.sub_class_id IS NULL
   OR c.currency_code IS NULL;

CREATE VIEW RestoreValidationSummary AS
SELECT
    'Instruments' as table_name,
    COUNT(*) as total_records,
    SUM(CASE WHEN validation_status = 'valid' THEN 1 ELSE 0 END) as valid_records,
    SUM(CASE WHEN validation_status = 'invalid' THEN 1 ELSE 0 END) as invalid_records,
    SUM(CASE WHEN validation_status = 'pending_validation' THEN 1 ELSE 0 END) as pending_records,
    (SELECT COUNT(*) FROM InstrumentsDuplicateCheck) as duplicate_conflicts
FROM Instruments;

-- migrate:down
-- Purpose: revert cascading deletes to previous restrict behavior
-- Assumptions: data fits original constraints
-- Idempotency: recreates tables without ON DELETE CASCADE

-- Drop views prior to reverting tables
DROP VIEW IF EXISTS PortfolioSummary;
DROP VIEW IF EXISTS Positions;
DROP VIEW IF EXISTS InstrumentPerformance;
DROP VIEW IF EXISTS DataIntegrityCheck;
DROP VIEW IF EXISTS V_ClassValidationStatus;
DROP VIEW IF EXISTS V_SubClassValidationStatus;
DROP VIEW IF EXISTS RestoreValidationSummary;
DROP VIEW IF EXISTS InstrumentsValidationReport;
DROP VIEW IF EXISTS InstrumentsDuplicateCheck;

CREATE TABLE PositionReports_old (
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
INSERT INTO PositionReports_old SELECT * FROM PositionReports;
DROP TABLE PositionReports;
ALTER TABLE PositionReports_old RENAME TO PositionReports;

CREATE TABLE Instruments_old (
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
    isin_original TEXT,
    valor_original TEXT,
    validation_status TEXT DEFAULT 'valid' CHECK(validation_status IN ('valid','invalid','pending_validation')),
    restore_source TEXT DEFAULT 'original',
    restore_timestamp DATETIME,
    is_deleted BOOLEAN DEFAULT 0,
    deleted_at DATETIME,
    deleted_reason TEXT,
    FOREIGN KEY (sub_class_id) REFERENCES AssetSubClasses(sub_class_id),
    FOREIGN KEY (currency) REFERENCES Currencies(currency_code)
);
INSERT INTO Instruments_old SELECT * FROM Instruments;
DROP TABLE Instruments;
ALTER TABLE Instruments_old RENAME TO Instruments;

CREATE INDEX idx_instruments_isin ON Instruments(isin);
CREATE INDEX idx_instruments_ticker ON Instruments(ticker_symbol);
CREATE INDEX idx_instruments_sub_class ON Instruments(sub_class_id);
CREATE INDEX idx_instruments_currency ON Instruments(currency);

CREATE TRIGGER tr_instruments_updated_at
AFTER UPDATE ON Instruments
BEGIN
    UPDATE Instruments
       SET updated_at = CURRENT_TIMESTAMP
     WHERE instrument_id = NEW.instrument_id;
END;

CREATE TABLE AssetSubClasses_old (
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
INSERT INTO AssetSubClasses_old SELECT * FROM AssetSubClasses;
DROP TABLE AssetSubClasses;
ALTER TABLE AssetSubClasses_old RENAME TO AssetSubClasses;

DELETE FROM sqlite_sequence WHERE name IN ('AssetSubClasses','Instruments','PositionReports');
INSERT INTO sqlite_sequence(name, seq) SELECT 'AssetSubClasses', IFNULL(MAX(sub_class_id),0) FROM AssetSubClasses;
INSERT INTO sqlite_sequence(name, seq) SELECT 'Instruments', IFNULL(MAX(instrument_id),0) FROM Instruments;
INSERT INTO sqlite_sequence(name, seq) SELECT 'PositionReports', IFNULL(MAX(position_id),0) FROM PositionReports;

-- Recreate dropped views after reverting tables
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

CREATE VIEW V_ClassValidationStatus AS
WITH class_err AS (
  SELECT ac.class_id FROM AssetClasses ac
  WHERE EXISTS (SELECT 1 FROM ValidationFindings vf
                  WHERE vf.entity_type='class'
                    AND vf.entity_id=ac.class_id
                    AND vf.severity='error')
     OR EXISTS (SELECT 1 FROM ValidationFindings vf
                  JOIN AssetSubClasses s ON s.sub_class_id=vf.entity_id
                 WHERE vf.entity_type='subclass'
                   AND s.class_id=ac.class_id
                   AND vf.severity='error')
),
class_warn AS (
  SELECT ac.class_id FROM AssetClasses ac
  WHERE EXISTS (SELECT 1 FROM ValidationFindings vf
                  WHERE vf.entity_type='class'
                    AND vf.entity_id=ac.class_id
                    AND vf.severity='warning')
     OR EXISTS (SELECT 1 FROM ValidationFindings vf
                  JOIN AssetSubClasses s ON s.sub_class_id=vf.entity_id
                 WHERE vf.entity_type='subclass'
                   AND s.class_id=ac.class_id
                   AND vf.severity='warning')
)
SELECT ac.class_id,
       CASE
         WHEN EXISTS (SELECT 1 FROM class_err e WHERE e.class_id=ac.class_id) THEN 'error'
         WHEN EXISTS (SELECT 1 FROM class_warn w WHERE w.class_id=ac.class_id) THEN 'warning'
         ELSE 'compliant'
       END AS validation_status,
       (
         SELECT COUNT(*) FROM ValidationFindings vf
         WHERE (vf.entity_type='class' AND vf.entity_id=ac.class_id)
            OR (vf.entity_type='subclass' AND vf.entity_id IN (
                 SELECT sub_class_id FROM AssetSubClasses s WHERE s.class_id=ac.class_id
               ))
       ) AS findings_count
FROM AssetClasses ac;

CREATE VIEW V_SubClassValidationStatus AS
WITH sub_err AS (
  SELECT entity_id AS sub_class_id FROM ValidationFindings
  WHERE entity_type='subclass' AND severity='error'
),
sub_warn AS (
  SELECT entity_id AS sub_class_id FROM ValidationFindings
  WHERE entity_type='subclass' AND severity='warning'
)
SELECT s.sub_class_id,
       CASE
         WHEN EXISTS(SELECT 1 FROM sub_err e WHERE e.sub_class_id=s.sub_class_id) THEN 'error'
         WHEN EXISTS(SELECT 1 FROM sub_warn w WHERE w.sub_class_id=s.sub_class_id) THEN 'warning'
         ELSE 'compliant'
       END AS validation_status,
       (SELECT COUNT(*) FROM ValidationFindings vf
         WHERE vf.entity_type='subclass' AND vf.entity_id=s.sub_class_id) AS findings_count
FROM AssetSubClasses s;

CREATE VIEW InstrumentsDuplicateCheck AS
SELECT
    'ISIN' as conflict_type,
    isin as conflicting_value,
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(instrument_id) as affected_instruments
FROM Instruments
WHERE isin IS NOT NULL
GROUP BY isin
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'VALOR' as conflict_type,
    valor_nr as conflicting_value,
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(instrument_id) as affected_instruments
FROM Instruments
WHERE valor_nr IS NOT NULL
GROUP BY valor_nr
HAVING COUNT(*) > 1;

CREATE VIEW InstrumentsValidationReport AS
SELECT
    i.instrument_id,
    i.instrument_name,
    i.isin,
    i.valor_nr,
    i.validation_status,
    CASE
        WHEN asc.sub_class_id IS NULL THEN 'MISSING_SUBCLASS: ' || i.sub_class_id
        ELSE NULL
    END as subclass_issue,
    CASE
        WHEN c.currency_code IS NULL THEN 'MISSING_CURRENCY: ' || i.currency
        ELSE NULL
    END as currency_issue,
    i.restore_source,
    i.restore_timestamp
FROM Instruments i
LEFT JOIN AssetSubClasses asc ON i.sub_class_id = asc.sub_class_id
LEFT JOIN Currencies c ON i.currency = c.currency_code
WHERE i.validation_status != 'valid'
   OR asc.sub_class_id IS NULL
   OR c.currency_code IS NULL;

CREATE VIEW RestoreValidationSummary AS
SELECT
    'Instruments' as table_name,
    COUNT(*) as total_records,
    SUM(CASE WHEN validation_status = 'valid' THEN 1 ELSE 0 END) as valid_records,
    SUM(CASE WHEN validation_status = 'invalid' THEN 1 ELSE 0 END) as invalid_records,
    SUM(CASE WHEN validation_status = 'pending_validation' THEN 1 ELSE 0 END) as pending_records,
    (SELECT COUNT(*) FROM InstrumentsDuplicateCheck) as duplicate_conflicts
FROM Instruments;
