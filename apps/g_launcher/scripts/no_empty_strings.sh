#!/usr/bin/env bash
# An empty translation renders as blank space rather than as a visible fault,
# so it survives testing in a way a missing key does not.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
python3 - <<'PY'
import json, sys
empty = [k for k, v in json.load(open('assets/i18n/en.json')).items()
         if not str(v).strip()]
if empty:
    print('Empty translations:', *empty, sep='\n  ')
    sys.exit(1)
print('No empty translations')
PY
