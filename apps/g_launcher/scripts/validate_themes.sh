#!/usr/bin/env bash
#
# validate_themes.sh — PHASE D7. Fourth in the family after no_snackbars.sh,
# no_bare_update.sh and no_constants.sh.
#
# Validates every theme.json against schema/theme.schema.json.
#
# WHY THIS EXISTS, and it is not documentation:
#
# The runtime parser is TOLERANT by design. An unknown key from a newer CDN
# theme is ignored, an unknown enum value degrades to a safe default, and a
# missing block falls back to the shell family. That is correct for a home
# screen — a downgrade must never black-screen someone's phone.
#
# It is also exactly why a typo in OUR OWN themes is invisible. "splsh" is not
# forward compatibility, it is a splash nobody notices is missing for a month.
# This script is the other half of that contract: strict where the app is
# lenient, and only over files we wrote.
#
# Usage:
#   ./scripts/validate_themes.sh            # every bundled theme
#   ./scripts/validate_themes.sh path.json  # one file, e.g. a downloaded pack
#
# DEPENDENCY, AND WHY IT BOOTSTRAPS ITSELF:
#
# It needs python3 with jsonschema. Homebrew's python is PEP 668 "externally
# managed", so a plain `pip install` refuses, and the documented workarounds are
# either `--break-system-packages` (which does what it says) or a venv.
#
# So this creates a throwaway venv under .tools-venv/ the first time and reuses
# it after. A validator that a new machine cannot run is a validator that gets
# skipped, and one that is skipped is worse than none — it looks like coverage.
#
# Add to .gitignore:  .tools-venv/
# Opt out with:       GL_NO_VENV=1 ./scripts/validate_themes.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="$ROOT/schema/theme.schema.json"
VENV="$ROOT/.tools-venv"

if [ ! -f "$SCHEMA" ]; then
  echo "FAIL: schema not found at $SCHEMA"
  exit 1
fi

# Pick an interpreter that can import jsonschema, in order of least surprise:
# whatever is on PATH, then an existing venv, then a fresh venv.
PY=""
if python3 -c "import jsonschema" 2>/dev/null; then
  PY="python3"
elif [ -x "$VENV/bin/python" ] && "$VENV/bin/python" -c "import jsonschema" 2>/dev/null; then
  PY="$VENV/bin/python"
elif [ "${GL_NO_VENV:-0}" = "1" ]; then
  echo "FAIL: python3 jsonschema is not installed and GL_NO_VENV=1."
  echo "      pip install jsonschema --break-system-packages"
  exit 1
else
  echo "jsonschema not found. Creating a local venv at .tools-venv (once)..."
  if ! python3 -m venv "$VENV" 2>/dev/null; then
    echo "FAIL: could not create a venv."
    echo "      pip install jsonschema --break-system-packages"
    exit 1
  fi
  # -q twice: the install banner is noise in a CI log, and this script's output
  # is meant to be scannable.
  if ! "$VENV/bin/pip" install -q -q --upgrade pip jsonschema 2>/dev/null; then
    echo "FAIL: could not install jsonschema into .tools-venv."
    echo "      Check network access to pypi.org, or:"
    echo "      pip install jsonschema --break-system-packages"
    exit 1
  fi
  PY="$VENV/bin/python"
  echo "Done. Add .tools-venv/ to .gitignore."
  echo
fi

if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  # -print0 / read -d '' rather than a bare for-loop over find: a path with a
  # space in it would otherwise split into two arguments and report two
  # nonexistent files.
  FILES=()
  while IFS= read -r -d '' f; do FILES+=("$f"); done \
    < <(find "$ROOT/assets/themes" -name 'theme.json' -print0 | sort -z)
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "FAIL: no theme.json found under assets/themes"
  exit 1
fi

"$PY" - "$SCHEMA" "${FILES[@]}" <<'PY'
import json, sys
from jsonschema import Draft202012Validator

schema_path, *files = sys.argv[1:]
schema = json.load(open(schema_path))
validator = Draft202012Validator(schema)

failed = 0
for path in files:
    short = path.split('assets/')[-1] if 'assets/' in path else path
    try:
        doc = json.load(open(path))
    except json.JSONDecodeError as e:
        print(f"  FAIL  {short}")
        print(f"        not valid JSON: {e}")
        failed += 1
        continue

    # Sorted so the report is stable between runs. A validator whose output
    # reorders makes a diff useless for seeing what actually changed.
    errors = sorted(validator.iter_errors(doc), key=lambda e: list(e.path))
    if not errors:
        print(f"  ok    {short}")
        continue

    failed += 1
    print(f"  FAIL  {short}")
    for e in errors:
        where = '.'.join(str(p) for p in e.path) or '(root)'
        print(f"        {where}: {e.message}")

print()
if failed:
    print(f"{failed} of {len(files)} themes failed")
    sys.exit(1)
print(f"all {len(files)} themes valid")
PY
