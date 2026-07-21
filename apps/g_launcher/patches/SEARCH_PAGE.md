# SearchPage — the third surface with the same blind spot

## Confirmed

`_results()` watched `visibleAppsProvider(_query)`, which returns
`List<AppEntry>`. A launcher entry is not one, so typing "settings" in the GNOME
drawer's search page found Android's Settings app and never G Launcher's.

That is three surfaces now, all the same root cause:

| surface | symptom | fixed in |
|---|---|---|
| terminal | no drawer at all, Settings unreachable | Phase A `_commands` |
| rofi (tiling) | present on empty query, vanishes when you type | `drawerSearchProvider` |
| GNOME search page | never present | this patch |

Each was found separately because each looked like a different bug. They were
one bug: **every search path ranks `AppEntry`, and the launcher's own entries
are not apps.**

## The fix

`search_page.dart` gains a **Launcher** section above the app grid, shown only
when the query matches. Two changes and one new widget:

- `_results()` also computes `launcherItemsMatching(_query)`
- the empty state now says "Nothing matches" rather than "No apps match", since
  a query can now succeed with zero app results
- the grid is factored into `_appGrid()` so both branches share it

A **separate section**, not cells mixed into the grid, for two reasons. The grid
is typed to `AppEntry` all the way down — `_AppCell`, `onTap`, the usage
recording — so mixing would mean threading a sealed type through the whole page
for two rows. And a launcher entry genuinely is not an app; a heading says so,
the same way the drawer now pins these above the app list instead of sorting
them in.

Tapping routes through `activateDrawerItem`, the drawer's own router, so this
page cannot drift from what the same entry does elsewhere.

## Shared vocabulary

`launcherItemsMatching(query)` is now public in `drawer_items.dart` and is the
single matcher all three surfaces use. Three private copies of "does 'theme'
mean Settings" is how a search box starts disagreeing with itself between
shells.

Aliases: `settings`, `theme`, `themes`, `distro`, `launcher`, `wallpaper`,
`gestures`, `icons` → G Launcher Settings. `android`, `system`, `device`,
`phone` → Device Settings.

The theme one is the point. Nobody hunting for the distro picker types
"G Launcher Settings"; they type "theme".

## Files

```
lib/features/drawer/drawer_items.dart     pinned order + drawerSearchProvider
                                          + launcherItemsMatching (public)
lib/features/search/search_page.dart      Launcher section
```

Plus the one-line change in `tiling_launcher.dart` from the previous note:

```dart
final results = ref.watch(
  drawerSearchProvider((theme: theme, query: query)),
);
```

## Unverified

`_LauncherHit` uses `d.text.body`, `c.text`, `c.textMuted`, `c.textFaint` and
`LauncherBrandIcon(theme:, size:)` — all copied from call sites already in
`search_page.dart` and `app_drawer.dart`, so they should be right. But I have
not compiled it. If `LauncherBrandIcon` takes different named parameters, that
is the one line to check.

## After this

Every shell, three ways in:

- **drawer** — first row, after folders (Ubuntu, Fedora, Aqua)
- **search** — "settings", "theme", "wallpaper", "gestures" all find it
- **desktop long-press** — Settings action (GNOME, Aqua)

KDE keeps its Kickoff footer. Arch gets both drawer and typed search. Terminal
keeps `settings` and `themes` as commands.
