CREATE TABLE IF NOT EXISTS "schema_migrations" (version varchar(128) primary key);
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, validation_status TEXT NOT NULL DEFAULT 'compliant'
    CHECK(validation_status IN('compliant','warning','error')),
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, validation_status TEXT NOT NULL DEFAULT 'compliant'
    CHECK(validation_status IN('compliant','warning','error')),
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
CREATE TABLE ValidationFindings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL CHECK(entity_type IN('class','subclass')),
    entity_id INTEGER NOT NULL,
    severity TEXT NOT NULL CHECK(severity IN('warning','error')),
    code TEXT NOT NULL,
    message TEXT NOT NULL,
    details_json TEXT,
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(entity_type, entity_id, code)
);
CREATE INDEX idx_subclass_targets_class_id ON SubClassTargets(class_target_id);
CREATE INDEX idx_class_targets_status     ON ClassTargets(validation_status);
CREATE INDEX idx_vf_entity ON ValidationFindings(entity_type, entity_id);
CREATE INDEX idx_vf_severity_time ON ValidationFindings(severity, computed_at);
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
CREATE VIEW AccountSummary AS
SELECT
    a.account_id,
    a.account_name,
    i.institution_name,
    act.type_name as account_type,
    a.currency_code as account_currency,
    COUNT(DISTINCT t.instrument_id) as instruments_count,
    COUNT(t.transaction_id) as transactions_count,
    SUM(CASE WHEN tt.type_code IN ('DEPOSIT', 'DIVIDEND', 'INTEREST') THEN t.amount_chf ELSE 0 END) as total_inflows_chf,
    SUM(CASE WHEN tt.type_code IN ('WITHDRAWAL', 'FEE', 'TAX') THEN ABS(t.amount_chf) ELSE 0 END) as total_outflows_chf,
    SUM(CASE WHEN tt.type_code = 'BUY' THEN ABS(t.amount_chf) ELSE 0 END) as total_purchases_chf,
    SUM(CASE WHEN tt.type_code = 'SELL' THEN t.amount_chf ELSE 0 END) as total_sales_chf,
    MIN(t.transaction_date) as first_transaction_date,
    MAX(t.transaction_date) as last_transaction_date
FROM Accounts a
JOIN Institutions i ON a.institution_id = i.institution_id
JOIN AccountTypes act ON a.account_type_id = act.account_type_id
LEFT JOIN Transactions t ON a.account_id = t.account_id
LEFT JOIN TransactionTypes tt ON t.transaction_type_id = tt.transaction_type_id
WHERE a.is_active = 1
  AND (t.transaction_date IS NULL OR t.transaction_date <= (SELECT value FROM Configuration WHERE key = 'as_of_date'))
GROUP BY a.account_id, a.account_name, i.institution_name, act.type_name, a.currency_code
ORDER BY a.account_name
/* AccountSummary(account_id,account_name,institution_name,account_type,account_currency,instruments_count,transactions_count,total_inflows_chf,total_outflows_chf,total_purchases_chf,total_sales_chf,first_transaction_date,last_transaction_date) */;
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
ORDER BY c.currency_code
/* LatestExchangeRates(currency_code,currency_name,currency_symbol,current_rate_to_chf,rate_date,rate_source) */;
CREATE TABLE InstrumentsBackup (
    backup_id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    backup_reason TEXT NOT NULL,
    instrument_id INTEGER,
    isin TEXT,
    valor_nr TEXT,
    ticker_symbol TEXT,
    instrument_name TEXT,
    sub_class_id INTEGER,
    currency TEXT,
    country_code TEXT,
    exchange_code TEXT,
    sector TEXT,
    include_in_portfolio BOOLEAN,
    is_active BOOLEAN,
    notes TEXT,
    created_at DATETIME,
    updated_at DATETIME
);
CREATE TABLE PortfolioThemeStatus (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE CHECK (code GLOB '[A-Z][A-Z0-9_]*'),
    name TEXT NOT NULL UNIQUE,
    color_hex TEXT NOT NULL CHECK (color_hex GLOB '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'),
    is_default BOOLEAN NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX idx_portfolio_theme_status_default
ON PortfolioThemeStatus(is_default) WHERE is_default = 1;
CREATE TABLE PortfolioTheme (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL CHECK (LENGTH(name) BETWEEN 1 AND 64),
    code TEXT NOT NULL CHECK (code GLOB '[A-Z][A-Z0-9_]*' AND LENGTH(code) BETWEEN 2 AND 31),
    status_id INTEGER NOT NULL REFERENCES PortfolioThemeStatus(id),
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    archived_at TEXT NULL,
    soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1))
, description TEXT, institution_id INTEGER REFERENCES Institutions(institution_id) ON DELETE SET NULL);
CREATE UNIQUE INDEX idx_portfolio_theme_name_unique
ON PortfolioTheme(LOWER(name))
WHERE soft_delete = 0;
CREATE UNIQUE INDEX idx_portfolio_theme_code_unique
ON PortfolioTheme(LOWER(code))
WHERE soft_delete = 0;
CREATE TABLE PortfolioThemeAsset (
    theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE RESTRICT,
    instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE RESTRICT,
    research_target_pct REAL NOT NULL DEFAULT 0.0 CHECK(research_target_pct >= 0.0 AND research_target_pct <= 100.0),
    user_target_pct REAL NOT NULL DEFAULT 0.0 CHECK(user_target_pct >= 0.0 AND user_target_pct <= 100.0),
    notes TEXT NULL,
    created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
    PRIMARY KEY (theme_id, instrument_id)
);
CREATE INDEX idx_portfolio_theme_asset_instrument ON PortfolioThemeAsset(instrument_id);
CREATE INDEX idx_theme_asset_instrument ON PortfolioThemeAsset(instrument_id);
CREATE INDEX idx_portfolio_theme_institution_id ON PortfolioTheme(institution_id);
CREATE TRIGGER trg_portfolio_theme_description_len
BEFORE INSERT ON PortfolioTheme
WHEN NEW.description IS NOT NULL AND LENGTH(NEW.description) > 2000
BEGIN
  SELECT RAISE(ABORT, 'Description exceeds 2000 characters');
END;
CREATE TRIGGER trg_portfolio_theme_description_len_upd
BEFORE UPDATE ON PortfolioTheme
WHEN NEW.description IS NOT NULL AND LENGTH(NEW.description) > 2000
BEGIN
  SELECT RAISE(ABORT, 'Description exceeds 2000 characters');
END;
CREATE TABLE Attachment (
    id INTEGER PRIMARY KEY,
    sha256 TEXT NOT NULL UNIQUE,
    original_filename TEXT NOT NULL,
    mime TEXT NOT NULL,
    byte_size INTEGER NOT NULL,
    ext TEXT NULL,
    created_at TEXT NOT NULL,
    created_by TEXT NOT NULL
);
CREATE INDEX idx_attachment_sha ON Attachment(sha256);
CREATE TABLE ThemeUpdateAttachment (
    id INTEGER PRIMARY KEY,
    theme_update_id INTEGER NOT NULL
        REFERENCES PortfolioThemeUpdate(id) ON DELETE CASCADE,
    attachment_id INTEGER NOT NULL
        REFERENCES Attachment(id) ON DELETE RESTRICT,
    created_at TEXT NOT NULL
);
CREATE INDEX idx_tua_update ON ThemeUpdateAttachment(theme_update_id);
CREATE INDEX idx_tua_attachment ON ThemeUpdateAttachment(attachment_id);
CREATE TABLE ThemeAssetUpdateAttachment (
  id                     INTEGER PRIMARY KEY,
  theme_asset_update_id  INTEGER NOT NULL
      REFERENCES PortfolioThemeAssetUpdate(id) ON DELETE CASCADE,
  attachment_id          INTEGER NOT NULL
      REFERENCES Attachment(id) ON DELETE RESTRICT,
  created_at             TEXT    NOT NULL
);
CREATE INDEX idx_taua_update ON ThemeAssetUpdateAttachment(theme_asset_update_id);
CREATE INDEX idx_taua_attachment ON ThemeAssetUpdateAttachment(attachment_id);
CREATE TABLE Link (
  id               INTEGER PRIMARY KEY,
  normalized_url   TEXT    NOT NULL UNIQUE,
  raw_url          TEXT    NOT NULL,
  title            TEXT    NULL,
  created_at       TEXT    NOT NULL,
  created_by       TEXT    NOT NULL
);
CREATE INDEX idx_link_normalized ON Link(normalized_url);
CREATE TABLE ThemeUpdateLink (
  id              INTEGER PRIMARY KEY,
  theme_update_id INTEGER NOT NULL
      REFERENCES PortfolioThemeUpdate(id) ON DELETE CASCADE,
  link_id         INTEGER NOT NULL
      REFERENCES Link(id) ON DELETE RESTRICT,
  created_at      TEXT    NOT NULL
);
CREATE INDEX idx_tul_update ON ThemeUpdateLink(theme_update_id);
CREATE INDEX idx_tul_link ON ThemeUpdateLink(link_id);
CREATE TABLE IF NOT EXISTS "AssetSubClasses" (
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
CREATE TABLE IF NOT EXISTS "Instruments" (
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
    deleted_reason TEXT, user_note TEXT DEFAULT NULL,
    FOREIGN KEY (sub_class_id) REFERENCES AssetSubClasses(sub_class_id) ON DELETE CASCADE,
    FOREIGN KEY (currency) REFERENCES Currencies(currency_code)
);
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
CREATE TRIGGER trg_instruments_restore_tracking
AFTER INSERT ON Instruments
WHEN NEW.restore_source IS NOT NULL AND NEW.restore_source != 'original'
BEGIN
    UPDATE Instruments
    SET restore_timestamp = CURRENT_TIMESTAMP
    WHERE instrument_id = NEW.instrument_id;
END;
CREATE TRIGGER trg_instruments_validate_restore
AFTER INSERT ON Instruments
BEGIN
    UPDATE Instruments
    SET validation_status = 'invalid'
    WHERE instrument_id = NEW.instrument_id
      AND (
        NOT EXISTS (SELECT 1 FROM AssetSubClasses WHERE sub_class_id = NEW.sub_class_id)
        OR NOT EXISTS (SELECT 1 FROM Currencies WHERE currency_code = NEW.currency)
      );
END;
CREATE TRIGGER trg_instruments_auto_backup
BEFORE DELETE ON Instruments
BEGIN
    INSERT INTO InstrumentsBackup (
        backup_reason, instrument_id, isin, valor_nr, ticker_symbol,
        instrument_name, sub_class_id, currency, country_code, exchange_code,
        sector, include_in_portfolio, is_active, notes, created_at, updated_at
    ) VALUES (
        'AUTO_BACKUP_BEFORE_DELETE', OLD.instrument_id, OLD.isin, OLD.valor_nr,
        OLD.ticker_symbol, OLD.instrument_name, OLD.sub_class_id, OLD.currency,
        OLD.country_code, OLD.exchange_code, OLD.sector, OLD.include_in_portfolio,
        OLD.is_active, OLD.notes, OLD.created_at, OLD.updated_at
    );
END;
CREATE TABLE IF NOT EXISTS "PositionReports" (
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
       END) < 0
/* DataIntegrityCheck(issue_type,issue_description,occurrence_count) */;
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
ORDER BY i.instrument_name
/* InstrumentPerformance(instrument_id,instrument_name,ticker_symbol,isin,class_name,currency,current_quantity,avg_cost_basis_chf,total_invested_chf,total_sold_chf,total_dividends_chf,transaction_count,first_purchase_date,last_transaction_date,include_in_portfolio,is_active) */;
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
HAVING total_quantity > 0
/* Positions(portfolio_id,portfolio_name,instrument_id,instrument_name,isin,ticker_symbol,asset_class,asset_sub_class,account_id,account_name,instrument_currency,total_quantity,avg_cost_chf_per_unit,total_invested_chf,total_sold_chf,total_dividends_chf,total_fees_chf,transaction_count,first_transaction_date,last_transaction_date) */;
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
ORDER BY p.portfolio_name, p.asset_class
/* PortfolioSummary(portfolio_name,asset_class,instrument_count,total_transactions,current_market_value_chf,total_invested_chf,total_sold_chf,total_dividends_chf,total_fees_chf,unrealized_return_percent,dividend_yield_percent) */;
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
FROM AssetClasses ac
/* V_ClassValidationStatus(class_id,validation_status,findings_count) */;
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
FROM AssetSubClasses s
/* V_SubClassValidationStatus(sub_class_id,validation_status,findings_count) */;
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
   OR c.currency_code IS NULL
/* InstrumentsValidationReport(instrument_id,instrument_name,isin,valor_nr,validation_status,subclass_issue,currency_issue,restore_source,restore_timestamp) */;
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
HAVING COUNT(*) > 1
/* InstrumentsDuplicateCheck(conflict_type,conflicting_value,duplicate_count,affected_instruments) */;
CREATE VIEW RestoreValidationSummary AS
SELECT
    'Instruments' as table_name,
    COUNT(*) as total_records,
    SUM(CASE WHEN validation_status = 'valid' THEN 1 ELSE 0 END) as valid_records,
    SUM(CASE WHEN validation_status = 'invalid' THEN 1 ELSE 0 END) as invalid_records,
    SUM(CASE WHEN validation_status = 'pending_validation' THEN 1 ELSE 0 END) as pending_records,
    (SELECT COUNT(*) FROM InstrumentsDuplicateCheck) as duplicate_conflicts
FROM Instruments
/* RestoreValidationSummary(table_name,total_records,valid_records,invalid_records,pending_records,duplicate_conflicts) */;
CREATE TABLE UpdateType (
    type_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
);
CREATE TABLE NewsType (
  id           INTEGER PRIMARY KEY,
  code         TEXT    NOT NULL UNIQUE,
  display_name TEXT    NOT NULL,
  sort_order   INTEGER NOT NULL,
  active       INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  color        TEXT    NULL,
  icon         TEXT    NULL,
  created_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at   TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE UNIQUE INDEX idx_news_type_code ON NewsType(code);
CREATE INDEX idx_news_type_active_order ON NewsType(active, sort_order);
CREATE TABLE IF NOT EXISTS "PortfolioThemeUpdate" (
  id INTEGER PRIMARY KEY,
  theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type_id INTEGER NOT NULL REFERENCES NewsType(id),
  author TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
  positions_asof TEXT NULL,
  total_value_chf REAL NULL,
  created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  soft_delete INTEGER NOT NULL DEFAULT 0 CHECK (soft_delete IN (0,1)),
  deleted_at TEXT NULL,
  deleted_by TEXT NULL
);
CREATE INDEX idx_ptu_theme_active_order ON PortfolioThemeUpdate(theme_id, soft_delete, pinned, created_at DESC);
CREATE INDEX idx_ptu_theme_deleted_order ON PortfolioThemeUpdate(theme_id, soft_delete, deleted_at DESC);
CREATE TABLE IF NOT EXISTS "PortfolioThemeAssetUpdate" (
  id INTEGER PRIMARY KEY,
  theme_id INTEGER NOT NULL REFERENCES PortfolioTheme(id) ON DELETE CASCADE,
  instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE SET NULL,
  title TEXT NOT NULL CHECK (LENGTH(title) BETWEEN 1 AND 120),
  body_text TEXT NOT NULL CHECK (LENGTH(body_text) BETWEEN 1 AND 5000),
  body_markdown TEXT NOT NULL CHECK (LENGTH(body_markdown) BETWEEN 1 AND 5000),
  type_id INTEGER NOT NULL REFERENCES NewsType(id),
  author TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK (pinned IN (0,1)),
  positions_asof TEXT NULL,
  value_chf REAL NULL,
  actual_percent REAL NULL,
  created_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX idx_ptau_theme_instr_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, created_at DESC);
CREATE INDEX idx_ptau_theme_instr_pinned_order ON PortfolioThemeAssetUpdate(theme_id, instrument_id, pinned DESC, created_at DESC);
CREATE TABLE InstrumentPrice (
  id            INTEGER PRIMARY KEY,
  instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE CASCADE,
  price         REAL    NOT NULL,
  currency      TEXT    NOT NULL,
  source        TEXT    NOT NULL DEFAULT '',
  as_of         TEXT    NOT NULL,
  created_at    TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE UNIQUE INDEX uq_instr_price_key ON InstrumentPrice(instrument_id, as_of, source);
CREATE INDEX idx_instr_price_latest ON InstrumentPrice(instrument_id, as_of DESC);
CREATE VIEW InstrumentPriceLatest AS
SELECT ip1.instrument_id, ip1.price, ip1.currency, ip1.source, ip1.as_of
FROM InstrumentPrice ip1
WHERE ip1.as_of = (
  SELECT MAX(ip2.as_of)
  FROM InstrumentPrice ip2
  WHERE ip2.instrument_id = ip1.instrument_id
)
/* InstrumentPriceLatest(instrument_id,price,currency,source,as_of) */;
CREATE TABLE InstrumentPriceSource (
  id             INTEGER PRIMARY KEY,
  instrument_id  INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE CASCADE,
  provider_code  TEXT    NOT NULL,
  external_id    TEXT    NOT NULL,
  enabled        INTEGER NOT NULL DEFAULT 1,
  priority       INTEGER NOT NULL DEFAULT 1,
  last_status    TEXT    NULL,
  last_checked_at TEXT   NULL,
  created_at     TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at     TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE UNIQUE INDEX uq_price_source_instrument_provider
  ON InstrumentPriceSource(instrument_id, provider_code);
CREATE INDEX idx_price_source_provider
  ON InstrumentPriceSource(provider_code, enabled, priority);
CREATE TABLE InstrumentPriceFetchLog (
  id             INTEGER PRIMARY KEY,
  instrument_id  INTEGER,
  provider_code  TEXT,
  external_id    TEXT,
  status         TEXT NOT NULL,
  message        TEXT,
  created_at     TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
-- Dbmate schema migrations
INSERT INTO "schema_migrations" (version) VALUES
  ('001'),
  ('002'),
  ('003'),
  ('004'),
  ('005'),
  ('006'),
  ('007'),
  ('008'),
  ('009'),
  ('010'),
  ('011'),
  ('012'),
  ('013'),
  ('014'),
  ('015'),
  ('016'),
  ('017'),
  ('018'),
  ('019'),
  ('020'),
  ('021'),
  ('022'),
  ('023'),
  ('024'),
  ('025'),
  ('026'),
  ('028'),
  ('029');
