-- migrate:up
-- Purpose: enforce cascading deletes from asset classes down to position reports
-- Assumptions: existing records have valid foreign-key relations; triggers and indexes will be recreated
-- Idempotency: recreates tables using temporary names; safe to run once

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

-- migrate:down
-- Purpose: revert cascading deletes to previous restrict behavior
-- Assumptions: data fits original constraints
-- Idempotency: recreates tables without ON DELETE CASCADE

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
