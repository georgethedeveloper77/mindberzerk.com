# Fixing the ten analyzer errors

Eight of them come from **two files that never landed**, not from bad code.

## 1. `lib/data/cdn/pack_repository.dart` is missing

Your tree has `lib/data/billing/` but no `lib/data/cdn/`, so the pack bridge zip
either was not extracted or went somewhere else. That single absence explains:

```
Undefined name 'packProgressProvider'      themes_screen.dart:47
Undefined name 'packActionsProvider'       themes_screen.dart:72
Undefined name 'catalogueProvider'         theme_catalog.dart:286
```

It is re-shipped here.

## 2. Pigeon has not been run

`lib/platform/` holds only `launcher_api.g.dart`. `pack_api.g.dart` is generated,
not committed by me, which is why:

```
Undefined class 'PackInfo'                 theme_catalog.dart:207, 323
'PackInfo' isn't a type                    theme_catalog.dart:290
```

Fix:

```bash
cd apps/g_launcher
dart run pigeon --input pigeons/pack_api.dart
```

If `pigeons/pack_api.dart` is also missing, the same zip that carried the
repository carried it.

## 3. `library;` after the imports — my mistake

```
The library directive must appear before all other directives   theme_catalog.dart:40
```

Correct order is doc comment, then `library;`, then imports. This is the third
time this exact thing has bitten this codebase (`aqua_dock_metrics.dart`, then
nearly `grid_metrics.dart`). `layout_resolver.dart` is the pattern to copy.

Fixed copy included.

## 4. `ChromeColors.onSurface` does not exist — my guess, wrong

```
The getter 'onSurface' isn't defined for the type 'ChromeColors'   themes_screen.dart:272
```

I used it for the progress-bar track without having seen `chrome_theme.dart`.
Changed to `c.line`, which the same file already uses for card borders and is
the right weight for a track anyway. Fixed copy included.

## 5. `setup_screen.dart:438` — a real consequence you need to fix by hand

```
The method 'where' isn't defined for the type 'AsyncValue'
```

`themeCatalogProvider` changed from `Provider<List<ThemeCard>>` to
`FutureProvider<List<ThemeCard>>`, so every reader has to unwrap it. I do not
have `setup_screen.dart`, so this one is yours:

```dart
// before
final cards = ref.watch(themeCatalogProvider);

// after — the floor is always present, so an empty list only appears for the
// single frame before the cached catalogue resolves.
final cards = ref.watch(themeCatalogProvider).asData?.value ?? const <ThemeCard>[];
```

Then `grep -rn "themeCatalogProvider" lib/` and check for any other reader.
`themes_screen.dart` is already updated; setup is the only other one I know of.

## Order to apply

```bash
# 1. layout cleanup (admin nesting, the literal {drawer,settings} directory)
./scripts/fix_c4_layout.sh

# 2. extract this zip

# 3. generate the bridge
cd apps/g_launcher && dart run pigeon --input pigeons/pack_api.dart

# 4. fix setup_screen.dart by hand, per section 5

# 5.
flutter analyze
```
