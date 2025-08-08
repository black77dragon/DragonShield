CREATE TABLE PortfolioInstruments_new (
    portfolio_id INTEGER NOT NULL,
    instrument_id INTEGER NOT NULL,
    assigned_date DATE DEFAULT CURRENT_DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (portfolio_id, instrument_id),
    FOREIGN KEY (portfolio_id) REFERENCES Portfolios(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY (instrument_id) REFERENCES Instruments(instrument_id) ON DELETE CASCADE
);
INSERT INTO PortfolioInstruments_new (portfolio_id, instrument_id, assigned_date, created_at)
    SELECT portfolio_id, instrument_id, assigned_date, created_at
    FROM PortfolioInstruments;
DROP TABLE PortfolioInstruments;
ALTER TABLE PortfolioInstruments_new RENAME TO PortfolioInstruments;
CREATE INDEX idx_portfolio_instruments_instrument ON PortfolioInstruments(instrument_id);
