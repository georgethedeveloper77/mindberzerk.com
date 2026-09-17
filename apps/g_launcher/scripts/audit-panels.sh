#!/usr/bin/env bash
#
# Which live distro packs draw a clock, a tray, or a battery/wifi/volume chip on
# their top panel while Android's status bar is still showing.
#
# A module is only a DUPLICATE when the system status bar is visible, which is
# `layout.statusBar` absent or true. A pack that hides the system bar owns the
# whole row and is expected to carry the clock and the tray, so it reads ok.
#
# Needs curl and jq. Honours CDN_BASE_URL and INDEX_URL.
#
#   ./audit-panels.sh           table
#   ./audit-panels.sh --json    one JSON object per pack
#   ./audit-panels.sh --index   dump the raw index and stop
#
# Written for bash 3.2, which is what macOS ships: no mapfile, no associative
# arrays, no ${var,,}.

set -eu

BASE="${CDN_BASE_URL:-https://cdn.mindberzerk.com}"

# HYPHEN. `CdnIndex.kt` says the catalogue lives at
# `<cdn_base_url>/g-launcher/index.json`; the underscore is the Kotlin package
# name and resolves to a 404.
APP="g-launcher"
INDEX="${INDEX_URL:-$BASE/$APP/index.json}"
MODE="${1:-table}"

# `tray` is on this list because on a TOP panel it stays a single button whose
# face is a wifi glyph, a speaker glyph and a battery glyph. That button is the
# duplication, not the three separate modules.
DUPES='["clock","tray","battery","wifi","volume"]'

raw="$(curl -fsSL "$INDEX")" || {
  echo "index not readable at $INDEX" >&2
  exit 1
}

if [ "$MODE" = "--index" ]; then
  printf '%s\n' "$raw" | jq .
  exit 0
fi

[ "$MODE" = "table" ] &&
  printf '%-26s %-9s %-10s %s\n' PACK SYSBAR VERDICT 'TOP PANEL'

found=0

# A pipeline would run the loop in a subshell and lose `found`, so the pack list
# goes through a temp file instead.
list="$(mktemp)"
trap 'rm -f "$list"' EXIT

printf '%s\n' "$raw" | jq -r '
  [ .packs[]? | select(.packType == "theme") ]
  | unique_by(.packId)[]
  | [.packId, .path] | @tsv
' > "$list"

while IFS="$(printf '\t')" read -r id path; do
  [ -n "${id:-}" ] || continue
  found=$((found + 1))
  url="$BASE/$APP/$path/theme.json"

  if ! theme="$(curl -fsSL "$url" 2>/dev/null)"; then
    printf '%-26s %-9s %-10s %s\n' "$id" "-" "MISSING" "$url"
    continue
  fi

  printf '%s\n' "$theme" | jq -r --argjson dupes "$DUPES" --arg id "$id" --arg mode "$MODE" '
    (.layout.panels // [])                                as $panels
    | [ $panels[] | select(.side == "top") | .modules[] ]  as $top
    | (.layout.statusBar != false)                         as $sysbar
    | [ $top[] | select(. as $m | $dupes | index($m)) ]     as $hits
    | {
        pack: $id,
        sysbar: (if $sysbar then "shown" else "hidden" end),
        authored: ($panels | length > 0),
        verdict: (if ($hits | length) == 0 then "ok"
                  elif $sysbar then "DUPLICATE"
                  else "ok" end),
        duplicates: $hits,
        top: $top
      }
    | if $mode == "--json" then tojson
      else [ .pack, .sysbar, .verdict,
             (if .authored then (.top | join(" ")) else "(no panels authored)" end)
           ] | @tsv
      end
  ' | if [ "$MODE" = "--json" ]; then cat; else
        awk -F'\t' '{ printf "%-26s %-9s %-10s %s\n", $1, $2, $3, $4 }'
      fi
done < "$list"

[ "$found" -eq 0 ] && {
  echo "no theme packs in the index; run --index to see its shape" >&2
  exit 1
}

exit 0
