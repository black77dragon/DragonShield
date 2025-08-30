-- migrate:up
-- Adds InstrumentPriceSource to map instruments to external provider identifiers

CREATE TABLE IF NOT EXISTS InstrumentPriceSource (
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

CREATE UNIQUE INDEX IF NOT EXISTS uq_price_source_instrument_provider
  ON InstrumentPriceSource(instrument_id, provider_code);

CREATE INDEX IF NOT EXISTS idx_price_source_provider
  ON InstrumentPriceSource(provider_code, enabled, priority);

-- Optional fetch log (audit)
CREATE TABLE IF NOT EXISTS InstrumentPriceFetchLog (
  id             INTEGER PRIMARY KEY,
  instrument_id  INTEGER,
  provider_code  TEXT,
  external_id    TEXT,
  status         TEXT NOT NULL,
  message        TEXT,
  created_at     TEXT NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- migrate:down
DROP TABLE IF EXISTS InstrumentPriceFetchLog;
DROP TABLE IF EXISTS InstrumentPriceSource;

