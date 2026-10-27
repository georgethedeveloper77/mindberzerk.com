#!/usr/bin/env bash
# One-time setup for the gvpn-isps Worker:
#   bash backend/gvpn-isps/setup.sh
# Creates the D1 database, writes its id into wrangler.toml, applies the
# schema, sets ADMIN_TOKEN to the SAME value the panel already uses
# (GVPN_ADMIN_TOKEN in admin/.env.local), and deploys.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$HERE"

if grep -q REPLACE_WITH_D1_ID wrangler.toml; then
  OUT="$(npx wrangler d1 create gvpn-isps 2>&1)" || { echo "$OUT"; exit 1; }
  ID="$(printf '%s' "$OUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
  [ -n "$ID" ] || { echo "Could not read the database id from:"; echo "$OUT"; exit 1; }
  sed -i.bak "s/REPLACE_WITH_D1_ID/$ID/" wrangler.toml && rm -f wrangler.toml.bak
  echo "D1 database $ID"
fi

npx wrangler d1 execute gvpn-isps --remote --file=schema.sql

TOKEN="$(grep '^GVPN_ADMIN_TOKEN=' "$ROOT/admin/.env.local" | cut -d= -f2-)"
[ -n "$TOKEN" ] || { echo "GVPN_ADMIN_TOKEN missing from admin/.env.local (run gvpn-servers/setup-admin.sh first)"; exit 1; }
# Deploy BEFORE setting the secret: a secret on a Worker that does not
# exist yet leaves it half-created, and the first deploy then fails.
npx wrangler deploy
printf '%s' "$TOKEN" | npx wrangler secret put ADMIN_TOKEN >/dev/null
echo
echo "Done. Add to apps/g_vpn/env/dev.json:  \"ISPS_URL\": \"https://gvpn-isps.<your-subdomain>.workers.dev\""
