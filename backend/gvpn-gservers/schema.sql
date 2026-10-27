-- G Servers: which phone (public key only) is on which server, in which
-- group, and when it was last used. No IP addresses, no account data.
CREATE TABLE IF NOT EXISTS devices (
  public_key TEXT PRIMARY KEY,
  server_id  TEXT NOT NULL,
  grp        TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  name       TEXT,
  address    TEXT,
  created_at INTEGER NOT NULL,
  last_seen  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS devices_grp ON devices (grp);
CREATE INDEX IF NOT EXISTS devices_token ON devices (token_hash);
CREATE INDEX IF NOT EXISTS devices_server ON devices (server_id);

CREATE TABLE IF NOT EXISTS settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Abuse limits on new phones: one row per scrambled address code per day,
-- deleted by the daily job. Never the address itself.
CREATE TABLE IF NOT EXISTS throttle (
  code          TEXT PRIMARY KEY,
  day           TEXT NOT NULL,
  day_count     INTEGER NOT NULL,
  minute_bucket INTEGER NOT NULL,
  minute_count  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS devices_created ON devices (created_at);
