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
INSERT INTO Configuration VALUES ('1', 'base_currency', 'CHF', 'string', 'Base reporting currency', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('2', 'as_of_date', '2025-05-24', 'date', 'Portfolio cut-off date for calculations', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('3', 'decimal_precision', '4', 'number', 'Decimal precision for financial calculations', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('4', 'auto_fx_update', 'true', 'boolean', 'Enable automatic FX rate updates', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('5', 'fx_api_provider', 'exchangerate-api', 'string', 'FX rate API provider', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('6', 'fx_update_frequency', 'daily', 'string', 'FX rate update frequency', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('7', 'default_timezone', 'Europe/Zurich', 'string', 'Default timezone for the application', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('8', 'table_row_spacing', '1.0', 'number', 'Spacing between table rows in points', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('9', 'table_row_padding', '12.0', 'number', 'Vertical padding inside table rows in points', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('10', 'table_font_size', '14.0', 'number', 'Font size for text in data table rows (in points)', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('11', 'include_direct_re', 'true', 'boolean', 'Include direct real estate in allocation views', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('12', 'direct_re_target_chf', '0', 'number', 'Target CHF amount for direct real estate', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Configuration VALUES ('13', 'db_version', '4.15', 'string', 'Database schema version', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
CREATE TABLE Currencies (
    currency_code TEXT PRIMARY KEY,
    currency_name TEXT NOT NULL,
    currency_symbol TEXT,
    is_active BOOLEAN DEFAULT 1,
    api_supported BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO Currencies VALUES ('CHF', 'Swiss Franc', 'CHF', '1', '0', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('EUR', 'Euro', '€', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('USD', 'US Dollar', '$', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('GBP', 'British Pound', '£', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('JPY', 'Japanese Yen', '¥', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('CAD', 'Canadian Dollar', 'C$', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('AUD', 'Australian Dollar', 'A$', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('SEK', 'Swedish Krona', 'SEK', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('NOK', 'Norwegian Krone', 'NOK', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('DKK', 'Danish Krone', 'DKK', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('CNY', 'Chinese Yuan', '¥', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('HKD', 'Hong Kong Dollar', 'HK$', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('SGD', 'Singapore Dollar', 'S$', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('BTC', 'Bitcoin', '₿', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Currencies VALUES ('ETH', 'Ethereum', 'Ξ', '1', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
CREATE TABLE AssetClasses (
    class_id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_code TEXT NOT NULL UNIQUE,
    class_name TEXT NOT NULL,
    class_description TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO AssetClasses VALUES ('1', 'LIQ', 'Liquidity', 'Cash and money market instruments', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetClasses VALUES ('2', 'EQ', 'Equity', 'Publicly traded equities', '2', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetClasses VALUES ('3', 'FI', 'Fixed Income', 'Government and corporate bonds', '3', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetClasses VALUES ('4', 'REAL', 'Real Assets', 'Physical real estate and commodities', '4', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetClasses VALUES ('5', 'ALT', 'Alternatives', 'Hedge funds and private equity', '5', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetClasses VALUES ('6', 'DERIV', 'Derivatives', 'Options and futures', '6', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetClasses VALUES ('7', 'CRYP', 'Crypto Currency', 'Digital Assets Bitcoin, L1, L2, L3', '7', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetClasses VALUES ('8', 'COMM', 'Commodity', 'Physical goods traded on exchange (metals, energy, agriculture)', '8', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetClasses VALUES ('9', 'OTHER', 'Other', 'Other investment instruments', '9', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
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
INSERT INTO AssetSubClasses VALUES ('1', '1', 'CASH', 'Cash', NULL, '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('2', '1', 'MM_INST', 'Money Market Instruments', NULL, '2', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('3', '2', 'STOCK', 'Single Stock', NULL, '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('4', '2', 'EQUITY_ETF', 'Equity ETF', NULL, '2', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('5', '2', 'EQUITY_FUND', 'Equity Fund', NULL, '3', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('6', '2', 'EQUITY_REIT', 'Equity REIT', NULL, '4', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('7', '3', 'GOV_BOND', 'Government Bond', NULL, '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('8', '3', 'CORP_BOND', 'Corporate Bond', NULL, '2', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('9', '3', 'BOND_ETF', 'Bond ETF', NULL, '3', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('10', '3', 'BOND_FUND', 'Bond Fund', NULL, '4', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('11', '4', 'DIRECT_RE', 'Direct Real Estate', NULL, '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('12', '4', 'MORT_REIT', 'Mortgage REIT', NULL, '2', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('13', '4', 'COMMOD', 'Commodities', NULL, '3', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('14', '4', 'INFRA', 'Infrastructure', NULL, '4', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('15', '5', 'HEDGE_FUND', 'Hedge Fund', NULL, '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('16', '5', 'PRIVATE', 'Private Equity / Debt', NULL, '2', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('17', '5', 'STRUCTURED', 'Structured Product', NULL, '3', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('18', '5', 'CRYPTO', 'Cryptocurrency', NULL, '4', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('19', '6', 'OPTION', 'Options', NULL, '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('20', '6', 'FUTURE', 'Futures', NULL, '2', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AssetSubClasses VALUES ('21', '7', 'OTHER', 'Other', NULL, '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
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
CREATE TABLE AccountTypes (
    account_type_id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_code TEXT NOT NULL UNIQUE, -- e.g., 'BANK', 'CUSTODY'
    type_name TEXT NOT NULL,        -- e.g., 'Bank Account', 'Account'
    type_description TEXT,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO AccountTypes VALUES ('1', 'BANK', 'Bank Account', 'Standard bank checking or savings account', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AccountTypes VALUES ('2', 'CUSTODY', 'Custody Account', 'Brokerage or custody account for securities', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AccountTypes VALUES ('3', 'CRYPTO', 'Crypto Wallet/Account', 'Account for holding cryptocurrencies', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AccountTypes VALUES ('4', 'PENSION', 'Pension Account', 'Retirement or pension savings account', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AccountTypes VALUES ('6', 'REAL_ESTATE', 'Real Estate', 'Physical real estate owned by the Keller Family', '1', '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO AccountTypes VALUES ('7', 'P2P_LENDING', 'P2P Lending', 'Peer to Peer Portfolio Account', '1', '2025-07-13 09:53:14', '2025-07-13 09:53:14');
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
INSERT INTO Institutions VALUES ('9', 'Crypto.com Crypto Exchange', 'Crypto Exchange', 'n/a', 'https://crypto.com', 'contact@crypto.com', 'USD', 'SG', 'Crypto exchange\n\nAccount Holder Name:\nRene Walter Keller\nIBAN: MT37CFTE28004000000000004267296\nBIC/SWIFT Code: CFTEMTM1\nBank Name: OpenPayd\nBank Address: Level 3, 137 Spinola Road St. Julian’s STJ 3011\nBank Institution Country: Malta MT\n', '1', '2025-07-08 00:00:00', '2025-07-12 14:31:11');
INSERT INTO Institutions VALUES ('10', 'Coinkite Inc', 'Crypto Hardware Wallet Producer', 'n/a', 'https://coldcard.com', 'support@coinkite.com', 'BTC', 'CA', 'Self-custody hardware wallet', '1', '2025-07-08 00:00:00', '2025-07-12 14:20:37');
INSERT INTO Institutions VALUES ('11', 'Libertas Fund LLC', 'Hedge Fund', 'n/a', 'https://www.hyperiondecimus.com/', 'Chris Sullivan', 'USD', 'KY', 'Hyperion Decimus, LLC (DE foreign LLC; HQ: Maitland, FL) \nDelaware-registered LLC (Foreign in Florida)', '1', '2025-07-12 14:25:32', '2025-07-12 14:30:39');
INSERT INTO Institutions VALUES ('12', 'Züricher Kantonal Bank ZKB', 'Bank', 'ZKBKCHZZ80A', 'www.zkb.ch', 'Oliver Lanz', 'CHF', 'CH', NULL, '1', '2025-07-12 14:27:50', '2025-07-12 14:27:50');
CREATE TABLE Instruments (
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
    FOREIGN KEY (sub_class_id) REFERENCES AssetSubClasses(sub_class_id),
    FOREIGN KEY (currency) REFERENCES Currencies(currency_code)
);
INSERT INTO Instruments VALUES ('1', 'CH0438959477', NULL, 'EICE', 'ENETIA Energy Infrastructure Fund -IA', '5', 'EUR', 'CH', 'SWX', 'Energy', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('2', 'CH1108457701', NULL, 'EICRFAK', 'ENETIA Energy Transition Fund -I CHF-', '5', 'CHF', 'CH', 'SWX', 'Energy', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('3', 'US37954Y8710', NULL, 'URA', 'Global X Uranium ETF', '4', 'USD', 'US', 'ARCA', 'Materials', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('4', 'US85208P3038', NULL, 'URNM', 'Sprott Uranium Miners ETF', '4', 'USD', 'US', 'ARCA', 'Materials', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('5', 'BTC', NULL, 'BTC', 'Bitcoin', '18', 'USD', 'BT', 'CRYPTO', 'Cryptocurrency', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('6', 'US19260Q1076', NULL, 'COIN', 'Coinbase Global Inc', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('7', 'DEEPVALUEETF', NULL, 'DEEP', 'Deep Value ETF', '3', 'USD', 'US', 'NYSE', 'Mixed', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('8', 'ETH', NULL, 'ETH', 'Ethereum', '18', 'USD', 'BT', 'CRYPTO', 'Cryptocurrency', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('9', NULL, NULL, '', 'Libertas (Hyperion Decimus)', '17', 'USD', '', '', ' ', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('10', 'LINK', NULL, 'LINK', 'Chainlink', '18', 'USD', 'BT', 'CRYPTO', 'Cryptocurrency', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('11', 'LTC', NULL, 'LTC', 'Litecoin', '18', 'USD', 'BT', 'CRYPTO', 'Cryptocurrency', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('12', 'MATIC', NULL, 'MATIC', 'Polygon', '18', 'USD', 'BT', 'CRYPTO', 'Cryptocurrency', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('13', 'PORTFOLIO', NULL, 'PORTFOLIO', 'Portfolio Overview', '21', 'CHF', 'CH', '', 'Mixed', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('14', NULL, NULL, 'SOL', 'Solana', '18', 'USD', 'BT', 'CRYPTO', 'Cryptocurrency', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('15', 'UNI', NULL, 'UNI', 'Uniswap', '18', 'USD', 'BT', 'CRYPTO', 'Cryptocurrency', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('16', 'USDCOIN', NULL, 'USDC', 'USD Coin', '18', 'USD', 'BT', 'CRYPTO', 'Cryptocurrency', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('17', 'XRP', NULL, 'XRP', 'Ripple', '18', 'USD', 'BT', 'CRYPTO', 'Cryptocurrency', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('18', NULL, NULL, '', '0.25% Axpo Holding 2022/04-Feb-2025', '8', 'CHF', 'CH', 'OTC', 'Utilities', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('19', NULL, NULL, '', '3.25% Credit Suisse 2024', '8', 'CHF', 'CH', 'OTC', 'Financials', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('20', NULL, NULL, '', '7.1% Reverse Convertible Vontobel', '17', 'CHF', 'CH', 'OTC', 'Financials', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('21', NULL, NULL, '', 'Float Mezz 2023-1', '17', 'CHF', 'CH', 'OTC', 'Financials', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('22', 'IE00B2NPKV68', NULL, 'SEMB', 'iShares JPM Emerging Markets Bond ETF', '4', 'USD', 'IE', 'SWX', 'Mixed', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('23', 'IE00BZ0G8977', NULL, 'DTLA', 'iShares USD Treasury Bond 20+ ETF', '4', 'USD', 'IE', 'SWX', 'Mixed', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('24', NULL, NULL, '', 'Sygnum Yield Core', '5', 'CHF', 'CH', '', 'Mixed', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('25', 'KYG8651H1267', NULL, '', 'Synergy Asia Market Neutral Fund', '5', 'USD', 'KY', 'OTC', 'Financials', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('26', 'KYG8652B1023', NULL, '', 'Synergy Global Market Neutral Feeder', '5', 'USD', 'KY', 'OTC', 'Financials', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('27', 'US04635Q1085', NULL, 'ALAB', 'Astera Labs Inc', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('28', 'US0079031078', NULL, 'AMD', 'Advanced Micro Devices', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('29', 'US02082P1084', NULL, 'AOSL', 'Alpha & Omega Semiconductor', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('30', 'US11135F1012', NULL, 'AVGO', 'Broadcom Inc', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('31', 'US19247X1000', NULL, 'COHR', 'Coherent Corp', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('32', 'US2252233042', NULL, 'CRDO', 'Credo Technology Group', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('33', 'US24703L2025', NULL, 'DELL', 'Dell Technologies', '3', 'USD', 'US', 'NYSE', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('34', 'US56585A1025', NULL, 'MARA', 'Marathon Digital Holdings', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('35', 'BMG5876H1051', NULL, 'MRVL', 'Marvell Technology', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('36', 'US67066G1040', NULL, 'NVDA', 'NVIDIA Corp', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('37', 'US7672921050', NULL, 'RIOT', 'Riot Platforms', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('38', 'US8740391003', NULL, 'TSM', 'Taiwan Semiconductor (ADR)', '3', 'USD', 'US', 'NYSE', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('39', 'US92556V1061', NULL, 'VRT', 'Vertiv Holdings', '3', 'USD', 'US', 'NYSE', 'Industrials', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('40', 'IE00BYM11L02', NULL, 'CNDX', 'iShares NASDAQ 100 UCITS ETF', '4', 'USD', 'IE', 'LSE', 'Mixed', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('41', 'US5949724083', NULL, 'MSTR', 'MicroStrategy Inc', '3', 'USD', 'US', 'NASDAQ', 'Technology', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('42', 'GB0002875804', NULL, 'BATS', 'British American Tobacco', '3', 'GBP', 'GB', 'LSE', 'Consumer Staples', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('43', 'US88160R1014', NULL, 'TSLA', 'Tesla Inc', '3', 'USD', 'US', 'NASDAQ', 'Consumer Disc.', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('44', 'CH0043238366', NULL, 'ARYZTA', 'Aryzta AG', '3', 'CHF', 'CH', 'SIX', 'Consumer Staples', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('45', 'CH0012214059', NULL, 'HOLN', 'Holcim Ltd', '3', 'CHF', 'CH', 'SIX', 'Materials', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('46', 'IE00B4L5Y983', NULL, 'IWDA', 'iShares Core MSCI World UCITS ETF', '4', 'USD', 'IE', 'LSE', 'Mixed', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('47', 'CH0038863350', NULL, 'NESN', 'Nestlé SA', '3', 'CHF', 'CH', 'SIX', 'Consumer Staples', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('48', 'CH0012032048', NULL, 'ROG', 'Roche Holding AG', '3', 'CHF', 'CH', 'SIX', 'Health Care', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('49', NULL, NULL, '', 'UBS SMIM CHF A-dis', '5', 'CHF', 'CH', '', 'Mixed', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
INSERT INTO Instruments VALUES ('50', NULL, NULL, '', 'Epic Suisse Fund', '5', 'CHF', 'CH', '', 'Mixed', '1', '1', NULL, '2025-07-13 09:04:29', '2025-07-13 09:04:29');
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
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (institution_id) REFERENCES Institutions(institution_id),
    FOREIGN KEY (account_type_id) REFERENCES AccountTypes(account_type_id),
    FOREIGN KEY (currency_code) REFERENCES Currencies(currency_code)
);
INSERT INTO Accounts VALUES ('1', 'EQUATE', 'Equate Plus Deferred compensation', '1', '1', 'GBP', '1', '1', '2024-01-15', NULL, 'Deferred Compensation', '2025-07-13 09:04:29', '2025-07-13 09:46:51');
INSERT INTO Accounts VALUES ('2', '398424-01', 'Credit Suisse Cash Account (Separat) 🇨🇭CHF', '2', '1', 'CHF', '1', '1', '2023-06-10', NULL, 'CH45 0483 5039 8424 0100 0', '2025-07-13 09:04:29', '2025-07-13 09:37:30');
INSERT INTO Accounts VALUES ('3', '84.008.724.202.9', 'Sygnum Cash Account 🇨🇭CHF', '3', '1', 'CHF', '1', '1', '2021-03-01', NULL, 'CH44 8301 4840 0872 4202 9', '2025-07-13 09:04:29', '2025-07-13 09:50:55');
INSERT INTO Accounts VALUES ('4', 'CH1800774110445559200', 'GKB Privatkonto 🇨🇭 CHF', '4', '1', 'CHF', '1', '1', '2024-02-15', NULL, 'GKB Cash Account in relation to the Mortgages', '2025-07-13 09:04:29', '2025-07-13 09:51:04');
INSERT INTO Accounts VALUES ('5', '62099360010', 'SCB Current Account 🇸🇬 SGD', '5', '1', 'SGD', '1', '1', '2020-01-01', NULL, NULL, '2025-07-13 09:04:29', '2025-07-13 09:28:31');
INSERT INTO Accounts VALUES ('6', 'BB02', 'BitBox 02', '6', '3', 'CHF', '1', '1', '2021-01-31', NULL, 'Crypto Wallet for BTC', '2025-07-13 09:04:29', '2025-07-13 09:17:54');
INSERT INTO Accounts VALUES ('7', 'S 398424-05', 'Credit-Suisse Custody Account 📈', '2', '2', 'CHF', '1', '1', '2024-06-01', NULL, 'Main custody account', '2025-07-13 09:04:29', '2025-07-13 09:44:58');
INSERT INTO Accounts VALUES ('8', 'LNX', 'Ledger Nano X', '7', '3', 'CHF', '1', '1', '2021-07-13', NULL, 'Crypto Wallet for Alt Coins', '2025-07-13 09:16:53', '2025-07-13 09:16:53');
INSERT INTO Accounts VALUES ('9', '84.008.724.203.7', 'Sygnum Cash Account 🇺🇸 USD', '3', '1', 'USD', '1', '1', '2021-07-13', NULL, 'CH22 8301 4840 0872 4203 7', '2025-07-13 09:22:04', '2025-07-13 09:50:42');
INSERT INTO Accounts VALUES ('10', '84.008.724.827.2', 'Sygnum Traditional Asset Custody Account', '3', '2', 'CHF', '1', '1', '2021-07-13', NULL, NULL, '2025-07-13 09:24:18', '2025-07-13 09:46:04');
INSERT INTO Accounts VALUES ('11', '84.008.724.853.1', 'Sygnum Digital Asset Wallet (Trading)', '3', '3', 'CHF', '1', '1', '2021-07-13', NULL, NULL, '2025-07-13 09:25:29', '2025-07-13 09:25:29');
INSERT INTO Accounts VALUES ('12', '84.008.724.902.3', 'Sygnum Digital Assets Vault (Storage)', '3', '3', 'CHF', '1', '1', '2021-07-13', NULL, 'storage for digital assets', '2025-07-13 09:26:28', '2025-07-13 09:26:28');
INSERT INTO Accounts VALUES ('13', '0127962719', 'SCB Savings Account 🇸🇬 SGD', '5', '1', 'SGD', '1', '1', '2020-01-01', NULL, NULL, '2025-07-13 09:29:24', '2025-07-13 09:30:05');
INSERT INTO Accounts VALUES ('14', '6209115679', 'SCB Current Account 🇨🇭CHF', '5', '1', 'CHF', '1', '1', '2020-01-01', NULL, NULL, '2025-07-13 09:30:44', '2025-07-13 09:30:44');
INSERT INTO Accounts VALUES ('15', '6229911713', 'SCB Current Account Tax 🇸🇬 SGD', '5', '1', 'SGD', '1', '1', '2020-01-01', NULL, NULL, '2025-07-13 09:31:52', '2025-07-13 09:31:52');
INSERT INTO Accounts VALUES ('16', '398424-01-9', 'Credit Suisse Cash Account (Wertschriften) 🇨🇭CHF', '2', '1', 'CHF', '1', '1', NULL, NULL, 'CH93 0483 5039 8424 0100 9', '2025-07-13 09:36:59', '2025-07-13 09:36:59');
INSERT INTO Accounts VALUES ('17', '398424-01-12', 'Credit Suisse Cash Account (Wettingen) 🇨🇭CHF', '2', '1', 'CHF', '1', '1', NULL, NULL, 'CH12 0483 5039 8424 0101 2', '2025-07-13 09:38:29', '2025-07-13 09:38:29');
INSERT INTO Accounts VALUES ('18', '398424-02', 'Credit Suisse Cash Account 🇺🇸 USD', '2', '1', 'USD', '1', '1', NULL, NULL, NULL, '2025-07-13 09:39:37', '2025-07-13 09:39:37');
INSERT INTO Accounts VALUES ('19', '398424-02-1', 'Credit Suisse Cash Account 🇪🇺 EUR', '2', '1', 'EUR', '1', '1', NULL, NULL, 'CH81 0483 5039 8424 0200 1', '2025-07-13 09:40:53', '2025-07-13 09:40:53');
INSERT INTO Accounts VALUES ('20', '398424-02-2CH54 0483 5039 8424 0200 2', 'Credit Suisse Cash Account 🇬🇧 GBP', '2', '1', 'CHF', '1', '1', NULL, NULL, 'CH54 0483 5039 8424 0200 2', '2025-07-13 09:42:02', '2025-07-13 09:42:02');
INSERT INTO Accounts VALUES ('21', '398424-02-3', 'Credit Suisse Call Account 🇺🇸 USD', '2', '1', 'USD', '1', '1', NULL, NULL, 'CH27 0483 5039 8424 0200 3', '2025-07-13 09:43:04', '2025-07-13 09:43:04');
INSERT INTO Accounts VALUES ('22', 'HD1034', 'Hyperion Decimus Hedge Fund Account', '11', '1', 'USD', '1', '1', NULL, NULL, NULL, '2025-07-13 09:48:30', '2025-07-13 09:48:30');
INSERT INTO Accounts VALUES ('23', 'CCMK4', 'ColdCard MK4 Cold Wallet BTC', '10', '3', 'CHF', '1', '1', NULL, NULL, NULL, '2025-07-13 09:50:28', '2025-07-13 09:50:28');
INSERT INTO Accounts VALUES ('24', 'SP', 'Swisspeers Portfolio', '8', '7', 'CHF', '1', '1', NULL, NULL, NULL, '2025-07-13 09:52:35', '2025-07-13 09:53:31');
INSERT INTO Accounts VALUES ('25', 'CC', 'Crypto.Com Crypto Hot Wallet', '9', '3', 'EUR', '1', '1', NULL, NULL, NULL, '2025-07-13 09:54:21', '2025-07-13 09:54:21');
COMMIT;
PRAGMA foreign_keys=ON;