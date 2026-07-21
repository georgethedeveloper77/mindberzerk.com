# Settings not appearing — diagnosis and fix

## It was never missing

`drawerItemsProvider` appends both entries. All four drawers have switch arms
for them. `activateDrawerItem` routes both. The `null`s in kickoff_drawer and
tiling_launcher are `onLongPress`, which is correct — nothing to pin, rename or
uninstall on a launcher entry.

I said this was "already solved" from my notes rather than from the files, and
that was wrong twice over: it was wrong to assert without looking, and the thing
I asserted was true of the code and false of the experience.

## Two real failures

**1. Buried alphabetically.** They were sorted into the same A-to-Z pass as the
apps, so on a 261-app device "G Launcher Settings" sits under G roughly sixty
rows down and "Device Settings" under D. Anyone hunting for settings scrolls to
S, finds Android's Settings app, and concludes we do not have one.

**2. Invisible to the rofi search.** `tiling_launcher.dart` renders
`drawerItemsProvider` on an empty query but switches to `paletteResultsProvider`
the moment you type — and that ranks `AppEntry`, which a launcher entry is not.
So typing "settings" on Arch could never find it. Identical root cause to the
terminal shell, which only got fixed because there the absence was total rather
than intermittent.

## The fix

`drawer_items.dart` only. Two changes.

### Launcher entries are pinned, not sorted

Order is now: **folders, launcher entries, apps A-Z.**

This reverses the Phase A decision to sort them in like any other app. They are
not apps — they are the launcher's own chrome, and chrome buried among 261
third-party icons is chrome nobody finds. It is the same argument that already
puts folders first.

KDE reached this independently: `kickoff_drawer` keeps them out of its main list
and pins them to its footer. This brings the grid drawers into line rather than
leaving one shell right and three wrong.

### `drawerSearchProvider`

Substring filter over the full drawer list, launcher entries included, plus
aliases: `theme`, `themes`, `distro`, `wallpaper`, `gestures`, `icons`,
`launcher` all find G Launcher Settings. Someone after the theme picker types
"theme", not "G Launcher Settings", and the picker is one tap inside that
screen.

Substring rather than fuzzy on purpose. Fuzzy is right for the palette, where
two letters should produce a best guess. Here the list is already on screen and
the user is narrowing it; results reordering under a substring reads as the list
fighting you. `AppDrawer`'s own filter already made that call.

## Wiring, one line

In `tiling_launcher.dart`, the typed branch currently reads
`paletteResultsProvider`. Point it at the new provider:

```dart
final results = ref.watch(
  drawerSearchProvider((theme: theme, query: query)),
);
```

The tiles already switch over `DrawerItem`, so the non-empty branch can use the
same builder as the empty one. That also removes the odd seam where typing
changed what KIND of thing the list contained.

Fuzzy highlighting is lost in that branch. If you want it back, rank
`DrawerItem` by `label` with `Fuzzy.rank` instead — the matcher is already
generic over its `label:` callback, so it is a type argument change, not new
code.

## Still unverified: the GNOME search page

`AppDrawer` routes typing to `SearchPage` (`features/search/search_page.dart`),
which I have not seen. If it searches `shellAppsProvider` or
`paletteResultsProvider`, it has the same blind spot and the same one-line fix.

Send that file and I will check rather than guess. Given the last two rounds, I
would rather look.

## What to expect after

Open the drawer on Ubuntu, Fedora or Aqua: **G Launcher Settings and Device
Settings are in the first row**, after any folders. Themes are the first row
inside Settings, so "change themes" is now two taps from the drawer on every
graphical shell.

Arch: typing "settings" or "theme" in the rofi box finds it once the one-line
change above is in.

KDE: unchanged, it was already right.

Terminal: unchanged, `settings` and `themes` are commands.
