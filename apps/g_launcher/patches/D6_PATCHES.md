# D6 — tui_shell wiring

Two edits to `lib/shells/tui_shell.dart`. I have not shipped a rewritten copy:
the version in this thread reads `Term.*` throughout and I am not going to
guess whether that is your current file.

## 1. Replace the `_commands` set

Delete:

```dart
static const _commands = <String>{'settings', 'gsettings', 'config', 'prefs'};
```

and rewrite `_submit`:

```dart
void _submit() {
  final query = _controller.text.trim();

  // Commands beat apps, always. An app called "Files" must not shadow `ls`.
  if (TerminalCommands.handles(query)) {
    _clear();
    TerminalCommands.run(context, ref, widget.theme, query);
    return;
  }

  if (launchTopMatch(ref, widget.theme)) {
    _controller.clear();
  }
}
```

with:

```dart
import '../features/desklets/terminal_commands.dart';
```

`TerminalCommands.handles` is checked before running so `_clear()` happens
first: the prompt should empty the instant a command is accepted, the way a
real shell does, rather than after the screen it pushed comes back.

## 2. Add the pane

In the `ListView`, between the fastfetch header and the prompt:

```dart
_FastfetchHeader(theme: widget.theme),
const SizedBox(height: 18),
DeskletPane(theme: widget.theme, page: 0),   // <- add
_Prompt(
```

with:

```dart
import '../features/desklets/desklet_surface.dart';
```

Blocks appear ABOVE the prompt and below the fetch header, so the prompt stays
at the bottom of the output the way a shell does. New blocks append to the end
of the list, which puts the newest nearest the prompt.

## 3. Update the hint line

```dart
'type to launch · free · df · ls · top · settings · esc clears'
```

Or read `TerminalCommands.helpLine`, which is the same string and stays in sync.

## Optional: the theme block

The terminal theme's `offers` should list the pane kinds so they show up if a
picker ever runs there. Not required for D6 — commands bypass the picker
entirely.

```json
"offers": ["clock", "free", "df", "ls", "uptime", "monitor", "network", "battery", "storage", "fastfetch"]
```
