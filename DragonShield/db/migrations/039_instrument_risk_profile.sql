-- migrate:up
-- Purpose: Add instrument-level risk profile storage (SRI + liquidity tiers, overrides, audit) and seed default mappings for existing instrument types.
-- Assumptions: Instruments and AssetSubClasses exist; SQLite json1 available for json_valid/json_object; mapping inserts are conditional on matching sub_class_code.
-- Idempotency: CREATE TABLE/INDEX/trigger IF NOT EXISTS; inserts use INSERT OR IGNORE or conflict handlers; backfill skips existing profiles.

CREATE TABLE IF NOT EXISTS InstrumentRiskMapping (
    sub_class_id INTEGER PRIMARY KEY,
    default_sri INTEGER NOT NULL CHECK (default_sri BETWEEN 1 AND 7),
    default_liquidity_tier INTEGER NOT NULL CHECK (default_liquidity_tier BETWEEN 0 AND 2),
    rationale TEXT,
    mapping_version TEXT NOT NULL DEFAULT 'risk_map_v1',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sub_class_id) REFERENCES AssetSubClasses(sub_class_id) ON DELETE CASCADE
);

CREATE TRIGGER IF NOT EXISTS trg_instrument_risk_mapping_updated_at
AFTER UPDATE ON InstrumentRiskMapping
BEGIN
    UPDATE InstrumentRiskMapping
       SET updated_at = CURRENT_TIMESTAMP
     WHERE sub_class_id = NEW.sub_class_id;
END;

CREATE TABLE IF NOT EXISTS InstrumentRiskProfile (
    instrument_id INTEGER PRIMARY KEY,
    computed_sri INTEGER NOT NULL CHECK (computed_sri BETWEEN 1 AND 7),
    computed_liquidity_tier INTEGER NOT NULL CHECK (computed_liquidity_tier BETWEEN 0 AND 2),
    manual_override BOOLEAN NOT NULL DEFAULT 0,
    override_sri INTEGER CHECK (override_sri BETWEEN 1 AND 7),
    override_liquidity_tier INTEGER CHECK (override_liquidity_tier BETWEEN 0 AND 2),
    override_reason TEXT,
    override_by TEXT,
    override_expires_at DATETIME,
    calc_method TEXT,
    mapping_version TEXT NOT NULL DEFAULT 'risk_map_v1',
    calc_inputs_json TEXT CHECK (calc_inputs_json IS NULL OR json_valid(calc_inputs_json)),
    calculated_at DATETIME,
    recalc_due_at DATETIME,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id) ON DELETE CASCADE
);

CREATE TRIGGER IF NOT EXISTS trg_instrument_risk_profile_updated_at
AFTER UPDATE ON InstrumentRiskProfile
BEGIN
    UPDATE InstrumentRiskProfile
       SET updated_at = CURRENT_TIMESTAMP
     WHERE instrument_id = NEW.instrument_id;
END;

-- Config defaults for mapping version and unmapped fallback behavior
INSERT INTO Configuration (key, value, data_type, description, updated_at)
VALUES ('risk_mapping_version', 'risk_map_v1', 'string', 'Version tag for instrument risk type mapping defaults', STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
ON CONFLICT(key) DO UPDATE SET
  value = excluded.value,
  data_type = excluded.data_type,
  description = COALESCE(excluded.description, Configuration.description),
  updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now');

INSERT INTO Configuration (key, value, data_type, description, updated_at)
VALUES ('risk_default_sri', '5', 'number', 'Default SRI applied when an instrument type has no mapping', STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
ON CONFLICT(key) DO UPDATE SET
  value = excluded.value,
  data_type = excluded.data_type,
  description = COALESCE(excluded.description, Configuration.description),
  updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now');

INSERT INTO Configuration (key, value, data_type, description, updated_at)
VALUES ('risk_default_liquidity_tier', '1', 'number', 'Default liquidity tier (0=Liquid,1=Restricted,2=Illiquid) for unmapped types', STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
ON CONFLICT(key) DO UPDATE SET
  value = excluded.value,
  data_type = excluded.data_type,
  description = COALESCE(excluded.description, Configuration.description),
  updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now');

-- Seed mapping entries for known instrument type codes (conditional on existence)
INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 1, 0, 'Risk-free base asset'
FROM AssetSubClasses WHERE sub_class_code = 'CASH';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 1, 0, 'Short-term, high safety'
FROM AssetSubClasses WHERE sub_class_code = 'MM_INST';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 1, 2, 'Restricted access; payout timing risk'
FROM AssetSubClasses WHERE sub_class_code = 'DEF_CASH';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 2, 0, 'Developed market sovereign; EM => 3'
FROM AssetSubClasses WHERE sub_class_code = 'GOV_BOND';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 3, 0, 'Investment grade corporate credit assumption'
FROM AssetSubClasses WHERE sub_class_code = 'CORP_BOND';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 3, 0, 'Diversified bond basket'
FROM AssetSubClasses WHERE sub_class_code = 'BOND_ETF';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 6, 2, 'Unsecured consumer/SME credit; funding risk'
FROM AssetSubClasses WHERE sub_class_code = 'DLP2P';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 5, 0, 'Idiosyncratic equity risk'
FROM AssetSubClasses WHERE sub_class_code = 'STOCK';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 4, 0, 'Diversified market beta'
FROM AssetSubClasses WHERE sub_class_code = 'EQUITY_ETF';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 4, 0, 'Diversified, active management'
FROM AssetSubClasses WHERE sub_class_code = 'EQUITY_FUND';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 7, 0, 'Extreme volatility and tail risk'
FROM AssetSubClasses WHERE sub_class_code = 'CRYPTO';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 6, 0, 'Diversified but high-vol asset class'
FROM AssetSubClasses WHERE sub_class_code = 'CRYPTO_FUND';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 6, 0, 'High beta to crypto markets'
FROM AssetSubClasses WHERE sub_class_code = 'CRYP_STOCK';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 2, 2, 'Slow exit; relatively stable pricing'
FROM AssetSubClasses WHERE sub_class_code = 'DIRECT_RE';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 5, 0, 'Rate and credit-spread sensitive'
FROM AssetSubClasses WHERE sub_class_code = 'MORT_REIT';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 5, 0, 'High volatility (commodities)'
FROM AssetSubClasses WHERE sub_class_code = 'COMMOD';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 3, 2, 'Regulated/stable returns; slow to exit'
FROM AssetSubClasses WHERE sub_class_code = 'INFRA';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 6, 2, 'Issuer risk; embedded barriers/paths'
FROM AssetSubClasses WHERE sub_class_code = 'STRUCTURED';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 7, 0, 'Leverage; full loss possible'
FROM AssetSubClasses WHERE sub_class_code = 'OPTION';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 7, 0, 'Leverage; tail exposure'
FROM AssetSubClasses WHERE sub_class_code = 'FUTURE';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 5, 1, 'Strategies vary; gates/lockups common'
FROM AssetSubClasses WHERE sub_class_code = 'HEDGE_FUND';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 2, 2, 'Long-dated, capital-protected frameworks'
FROM AssetSubClasses WHERE sub_class_code = 'PENSION_2';

INSERT OR IGNORE INTO InstrumentRiskMapping (sub_class_id, default_sri, default_liquidity_tier, rationale)
SELECT sub_class_id, 2, 2, 'Long-term contract; low volatility'
FROM AssetSubClasses WHERE sub_class_code = 'LIFIN';

-- Backfill one profile per instrument with mapping defaults or fallback values
INSERT INTO InstrumentRiskProfile (
    instrument_id,
    computed_sri,
    computed_liquidity_tier,
    manual_override,
    calc_method,
    mapping_version,
    calc_inputs_json,
    calculated_at,
    recalc_due_at
)
SELECT
    i.instrument_id,
    COALESCE(m.default_sri, 5) AS computed_sri,
    COALESCE(m.default_liquidity_tier, 1) AS computed_liquidity_tier,
    0 AS manual_override,
    CASE WHEN m.sub_class_id IS NOT NULL THEN 'mapping:v1' ELSE 'default:unmapped' END AS calc_method,
    COALESCE(m.mapping_version, 'risk_map_v1') AS mapping_version,
    CASE
        WHEN m.sub_class_id IS NOT NULL THEN json_object('source','migration_seed','sub_class_code', asc.sub_class_code)
        ELSE json_object('source','migration_seed','sub_class_code', asc.sub_class_code, 'unmapped', 1)
    END AS calc_inputs_json,
    STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') AS calculated_at,
    STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') AS recalc_due_at
FROM Instruments i
LEFT JOIN AssetSubClasses asc ON asc.sub_class_id = i.sub_class_id
LEFT JOIN InstrumentRiskMapping m ON m.sub_class_id = asc.sub_class_id
WHERE NOT EXISTS (
    SELECT 1 FROM InstrumentRiskProfile irp WHERE irp.instrument_id = i.instrument_id
);

-- migrate:down
-- Purpose: Drop risk profile and mapping artifacts and remove related configuration keys.
-- Idempotency: Drops objects if they exist; config deletes are conditional via WHERE.

DROP TRIGGER IF EXISTS trg_instrument_risk_profile_updated_at;
DROP TRIGGER IF EXISTS trg_instrument_risk_mapping_updated_at;
DROP TABLE IF EXISTS InstrumentRiskProfile;
DROP TABLE IF EXISTS InstrumentRiskMapping;

DELETE FROM Configuration WHERE key IN ('risk_mapping_version','risk_default_sri','risk_default_liquidity_tier');
