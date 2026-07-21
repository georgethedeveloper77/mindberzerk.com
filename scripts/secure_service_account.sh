#!/usr/bin/env bash
#
# A Firebase service-account key is sitting in the repo. Get it out, and find
# out whether it was ever committed.
#
# WHY THIS IS URGENT RATHER THAN UNTIDY. That JSON contains a private key that
# can mint session cookies for your project, impersonate your backend, and read
# or write anything the service account can reach. It is not a config file with
# an id in it; it is a credential, and the file name is a well-known pattern
# that credential scanners crawl public repos for continuously.
#
# Two cases, and the difference matters:
#
#   UNTRACKED  — you got lucky. Move it out, ignore the pattern, carry on.
#   TRACKED    — it is in git history. Deleting the file does NOT remove it;
#                anyone with the repo can `git show` it back. The key must be
#                REVOKED in the console. Rewriting history is optional and
#                secondary; revocation is the fix.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

FOUND=0
for f in *firebase-adminsdk*.json *service-account*.json *serviceAccount*.json; do
  [ -e "$f" ] || continue
  FOUND=1
  echo "── $f"

  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    echo "   STATUS: TRACKED BY GIT."
    echo
    echo "   This key must be treated as compromised. Deleting the file does not"
    echo "   remove it from history."
    echo
    echo "   1. Firebase Console -> Project settings -> Service accounts ->"
    echo "      Manage service account permissions -> the account -> Keys ->"
    echo "      DELETE this key. Do this first; everything else is cleanup."
    echo "   2. Generate a new key, put it OUTSIDE the repo."
    echo "   3. git rm --cached '$f'"
    echo "   4. If the repo has ever been pushed anywhere, rewrite history:"
    echo "        git filter-repo --path '$f' --invert-paths"
    echo "      and force-push. If it has only ever been local, revocation is"
    echo "      enough on its own."
    TRACKED=1
  else
    echo "   STATUS: untracked. Nothing is in history."
    mkdir -p "$HOME/.mindberzerk"
    mv "$f" "$HOME/.mindberzerk/$f"
    chmod 600 "$HOME/.mindberzerk/$f"
    echo "   moved to ~/.mindberzerk/$f (chmod 600)"
  fi
  echo
done

if [ "$FOUND" -eq 0 ]; then
  echo "No service-account JSON found at the repo root."
fi

# ── widen .gitignore so this cannot recur ────────────────────────────────────
echo "==> hardening .gitignore"
touch .gitignore
add_ignore() {
  grep -qxF "$1" .gitignore || { echo "$1" >> .gitignore; echo "    + $1"; }
}

grep -q "CREDENTIALS — never commit" .gitignore || cat >> .gitignore << 'IGN'

# ── CREDENTIALS — never commit ───────────────────────────────────────────────
# Every pattern below is a private key or a token. The service-account filename
# pattern in particular is one that automated scanners crawl public repos for,
# so a single accidental push is a compromise within minutes rather than a
# problem for later.
IGN

add_ignore '*firebase-adminsdk*.json'
add_ignore '*service-account*.json'
add_ignore '*serviceAccount*.json'
add_ignore '*.key'
add_ignore '*pack-signing*'
add_ignore '.env'
add_ignore '.env.local'
add_ignore '.env*.local'
add_ignore 'key.properties'
add_ignore '*.jks'
add_ignore '*.keystore'

echo
echo "==> scanning the whole tree for anything else that looks like a credential"
git ls-files 2>/dev/null | grep -Ei '(adminsdk|service.?account|\.jks$|\.keystore$|key\.properties|^\.env)' || \
  echo "    nothing tracked that matches. Good."

echo
echo "Remember: FIREBASE_SERVICE_ACCOUNT is only needed for LOCAL admin panel"
echo "development. In App Hosting, application-default credentials are supplied"
echo "and auth.ts falls back to them, so the key never has to leave your machine."
