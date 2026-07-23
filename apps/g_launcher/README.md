# G Launcher

A faithful Linux desktop for Android. Not a grid-of-icons launcher with a
theme slapped on: each "distro" reproduces a real desktop environment, from
the shell layout down to the boot log, the installer, the fonts and the icon
treatment.

Part of the Mindberzerk ecosystem (`mindberzerk.com`), built as a standalone
Flutter project. Package: `com.mindhunter.g_launcher`.

## What it does

- **Desktop shells, keyed by DE, not by distro.** GNOME (top bar, left dock,
  vertical workspaces), KDE Plasma (bottom panel), tiling WM (waybar), a full
  TUI terminal shell (type to launch), and Aqua (magnifying dock). A distro is
  data on top of a shell: palette, wallpaper, boot log, splash, icon recipe.
- **Data-driven themes.** `theme.json` files, bundled in the APK or delivered
  over the CDN (Cloudflare R2), selected live with a guaranteed Ubuntu
  fallback. `EffectiveTheme` is the single source of truth for rendering.
  Shells never read constants; `scripts/no_constants.sh` polices this.
- **Authentic details.** Verbose boot logs authored per distro, Plymouth-style
  splashes, per-shell installers (wizard for GNOME, Calamares-style rail for
  Plasma, TTY console for tiling/terminal), distro fonts under their real
  licences.
- **Monetization: distro packs, never feature gates.** All launcher features
  are free. Paid SKUs are whole distros and standalone icon packs over the
  CDN via Play Billing. Ubuntu, KDE Plasma and Terminal ship free in the APK.
- **No ads, ever.**

## Stack

- Flutter (Android first), plain Riverpod 3 (no codegen)
- Pigeon for the native bridge (`pigeons/launcher_api.dart` is load-bearing,
  never delete it)
- Kotlin for the heavy lifting: app repository, icon rendering and caching,
  wallpaper control
- `shared_preferences` + JSON for persistence
- Firebase: Analytics, Crashlytics, Remote Config (init is fail-safe; the
  launcher must boot on de-Googled ROMs)
- Cloudflare R2 CDN at `cdn.mindberzerk.com`, admin panel at
  `admin.mindberzerk.com`

## Repo layout

```
lib/
  engine/       theme_spec, effective_theme, layout_resolver, boot/splash specs
  shells/       gnome, plasma, tiling, tui, aqua
  features/     home, drawer, dock, settings, setup, themes, boot, desklets
  design/       chrome components, tokens, device previews
  data/         prefs, billing entitlements, CDN pack repository
  i18n/         translations engine (see below)
  system/       live stats, wallpaper source
assets/
  themes/       bundled theme.json + wallpapers per distro (non-recursive!)
  i18n/         one JSON per language, en.json is the source of truth
  fonts/        Ubuntu, UbuntuMono (UFL 1.0, registered in LicenseRegistry)
pigeons/        Pigeon schema (source of the generated native bridge)
tool/           i18n_extract.dart, i18n_translate.py, i18n_unwrap.py
scripts/        no_snackbars.sh, no_bare_update.sh, no_constants.sh
```

## Build and run

```bash
flutter pub get
flutter run
```

`flutter run` resets the default home app on every reinstall. Restore it:

```bash
adb shell cmd package set-home-activity com.mindhunter.g_launcher/.MainActivity
```

Regenerate the native bridge after editing the Pigeon schema:

```bash
dart run pigeon --input pigeons/launcher_api.dart
```

Exit gates before shipping:

```bash
./scripts/no_constants.sh     # shells must read EffectiveTheme, not constants
./scripts/no_snackbars.sh     # all toasts via context.showMessage
./scripts/no_bare_update.sh   # never .update() on notifiers
```

## Internationalization

Strings live in flat JSON under `assets/i18n/`, keyed like
`setup.welcome.chooseLanguage`. `en.json` is the source of truth. Lookups go
through `ref.t('key')` or `context.t('key', {'name': value})` with `{name}`
placeholders. Missing keys fall back to English, then to the key itself, so a
gap is visible instead of blank. The language is a global pref
(`appLocale.v1`); `null` follows the device language.

Deliberately untranslated: distro names, version strings, boot logs and
terminal output. A localized Linux boot log would break the authenticity that
is the point.

### Adding a language

1. Add the entry to `kBundledLocales` in `lib/i18n/app_locale.dart` (native
   name with real diacritics).
2. Add the code to `LANGUAGES` in `tool/i18n_translate.py`.
3. Run the translation workflow below. The setup language box scrolls, so the
   list can grow to anything Google Translate supports (~130 languages).

### Translation workflow

One-time setup:

```bash
dart pub add --dev analyzer
pip install deep-translator
```

Extract every user-facing string in `lib/` into `assets/i18n/en.json`
(report only, changes nothing but en.json):

```bash
dart run tool/i18n_extract.dart
```

Wrap the strings in `context.t(...)` calls (run on a branch, compile after,
expect to drop a few `const`s by hand):

```bash
dart run tool/i18n_extract.dart --write
```

Machine-translate every missing key into every configured language using
Google Translate (free, no API key):

```bash
python3 tool/i18n_translate.py
```

Useful variants:

```bash
dart run tool/i18n_extract.dart --dir lib/features/setup   # limit scope
dart run tool/i18n_extract.dart --write --ref              # wrap with ref.t
python3 tool/i18n_translate.py es fr                       # only these codes
python3 tool/i18n_translate.py --all es                    # re-translate all keys
python3 tool/i18n_translate.py --dry-run                   # preview, no network
```

Notes that matter:

- The extractor re-parses every file it rewrites and refuses to write one it
  would break. It skips directives, URIs, asset paths, identifiers and code
  strings, and reuses existing keys by value so re-runs are stable.
- The translator only fills keys missing from each `<code>.json`, so reviewed
  translations survive re-runs. Placeholders and product names (G Launcher,
  Ubuntu, Dock, ...) are protected through the round trip; a string whose
  placeholder does not survive falls back to English with a warning.
- Machine output is a first pass. Review the short button labels per language.
- `tool/i18n_unwrap.py` is the disaster-recovery tool: it reverses a bad
  extract using `en.json` as the undo log. You should not need it in normal
  work. `--force-file <path>` unwraps every key in a named file.

### Runtime wiring (already in place)

- `main.dart` loads the saved locale before the first frame and overrides
  `i18nProvider`.
- `app.dart` feeds `locale` and the `flutter_localizations` delegates to
  `MaterialApp` (RTL for Arabic comes free).
- New assets require a cold rebuild: `flutter clean && flutter run`. Hot
  restart does not pick up newly declared asset folders.

## Conventions

- Shells read `EffectiveTheme`, never `ThemeSpec` constants or hardcoded
  values. House `ThemeData` is bootstrap fallback only.
- Never `.update()` on notifiers: `.edit()` on `PrefsNotifier`, `.set()` or
  `.record()` on the rest. `.update()` silently loses persisted prefs.
- All transient messages via `context.showMessage(string)`. No SnackBars
  anywhere in the ecosystem.
- Nullable stats render as absent rows, never placeholder strings.
- `library;` must precede all imports (doc comment, then `library;`, then
  imports).
- Import `theme_spec.dart` with `show` where `DockSide` would collide with
  `dock_metrics.dart`.
- Asset folders in pubspec are non-recursive: every theme subfolder needs its
  own line.
- Commit before running any batch tool over the tree.

## Licences

Ubuntu and UbuntuMono ship under the Ubuntu Font Licence 1.0, registered with
`LicenseRegistry` and visible in the app's licence page. Simple Icons brand
glyphs are CC0 (the files, not the trademarks). GPL icon sets (Papirus,
Numix) are not distributable over the CDN and are not used.
