#!/usr/bin/env bash
# Connects the admin's G VPN Live map to G VPN's GA4 property.
#
# Google blocks gcloud's own sign-in from asking for Analytics access
# ("This app is blocked"), so this script never asks for it. Instead:
#
#   1. your normal gcloud sign-in finds the GA4 property through Firebase
#      and writes GA4_PROPERTY_G_VPN into admin/.env.local
#   2. you add the panel's service account to the property, once, in the
#      GA4 screen (the one step Google keeps to its own pages)
#   3. the script then acts AS that service account, which may use the
#      Analytics API, and registers the server_country and protocol dimensions
#
# Safe to run again. Usage:  bash admin/scripts/setup-gvpn-analytics.sh
# Optional:  GVPN_PROJECT=gvpn-9bc4c

set -euo pipefail

GVPN_PROJECT="${GVPN_PROJECT:-gvpn-9bc4c}"
ADMIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ADMIN_DIR/.env.local"
API="https://analyticsadmin.googleapis.com"

envget() { # value of KEY in .env.local, quotes stripped
  [ -f "$ENV_FILE" ] && grep -E "^$1=" "$ENV_FILE" | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true
}

# ── 1. The property, through Firebase, with your usual sign-in ──────────────
echo "1/3  Finding the GA4 property linked to $GVPN_PROJECT"
gcloud services enable firebase.googleapis.com analyticsadmin.googleapis.com analyticsdata.googleapis.com \
  --project "$GVPN_PROJECT" >/dev/null
USER_TOKEN="$(gcloud auth print-access-token)"
PROPERTY="$(curl -sS -H "Authorization: Bearer $USER_TOKEN" -H "x-goog-user-project: $GVPN_PROJECT" \
  "https://firebase.googleapis.com/v1beta1/projects/$GVPN_PROJECT/analyticsDetails" |
  python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("analyticsProperty",{}).get("id","").split("/")[-1])' || true)"
if [ -z "$PROPERTY" ]; then
  echo "     Firebase did not name a property. In GA4: Admin > Property details > Property ID."
  read -r -p "     Type the G VPN property number: " PROPERTY
fi
[ -n "$PROPERTY" ] || { echo "No property, stopping."; exit 1; }
echo "     Property $PROPERTY"

touch "$ENV_FILE"
python3 - "$ENV_FILE" "$PROPERTY" <<'PY'
import re, sys
path, value = sys.argv[1], sys.argv[2]
text = open(path).read()
line = f"GA4_PROPERTY_G_VPN={value}"
if re.search(r"^GA4_PROPERTY_G_VPN=.*$", text, re.M):
    text = re.sub(r"^GA4_PROPERTY_G_VPN=.*$", line, text, flags=re.M)
else:
    text = text.rstrip("\n") + ("\n" if text else "") + line + "\n"
open(path, "w").write(text)
PY
echo "     Written to $ENV_FILE"

# ── 2. The service account, added once in GA4 ───────────────────────────────
CREDS="${GOOGLE_APPLICATION_CREDENTIALS:-$(envget GOOGLE_APPLICATION_CREDENTIALS)}"
if [ -z "$CREDS" ] || [ ! -f "$CREDS" ]; then
  echo
  echo "No service account key file found (GOOGLE_APPLICATION_CREDENTIALS in .env.local)."
  echo "Register the two dimensions by hand instead: GA4 > Admin > Custom definitions >"
  echo "Create custom dimension, scope Event, parameters server_country and protocol."
  exit 0
fi
SA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["client_email"])' "$CREDS")"
SA_PROJECT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["project_id"])' "$CREDS")"
ADMIN_PROJECT="$(envget GCP_PROJECT)"
ADMIN_PROJECT="${ADMIN_PROJECT:-$SA_PROJECT}"

cat <<STEP

2/3  One step in the GA4 screen (Google allows it nowhere else):
     Open https://analytics.google.com, choose the G VPN property ($PROPERTY),
     then Admin > Property access management > + > Add users. Add, each as Editor:

       $SA
       firebase-app-hosting-compute@$ADMIN_PROJECT.iam.gserviceaccount.com

     (The first is the panel on this Mac, the second the deployed panel.
      Editor lets the next step register the dimensions; Viewer is enough
      afterwards if you want to lower it.)

STEP
read -r -p "     Press Enter once they are added... " _

# ── 3. The dimensions, as the service account ───────────────────────────────
echo "3/3  Registering the event dimensions as $SA"
gcloud services enable analyticsadmin.googleapis.com --project "$SA_PROJECT" >/dev/null 2>&1 || true
ORIGINAL="$(gcloud config get-value account 2>/dev/null || true)"
gcloud auth activate-service-account --key-file="$CREDS" >/dev/null
SA_TOKEN="$(gcloud auth print-access-token "$SA" --scopes=https://www.googleapis.com/auth/analytics.edit)"
# Put your own account back as gcloud's active one.
[ -n "$ORIGINAL" ] && gcloud config set account "$ORIGINAL" >/dev/null 2>&1 || true

for dim in "server_country:Server country" "protocol:Protocol"; do
  name="${dim%%:*}"; label="${dim#*:}"
  out="$(curl -sS -X POST -H "Authorization: Bearer $SA_TOKEN" -H "Content-Type: application/json" \
    "$API/v1beta/properties/$PROPERTY/customDimensions" \
    -d "{\"parameterName\":\"$name\",\"displayName\":\"$label\",\"scope\":\"EVENT\"}")"
  if echo "$out" | grep -q '"parameterName"'; then echo "     $name registered"
  elif echo "$out" | grep -q 'ALREADY_EXISTS'; then echo "     $name was already registered"
  elif echo "$out" | grep -q 'PERMISSION_DENIED'; then echo "     $name: the service account is not an Editor on the property yet"
  else echo "     $name: $out"; fi
done

cat <<NOTE

Done. Restart \`npm run dev\` so it reads .env.local.

For the deployed panel, add this to admin/apphosting.yaml under env:

  - variable: GA4_PROPERTY_G_VPN
    value: "$PROPERTY"
    availability:
      - RUNTIME

GA4 fills server_country and protocol from now on; arcs appear with the next connections.
NOTE
