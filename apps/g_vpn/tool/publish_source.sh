#!/usr/bin/env bash
# Prepares G VPN's public source release (GPL-2.0, required by the OpenVPN
# engine it embeds).
#
#   bash apps/g_vpn/tool/publish_source.sh [destination]   # default: ../g-vpn-source
#
# Copies only git-tracked files of apps/g_vpn and packages/g_network, leaves
# out every secret and private config, adds the licence, a README and a
# workspace file, scans the result for anything key-shaped, and commits it
# in a fresh git repository. It never pushes: that is your call.
set -euo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
DEST="${1:-$ROOT/../g-vpn-source}"
VERSION="$(grep '^version:' "$ROOT/apps/g_vpn/pubspec.yaml" | awk '{print $2}')"

die() { echo "ERROR: $*" >&2; exit 1; }

# Never published: secrets, private config, build output, binaries.
EXCLUDE='(^|/)(google-services\.json|GoogleService-Info\.plist|firebase_options\.dart|key\.properties|local\.properties|.*\.jks|.*\.keystore|.*\.p12|\.env.*|\.dev\.vars)$|(^|/)env/[^/]*\.json$|(^|/)(build|\.dart_tool|\.gradle|\.idea|\.build)/|\.aar$|\.apk$|\.aab$|\.iml$'

[[ -e "$DEST" ]] && die "$DEST already exists. Remove it or pass another folder."
mkdir -p "$DEST"

echo "== Copying tracked files (version $VERSION)"
count=0
while IFS= read -r f; do
  [[ "$f" =~ $EXCLUDE ]] && continue
  mkdir -p "$DEST/$(dirname "$f")"
  cp "$ROOT/$f" "$DEST/$f"
  count=$((count + 1))
done < <(git -C "$ROOT" ls-files apps/g_vpn packages/g_network)
echo "   $count files"

# The app needs firebase_options.dart to compile. Ship a stub that says how
# to make a real one, instead of our project's identifiers.
cat > "$DEST/apps/g_vpn/lib/firebase_options.dart" <<'DART'
// Stub for the public source release. Create your own Firebase project and
// generate the real file with:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<your-project> --platforms=android
// That also writes android/app/google-services.json.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('Run `flutterfire configure` to create lib/firebase_options.dart.');
}
DART

# The two Workers' addresses are public; the env file is still yours to write.
mkdir -p "$DEST/apps/g_vpn/env"
cat > "$DEST/apps/g_vpn/env/example.json" <<'JSON'
{
  "WHOAMI_URL": "https://your-whoami-worker.example.workers.dev",
  "COMMUNITY_URL": "https://your-servers-worker.example.workers.dev",
  "ISPS_URL": "https://your-isps-worker.example.workers.dev"
}
JSON

cat > "$DEST/pubspec.yaml" <<YAML
name: g_vpn_workspace
publish_to: none
environment:
  sdk: ^3.6.0
workspace:
  - apps/g_vpn
  - packages/g_network
YAML

cat > "$DEST/README.md" <<MD
# G VPN

Source code of [G VPN](https://play.google.com/store/apps/details?id=com.mindberzerk.gvpn)
version $VERSION, published by Mindberzerk under the GNU General Public License,
version 2 (see LICENSE). The app embeds OpenVPN for Android (GPL-2.0) and the
WireGuard Android library (Apache-2.0).

## Building

1. Flutter (stable) and the Android SDK with NDK, plus \`swig\` for the OpenVPN engine.
2. Build the OpenVPN engine from source (10 to 20 minutes the first time):
   \`bash apps/g_vpn/android/openvpn/build-aar.sh\`
3. Create your own Firebase project for the app:
   \`cd apps/g_vpn && flutterfire configure --platforms=android\`
4. Copy \`apps/g_vpn/env/example.json\` to \`env/dev.json\` and point it at your own
   servers, or leave the values empty to use the app without them.
5. \`cd apps/g_vpn && flutter pub get && dart run slang && dart run pigeon --input pigeons/vpn_api.dart\`
6. \`flutter run --dart-define-from-file=env/dev.json\`

Builds from this source are not signed with Mindberzerk's key and cannot update
the Play Store version.
MD

echo "== Licence"
if ! curl -fsSL https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt -o "$DEST/LICENSE"; then
  die "Could not download the GPL-2.0 text. Save it as $DEST/LICENSE and re-run the scan below."
fi

echo "== Scanning for anything key-shaped"
# Real values only: a quoted password, or a key that is not a test
# placeholder (one character repeated). Reading a value from key.properties
# by name, as build.gradle.kts does, is fine.
hits=$(grep -rnIE \
  'AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY|PrivateKey *= *[A-Za-z0-9+/]{40,}=|(store|key)Password *= *"[^"$]+"|sk_live_|ghp_[A-Za-z0-9]{30,}|xox[baprs]-' \
  "$DEST" --exclude=LICENSE --exclude=publish_source.sh \
  | grep -vE 'PrivateKey *= *([A-Za-z0-9+/])\1{39,}=' || true)
if [[ -n "$hits" ]]; then
  echo "$hits"
  die "Possible secrets above. Nothing was committed; fix and run again."
fi
echo "   clean"

echo "== Git"
git -C "$DEST" init -q -b main
git -C "$DEST" add -A
git -C "$DEST" -c user.name="Mindberzerk" -c user.email="info@mindberzerk.com" commit -q -m "G VPN $VERSION source release"
echo
echo "Ready in $DEST. Review it, then publish:"
echo "  cd \"$DEST\""
echo "  git remote add origin git@github.com:<you>/g-vpn.git"
echo "  git push -u origin main"
