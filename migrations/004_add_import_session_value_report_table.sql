CREATE TABLE IF NOT EXISTS ImportSessionValueReports (
    report_id INTEGER PRIMARY KEY AUTOINCREMENT,
    import_session_id INTEGER NOT NULL,
    instrument_name TEXT NOT NULL,
    currency TEXT NOT NULL,
    value_orig REAL NOT NULL,
    value_chf REAL NOT NULL,
    FOREIGN KEY (import_session_id) REFERENCES ImportSessions(import_session_id)
);
