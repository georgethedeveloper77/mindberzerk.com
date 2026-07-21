#!/usr/bin/env bash
#
# Provision the four secrets admin.mindberzerk.com needs.
#
#   ./admin/scripts/setup_secrets.sh <firebase-project-id>
#
# Run it once, from the repo root or anywhere. It is interactive: each secret is
# read from a prompt rather than an argument, so none of them lands in your
# shell history. That is the entire reason this is a script and not four lines
# in a README.
#
# WHAT THESE SECRETS ARE, in order of how bad it is to leak them:
#
#  pack-signing-key      The ed25519 private half. Its public counterpart is
#                        compiled into every shipped APK. If this leaks, anyone
#                        can publish a pack that every installed launcher will
#                        verify and load, and a theme drives fonts, colours,
#                        layout and icons. The fix is a key rotation plus a Play
#                        release plus waiting for the install base to move.
#                        Treat it exactly like your upload keystore.
#
#  r2-secret-access-key  Write access to the CDN. Bad, but recoverable in
#                        minutes: revoke the token in Cloudflare and re-upload.
#                        Cannot forge a pack on its own, because the device
#                        still checks the signature.
#
#  admin-uids            Who may sign in to the panel. Not secret in the
#                        cryptographic sense — a UID is not a credential — but
#                        it is the access-control list for a machine that holds
#                        the signing key, so it is treated as one.
#
#  r2-access-key-id      The public half of the R2 pair. In Secret Manager only
#                        so it travels with its secret.
set -euo pipefail

PROJECT="${1:-}"
if [ -z "$PROJECT" ]; then
  echo "usage: $0 <firebase-project-id>" >&2
  exit 1
fi

command -v firebase >/dev/null || { echo "firebase CLI not found: npm i -g firebase-tools" >&2; exit 1; }

echo "project: $PROJECT"
echo

# `firebase apphosting:secrets:set` does three things gcloud would need three
# commands for: creates the Secret Manager secret, adds the version, AND grants
# the App Hosting compute service account access to it. Doing it by hand with
# gcloud works too (see the bottom of this file) but forgetting the IAM grant is
# the classic failure: the deploy succeeds and the container crashes on boot
# with a permission error nobody reads.
set_secret() {
  local name="$1" prompt="$2"
  echo "── $name"
  echo "   $prompt"
  firebase apphosting:secrets:set "$name" --project "$PROJECT"
  echo
}

set_secret pack-signing-key \
  "Paste the 64-hex PRIVATE key from 'node tools/sign-pack.mjs keygen'.
   Its public half must already be in PackKeys.ACCEPTED_HEX, or every pack
   this panel publishes is refused on-device with UnknownKey."

set_secret r2-access-key-id \
  "Cloudflare dashboard -> R2 Object Storage -> Overview -> API Tokens ->
   Manage. Create a token with Object Read & Write, scoped to the single
   bucket mindberzerk-cdn. Paste the Access Key ID."

set_secret r2-secret-access-key \
  "The Secret Access Key from the same token. Cloudflare shows it ONCE and
   never again; if you have lost it, delete the token and make a new one."

set_secret admin-uids \
  "Your Firebase Auth UID, from Console -> Authentication -> Users -> the
   'User UID' column (a 28-character string). Comma-separated for more than
   one. An EMPTY value locks everybody out, which is the intended failure."

echo "── granting the App Hosting backend access"
firebase apphosting:secrets:grantaccess \
  pack-signing-key,r2-access-key-id,r2-secret-access-key,admin-uids \
  --project "$PROJECT" || true

echo
echo "Done. Verify:"
echo "  gcloud secrets list --project $PROJECT"
echo
echo "Then fill the three NEXT_PUBLIC_FIREBASE_* values in admin/apphosting.yaml"
echo "from the web app config, and deploy."

# ── the equivalent in raw gcloud, if you prefer ──────────────────────────────
#
#   printf '%s' "$KEY" | gcloud secrets create pack-signing-key \
#       --data-file=- --replication-policy=automatic --project "$PROJECT"
#
#   gcloud secrets add-iam-policy-binding pack-signing-key \
#       --member="serviceAccount:firebase-app-hosting-compute@${PROJECT}.iam.gserviceaccount.com" \
#       --role="roles/secretmanager.secretAccessor" \
#       --project "$PROJECT"
#
# `printf '%s'` rather than `echo`, because echo appends a newline and the
# trailing byte becomes part of the secret. A 65-character signing key then
# fails the 64-hex check in sign.ts with a message about length that looks like
# you mistyped it.
#
# To rotate later, add a version rather than recreating:
#   printf '%s' "$NEW" | gcloud secrets versions add pack-signing-key --data-file=-
