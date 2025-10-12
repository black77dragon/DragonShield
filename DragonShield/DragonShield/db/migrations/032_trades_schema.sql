-- migrate:up
-- Introduce Trade (header) and TradeLeg (two legs per trade) for buy/sell transactions.
-- Notes: SQLite dialect, timestamps stored as ISO8601 UTC strings.

CREATE TABLE IF NOT EXISTS Trade (
  trade_id        INTEGER PRIMARY KEY,
  type_code       TEXT    NOT NULL CHECK (type_code IN ('BUY','SELL')),
  trade_date      TEXT    NOT NULL, -- YYYY-MM-DD
  instrument_id   INTEGER NOT NULL REFERENCES Instruments(instrument_id),
  quantity        REAL    NOT NULL,
  price_txn       REAL    NOT NULL,
  currency_code   TEXT    NOT NULL REFERENCES Currencies(currency_code),
  fees_chf        REAL    NOT NULL DEFAULT 0,
  commission_chf  REAL    NOT NULL DEFAULT 0,
  fx_chf_to_txn   REAL    NULL, -- CHF -> transaction currency rate used for fees conversion
  notes           TEXT    NULL,
  created_at      TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at      TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_trade_date   ON Trade(trade_date);
CREATE INDEX IF NOT EXISTS idx_trade_instr  ON Trade(instrument_id);

CREATE TABLE IF NOT EXISTS TradeLeg (
  leg_id        INTEGER PRIMARY KEY,
  trade_id      INTEGER NOT NULL REFERENCES Trade(trade_id) ON DELETE CASCADE,
  leg_type      TEXT    NOT NULL CHECK (leg_type IN ('CASH','INSTRUMENT')),
  account_id    INTEGER NOT NULL REFERENCES Accounts(account_id),
  instrument_id INTEGER NOT NULL REFERENCES Instruments(instrument_id),
  delta_quantity REAL   NOT NULL,  -- cash delta (txn currency) for CASH leg; +/- qty for INSTRUMENT leg
  fx_to_chf     REAL    NULL,      -- optional normalized reporting
  amount_chf    REAL    NULL,
  created_at    TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at    TEXT    NOT NULL DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(trade_id, leg_type)
);

CREATE INDEX IF NOT EXISTS idx_tradeleg_account ON TradeLeg(account_id);
CREATE INDEX IF NOT EXISTS idx_tradeleg_instr   ON TradeLeg(instrument_id);

-- migrate:down
DROP INDEX IF EXISTS idx_tradeleg_instr;
DROP INDEX IF EXISTS idx_tradeleg_account;
DROP TABLE IF EXISTS TradeLeg;
DROP INDEX IF EXISTS idx_trade_instr;
DROP INDEX IF EXISTS idx_trade_date;
DROP TABLE IF EXISTS Trade;

