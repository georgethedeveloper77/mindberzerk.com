# Retiring `lib/**/README.md`

Thirteen files. **Six are actively wrong**, which is the real argument: a stale
README is worse than no README, because it reads as authority and nobody
re-checks it against the code.

## The six that are lying

| File | What it says | What is true |
|---|---|---|
| `platform/README.md` | `dart run pigeon --input pigeons/g_launcher_api.dart` | The file is `pigeons/launcher_api.dart`. **This one has already cost you an evening** — the Pigeon source was lost once and reconstructed by hand. A wrong regen command in the docs is how that happens again. |
| `features/gestures/README.md` | "Swipe up -> drawer. Swipe down -> search." | Both are UNBOUND. Vertical belongs to workspaces now; notifications moved to swipeRight, activities to swipeLeft. |
| `data/repositories/README.md` | lists `icon_repository.dart` and `theme_repository.dart` | Neither exists. Only `app_repository.dart` and `shell_apps.dart` do. |
| `features/settings/README.md` | "Home grid: rows x columns" | Renamed to "Desktop grid" in Phase A. An authentic desktop has no app-icon grid; that row is the widget placement grid. |
| `data/db/README.md` | Drift/SQLite when state outgrows prefs | Drift was rejected. The decision is `shared_preferences` + JSON. The directory is empty. |
| `features/folders/README.md` | "Home-screen folders" | Folders are DRAWER folders and live in `data/prefs/drawer_layout.dart` and `features/settings/folders_screen.dart`. This directory is empty. |

## Disposition

**Delete the directory outright** (empty, and the README describes work that
either moved or was rejected):

- `lib/data/db/`
- `lib/features/folders/`
- `lib/features/ecosystem/` — legitimately future work (Phase D), but future
  work belongs in `MINDHUNTER.md`, not in a file that makes an empty directory
  look inhabited.

**Delete the README, content already superseded:**

- `lib/platform/README.md` — the correct command now lives in the root
  `pubspec.yaml` melos script (`melos run pigeon`) and in the Pigeon source
  header. "Never hand-roll a MethodChannel" is a project rule, not a directory
  rule; it goes in `MINDHUNTER.md`.

**Absorbed into new barrel files, shipped in this zip:**

- `lib/core/README.md` → `lib/core/core.dart`
- `lib/design/README.md` + `lib/design/components/README.md` →
  `lib/design/design.dart`

Both are genuinely good content and both describe *liftable* boundaries, so
they belong at the package seam. The components README's "Not here yet" section
described `chromeFamily` and per-family radii as future work; both shipped in
Phase B, which is the case for source-adjacent docs in one line.

**Needs the source file to fold correctly — send these four and I will do it:**

| README | Target |
|---|---|
| `features/drawer/README.md` | `features/drawer/app_drawer.dart` — the perf rules (lazy grid, never decode icons on the main isolate, read from the native disk cache) are real and still true. |
| `features/gestures/README.md` | `features/gestures/gesture_actions.dart` — keep the durable rule (double-tap left edge is inherited muscle memory from the shipped app, removing it is a felt regression), drop the wrong defaults. |
| `features/palette/README.md` | `features/palette/fuzzy.dart` — the matcher must stay pure Dart with no Flutter imports, and the ranking (exact prefix > word boundary > subsequence, tie-broken by launch count) is a spec worth keeping. |
| `features/themes/README.md` | `features/themes/themes_screen.dart` — "previews rendered from ThemeSpec, never screenshots" is the decision that keeps them from drifting. This one folds naturally into the storefront work anyway. |
| `features/settings/README.md` | `features/settings/settings_screen.dart` — keep "we deep-link to real Android settings rather than reimplementing them" and "overrides are stored PER THEME"; drop the stale row list. |

## The command, once the folds are done

```bash
cd apps/g_launcher
rm -rf lib/data/db lib/features/folders lib/features/ecosystem
rm lib/platform/README.md lib/core/README.md \
   lib/design/README.md lib/design/components/README.md \
   lib/features/drawer/README.md lib/features/gestures/README.md \
   lib/features/palette/README.md lib/features/themes/README.md \
   lib/features/settings/README.md lib/data/repositories/README.md
find lib -name README.md   # should print nothing
```

## Worth adding as a fourth gate

`scripts/no_constants.sh`, `no_snackbars.sh` and `no_bare_update.sh` already
exist. A `no_readmes.sh` that fails on `find lib -name README.md` returning
anything would stop this growing back, and it is a two-line script.
