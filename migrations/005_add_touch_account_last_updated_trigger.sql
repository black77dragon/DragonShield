CREATE TRIGGER tr_touch_account_last_updated_insert
AFTER INSERT ON PositionReports
WHEN NEW.account_id IS NOT NULL
BEGIN
    UPDATE Accounts
    SET earliest_instrument_last_updated_at = CURRENT_TIMESTAMP
    WHERE account_id = NEW.account_id;
END;

CREATE TRIGGER tr_touch_account_last_updated_update
AFTER UPDATE ON PositionReports
WHEN NEW.account_id IS NOT NULL
BEGIN
    UPDATE Accounts
    SET earliest_instrument_last_updated_at = CURRENT_TIMESTAMP
    WHERE account_id = NEW.account_id;
END;
