-- migrate:up
-- Purpose: Add InstrumentPrice table as single source of truth for instrument prices

CREATE TABLE IF NOT EXISTS InstrumentPrice (
  instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id) ON DELETE CASCADE,
  price         REAL    NOT NULL,
  currency      TEXT    NOT NULL,
  source        TEXT    NULL,
  as_of         TEXT    NOT NULL,
  created_at    TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (instrument_id, as_of, COALESCE(source, ''))
);

CREATE INDEX IF NOT EXISTS idx_instr_price_latest ON InstrumentPrice(instrument_id, as_of DESC);

-- Optional view for latest price per instrument
CREATE VIEW IF NOT EXISTS InstrumentPriceLatest AS
SELECT ip1.instrument_id, ip1.price, ip1.currency, ip1.source, ip1.as_of
FROM InstrumentPrice ip1
WHERE ip1.as_of = (
  SELECT MAX(ip2.as_of)
  FROM InstrumentPrice ip2
  WHERE ip2.instrument_id = ip1.instrument_id
);

-- Seed from PositionReports: take most recent report_date with a current_price per instrument
INSERT INTO InstrumentPrice(instrument_id, price, currency, source, as_of)
SELECT pr.instrument_id,
       pr.current_price,
       i.currency,
       'seed_position',
       pr.report_date
FROM PositionReports pr
JOIN Instruments i ON i.instrument_id = pr.instrument_id
WHERE pr.current_price IS NOT NULL
  AND pr.report_date IS NOT NULL
  AND pr.report_date = (
      SELECT MAX(pr2.report_date)
      FROM PositionReports pr2
      WHERE pr2.instrument_id = pr.instrument_id
        AND pr2.current_price IS NOT NULL
  );

-- migrate:down
DROP VIEW IF EXISTS InstrumentPriceLatest;
DROP TABLE IF EXISTS InstrumentPrice;

