-- gvpn-providers: internet providers, their brand, and what users rate them.
-- No IP addresses are stored. A rating is keyed by a random install id the
-- app makes, so one phone counts once per provider per month.

CREATE TABLE IF NOT EXISTS providers (
  asn INTEGER PRIMARY KEY,      -- the network number Cloudflare sees
  org TEXT NOT NULL,            -- as Cloudflare names it ("Safaricom Limited")
  country TEXT,                 -- where it was first seen
  name TEXT,                    -- display name, set in admin ("Safaricom Home")
  color TEXT,                   -- brand colour, "#2EB34A"
  logo TEXT,                    -- https URL on the CDN, optional
  phone TEXT,
  website TEXT,
  outages TEXT,                 -- the provider's outage or status page
  hidden INTEGER NOT NULL DEFAULT 0,  -- 1: not a home provider (hosting, VPN)
  first_seen INTEGER NOT NULL,
  updated INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS ratings (
  asn INTEGER NOT NULL,
  device TEXT NOT NULL,         -- random install id, never an IP
  month TEXT NOT NULL,          -- "2026-10": one rating a month
  country TEXT,
  city TEXT,
  stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  tags TEXT NOT NULL DEFAULT '',-- comma separated, from a fixed list
  verified INTEGER NOT NULL DEFAULT 0, -- came with a speed test
  at INTEGER NOT NULL,
  PRIMARY KEY (asn, device, month)
);
CREATE INDEX IF NOT EXISTS ratings_place ON ratings (country, city);

-- Which providers phones use, without ratings: one row per install per
-- provider per month, so the directory and its size grow from ordinary use.
CREATE TABLE IF NOT EXISTS seen (
  asn INTEGER NOT NULL,
  device TEXT NOT NULL,         -- random install id, never an IP
  month TEXT NOT NULL,
  country TEXT,
  city TEXT,
  PRIMARY KEY (asn, device, month)
);
CREATE INDEX IF NOT EXISTS seen_place ON seen (country, city, month);

CREATE TABLE IF NOT EXISTS hits (
  key TEXT PRIMARY KEY,         -- hash of IP and hour
  hour INTEGER NOT NULL,
  n INTEGER NOT NULL
);
