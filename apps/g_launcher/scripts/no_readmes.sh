#!/usr/bin/env bash
#
# Gate four, after no_snackbars.sh, no_bare_update.sh and no_constants.sh.
#
# WHY THIS IS WORTH A SCRIPT. Thirteen READMEs accumulated under lib/ and SIX of
# them were actively wrong by the time anyone re-read them: a Pigeon regen
# command naming a file that does not exist, gesture defaults that had since
# changed, two repository files that were never written, a Drift layer that was
# rejected, a folders directory whose feature lives somewhere else entirely.
#
# None of that was carelessness. It is the default outcome, because a README
# beside code is a second place for truth to live and NOTHING EVER FAILS when it
# drifts. The compiler does not read it, the tests do not read it, and the next
# person does, and believes it.
#
# Rationale belongs in a `library;` doc comment on the file it governs, where it
# sits in the diff next to the thing it explains and gets re-read every time
# that thing changes. Project-level planning belongs in MINDHUNTER.md. Neither
# belongs in lib/.
#
# Worth noting what the cleanup actually found: of the five READMEs thought to
# hold unique rationale, THREE were already fully documented in their own source
# (gesture_actions.dart carried the correct defaults AND the v1 muscle-memory
# note; fuzzy.dart carried the entire ranking spec; theme_catalog.dart carried
# the no-screenshots decision). The files that followed this rule were the ones
# that stayed correct. That is the argument, in one sentence.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

found="$(find lib -name 'README.md' 2>/dev/null || true)"

if [ -n "$found" ]; then
  echo "no_readmes: FAIL"
  echo
  echo "$found" | sed 's/^/  /'
  echo
  echo "Move the content into a library doc comment on the most load-bearing"
  echo "file in that directory, or into MINDHUNTER.md if it is planning."
  exit 1
fi

echo "no_readmes: 0"
