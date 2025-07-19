-- Sample institutions for testing
INSERT INTO Institutions (
    institution_id,
    institution_name,
    institution_type,
    bic,
    website,
    contact_info,
    default_currency,
    country_code,
    notes,
    is_active,
    created_at,
    updated_at
) VALUES
    (1, 'Equate Plus (to be replaced)', 'Deferred Compensation', 'n/a', NULL, 'to be enhanced', 'GBP', 'GB', 'Deferred Compensation Standard Chartered', 1, '2025-07-08 00:00:00', '2025-07-12 14:26:44'),
    (2, 'Credit Suisse', 'Bank', 'CRESCHZZ80A', 'https://www.credit-suisse.com', 'Christoph Birrer', 'CHF', 'CH', NULL, 1, '2025-07-08 00:00:00', '2025-07-12 14:17:57'),
    (3, 'Sygnum Bank', 'Bank', 'SYGNCHZZ', 'https://www.sygnum.com', 'info@sygnum.com', 'CHF', 'CH', 'Digital asset bank', 1, '2025-07-08 00:00:00', '2025-07-12 14:24:32'),
    (4, 'Graubündner Kantonalbank', 'Bank', 'GRKBCH2270A', 'https://www.gkb.ch', 'info@gkb.ch', 'CHF', 'CH', 'Regional cantonal bank', 1, '2025-07-08 00:00:00', '2025-07-12 14:24:13'),
    (5, 'Standard Chartered Bank Singapore', 'Bank', 'SCBLSGSG', 'https://www.sc.com/sg', 'contactus.sg@sc.com', 'SGD', 'SG', 'International bank', 1, '2025-07-08 00:00:00', '2025-07-12 14:24:21'),
    (6, 'Bitbox (Switzerland)', 'Crypto Hardware Wallet Producer', 'n/a', 'https://bitbox.swiss/', 'web support', 'BTC', 'CH', 'Self-custody hardware wallet provider', 1, '2025-07-08 00:00:00', '2025-07-12 14:19:05'),
    (7, 'Ledger SAS', 'Crypto Hardware Wallet Producer', 'n/a', 'https://www.ledger.com', 'support@ledger.com', 'BTC', 'FR', 'Self-custody hardware wallet', 1, '2025-07-08 00:00:00', '2025-07-12 14:20:47'),
    (8, 'Swisspeers', 'Peer2Peer Marketplace', 'n/a', 'https://www.swisspeers.ch', 'info@swisspeers.ch', 'CHF', 'CH', 'P2P lending marketplace', 1, '2025-07-08 00:00:00', '2025-07-12 14:31:01'),
    (9, 'Crypto.com Crypto Exchange', 'Crypto Exchange', 'n/a', 'https://crypto.com', 'contact@crypto.com', 'USD', 'SG', 'Crypto exchange\n\nAccount Holder Name:\nRene Walter Keller\nIBAN: MT37CFTE28004000000000004267296\nBIC/SWIFT Code: CFTEMTM1\nBank Name: OpenPayd\nBank Address: Level 3, 137 Spinola Road St. Julian’s STJ 3011\nBank Institution Country: Malta MT\n', 1, '2025-07-08 00:00:00', '2025-07-12 14:31:11'),
    (10, 'Coinkite Inc', 'Crypto Hardware Wallet Producer', 'n/a', 'https://coldcard.com', 'support@coinkite.com', 'BTC', 'CA', 'Self-custody hardware wallet', 1, '2025-07-08 00:00:00', '2025-07-12 14:20:37'),
    (11, 'Libertas Fund LLC', 'Hedge Fund', 'n/a', 'https://www.hyperiondecimus.com/', 'Chris Sullivan', 'USD', 'KY', 'Hyperion Decimus, LLC (DE foreign LLC; HQ: Maitland, FL) \nDelaware-registered LLC (Foreign in Florida)', 1, '2025-07-12 14:25:32', '2025-07-12 14:30:39'),
    (12, 'Züricher Kantonalbank ZKB', 'Bank', 'ZKBKCHZZ80A', 'www.zkb.ch', 'Oliver Lanz', 'CHF', 'CH', NULL, 1, '2025-07-12 14:27:50', '2025-07-12 14:27:50');
