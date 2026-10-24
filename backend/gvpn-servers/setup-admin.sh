#!/usr/bin/env bash
# One-step admin wiring for the G VPN server list.
#
#   bash backend/gvpn-servers/setup-admin.sh
#
# Generates a fresh admin token and puts it everywhere it is needed, without
# ever printing it:
#   1. the Worker's REFRESH_TOKEN secret, then deploys the Worker
#   2. the panel's admin/.env.local (GVPN_ADMIN_TOKEN), for local runs
#   3. the panel's App Hosting secret gvpn-admin-token, with backend access
# Then runs a first refresh to prove the token works.
#
# Safe to re-run: each run rotates the token in all three places.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
ADMIN="$ROOT/admin"
PROJECT="${FIREBASE_PROJECT:-mindberzerk-3eaf5}"
WORKER_URL="https://gvpn-servers.mindberzerk.workers.dev"

step() { printf '\n\033[1m%s\033[0m\n' "$*"; }

TOKEN="$(openssl rand -hex 32)"

step "1/4  Worker secret and deploy"
cd "$HERE"
printf '%s' "$TOKEN" | npx wrangler secret put REFRESH_TOKEN >/dev/null
npx wrangler deploy

step "2/4  Panel .env.local"
ENV_FILE="$ADMIN/.env.local"
touch "$ENV_FILE"
# Replace any previous value rather than appending a second line.
grep -v '^GVPN_ADMIN_TOKEN=' "$ENV_FILE" > "$ENV_FILE.tmp" || true
printf 'GVPN_ADMIN_TOKEN=%s\n' "$TOKEN" >> "$ENV_FILE.tmp"
mv "$ENV_FILE.tmp" "$ENV_FILE"
echo "Updated $ENV_FILE"

step "3/4  App Hosting secret"
cd "$ADMIN"
printf '%s' "$TOKEN" | firebase apphosting:secrets:set gvpn-admin-token \
  --data-file=- --project "$PROJECT" --non-interactive >/dev/null
BACKENDS="$(firebase apphosting:backends:list --project "$PROJECT" --json 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const r=JSON.parse(s).result??[];console.log(r.map(b=>b.name.split("/").pop()).join(" "))}catch{}})')"
if [ -z "$BACKENDS" ]; then
  echo "No App Hosting backend found. Grant access later with:"
  echo "  firebase apphosting:secrets:grantaccess gvpn-admin-token --backend <backend-id> --project $PROJECT"
else
  for b in $BACKENDS; do
    firebase apphosting:secrets:grantaccess gvpn-admin-token --backend "$b" --project "$PROJECT" >/dev/null
    echo "Backend $b can read gvpn-admin-token"
  done
fi

step "4/4  First refresh"
curl -fsS -X POST -H "Authorization: Bearer $TOKEN" "$WORKER_URL/refresh" && echo
echo
echo "Done. Start the panel with: cd admin && pnpm dev"
