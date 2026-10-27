-- One row per direct speed test. No IP address, no device id: the provider,
-- country and city come from Cloudflare's view of the connection.
CREATE TABLE IF NOT EXISTS results (
  id      INTEGER PRIMARY KEY,
  isp     TEXT NOT NULL,
  country TEXT NOT NULL,
  city    TEXT NOT NULL,
  down    REAL NOT NULL,
  up      REAL NOT NULL,
  ping    REAL NOT NULL,
  day     TEXT NOT NULL  -- YYYY-MM-DD, UTC
);
CREATE INDEX IF NOT EXISTS results_place ON results (country, day);

-- Flood control: a keyed hash of (IP, day), never the IP itself, deleted
-- after a day. Without the Worker's secret it cannot be turned back into an
-- address.
CREATE TABLE IF NOT EXISTS recent (
  hash TEXT NOT NULL,
  day  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS recent_hash ON recent (hash, day);
