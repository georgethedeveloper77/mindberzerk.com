#!/usr/bin/env python3
"""i18n_unwrap.py (v3) - REPAIR script for the broken extractor run.

Adds two fixes on top of v2:

  1. MULTILINE LITERALS. The broken extractor also captured triple-quoted
     multiline strings (ASCII art, fastfetch text). Earlier unwrap passes wrote
     those back as single-quoted literals with RAW newlines, which is illegal
     Dart ("unterminated string literal"). The broken rendering is a pure
     function of the mapping value, so this pass finds the exact broken form
     and replaces it with a correctly escaped literal.

  2. IMPORTS. The broken run injected the i18n import once PER RUN, so files
     it hit twice have it twice. This pass removes ALL copies from files with
     no i18n usage, and for files that DO use i18n it keeps exactly one copy,
     relocated below `library;` when the injection landed above it.

Reads the undo mapping from the union of every assets/i18n/en*.json (backup
first, live en.json last). Run repeatedly: idempotent. Stdlib only.

Usage:
    python3 tool/i18n_unwrap.py --dry-run
    python3 tool/i18n_unwrap.py
    python3 tool/i18n_unwrap.py --force-file lib/path/to/file.dart
        # unwraps EVERY key in that file, curated ones included. For files
        # that contain no intentional i18n calls but caught curated keys via
        # the broken run's value-dedupe (e.g. a literal 'Cancel' being keyed
        # as common.cancel). Repeatable.
"""

import glob
import json
import os
import re
import shutil
import sys

EN_PATH = "assets/i18n/en.json"
BACKUP_GLOB = "assets/i18n/en*.json"
BACKUP_PATH = "assets/i18n/en_backup.json"
LIB_ROOT = "lib"

I18N_IMPORT_RE = re.compile(
    r"^import 'package:[a-z0-9_]+/i18n/i18n\.dart';\n", re.MULTILINE)
LIBRARY_RE = re.compile(r"^library[^;]*;\s*\n", re.MULTILINE)
ANY_IMPORT_RE = re.compile(r"^import\s+'[^']+';[^\n]*\n", re.MULTILINE)

# A file "uses i18n" if any of these appear in it (imports excluded first).
USES_I18N_RE = re.compile(
    r"\.t\(|i18nProvider|I18nController|I18nState|loadInitialI18n|"
    r"kBundledLocales|AppLocale|localesForDisplay|Translations|LanguageList")

KEEP = {
    "common.back", "common.cancel", "common.done", "common.next", "common.ok",
    "common.save", "common.skip",

    "settings.language.title", "settings.language.system",
    "settings.language.subtitle",

    "setup.step.welcome", "setup.step.distro", "setup.step.dock",
    "setup.step.drawer", "setup.step.folders", "setup.step.install",

    "setup.title.welcome", "setup.title.distro", "setup.title.dock",
    "setup.title.drawer", "setup.title.folders", "setup.title.install",

    "setup.subtitle.welcome", "setup.subtitle.distro", "setup.subtitle.dock",
    "setup.subtitle.drawer", "setup.subtitle.folders", "setup.subtitle.install",

    "setup.next.getStarted", "setup.next.install", "setup.next.continue",

    "setup.status", "setup.window.install", "setup.window.console",

    "setup.welcome.language", "setup.welcome.chooseHome",
    "setup.welcome.setHome", "setup.welcome.homeHelper",
    "setup.welcome.homeSet", "setup.welcome.homeSetSub",
    "setup.welcome.homeWarn",
}

CALL_RE = re.compile(r"(?:context|ref)\.t\('([^'\\]+)'\)")


def base_escape(s):
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")


def dart_quote(s):
    """Correct single-quoted Dart literal, newlines escaped."""
    return "'" + base_escape(s).replace("\n", "\\n").replace("\r", "\\r") + "'"


def broken_quote(s):
    """What earlier passes wrote for multiline values: newlines left raw.
    Used only to FIND previous bad output, never to write."""
    return "'" + base_escape(s) + "'"


def load_mapping():
    mapping = {}
    paths = sorted(glob.glob(BACKUP_GLOB))
    paths.sort(key=lambda p: os.path.basename(p) == "en.json")  # live last
    for p in paths:
        try:
            with open(p, encoding="utf-8") as f:
                mapping.update(json.load(f))
        except (OSError, json.JSONDecodeError) as e:
            print("skipping unreadable %s (%s)" % (p, e))
    return mapping, paths


def fix_imports(out):
    """Remove all injected i18n imports; if the file uses i18n, put exactly one
    back in a legal position (after existing imports, and always after any
    `library;`). Returns (new_src, removed_count, kept_one)."""
    matches = I18N_IMPORT_RE.findall(out)
    if not matches:
        return out, 0, False
    import_line = matches[0]
    stripped = I18N_IMPORT_RE.sub("", out)

    if not USES_I18N_RE.search(stripped):
        return stripped, len(matches), False

    # Uses i18n: insert one copy legally.
    anchor = None
    for m in ANY_IMPORT_RE.finditer(stripped):
        anchor = m  # last remaining import
    if anchor is not None:
        pos = anchor.end()
    else:
        lib = LIBRARY_RE.search(stripped)
        pos = lib.end() if lib else 0
    rebuilt = stripped[:pos] + import_line + stripped[pos:]
    return rebuilt, len(matches) - 1, True


def dart_files(root):
    for dirpath, _dirs, files in os.walk(root):
        p = dirpath.replace("\\", "/")
        if "/i18n" in p or "/generated" in p:
            continue
        for f in files:
            if f.endswith(".dart") and not f.endswith((".g.dart", ".freezed.dart")):
                yield os.path.join(dirpath, f)


def main(argv):
    dry = "--dry-run" in argv

    # --force-file <path> (repeatable): unwrap curated keys too in these files.
    force_files = set()
    argv = list(argv)
    while "--force-file" in argv:
        i = argv.index("--force-file")
        force_files.add(os.path.normpath(argv[i + 1]))
        del argv[i:i + 2]

    mapping, sources = load_mapping()
    if not mapping:
        sys.exit("no en*.json found under assets/i18n - nothing to restore from")
    print("undo mapping: %d key(s) from %s" % (len(mapping), ", ".join(sources)))

    # Values whose earlier restoration produced illegal literals.
    multiline = {k: v for k, v in mapping.items() if ("\n" in v or "\r" in v)}

    restored = 0
    healed = 0
    imports_removed = 0
    files_changed = 0
    unknown = {}

    for path in sorted(dart_files(LIB_ROOT)):
        with open(path, encoding="utf-8") as f:
            src = f.read()
        out = src
        count = [0]
        forced = os.path.normpath(path) in force_files

        # 1. Unwrap remaining .t('key') calls.
        def sub(m):
            key = m.group(1)
            if key in KEEP and not forced:
                return m.group(0)
            if key not in mapping:
                unknown.setdefault(key, path)
                return m.group(0)
            count[0] += 1
            return dart_quote(mapping[key])

        out = CALL_RE.sub(sub, out)

        # 2. Heal broken multiline literals written by earlier passes.
        healed_here = 0
        for v in multiline.values():
            bad = broken_quote(v)
            if bad in out:
                out = out.replace(bad, dart_quote(v))
                healed_here += 1

        # 3. Imports: strip all injected copies, re-add one only if used.
        out, removed_here, _kept = fix_imports(out)

        if out != src:
            files_changed += 1
            restored += count[0]
            healed += healed_here
            imports_removed += removed_here
            bits = []
            if count[0]:
                bits.append("%d restored" % count[0])
            if healed_here:
                bits.append("%d multiline literal(s) healed" % healed_here)
            if removed_here:
                bits.append("%d import(s) removed/moved" % removed_here)
            print("%s: %s" % (path, ", ".join(bits) or "imports normalised"))
            if not dry:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(out)

    print("")
    print("%s%d restored, %d multiline healed, %d imports removed, %d file(s) changed."
          % ("[dry-run] " if dry else "", restored, healed, imports_removed, files_changed))

    if unknown:
        print("")
        print("STILL WRAPPED - %d key(s) in code but in NO en*.json "
              "(hand fix; first sighting shown):" % len(unknown))
        for k in sorted(unknown):
            print("  %s   (%s)" % (k, unknown[k]))

    # Keep the live en.json curated.
    try:
        with open(EN_PATH, encoding="utf-8") as f:
            live = json.load(f)
    except (OSError, json.JSONDecodeError):
        live = {}
    junk = [k for k in live if k not in KEEP]
    if junk:
        print("")
        print("%sPruning %d junk key(s) from %s." % ("[dry-run] " if dry else "", len(junk), EN_PATH))
        if not dry:
            if not os.path.exists(BACKUP_PATH):
                shutil.copyfile(EN_PATH, BACKUP_PATH)
            pruned = {k: v for k, v in live.items() if k in KEEP}
            keys = sorted(pruned)
            lines = ["{"]
            for i, k in enumerate(keys):
                comma = "" if i == len(keys) - 1 else ","
                lines.append("  %s: %s%s" % (
                    json.dumps(k, ensure_ascii=False),
                    json.dumps(pruned[k], ensure_ascii=False), comma))
            lines.append("}")
            with open(EN_PATH, "w", encoding="utf-8") as f:
                f.write("\n".join(lines) + "\n")

    print("")
    print("Next: flutter analyze. When it is back to baseline, COMMIT, then "
          "delete en_backup.json.")


if __name__ == "__main__":
    main(sys.argv[1:])
