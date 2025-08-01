PRAGMA foreign_keys=OFF;

-- Additional account representing real estate holdings at ZKB
INSERT INTO Accounts VALUES (
    26,
    'ZKB-RE1',
    'ZKB Real Estate Portfolio',
    12,
    6,
    'CHF',
    1,
    1,
    '2018-01-01',
    NULL,
    NULL,
    'Real estate holdings with ZKB',
    '2025-07-13 10:00:00',
    '2025-07-13 10:00:00'
);

-- Import session placeholder
INSERT INTO ImportSessions VALUES (
    6,
    'Test Allocation',
    'alloc.sql',
    '/tmp/alloc.sql',
    'CSV',
    0,
    'zzz000',
    12,
    'COMPLETED',
    0,
    0,
    0,
    0,
    NULL,
    'Test dataset load',
    '2025-07-13 10:00:00',
    '2025-07-13 10:00:00',
    '2025-07-13 10:00:00'
);

-- Position holdings
INSERT INTO PositionReports VALUES (
    23, 6, 26, 12, 50, 50000, 100, 100, '2025-07-01', 'Epic Suisse Fund holding', '2025-07-01', '2025-07-13 10:00:00'
);
INSERT INTO PositionReports VALUES (
    24, 6, 7, 2, 5, 20, 50000, 60000, '2025-07-01', 'Bitcoin holdings', '2025-07-01', '2025-07-13 10:00:00'
);
INSERT INTO PositionReports VALUES (
    25, 6, 7, 2, 8, 400, 2000, 2000, '2025-07-01', 'Ethereum holdings', '2025-07-01', '2025-07-13 10:00:00'
);
INSERT INTO PositionReports VALUES (
    26, 6, 7, 2, 36, 1000, 700, 1000, '2025-07-01', 'NVDA position', '2025-07-01', '2025-07-13 10:00:00'
);
INSERT INTO PositionReports VALUES (
    27, 6, 7, 2, 41, 4000, 100, 250, '2025-07-01', 'MSTR position', '2025-07-01', '2025-07-13 10:00:00'
);
INSERT INTO PositionReports VALUES (
    28, 6, 9, 3, 16, 1000000, 1, 1, '2025-07-01', 'USDC liquidity', '2025-07-01', '2025-07-13 10:00:00'
);

-- Target allocations (class level)
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (4, NULL, 40, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (7, NULL, 15, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (2, NULL, 35, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (1, NULL, 15, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (3, NULL, 5, NULL, 'percent', 5.0, '2025-07-13 10:00:00');

-- Target allocations (sub-class level)
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (4, 11, 30, 0, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (4, 14, 10, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (7, 18, 10, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (7, 21, 5, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (2, 3, 20, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (2, 4, 15, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (1, 1, 15, NULL, 'percent', 5.0, '2025-07-13 10:00:00');
INSERT INTO TargetAllocation (asset_class_id, sub_class_id, target_percent, target_amount_chf, target_kind, tolerance_percent, updated_at) VALUES (3, 7, 5, NULL, 'percent', 5.0, '2025-07-13 10:00:00');

PRAGMA foreign_keys=ON;
