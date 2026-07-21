# D4 — shell and menu wiring

Four edits, none longer than a few lines. Everything else is new files.

## 1. `lib/features/home/gnome/desktop_menu.dart` — the entry point

The desktop long-press bar already has a **Widgets** action. Point it at edit
mode:

```dart
import '../../desklets/desklet_edit.dart';

// in the Widgets action's onTap, after dismissing the menu:
ref.read(deskletEditProvider.notifier).enter();
```

If that action currently shows a "coming soon" message, this replaces it.
`showDesktopMenu` is called from GnomeShell and AquaShell, so both get it.

## 2. `lib/shells/gnome_shell.dart` — physics + the edit bar

GNOME has its own inline PageView. Add the same physics line the shared canvas
now carries:

```dart
child: PageView.builder(
  controller: _pages,
  scrollDirection: Axis.vertical,
  physics: ref.watch(deskletEditProvider).active
      ? const NeverScrollableScrollPhysics()
      : null,
  ...
```

and add the bar as the LAST child of the outer `Stack` (after the dock, before
or after `_Activities` — it must be on top of the desktop but it does not
matter relative to the drawer, which covers the screen anyway):

```dart
DeskletEditBar(theme: theme),
```

with:

```dart
import '../features/desklets/desklet_edit.dart';
import '../features/desklets/desklet_edit_bar.dart';
```

## 3. `plasma_shell.dart`, `tiling_shell.dart`, `aqua_shell.dart`

Physics is already handled: all three go through `WorkspaceCanvas`, which now
watches edit mode itself. They only need the bar, as the last child of their
outer `Stack`:

```dart
DeskletEditBar(theme: theme),
```

Plasma and tiling have no desktop long-press menu of their own today, so until
they do, edit mode is reachable there only if you add one. Aqua already calls
`showDesktopMenu`, so it gets the Widgets action for free.

## 4. Back should leave edit mode

Wherever the shells handle back (`LauncherActivity.onBackPressed` sends it to
Dart, and each shell has a `PopScope` for its drawer), edit mode should be the
first thing back closes:

```dart
if (ref.read(deskletEditProvider).active) {
  ref.read(deskletEditProvider.notifier).exit();
  return;
}
```

This matters more than it looks: edit mode disables workspace swiping, so a
user who does not spot the Done button has a desktop whose main gesture stopped
working. Back is the reflex they will reach for.
