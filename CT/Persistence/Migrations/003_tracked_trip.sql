CREATE TABLE IF NOT EXISTS tracked_trip (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    trip_id TEXT NOT NULL,
    train_number TEXT NOT NULL,
    service_date TEXT NOT NULL,
    origin_stop_id TEXT NOT NULL,
    origin_name TEXT NOT NULL,
    dest_stop_id TEXT NOT NULL,
    dest_name TEXT NOT NULL,
    state TEXT NOT NULL,
    created_at TEXT NOT NULL
);
