-- =============================================================================
-- Dragonshield v4.18 to v4.20 Data Migration Script (Final)
-- =============================================================================
-- INSTRUCTIONS:
-- 1. Close and re-open DB Browser for SQLite to ensure a clean session.
-- 2. Open your NEW, EMPTY v4.20 database file.
-- 3. Run this entire script at once in the "Execute SQL" tab.
-- 4. When it finishes, close and re-open the database file to finalize.
-- =============================================================================

-- Step 1: Attach the old v4.18 database to the current connection.
ATTACH DATABASE '/Users/renekeller/Library/Containers/com.rene.DragonShield/Data/Library/Application Support/DragonShield/dragonshield 4.18.sqlite' AS old_db;

-- Step 2: Migrate data for tables with identical structures.
INSERT INTO main.AssetClasses SELECT * FROM old_db.AssetClasses;
INSERT INTO main.AssetSubClasses SELECT * FROM old_db.AssetSubClasses;
INSERT INTO main.Currencies SELECT * FROM old_db.Currencies;
INSERT INTO main.Configuration SELECT * FROM old_db.Configuration;
INSERT INTO main.Institutions SELECT * FROM old_db.Institutions;
INSERT INTO main.AccountTypes SELECT * FROM old_db.AccountTypes;
INSERT INTO main.Accounts SELECT * FROM old_db.Accounts;
INSERT INTO main.Instruments SELECT * FROM old_db.Instruments;
INSERT INTO main.Portfolios SELECT * FROM old_db.Portfolios;
INSERT INTO main.Transactions SELECT * FROM old_db.Transactions;
INSERT INTO main.ExchangeRates SELECT * FROM old_db.ExchangeRates;
INSERT INTO main.ImportSessions SELECT * FROM old_db.ImportSessions;
INSERT INTO main.PositionReports SELECT * FROM old_db.PositionReports;
INSERT INTO main.TransactionTypes SELECT * FROM old_db.TransactionTypes;
INSERT INTO main.FxRateUpdates SELECT * FROM old_db.FxRateUpdates;

-- Step 3: Migrate data for tables with modified structures.

-- PortfolioInstruments: The 'target_allocation_percent' column was removed in v4.20.
INSERT INTO main.PortfolioInstruments (portfolio_id, instrument_id, assigned_date, created_at)
SELECT portfolio_id, instrument_id, assigned_date, created_at FROM old_db.PortfolioInstruments;

-- TargetAllocation: This is the corrected section to handle duplicates.
-- It now de-duplicates targets for the same asset_class_id by picking the most recent entry.
INSERT INTO main.ClassTargets (asset_class_id, target_kind, target_percent, target_amount_chf, tolerance_percent, created_at, updated_at)
SELECT
    t1.asset_class_id,
    t1.target_kind,
    t1.target_percent,
    t1.target_amount_chf,
    t1.tolerance_percent,
    t1.updated_at,
    t1.updated_at
FROM old_db.TargetAllocation AS t1
INNER JOIN (
    SELECT asset_class_id, MAX(allocation_id) AS max_id
    FROM old_db.TargetAllocation
    WHERE sub_class_id IS NULL
    GROUP BY asset_class_id
) AS t2 ON t1.asset_class_id = t2.asset_class_id AND t1.allocation_id = t2.max_id;

-- Second, migrate targets that apply to a specific sub-class. This part remains the same.
INSERT INTO main.SubClassTargets (class_target_id, asset_sub_class_id, target_kind, target_percent, target_amount_chf, tolerance_percent, created_at, updated_at)
SELECT
    ct.id,
    ta.sub_class_id,
    ta.target_kind,
    ta.target_percent,
    ta.target_amount_chf,
    ta.tolerance_percent,
    ta.updated_at,
    ta.updated_at
FROM old_db.TargetAllocation AS ta
JOIN main.ClassTargets AS ct ON ta.asset_class_id = ct.asset_class_id
WHERE ta.sub_class_id IS NOT NULL;

-- Step 4: Update the sequence numbers for tables with AUTOINCREMENT.
INSERT OR REPLACE INTO main.sqlite_sequence (name, seq)
SELECT name, seq FROM old_db.sqlite_sequence;

-- =============================================================================
-- Migration Complete. Please close and re-open the database.
-- =============================================================================
