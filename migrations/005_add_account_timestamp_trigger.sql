CREATE TRIGGER IF NOT EXISTS tr_touch_account_last_updated
AFTER INSERT ON PositionReports
WHEN NEW.account_id IS NOT NULL
BEGIN
    UPDATE Accounts
       SET earliest_instrument_last_updated_at = CURRENT_TIMESTAMP
     WHERE account_id = NEW.account_id;
END;

CREATE TRIGGER IF NOT EXISTS tr_touch_account_last_updated_update
AFTER UPDATE ON PositionReports
WHEN NEW.account_id IS NOT NULL
BEGIN
    UPDATE Accounts
       SET earliest_instrument_last_updated_at = CURRENT_TIMESTAMP
     WHERE account_id = NEW.account_id;
END;
