-- gvpn-linkcheck: a counter only. No links, no IP addresses.
CREATE TABLE IF NOT EXISTS hits (
  key TEXT PRIMARY KEY,   -- hash of IP and hour
  hour INTEGER NOT NULL,
  n INTEGER NOT NULL
);
