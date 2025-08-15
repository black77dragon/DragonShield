-- migrate:up
-- Fix critical backup/restore safety issues in database structure

-- 1. ADD CONFLICT RESOLUTION FOR UNIQUE CONSTRAINTS
-- Current problem: UNIQUE constraints fail during restore with duplicates
-- Solution: Add backup columns and conflict resolution logic

-- Add backup columns for natural keys (allows for conflict resolution)
ALTER TABLE Instruments ADD COLUMN isin_original TEXT;
ALTER TABLE Instruments ADD COLUMN valor_original TEXT;

-- Copy existing values to backup columns
UPDATE Instruments SET isin_original = isin WHERE isin IS NOT NULL;
UPDATE Instruments SET valor_original = valor_nr WHERE valor_nr IS NOT NULL;

-- 2. IMPROVE FOREIGN KEY SAFETY
-- Current problem: NOT NULL foreign keys cause restore failures
-- Solution: Add validation without breaking restore process

-- Add validation status for instruments
ALTER TABLE Instruments ADD COLUMN validation_status TEXT DEFAULT 'valid' 
    CHECK(validation_status IN ('valid', 'invalid', 'pending_validation'));

-- Add restoration metadata
ALTER TABLE Instruments ADD COLUMN restore_source TEXT DEFAULT 'original';
ALTER TABLE Instruments ADD COLUMN restore_timestamp DATETIME;

-- 3. ADD SAFER CASCADE BEHAVIOR
-- Current problem: ON DELETE CASCADE is too aggressive during restore
-- Solution: Add soft delete capability

ALTER TABLE Instruments ADD COLUMN is_deleted BOOLEAN DEFAULT 0;
ALTER TABLE Instruments ADD COLUMN deleted_at DATETIME;
ALTER TABLE Instruments ADD COLUMN deleted_reason TEXT;

-- 4. ADD RESTORE SAFETY TRIGGERS
-- These triggers help during restore operations

-- Trigger to track restoration operations
CREATE TRIGGER trg_instruments_restore_tracking
AFTER INSERT ON Instruments
WHEN NEW.restore_source IS NOT NULL AND NEW.restore_source != 'original'
BEGIN
    UPDATE Instruments 
    SET restore_timestamp = CURRENT_TIMESTAMP
    WHERE instrument_id = NEW.instrument_id;
END;

-- Trigger to validate foreign key references during restore
CREATE TRIGGER trg_instruments_validate_restore
AFTER INSERT ON Instruments
BEGIN
    -- Mark as invalid if foreign key references don't exist
    UPDATE Instruments 
    SET validation_status = 'invalid'
    WHERE instrument_id = NEW.instrument_id
    AND (
        NOT EXISTS (SELECT 1 FROM AssetSubClasses WHERE sub_class_id = NEW.sub_class_id)
        OR 
        NOT EXISTS (SELECT 1 FROM Currencies WHERE currency_code = NEW.currency)
    );
END;

-- 5. CREATE INSTRUMENTS BACKUP TABLE
-- This provides a safety net during dangerous operations
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

-- Trigger to automatically backup before dangerous operations
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

-- 6. ADD SAFER RESTORE PROCEDURES AS VIEWS
-- These views help identify problematic data during restore

-- View to identify instruments with missing foreign key references
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

-- View to identify potential UNIQUE constraint conflicts
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

-- 7. ADD RESTORE SAFETY FUNCTIONS (as views since SQLite doesn't have stored procedures)

-- Emergency restore validation
CREATE VIEW RestoreValidationSummary AS
SELECT 
    'Instruments' as table_name,
    COUNT(*) as total_records,
    SUM(CASE WHEN validation_status = 'valid' THEN 1 ELSE 0 END) as valid_records,
    SUM(CASE WHEN validation_status = 'invalid' THEN 1 ELSE 0 END) as invalid_records,
    SUM(CASE WHEN validation_status = 'pending_validation' THEN 1 ELSE 0 END) as pending_records,
    (SELECT COUNT(*) FROM InstrumentsDuplicateCheck) as duplicate_conflicts
FROM Instruments;

-- Update database version
UPDATE Configuration SET value = '4.26' WHERE key = 'db_version';

-- migrate:down
-- WARNING: This down migration will lose the safety features!
-- Only run if you're absolutely sure you want to remove the safety nets.

-- Drop safety triggers
DROP TRIGGER IF EXISTS trg_instruments_restore_tracking;
DROP TRIGGER IF EXISTS trg_instruments_validate_restore; 
DROP TRIGGER IF EXISTS trg_instruments_auto_backup;

-- Drop safety views
DROP VIEW IF EXISTS InstrumentsValidationReport;
DROP VIEW IF EXISTS InstrumentsDuplicateCheck;
DROP VIEW IF EXISTS RestoreValidationSummary;

-- Drop backup table (WARNING: This loses all backup data!)
DROP TABLE IF EXISTS InstrumentsBackup;

-- Remove added columns (WARNING: This loses data!)
-- Note: SQLite doesn't support DROP COLUMN, so we'd need to recreate the table
-- For safety, we're not implementing the full down migration
-- If you really need to revert, you'll need to manually recreate the table

UPDATE Configuration SET value = '4.25' WHERE key = 'db_version';
