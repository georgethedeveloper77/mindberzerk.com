#!/usr/bin/env bash
# One-time setup of the G Servers broker on Cloudflare's free plan.
#
#   bash backend/gvpn-gservers/setup.sh <server-ip> "<name>" <city> <country>
#   bash backend/gvpn-gservers/setup.sh 79.76.105.107 "G Server · Frankfurt" Frankfurt DE
#
# Creates the D1 database, applies the schema, reads the agent secret from
# the server over SSH, stores both secrets in Cloudflare and deploys.
# Re-run with another server's details to replace the list (one server for now).
set -euo pipefail
IP="${1:?server IP}"; NAME="${2:?server name}"; CITY="${3:?city}"; CC="${4:?country code}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$HERE"

if grep -q 'REPLACE_WITH_ID' wrangler.toml; then
  echo "== Creating the D1 database"
  OUT=$(npx wrangler d1 create gvpn-gservers 2>&1) || { echo "$OUT"; exit 1; }
  ID=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<<"$OUT" | head -1)
  [[ -n "$ID" ]] || { echo "$OUT"; echo "Could not read the database id."; exit 1; }
  sed -i.bak "s/REPLACE_WITH_ID/$ID/" wrangler.toml && rm -f wrangler.toml.bak
fi

echo "== Schema"
npx wrangler d1 execute gvpn-gservers --remote --file schema.sql

echo "== Deploy (secrets are added to the deployed Worker)"
npx wrangler deploy

echo "== Agent secret from the server"
SECRET=$(ssh "ubuntu@$IP" "sudo grep '^GVPN_AGENT_SECRET=' /etc/gvpn-agent.env | cut -d= -f2-")
[[ -n "$SECRET" ]] || { echo "No agent secret on $IP"; exit 1; }
ID_SLUG=$(echo "$CITY" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-$//')-1
printf '[{"id":"%s","name":"%s","city":"%s","country":"%s","host":"%s","port":8443,"secret":"%s"}]' \
  "$ID_SLUG" "$NAME" "$CITY" "$CC" "$IP" "$SECRET" | npx wrangler secret put GSERVERS

echo "== Admin token (the same one the panel uses)"
TOKEN=$(grep '^GVPN_ADMIN_TOKEN=' "$ROOT/admin/.env.local" | cut -d= -f2-)
[[ -n "$TOKEN" ]] || { echo "GVPN_ADMIN_TOKEN missing from admin/.env.local"; exit 1; }
printf '%s' "$TOKEN" | npx wrangler secret put ADMIN_TOKEN

echo
echo "Check:  curl -s https://gvpn-gservers.mindberzerk.workers.dev/servers"
