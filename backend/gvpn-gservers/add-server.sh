#!/usr/bin/env bash
# Adds (or updates) one G Server in the list phones and the panel use.
#
#   bash backend/gvpn-gservers/add-server.sh <ip> "<name>" <city> <country>
#   bash backend/gvpn-gservers/add-server.sh 79.76.105.107 "G Server · Frankfurt" Frankfurt DE
#
# Cloudflare cannot hand a secret back, so the full list lives on this Mac in
# ~/.config/gvpn/gservers.json (owner-only), outside the repository. Each run
# reads the server's agent secret over SSH, adds or replaces that server in
# the file, then pushes the whole list to the broker and to admin/.env.local.
# Run it once for every existing server first, then for each new one.
set -euo pipefail
IP="${1:?server IP}"; NAME="${2:?server name}"; CITY="${3:?city}"; CC="${4:?country code}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LIST="$HOME/.config/gvpn/gservers.json"
mkdir -p "$(dirname "$LIST")"
[[ -f "$LIST" ]] || echo '[]' > "$LIST"
chmod 600 "$LIST"

echo "== Agent secret from $IP"
SECRET=$(ssh "ubuntu@$IP" "sudo grep '^GVPN_AGENT_SECRET=' /etc/gvpn-agent.env | cut -d= -f2-")
[[ -n "$SECRET" ]] || { echo "No agent secret on $IP"; exit 1; }
ID=$(echo "$CITY" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-$//')-1

echo "== Updating $LIST"
python3 - "$LIST" "$ID" "$NAME" "$CITY" "$CC" "$IP" "$SECRET" <<'PY'
import json, sys
path, sid, name, city, cc, host, secret = sys.argv[1:]
servers = [s for s in json.load(open(path)) if s.get("host") != host]
servers.append({"id": sid, "name": name, "city": city, "country": cc.upper(), "host": host, "port": 8443, "secret": secret})
json.dump(servers, open(path, "w"), indent=2)
print("   " + ", ".join(f"{s['city']} ({s['host']})" for s in servers))
PY

echo "== Broker"
(cd "$HERE" && npx wrangler secret put GSERVERS < "$LIST")

echo "== Panel (admin/.env.local)"
ENV="$ROOT/admin/.env.local"
LINE="GVPN_GSERVERS=$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "$LIST")"
if grep -q '^GVPN_GSERVERS=' "$ENV"; then
  python3 - "$ENV" "$LINE" <<'PY'
import sys
path, line = sys.argv[1:]
out = [line if l.startswith("GVPN_GSERVERS=") else l for l in open(path).read().splitlines()]
open(path, "w").write("\n".join(out) + "\n")
PY
else
  echo "$LINE" >> "$ENV"
fi
echo
echo "Done. Also update the GVPN_GSERVERS secret on App Hosting with the same value:"
echo "  firebase apphosting:secrets:set GVPN_GSERVERS < <(python3 -c 'import json; print(json.dumps(json.load(open(\"$LIST\"))))')"
