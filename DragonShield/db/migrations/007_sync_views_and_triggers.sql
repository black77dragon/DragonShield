BEGIN TRANSACTION;
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
CREATE INDEX IF NOT EXISTS "idx_vf_entity" ON "ValidationFindings" (
	"entity_type",
	"entity_id"
);
CREATE INDEX IF NOT EXISTS "idx_vf_severity_time" ON "ValidationFindings" (
	"severity",
	"computed_at"
);
CREATE TRIGGER trg_ct_after_insert
AFTER INSERT ON ClassTargets
BEGIN
  -- Log global portfolio % drift if off by > ±0.10%
  INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
  SELECT 'class', NEW.id, 'portfolio_class_percent_sum',
         NULL,
         printf('%.4f', (SELECT COALESCE(SUM(ct2.target_percent), 0.0) FROM ClassTargets ct2)),
         'trigger'
  WHERE ABS((SELECT COALESCE(SUM(ct2.target_percent), 0.0) FROM ClassTargets ct2) - 100.0) > 0.1;

  -- Update this row’s validation_status:
  --   error    -> any negative (defensive; CHECK should prevent)
  --   warning  -> portfolio % sum drift > ±0.10%
  --   compliant otherwise
  UPDATE ClassTargets
  SET validation_status =
      CASE
        WHEN NEW.target_percent    < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
        WHEN ABS((SELECT COALESCE(SUM(ct3.target_percent), 0.0) FROM ClassTargets ct3) - 100.0) > 0.1 THEN 'warning'
        ELSE 'compliant'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;
END;
CREATE TRIGGER trg_ct_after_update
AFTER UPDATE ON ClassTargets
BEGIN
  -- Log global portfolio % drift if off by > ±0.10%
  INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
  SELECT 'class', NEW.id, 'portfolio_class_percent_sum',
         NULL,
         printf('%.4f', (SELECT COALESCE(SUM(ct2.target_percent), 0.0) FROM ClassTargets ct2)),
         'trigger'
  WHERE ABS((SELECT COALESCE(SUM(ct2.target_percent), 0.0) FROM ClassTargets ct2) - 100.0) > 0.1;

  -- Update this row’s validation_status
  UPDATE ClassTargets
  SET validation_status =
      CASE
        WHEN NEW.target_percent    < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
        WHEN ABS((SELECT COALESCE(SUM(ct3.target_percent), 0.0) FROM ClassTargets ct3) - 100.0) > 0.1 THEN 'warning'
        ELSE 'compliant'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;
END;
CREATE TRIGGER trg_ct_zero_target AFTER UPDATE ON ClassTargets
WHEN NEW.target_percent = 0 AND COALESCE(NEW.target_amount_chf, 0) = 0
BEGIN
  DELETE FROM ValidationFindings
  WHERE (entity_type = 'class' AND entity_id = NEW.id)
     OR (entity_type = 'subclass' AND entity_id IN (
          SELECT sct.id FROM SubClassTargets sct WHERE sct.class_target_id = NEW.id
        ));

  UPDATE ClassTargets SET validation_status = 'compliant' WHERE id = NEW.id;
  UPDATE SubClassTargets SET validation_status = 'compliant' WHERE class_target_id = NEW.id;
END;
CREATE TRIGGER trg_sct_after_insert
AFTER INSERT ON SubClassTargets
BEGIN
  -- Log child % sum vs tolerance (non-blocking)
  INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
  SELECT 'class', NEW.class_target_id, 'child_percent_sum_vs_tol',
         NULL,
         printf('sum=%.4f tol=%.4f',
                (SELECT COALESCE(SUM(sct2.target_percent), 0.0)
                   FROM SubClassTargets sct2
                  WHERE sct2.class_target_id = NEW.class_target_id),
                (SELECT COALESCE(ct2.tolerance_percent, 0.0)
                   FROM ClassTargets ct2
                  WHERE ct2.id = NEW.class_target_id)),
         'trigger'
  WHERE ABS(
          (SELECT COALESCE(SUM(sct3.target_percent), 0.0)
             FROM SubClassTargets sct3
            WHERE sct3.class_target_id = NEW.class_target_id) - 100.0
        ) >
        (SELECT COALESCE(ct3.tolerance_percent, 0.0)
           FROM ClassTargets ct3
          WHERE ct3.id = NEW.class_target_id);

  -- Sub-class row validation (basic)
  UPDATE SubClassTargets
  SET validation_status =
      CASE
        WHEN NEW.target_percent    < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
        ELSE 'compliant'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;

  -- Bubble warning to parent if child % sum beyond tolerance (do not override 'error')
  UPDATE ClassTargets
  SET validation_status =
      CASE
        WHEN validation_status = 'error' THEN 'error'
        ELSE 'warning'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.class_target_id
    AND ABS(
          (SELECT COALESCE(SUM(sct4.target_percent), 0.0)
             FROM SubClassTargets sct4
            WHERE sct4.class_target_id = NEW.class_target_id) - 100.0
        ) >
        (SELECT COALESCE(ct4.tolerance_percent, 0.0)
           FROM ClassTargets ct4
          WHERE ct4.id = NEW.class_target_id);
END;
CREATE TRIGGER trg_sct_after_update
AFTER UPDATE ON SubClassTargets
BEGIN
  -- Log child % sum vs tolerance (non-blocking)
  INSERT INTO TargetChangeLog(target_type, target_id, field_name, old_value, new_value, changed_by)
  SELECT 'class', NEW.class_target_id, 'child_percent_sum_vs_tol',
         NULL,
         printf('sum=%.4f tol=%.4f',
                (SELECT COALESCE(SUM(sct2.target_percent), 0.0)
                   FROM SubClassTargets sct2
                  WHERE sct2.class_target_id = NEW.class_target_id),
                (SELECT COALESCE(ct2.tolerance_percent, 0.0)
                   FROM ClassTargets ct2
                  WHERE ct2.id = NEW.class_target_id)),
         'trigger'
  WHERE ABS(
          (SELECT COALESCE(SUM(sct3.target_percent), 0.0)
             FROM SubClassTargets sct3
            WHERE sct3.class_target_id = NEW.class_target_id) - 100.0
        ) >
        (SELECT COALESCE(ct3.tolerance_percent, 0.0)
           FROM ClassTargets ct3
          WHERE ct3.id = NEW.class_target_id);

  -- Sub-class row validation (basic)
  UPDATE SubClassTargets
  SET validation_status =
      CASE
        WHEN NEW.target_percent    < 0.0 OR NEW.target_amount_chf < 0.0 THEN 'error'
        ELSE 'compliant'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;

  -- Bubble warning to parent if child % sum beyond tolerance (do not override 'error')
  UPDATE ClassTargets
  SET validation_status =
      CASE
        WHEN validation_status = 'error' THEN 'error'
        ELSE 'warning'
      END,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.class_target_id
    AND ABS(
          (SELECT COALESCE(SUM(sct4.target_percent), 0.0)
             FROM SubClassTargets sct4
            WHERE sct4.class_target_id = NEW.class_target_id) - 100.0
        ) >
        (SELECT COALESCE(ct4.tolerance_percent, 0.0)
           FROM ClassTargets ct4
          WHERE ct4.id = NEW.class_target_id);
END;
CREATE TRIGGER trg_vf_ad_class AFTER DELETE ON ValidationFindings
WHEN OLD.entity_type = 'class'
BEGIN
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = OLD.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = OLD.entity_id
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = OLD.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = OLD.entity_id
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = OLD.entity_id;
END;
CREATE TRIGGER trg_vf_ad_subclass AFTER DELETE ON ValidationFindings
WHEN OLD.entity_type = 'subclass'
BEGIN
  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = OLD.entity_id
          AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = OLD.entity_id
          AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = OLD.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
            )
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
            )
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (
    SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
  );
END;
CREATE TRIGGER trg_vf_ai_class AFTER INSERT ON ValidationFindings
WHEN NEW.entity_type = 'class'
BEGIN
  -- Enforce zero-target skip rule
  DELETE FROM ValidationFindings
  WHERE id = NEW.id
    AND EXISTS (
      SELECT 1 FROM ClassTargets ct
      WHERE ct.id = NEW.entity_id
        AND ct.target_percent = 0 AND COALESCE(ct.target_amount_chf, 0) = 0
    );

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = NEW.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = NEW.entity_id
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = NEW.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = NEW.entity_id
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = NEW.entity_id;
END;
CREATE TRIGGER trg_vf_ai_subclass AFTER INSERT ON ValidationFindings
WHEN NEW.entity_type = 'subclass'
BEGIN
  -- Enforce zero-target skip rule
  DELETE FROM ValidationFindings
  WHERE id = NEW.id
    AND EXISTS (
      SELECT 1
      FROM ClassTargets ct
      JOIN SubClassTargets sct ON sct.class_target_id = ct.id
      WHERE sct.id = NEW.entity_id
        AND ct.target_percent = 0 AND COALESCE(ct.target_amount_chf, 0) = 0
    );

  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = NEW.entity_id
          AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = NEW.entity_id
          AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = NEW.entity_id;

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
            )
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
            )
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (
    SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
  );
END;
CREATE TRIGGER trg_vf_au_sync AFTER UPDATE ON ValidationFindings
BEGIN
  -- Recompute for old entity
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = OLD.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = OLD.entity_id
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = OLD.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = OLD.entity_id
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = OLD.entity_id AND OLD.entity_type = 'class';

  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = OLD.entity_id
          AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = OLD.entity_id
          AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = OLD.entity_id AND OLD.entity_type = 'subclass';

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
            )
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
            )
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (
    SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = OLD.entity_id
  ) AND OLD.entity_type = 'subclass';

  -- Recompute for new entity
  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = NEW.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = NEW.entity_id
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = NEW.entity_id)
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct.id FROM SubClassTargets sct
            WHERE sct.class_target_id = NEW.entity_id
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = NEW.entity_id AND NEW.entity_type = 'class';

  UPDATE SubClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = NEW.entity_id
          AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE vf.entity_type = 'subclass'
          AND vf.entity_id = NEW.entity_id
          AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = NEW.entity_id AND NEW.entity_type = 'subclass';

  UPDATE ClassTargets
  SET validation_status = (
    SELECT CASE
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
            )
          ))
        ) AND vf.severity = 'error'
      ) THEN 'error'
      WHEN EXISTS (
        SELECT 1 FROM ValidationFindings vf
        WHERE (
          (vf.entity_type = 'class' AND vf.entity_id = (
            SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
          ))
          OR
          (vf.entity_type = 'subclass' AND vf.entity_id IN (
            SELECT sct2.id FROM SubClassTargets sct2
            WHERE sct2.class_target_id = (
              SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
            )
          ))
        ) AND vf.severity = 'warning'
      ) THEN 'warning'
      ELSE 'compliant'
    END
  )
  WHERE id = (
    SELECT sct.class_target_id FROM SubClassTargets sct WHERE sct.id = NEW.entity_id
  ) AND NEW.entity_type = 'subclass';
END;
COMMIT;
