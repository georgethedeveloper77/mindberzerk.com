# D3 — three one-line shell patches

Everything else in this drop is new files or files replaced wholesale. These
three are edits to files I either do not have the latest copy of, or that are
large enough that a blind rewrite is the wrong risk.

## 1. `lib/shells/gnome_shell.dart` (I have it, but it is a big file)

GNOME keeps its own inline copy of the workspace PageView. Around line 269:

```dart
  itemBuilder: (_, __) => const SizedBox.expand(),
```

becomes:

```dart
  itemBuilder: (_, page) =>
      DeskletSurfaceView(theme: theme, page: page),
```

plus the import:

```dart
import '../features/desklets/desklet_surface.dart';
```

## 2. `plasma_shell.dart`, `tiling_shell.dart`, `aqua_shell.dart`

`WorkspaceCanvas` gained an optional `theme`. All three already have `theme` in
scope at the call site:

```dart
WorkspaceCanvas(controller: _pages, count: count, theme: theme)
```

The parameter is nullable so these three compile untouched and simply keep the
old empty pages until you add it. Add it to all three.

## 3. `lib/shells/tui_shell.dart` — DO NOT PATCH FROM MY COPY

The copy uploaded to this thread still reads `Term.*` throughout, but the Phase
B exit gate converted those ~30 reads to theme reads. That copy is pre-fix, so
anything I wrote against it would revert your work. Apply by hand.

In the `ListView` inside `build`, between the fastfetch header and the prompt:

```dart
  _FastfetchHeader(theme: widget.theme),
  const SizedBox(height: 18),
  DeskletPane(theme: widget.theme, page: 0),   // <- add
  _Prompt(
```

plus:

```dart
import '../features/desklets/desklet_surface.dart';
```

`page: 0` is correct and not a placeholder: the terminal shell has no workspace
pager, so it renders workspace 1's pane and nothing else. If the terminal ever
grows `tmux`-style windows, that is where the page number starts meaning
something.
