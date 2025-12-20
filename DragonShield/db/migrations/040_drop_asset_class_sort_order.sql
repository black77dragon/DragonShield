-- migrate:up
-- Purpose: Drop AssetClasses.sort_order now that ordering is derived at query time.
-- Assumptions: AssetClasses exists; consumers no longer depend on persisted ordering.

DROP VIEW IF EXISTS PortfolioSummary;
DROP VIEW IF EXISTS Positions;
DROP VIEW IF EXISTS InstrumentPerformance;
DROP VIEW IF EXISTS V_ClassValidationStatus;

CREATE TABLE IF NOT EXISTS AssetClasses_new (
    class_id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_code TEXT NOT NULL UNIQUE,
    class_name TEXT NOT NULL,
    class_description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO AssetClasses_new (class_id, class_code, class_name, class_description, created_at, updated_at)
  SELECT class_id, class_code, class_name, class_description, created_at, updated_at
  FROM AssetClasses;
DROP TABLE AssetClasses;
ALTER TABLE AssetClasses_new RENAME TO AssetClasses;

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

-- migrate:down
-- Purpose: Reintroduce AssetClasses.sort_order.
-- Assumptions: Sorting restarts at 0 for existing rows (previous values are not recoverable).

DROP VIEW IF EXISTS PortfolioSummary;
DROP VIEW IF EXISTS Positions;
DROP VIEW IF EXISTS InstrumentPerformance;
DROP VIEW IF EXISTS V_ClassValidationStatus;

CREATE TABLE IF NOT EXISTS AssetClasses_old (
    class_id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_code TEXT NOT NULL UNIQUE,
    class_name TEXT NOT NULL,
    class_description TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO AssetClasses_old (class_id, class_code, class_name, class_description, sort_order, created_at, updated_at)
  SELECT class_id, class_code, class_name, class_description, 0, created_at, updated_at
  FROM AssetClasses;
DROP TABLE AssetClasses;
ALTER TABLE AssetClasses_old RENAME TO AssetClasses;

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
