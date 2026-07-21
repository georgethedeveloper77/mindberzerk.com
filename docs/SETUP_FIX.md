# `setup_screen.dart:438` — the last error

`themeCatalogProvider` became a `FutureProvider`, so the old synchronous
`.where` no longer compiles.

## The fix

In `_StepDistro.build`, replace:

```dart
final cards = ref
    .watch(themeCatalogProvider)
    .where((c) => c.bundled && c.specId != null)
    .toList();
```

with:

```dart
final cards = ref.watch(bundledThemeCardsProvider);
```

That is the whole change. The filter moved into the provider, which is shipped
in the updated `theme_catalog.dart` in this zip.

## Why a new provider rather than `.asData?.value ?? []`

Unwrapping the async one would compile, and it would be wrong on the first
screen anyone ever sees.

`themeCatalogProvider` reads the cached CDN index through the platform channel,
so on a cold first run it is `loading` for a frame or two. The distro step's
entire content is that row of chips, so unwrapping to an empty list gives you a
wizard step that renders blank and then pops four chips in. On a Tecno with a
cold Dart isolate that gap is visible.

Setup also has no business offering downloads. Everything it shows is already in
the APK and applies instantly, which is what makes the step feel like flipping a
switch rather than shopping. `bundledThemeCardsProvider` is a plain `Provider`
over the same `_floorCards` list, so it resolves in the same frame and can never
show anything that needs the network.

## Also worth doing while you are in there

**`pubspec.yaml`** — the analyzer info about `g_account` is real. Add:

```yaml
dependencies:
  g_account:
    path: ../../packages/g_account
```

then `melos bootstrap` again. It is an info rather than an error only because
the workspace resolved the package anyway; without the explicit dependency the
import is working by accident.

**`dock_metrics.dart:3`** — dangling library doc comment. Same shape as the one
that just broke `theme_catalog.dart`: a doc comment with no `library;` after it.
One line:

```dart
/// … existing doc comment …
library;

import '...';
```

**Confirm the version.** `pubspec.yaml` was showing `5.0.0+3` earlier while the
comment above it said `+6`. Your signed packs carry `--min-app 6`, so anything
below that makes every install come back `AppTooOld`.
