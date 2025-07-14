PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;

-- Sample Exchange Rates for testing
-- Five consecutive dates: 2025-07-09 to 2025-07-13

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CHF', '2025-07-09', 1.0000, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CHF', '2025-07-10', 1.0000, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CHF', '2025-07-11', 1.0000, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CHF', '2025-07-12', 1.0000, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CHF', '2025-07-13', 1.0000, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('EUR', '2025-07-09', 0.9200, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('EUR', '2025-07-10', 0.9210, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('EUR', '2025-07-11', 0.9220, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('EUR', '2025-07-12', 0.9230, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('EUR', '2025-07-13', 0.9240, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('USD', '2025-07-09', 0.8810, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('USD', '2025-07-10', 0.8820, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('USD', '2025-07-11', 0.8830, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('USD', '2025-07-12', 0.8840, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('USD', '2025-07-13', 0.8850, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('GBP', '2025-07-09', 0.7760, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('GBP', '2025-07-10', 0.7770, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('GBP', '2025-07-11', 0.7780, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('GBP', '2025-07-12', 0.7790, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('GBP', '2025-07-13', 0.7800, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('JPY', '2025-07-09', 0.0055, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('JPY', '2025-07-10', 0.0056, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('JPY', '2025-07-11', 0.0057, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('JPY', '2025-07-12', 0.0058, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('JPY', '2025-07-13', 0.0059, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CAD', '2025-07-09', 0.6610, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CAD', '2025-07-10', 0.6620, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CAD', '2025-07-11', 0.6630, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CAD', '2025-07-12', 0.6640, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CAD', '2025-07-13', 0.6650, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('AUD', '2025-07-09', 0.5890, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('AUD', '2025-07-10', 0.5900, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('AUD', '2025-07-11', 0.5910, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('AUD', '2025-07-12', 0.5920, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('AUD', '2025-07-13', 0.5930, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SEK', '2025-07-09', 0.0800, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SEK', '2025-07-10', 0.0810, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SEK', '2025-07-11', 0.0820, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SEK', '2025-07-12', 0.0830, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SEK', '2025-07-13', 0.0840, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('NOK', '2025-07-09', 0.0850, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('NOK', '2025-07-10', 0.0860, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('NOK', '2025-07-11', 0.0870, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('NOK', '2025-07-12', 0.0880, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('NOK', '2025-07-13', 0.0890, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('DKK', '2025-07-09', 0.1230, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('DKK', '2025-07-10', 0.1240, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('DKK', '2025-07-11', 0.1250, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('DKK', '2025-07-12', 0.1260, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('DKK', '2025-07-13', 0.1270, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CNY', '2025-07-09', 0.1260, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CNY', '2025-07-10', 0.1270, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CNY', '2025-07-11', 0.1280, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CNY', '2025-07-12', 0.1290, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('CNY', '2025-07-13', 0.1300, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('HKD', '2025-07-09', 0.1100, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('HKD', '2025-07-10', 0.1110, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('HKD', '2025-07-11', 0.1120, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('HKD', '2025-07-12', 0.1130, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('HKD', '2025-07-13', 0.1140, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SGD', '2025-07-09', 0.6490, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SGD', '2025-07-10', 0.6500, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SGD', '2025-07-11', 0.6510, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SGD', '2025-07-12', 0.6520, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('SGD', '2025-07-13', 0.6530, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('BTC', '2025-07-09', 60000.0000, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('BTC', '2025-07-10', 60500.0000, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('BTC', '2025-07-11', 61000.0000, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('BTC', '2025-07-12', 61500.0000, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('BTC', '2025-07-13', 62000.0000, 'api', 1);

INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('ETH', '2025-07-09', 2500.0000, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('ETH', '2025-07-10', 2525.0000, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('ETH', '2025-07-11', 2550.0000, 'manual', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('ETH', '2025-07-12', 2575.0000, 'api', 0);
INSERT INTO ExchangeRates (currency_code, rate_date, rate_to_chf, rate_source, is_latest) VALUES ('ETH', '2025-07-13', 2600.0000, 'api', 1);

COMMIT;
PRAGMA foreign_keys=ON;
