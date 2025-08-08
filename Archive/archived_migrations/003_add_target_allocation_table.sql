CREATE TABLE IF NOT EXISTS TargetAllocation (
    allocation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_class_id INTEGER NOT NULL,
    sub_class_id INTEGER,
    target_percent REAL,
    target_amount_chf REAL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (asset_class_id) REFERENCES AssetClasses(class_id),
    UNIQUE(asset_class_id, sub_class_id),
    FOREIGN KEY (sub_class_id) REFERENCES AssetSubClasses(sub_class_id)
);
