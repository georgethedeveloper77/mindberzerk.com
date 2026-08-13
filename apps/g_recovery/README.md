# G Recovery

`com.mindhunter.g_recovery` · already live on Play with 1K+ installs.

Feature complete across Home, Storage, Device and More. What remains is listed
under "What is left" below, and most of it is not code.

**Do not create a new listing.** Same applicationId, same signing key, higher
versionCode, staged rollout. Those installs and reviews are an asset.

## The reposition

From "recover deleted files", a category Android absorbed, to a **data control
app**. Five pillars:

1. **Honest recovery.** Aggregate OS trash, OEM gallery trash and Photos trash.
   No fake deep-scan theatre. No claims root cannot back up.
2. **Audit.** Permissions, storage breakdown, duplicates.
3. **Protect.** Privacy hardening, vault.
4. **Backup to YOUR server.** SMB, WebDAV, Nextcloud, SFTP, encrypted.
   *The headline differentiator.* No cloud bill, because the storage is theirs.
5. **Device and network.** Chipset, patch level, carrier, signal, Wi-Fi.

## The niche features

Swipe to clean with inline video playback · compression (zip plus video
re-encode) · archive and reclaim, offloading to your server and then freeing
local space · storage growth charts with a fill-up forecast · per-brand OEM
recovery guides.

No ads. One-time Pro unlock, priced for the Infinix and Tecno base.

---

## What is left

### Blocking the release, and none of it is code

- The listing still says "Contains ads". It does not.
- The icon is a stock mark shared with several competitors.
- The screenshots show empty screens with zero files in them.
- Play declarations for `MANAGE_EXTERNAL_STORAGE` and `QUERY_ALL_PACKAGES`.

### In progress

- **Translation migration.** 26 strings extracted so far out of roughly 467.
  `wrap.py` has not been applied across `lib` yet. See the section below.
- **Nav bar labels.** `gNavItems` in `app/shell.dart` is a top level const, so
  no `BuildContext` reaches it and `wrap.py` correctly skips it. Home, Storage,
  Device and More need translating where `g_bottom_nav.dart` renders them.
- **Right to left audit.** The direction now flips for Arabic and Urdu, which
  is not the same as the screens being correct. Anything hardcoding a side
  stays put while everything around it mirrors:

  ```bash
  grep -rn "EdgeInsets.only(left\|EdgeInsets.only(right\|centerLeft\|centerRight\|TextAlign.left\|TextAlign.right" lib | wc -l
  ```

  `Icons.arrow_back_rounded` does not mirror either, so a back arrow ends up on
  the right edge still pointing left.
- **Font coverage.** Amharic, Bengali, Tamil, Telugu and Thai depend on what the
  OEM shipped. The language picker is the test: a script with no font renders as
  boxes there first. A language that fails leaves `GLanguage.all`.

### Features not built

- SFTP transport. SMB and WebDAV are done.
- Video compression, which needs Media3 Transformer and a `mediaProcessing`
  foreground service. Images are done.
- View mode and sort persistence.
- Camera test tool, alongside the existing screen, sound and touch tools.

---

## Layout

```
android/          the host app, plus every Kotlin implementation
assets/           content, flags, lottie, packs
lib/              the Flutter app, below
pigeons/          bridge schemas, the input to the .g.dart files
test/
tool/i18n/        translation pipeline, below
```

`build/` is generated. `assets/icons/g_recovery.png` is read at build time by
flutter_launcher_icons and is not a runtime asset.

### lib

```
app/              bootstrap, MaterialApp, shell, splash, theme
bridge/           one <name>_api.g.dart per pigeon schema, one <name>_bridge
core/             content, prefs, messenger, logging, i18n, formatting
features/         one folder per surface, each with state/ and widgets/
generated/        asset constants
ui/               the design system, every widget prefixed G
```

**app** owns the frame and nothing else. `bootstrap.dart` awaits
SharedPreferences before the first frame so the app never paints a default theme
and then snaps to the user's. `shell.dart` runs one Navigator per tab, built on
first visit rather than at launch.

**bridge** is generated plus a thin wrapper each. Pigeon codec IDs are
positional: enums are numbered before classes, fields append to the END of a
class only, and every enum-shaped value crosses the wire as a string. Inserting
a field mid-class renumbers everything after it.

**core** holds what more than one feature needs. `i18n/g_strings.dart` is the
one to read before touching copy.

**features** is the app. Each folder owns its own providers under `state/` and
its own private widgets under `widgets/`. Nothing imports another feature's
`state/`.

**ui** is the only place a colour or a radius is decided. Screens read tokens
through `context.g` and never name a hex value.

---

## Translation

### How it works

**The English IS the key.** A call site reads
`context.s('Nothing deleted here')`, not `context.s('empty.recovery.title')`.
An app with no pack loaded is exactly the app that exists today, so there is no
failure mode where a screen renders blank or shows an identifier. The cost is
that rewording copy orphans its translation, and the pipeline retires the orphan
by itself on the next run.

English is compiled in. Translations are read from `assets/content/strings-
<code>.json` and a missing or broken pack falls back to English rather than
failing.

One placeholder per string, written `{}`, substituted by `s1`. A second slot is
a build error, because `one()` fills the first only.

### Setup, once

```bash
python3 -m venv tool/i18n/.venv
tool/i18n/.venv/bin/python -m pip install deep-translator
```

`.venv` is gitignored. `extract.py` and `wrap.py` need no dependencies and run
on the system python; only `translate.py` needs the venv.

### The three scripts

| | |
| --- | --- |
| `wrap.py` | rewrites hardcoded literals into `context.s()` calls |
| `extract.py` | collects every wrapped string into `tool/i18n/en.json` |
| `translate.py` | turns `en.json` into a pack per language |

### Migrating a folder

```bash
git commit -am "before wrap"
python3 tool/i18n/wrap.py lib/features/home            # report only
python3 tool/i18n/wrap.py lib/features/home --apply
dart format lib/features/home && dart analyze lib/features/home
```

Analyze is the gate. `wrap.py` picks the nearest `BuildContext` still in scope,
and a wrong pick is an undefined name, which fails loudly rather than silently.
It refuses interpolation and anything with no `BuildContext` in scope, and lists
both for the manual pass. `bridge/`, `generated/`, `core/i18n/`,
`firebase_options.dart` and every `.g.dart` are never touched.

### Translating

```bash
python3 tool/i18n/extract.py
tool/i18n/.venv/bin/python tool/i18n/translate.py               # all languages
tool/i18n/.venv/bin/python tool/i18n/translate.py --only sw     # one
tool/i18n/.venv/bin/python tool/i18n/translate.py --dry-run     # counts only
```

One language at a time survives a throttle better than one long run:

```bash
for code in $(grep -o "code: '[a-z-]*'" lib/core/i18n/g_strings.dart \
              | cut -d"'" -f2 | grep -v '^en$'); do
  tool/i18n/.venv/bin/python tool/i18n/translate.py --only "$code" \
    || echo "FAILED $code"
done
```

Every run is incremental. A language picks up from the file already on disk and
only the missing strings are sent.

### Adding a language

One entry in `GLanguage.all` in `lib/core/i18n/g_strings.dart`, one flag at
`assets/flags/<code>.webp` at 72 by 48, then run `translate.py`. The script
reads that list out of the Dart, so the picker and the files on disk cannot
drift apart. A code with no pack yet falls back to English.

Right to left needs nothing further: `rtl: true` on the entry reaches
`MaterialApp` through `gDirectionProvider`.

### Correcting a translation

Edit the value in `assets/content/strings-<code>.json` and add its ENGLISH to
the `locked` array in the same file. Locked entries survive every future run,
including `--force`. Machine translation is a first pass; the words worth
correcting first are the ones an engine cannot know are product terms, Reclaim,
Stale, Untouched, Trash.

### The gate

```bash
python3 tool/i18n/extract.py --check
```

Exits non-zero on a stale `en.json`, on any `s()` call it cannot read, on a
second `{}` slot, and on an em dash or ellipsis character in copy. Worth running
next to `dart analyze` before packaging.

---

## Conventions

- Never SnackBars. Transient messages go through the branded messenger.
- Never `.update(` on a notifier. Use `.edit()`, `.record()` or `.set()`.
- No ellipsis characters and no em dashes in authored copy or comments.
  `TextOverflow.ellipsis` is runtime truncation and stays.
- Nullable stats render as an absent row, never `--%`.
- No screen promises a figure it has not measured. Savings are measured by
  re-encoding, never predicted.
- The attention strip never scans to populate itself.