#!/usr/bin/env bash
#
# no_insecure_ssh.sh - the fifth gate, after no_snackbars.sh, no_bare_update.sh,
# no_constants.sh and no_readmes.sh.
#
# THE RULE: nothing in lib/ ever disables SSH host key verification, and nothing
# ever hardcodes a credential.
#
# ─── WHY THIS IS WORTH A SCRIPT AND NOT A CODE REVIEW ────────────────────────
#
# `SSHClient` takes `disableHostkeyVerification`. It defaults to false, it is one
# named argument away, and it is the single most tempting line in the codebase
# the first time a connection refuses for a reason nobody understands. Setting it
# makes the connection work immediately, which is exactly what makes it
# dangerous: the symptom disappears and the protection goes with it.
#
# What it protects is not theoretical. Without the check, anything positioned
# between the phone and the server terminates the connection, presents its own
# key, and reads the password in clear on the first connect. The user sees a
# normal login.
#
# A reviewer catches this the day it is written and misses it the day someone
# adds it at 1am to unblock a demo. A script does not.
#
# ─── NO ESCAPE HATCH ─────────────────────────────────────────────────────────
#
# no_constants.sh allows an inline exemption because a drop shadow genuinely is
# not chrome. There is no equivalent here: there is no legitimate reason for
# this app to skip host key verification, and an exemption comment would just be
# where the bypass eventually lives.
#
# If a test ever needs an unverified connection, it belongs in test/ against a
# fake, and test/ is not scanned.
#
#   ./scripts/no_insecure_ssh.sh

set -uo pipefail
cd "$(dirname "$0")/.."

found=0

check() {
  local label="$1"
  local pattern="$2"

  while IFS= read -r file; do
    # Strip full-line and trailing comments before matching, so the doc comment
    # in ssh_connection.dart explaining that the flag is never set does not trip
    # the gate that exists because of it. A linter that flags its own
    # documentation gets commented out within a day.
    hits=$(sed -e 's|//.*$||' "$file" | grep -nE "$pattern" || true)
    if [[ -n "$hits" ]]; then
      found=1
      while IFS= read -r line; do
        echo "  $label: $file:$line"
      done <<< "$hits"
    fi
  done < <(find lib -name '*.dart' -type f | sort)
}

check "host key verification disabled" 'disableHostkeyVerification'
check "hardcoded password"             'password: *['"'"'"]'
check "hardcoded private key"          'BEGIN (OPENSSH|RSA|EC) PRIVATE KEY'

if [[ $found -eq 1 ]]; then
  cat <<'EOF'

FAIL: insecure SSH usage in lib/.

Host key verification is what stops a machine in the middle reading the
password on the first connect. It is not optional and it has no exemption.

If a connection is failing, the fix is in the pin: `host forget <alias>` drops
a saved key so the next connect asks again. That is a deliberate act by the
person, which is the point.

EOF
  exit 1
fi

echo "no_insecure_ssh: 0"
