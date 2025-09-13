-- migrate:up
-- Bump database configuration version to 4.27 (introduces Trade & TradeLeg schema in 032).

INSERT INTO Configuration (key, value, data_type, description, updated_at)
VALUES ('db_version', '4.27', 'string', 'Database schema version', STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
ON CONFLICT(key) DO UPDATE SET
  value = excluded.value,
  data_type = excluded.data_type,
  description = COALESCE(excluded.description, Configuration.description),
  updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now');

-- migrate:down
-- Revert version back to 4.26
INSERT INTO Configuration (key, value, data_type, description, updated_at)
VALUES ('db_version', '4.26', 'string', 'Database schema version', STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
ON CONFLICT(key) DO UPDATE SET
  value = excluded.value,
  data_type = excluded.data_type,
  description = COALESCE(excluded.description, Configuration.description),
  updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now');

