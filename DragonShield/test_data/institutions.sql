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
    (1, 'ZKB', 'BANK', 'ZKBKCHZZ80A', 'https://www.zkb.ch', '0844 848 848', 'CHF', 'CH', NULL, 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00'),
    (2, 'Credit Suisse', 'BANK', 'CRESCHZZ80A', 'https://www.credit-suisse.com', '0848 880 084', 'CHF', 'CH', NULL, 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00'),
    (3, 'Sygnum Bank', 'BANK', 'SYGNCHZZ', 'https://www.sygnum.com', 'info@sygnum.com', 'CHF', 'CH', 'Digital asset bank', 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00'),
    (4, 'Graubündner Kantonalbank', 'BANK', 'GRKBCH2270A', 'https://www.gkb.ch', 'info@gkb.ch', 'CHF', 'CH', 'Regional cantonal bank', 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00'),
    (5, 'Standard Chartered Bank Singapore', 'BANK', 'SCBLSGSG', 'https://www.sc.com/sg', 'contactus.sg@sc.com', 'SGD', 'SG', 'International bank', 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00'),
    (6, 'Bitbox2 Bitcoin Wallet', 'WALLET', NULL, 'https://shiftcrypto.ch/bitbox', 'support@shiftcrypto.ch', 'BTC', 'CH', 'Self-custody hardware wallet', 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00'),
    (7, 'Ledger Wallet', 'WALLET', NULL, 'https://www.ledger.com', 'support@ledger.com', 'BTC', 'FR', 'Self-custody hardware wallet', 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00'),
    (8, 'Swisspeers', 'MARKETPLACE', NULL, 'https://www.swisspeers.ch', 'info@swisspeers.ch', 'CHF', 'CH', 'P2P lending marketplace', 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00'),
    (9, 'Crypto.com Crypto Exchange', 'CRYPTO_EXCHANGE', NULL, 'https://crypto.com', 'contact@crypto.com', 'USD', 'SG', 'Crypto exchange', 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00'),
    (10, 'ColdCard Mk4 Cold Wallet', 'WALLET', NULL, 'https://coldcard.com', 'support@coinkite.com', 'BTC', 'CA', 'Self-custody hardware wallet', 1, '2025-07-08 00:00:00', '2025-07-08 00:00:00');
