#!/usr/bin/env bash
#
# no_constants.sh — Phase B's exit gate, enforced.
#
# THE RULE: a shell or a chrome widget renders from EffectiveTheme. Never from a
# constant, never from a token file, never from the house ThemeData.
#
# Why a script and not a one-time sweep: a sweep is true on the day it is done
# and false the first time somebody adds a widget in a hurry. The rule this
# enforces is the one the whole theme layer stands on — the moment one surface
# reads Ubuntu.dockBorder, Fedora renders with Ubuntu's border and nobody
# notices for a month, because it is a 1px line and it looks fine.
#
# Third in the family, after no_snackbars.sh and no_bare_update.sh.
#
# ── ESCAPE HATCH ─────────────────────────────────────────────────────────────
# A deliberate exception is marked at the END of the offending line:
#
#     color: const Color(0x66000000),  // theme-exempt: drop shadow, not chrome
#
# The exemption lives in the source next to the thing it excuses, not in an
# allowlist in this file, so the reason is visible to whoever reads the code
# next. An exemption with no reason after the colon is itself a failure.
# ─────────────────────────────────────────────────────────────────────────────
#
# Usage:  scripts/no_constants.sh          # scan
#         scripts/no_constants.sh --list   # scan and show every hit with context

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

VERBOSE=0
[ "${1:-}" = "--list" ] && VERBOSE=1

# Surfaces the rule applies to. Chrome and shells, not tokens and not previews.
SCAN_DIRS=(
  "lib/shells"
  "lib/features/home"
  "lib/features/drawer"
  "lib/features/settings"
  "lib/features/setup"
  "lib/features/palette"
  "lib/features/search"
  "lib/features/gestures"
  "lib/design/components"
)

# Files that are ALLOWED to hold constants, because holding constants is their
# job. Each one needs a reason.
#
#   tokens/            — the token definitions themselves
#   ubuntu_tokens      — Ubuntu's own values; the problem is who READS it
#   terminal_tokens    — same, for the TUI palette
#   theme_catalog      — storefront preview data, deliberately hardcoded colours
#   themes_screen      — paints that catalog data at thumbnail size
#   theme.dart         — the house ThemeData, bootstrap fallback only
#   device_preview     — draws from a palette it is HANDED, but has geometry
#   boot_spec/splash   — data files, no rendering
EXEMPT_FILES=(
  "lib/design/tokens/"
  "lib/design/ubuntu_tokens.dart"
  "lib/design/terminal_tokens.dart"
  "lib/design/theme.dart"
  "lib/features/themes/theme_catalog.dart"
  "lib/features/themes/themes_screen.dart"
)

is_exempt() {
  local f="$1"
  for e in "${EXEMPT_FILES[@]}"; do
    case "$f" in *"$e"*) return 0 ;; esac
  done
  return 1
}

# ── The rules ────────────────────────────────────────────────────────────────
# Each is: label | grep -E pattern
#
# Colors.transparent is allowed everywhere: it is the absence of a colour, not a
# colour, and a shell that paints nothing is exactly right.
RULES=(
  "hardcoded ARGB literal|Color\(0x"
  "Material colour constant|(^|[^a-zA-Z])Colors\.(?!transparent)[a-zA-Z]"
  "hardcoded font family|fontFamily: *'"
  "Ubuntu token read|[^a-zA-Z]Ubuntu\.[a-z]"
  "Terminal token read|[^a-zA-Z]Term\.[a-z]"
  "house palette read|GColors\."
  "house ThemeData read|Theme\.of\(context\)"
)

total=0
declare -a summary

for rule in "${RULES[@]}"; do
  label="${rule%%|*}"
  pattern="${rule#*|}"
  count=0

  for dir in "${SCAN_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      file="${line%%:*}"
      is_exempt "$file" && continue

      # Skip comment lines. A gate that flags the comment EXPLAINING the fix
      # ("// Was Ubuntu.separator, now derived from the palette") is a gate
      # people learn to ignore, and a gate people ignore is not a gate. Strip
      # the file:line: prefix first, then look at the code itself.
      code="${line#*:}"; code="${code#*:}"
      case "$(printf '%s' "$code" | sed 's/^[[:space:]]*//')" in
        //*|/\**|\**) continue ;;
      esac

      # An exemption must carry a reason: "theme-exempt:" followed by text.
      if printf '%s' "$line" | grep -qE 'theme-exempt: *[^ ]'; then
        continue
      fi

      count=$((count + 1))
      total=$((total + 1))
      [ "$VERBOSE" = "1" ] && printf '  %s\n' "$line"
    done < <(grep -rnP "$pattern" "$dir" --include='*.dart' 2>/dev/null)
  done

  summary+=("$(printf '%-26s %s' "$label" "$count")")
done

echo "── Phase B exit gate ─────────────────────────────────────────"
for s in "${summary[@]}"; do echo "  $s"; done
echo "──────────────────────────────────────────────────────────────"

if [ "$total" -gt 0 ]; then
  echo "  FAIL: $total constant read(s) in shell/chrome surfaces."
  echo
  echo "  Every one of these makes a non-Ubuntu theme render with Ubuntu's"
  echo "  values. Fix by reading EffectiveTheme, or mark a deliberate"
  echo "  exception inline:  // theme-exempt: <reason>"
  echo
  echo "  Run with --list to see them."
  exit 1
fi

echo "  PASS: no surface renders from a constant."
exit 0
