PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE Configuration (
    config_id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    data_type TEXT NOT NULL CHECK (data_type IN ('string', 'number', 'boolean', 'date')),
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO Configuration VALUES ('1', 'base_currency', 'CHF', 'string', 'Base reporting currency', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('2', 'as_of_date', '2025-05-24', 'date', 'Portfolio cut-off date for calculations', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('3', 'decimal_precision', '4', 'number', 'Decimal precision for financial calculations', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('4', 'auto_fx_update', 'true', 'boolean', 'Enable automatic FX rate updates', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('5', 'fx_api_provider', 'exchangerate-api', 'string', 'FX rate API provider', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('6', 'fx_update_frequency', 'daily', 'string', 'FX rate update frequency', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('7', 'default_timezone', 'Europe/Zurich', 'string', 'Default timezone for the application', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('8', 'table_row_spacing', '1.0', 'number', 'Spacing between table rows in points', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('9', 'table_row_padding', '12.0', 'number', 'Vertical padding inside table rows in points', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('10', 'table_font_size', '14.0', 'number', 'Font size for text in data table rows (in points)', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Configuration VALUES ('12', 'db_version', '4.13', 'string', 'Database schema version', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
CREATE TABLE Currencies (
    currency_code TEXT PRIMARY KEY,
    currency_name TEXT NOT NULL,
    currency_symbol TEXT,
    is_active BOOLEAN DEFAULT 1,
    api_supported BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO Currencies VALUES ('CHF', 'Swiss Franc', 'CHF', '1', '0', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('EUR', 'Euro', '€', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('USD', 'US Dollar', '$', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('GBP', 'British Pound', '£', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('JPY', 'Japanese Yen', '¥', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('CAD', 'Canadian Dollar', 'C$', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('AUD', 'Australian Dollar', 'A$', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('SEK', 'Swedish Krona', 'SEK', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('NOK', 'Norwegian Krone', 'NOK', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('DKK', 'Danish Krone', 'DKK', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('CNY', 'Chinese Yuan', '¥', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('HKD', 'Hong Kong Dollar', 'HK$', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('SGD', 'Singapore Dollar', 'S$', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('BTC', 'Bitcoin', '₿', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO Currencies VALUES ('ETH', 'Ethereum', 'Ξ', '1', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
CREATE TABLE ExchangeRates (
    rate_id INTEGER PRIMARY KEY AUTOINCREMENT,
    currency_code TEXT NOT NULL,
    rate_date DATE NOT NULL,
    rate_to_chf REAL NOT NULL CHECK (rate_to_chf > 0),
    rate_source TEXT DEFAULT 'manual' CHECK (rate_source IN ('manual', 'api', 'import')),
    api_provider TEXT,
    is_latest BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (currency_code) REFERENCES Currencies(currency_code),
    UNIQUE(currency_code, rate_date)
);
INSERT INTO ExchangeRates VALUES ('1', 'CHF', '2025-05-24', '1.0', 'manual', NULL, '1', '2025-07-12 13:36:36');
INSERT INTO ExchangeRates VALUES ('2', 'EUR', '2025-05-24', '0.92', 'api', NULL, '1', '2025-07-12 13:36:36');
INSERT INTO ExchangeRates VALUES ('3', 'USD', '2025-05-24', '0.88', 'api', NULL, '1', '2025-07-12 13:36:36');
INSERT INTO ExchangeRates VALUES ('4', 'GBP', '2025-05-24', '0.785', 'api', NULL, '1', '2025-07-12 13:36:36');
INSERT INTO ExchangeRates VALUES ('5', 'JPY', '2025-05-24', '0.0058', 'api', NULL, '1', '2025-07-12 13:36:36');
INSERT INTO ExchangeRates VALUES ('6', 'BTC', '2025-05-24', '59280.0', 'api', NULL, '1', '2025-07-12 13:36:36');
INSERT INTO ExchangeRates VALUES ('7', 'ETH', '2025-05-24', '2890.5', 'api', NULL, '1', '2025-07-12 13:36:36');
CREATE TABLE AssetClasses (
    class_id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_code TEXT NOT NULL UNIQUE,
    class_name TEXT NOT NULL,
    class_description TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO AssetClasses VALUES ('1', 'LIQ', 'Liquidity', 'Cash and money market instruments', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetClasses VALUES ('2', 'EQ', 'Equity', 'Publicly traded equities', '2', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetClasses VALUES ('3', 'FI', 'Fixed Income', 'Government and corporate bonds', '3', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetClasses VALUES ('4', 'REAL', 'Real Assets', 'Physical real estate and commodities', '4', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetClasses VALUES ('5', 'ALT', 'Alternatives', 'Hedge funds and private equity', '5', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetClasses VALUES ('6', 'DERIV', 'Derivatives', 'Options and futures', '6', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetClasses VALUES ('7', 'OTHER', 'Other', 'Other investment instruments', '9', '2025-07-12 13:36:36', '2025-07-12 14:36:35');
INSERT INTO AssetClasses VALUES ('8', 'CRYP', 'Crypto Currency', 'Digital Assets Bitcoin, L1, L2, L3', '7', '2025-07-12 14:34:51', '2025-07-12 14:34:51');
INSERT INTO AssetClasses VALUES ('9', 'COMM', 'Commodity', 'Physical goods traded on exchange (metals, energy, agriculture)', '8', '2025-07-12 14:36:12', '2025-07-12 14:36:27');
CREATE TABLE AssetSubClasses (
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
INSERT INTO AssetSubClasses VALUES ('1', '1', 'CASH', 'Cash', NULL, '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('2', '1', 'MM_INST', 'Money Market Instruments', NULL, '2', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('3', '2', 'STOCK', 'Single Stock', NULL, '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('4', '2', 'EQUITY_ETF', 'Equity ETF', NULL, '2', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('5', '2', 'EQUITY_FUND', 'Equity Fund', NULL, '3', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('6', '2', 'EQUITY_REIT', 'Equity REIT', NULL, '4', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('7', '3', 'GOV_BOND', 'Government Bond', NULL, '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('8', '3', 'CORP_BOND', 'Corporate Bond', NULL, '2', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('9', '3', 'BOND_ETF', 'Bond ETF', NULL, '3', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('10', '3', 'BOND_FUND', 'Bond Fund', NULL, '4', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('11', '4', 'DIRECT_RE', 'Direct Real Estate', NULL, '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('12', '4', 'MORT_REIT', 'Mortgage REIT', NULL, '2', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('13', '4', 'COMMOD', 'Commodities', NULL, '3', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('14', '4', 'INFRA', 'Infrastructure', 'physical real estate', '4', '2025-07-12 13:36:36', '2025-07-12 14:38:48');
INSERT INTO AssetSubClasses VALUES ('15', '5', 'HEDGE_FUND', 'Hedge Fund', NULL, '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('16', '5', 'PRIVATE', 'Private Equity / Debt', NULL, '2', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('17', '5', 'STRUCTURED', 'Structured Product', NULL, '3', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('18', '5', 'CRYPTO', 'Cryptocurrency', NULL, '4', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('19', '6', 'OPTION', 'Options', NULL, '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('20', '6', 'FUTURE', 'Futures', NULL, '2', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AssetSubClasses VALUES ('21', '7', 'OTHER', 'Other', NULL, '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
CREATE TABLE AccountTypes (
    account_type_id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_code TEXT NOT NULL UNIQUE, -- e.g., 'BANK', 'CUSTODY'
    type_name TEXT NOT NULL,        -- e.g., 'Bank Account', 'Custody Account'
    type_description TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO AccountTypes VALUES ('1', 'BANK', 'Bank Account', 'Standard bank checking or savings account', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AccountTypes VALUES ('2', 'CUSTODY', 'Custody Account', 'Brokerage or custody account for securities (from Banks, Hedge Funds etc.)', '1', '2025-07-12 13:36:36', '2025-07-12 14:32:45');
INSERT INTO AccountTypes VALUES ('3', 'CRYPTO', 'Crypto Wallet/Account', 'Account for holding cryptocurrencies', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AccountTypes VALUES ('4', 'PENSION', 'Pension Account', 'Retirement or pension savings account', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AccountTypes VALUES ('5', 'CASH', 'Cash Account', 'Physical cash or simple cash holdings', '1', '2025-07-12 13:36:36', '2025-07-12 13:36:36');
INSERT INTO AccountTypes VALUES ('6', 'REAL_ESTATE', 'Real Estate', 'Physical real estate owned by the Keller Family', '1', '2025-07-12 14:33:15', '2025-07-12 14:33:44');
CREATE TABLE Institutions (
    institution_id INTEGER PRIMARY KEY AUTOINCREMENT,
    institution_name TEXT NOT NULL,
    institution_type TEXT,
    bic TEXT,
    website TEXT,
    contact_info TEXT,
    default_currency TEXT CHECK (LENGTH(default_currency) = 3),
    country_code TEXT CHECK (LENGTH(country_code) = 2),
    notes TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO Institutions VALUES ('1', 'Equate Plus (to be replaced)', 'Deferred Compensation', 'n/a', NULL, 'to be enhanced', 'GBP', 'GB', 'Deferred Compensation Standard Chartered', '1', '2025-07-08 00:00:00', '2025-07-12 14:26:44');
INSERT INTO Institutions VALUES ('2', 'Credit Suisse', 'Bank', 'CRESCHZZ80A', 'https://www.credit-suisse.com', 'Christoph Birrer', 'CHF', 'CH', NULL, '1', '2025-07-08 00:00:00', '2025-07-12 14:17:57');
INSERT INTO Institutions VALUES ('3', 'Sygnum Bank', 'Bank', 'SYGNCHZZ', 'https://www.sygnum.com', 'info@sygnum.com', 'CHF', 'CH', 'Digital asset bank', '1', '2025-07-08 00:00:00', '2025-07-12 14:24:32');
INSERT INTO Institutions VALUES ('4', 'Graubündner Kantonalbank', 'Bank', 'GRKBCH2270A', 'https://www.gkb.ch', 'info@gkb.ch', 'CHF', 'CH', 'Regional cantonal bank', '1', '2025-07-08 00:00:00', '2025-07-12 14:24:13');
INSERT INTO Institutions VALUES ('5', 'Standard Chartered Bank Singapore', 'Bank', 'SCBLSGSG', 'https://www.sc.com/sg', 'contactus.sg@sc.com', 'SGD', 'SG', 'International bank', '1', '2025-07-08 00:00:00', '2025-07-12 14:24:21');
INSERT INTO Institutions VALUES ('6', 'Bitbox (Switzerland)', 'Crypto Hardware Wallet Producer', 'n/a', 'https://bitbox.swiss/', 'web support', 'BTC', 'CH', 'Self-custody hardware wallet provider', '1', '2025-07-08 00:00:00', '2025-07-12 14:19:05');
INSERT INTO Institutions VALUES ('7', 'Ledger SAS', 'Crypto Hardware Wallet Producer', 'n/a', 'https://www.ledger.com', 'support@ledger.com', 'BTC', 'FR', 'Self-custody hardware wallet', '1', '2025-07-08 00:00:00', '2025-07-12 14:20:47');
INSERT INTO Institutions VALUES ('8', 'Swisspeers', 'Peer2Peer Marketplace', 'n/a', 'https://www.swisspeers.ch', 'info@swisspeers.ch', 'CHF', 'CH', 'P2P lending marketplace', '1', '2025-07-08 00:00:00', '2025-07-12 14:31:01');
INSERT INTO Institutions VALUES ('9', 'Crypto.com Crypto Exchange', 'Crypto Exchange', 'n/a', 'https://crypto.com', 'contact@crypto.com', 'USD', 'SG', 'Crypto exchange

Account Holder Name:
Rene Walter Keller
IBAN: MT37CFTE28004000000000004267296
BIC/SWIFT Code: CFTEMTM1
Bank Name: OpenPayd
Bank Address: Level 3, 137 Spinola Road St. Julian’s STJ 3011
Bank Institution Country: Malta MT
', '1', '2025-07-08 00:00:00', '2025-07-12 14:31:11');
INSERT INTO Institutions VALUES ('10', 'Coinkite Inc', 'Crypto Hardware Wallet Producer', 'n/a', 'https://coldcard.com', 'support@coinkite.com', 'BTC', 'CA', 'Self-custody hardware wallet', '1', '2025-07-08 00:00:00', '2025-07-12 14:20:37');
INSERT INTO Institutions VALUES ('11', 'Libertas Fund LLC', 'Hedge Fund', 'n/a', 'https://www.hyperiondecimus.com/', 'Chris Sullivan', 'USD', 'KY', 'Hyperion Decimus, LLC (DE foreign LLC; HQ: Maitland, FL) 
Delaware-registered LLC (Foreign in Florida)', '1', '2025-07-12 14:25:32', '2025-07-12 14:30:39');
INSERT INTO Institutions VALUES ('12', 'Züricher Kantonal Bank ZKB', 'Bank', 'ZKBKCHZZ80A', 'www.zkb.ch', 'Oliver Lanz', 'CHF', 'CH', NULL, '1', '2025-07-12 14:27:50', '2025-07-12 14:27:50');
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
INSERT INTO TransactionTypes VALUES ('1', 'BUY', 'Purchase', 'Buy securities or assets', '1', '1', '0', '1');
INSERT INTO TransactionTypes VALUES ('2', 'SELL', 'Sale', 'Sell securities or assets', '1', '1', '0', '2');
INSERT INTO TransactionTypes VALUES ('3', 'DIVIDEND', 'Dividend', 'Dividend payment received', '0', '1', '1', '3');
INSERT INTO TransactionTypes VALUES ('4', 'INTEREST', 'Interest', 'Interest payment received', '0', '1', '1', '4');
INSERT INTO TransactionTypes VALUES ('5', 'FEE', 'Fee', 'Transaction or management fee', '0', '1', '0', '5');
INSERT INTO TransactionTypes VALUES ('6', 'TAX', 'Tax', 'Withholding tax or other taxes', '0', '1', '0', '6');
INSERT INTO TransactionTypes VALUES ('7', 'DEPOSIT', 'Cash Deposit', 'Cash deposit to account', '0', '1', '0', '7');
INSERT INTO TransactionTypes VALUES ('8', 'WITHDRAWAL', 'Cash Withdrawal', 'Cash withdrawal from account', '0', '1', '0', '8');
INSERT INTO TransactionTypes VALUES ('9', 'TRANSFER_IN', 'Transfer In', 'Securities transferred into account', '1', '0', '0', '9');
INSERT INTO TransactionTypes VALUES ('10', 'TRANSFER_OUT', 'Transfer Out', 'Securities transferred out of account', '1', '0', '0', '10');
COMMIT;
PRAGMA foreign_keys=ON;
