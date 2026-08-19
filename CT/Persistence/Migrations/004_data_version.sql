ALTER TABLE preferences ADD COLUMN data_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE preferences ADD COLUMN data_synced_at TEXT;
