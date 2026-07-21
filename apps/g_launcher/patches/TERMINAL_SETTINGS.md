# Reaching Settings on the terminal theme

## Short answer

You type `settings`. Also `gsettings`, `config`, `prefs`. And `themes` or
`distro` goes straight to the distro picker, which is what you actually wanted.

## Why it did not feel like that worked

Your earlier screenshot: you typed `settings` and the list showed

```
launch  Settings      ↵
```

That is **Android's** Settings app, found by the fuzzy matcher. Enter did not
open it — commands are checked first, so enter opened G Launcher's settings. The
screen said one thing and the key did another, and the reasonable conclusion
from outside is that ours does not exist here.

A real shell never had this problem because it distinguishes builtins from
binaries. Now so does this one:

```
~ ❯ settings
  builtin  settings   G Launcher Settings      ↵
  app      Settings
  app      Settings Suggestions
```

The `↵` is now on the row that enter actually runs.

## What changed

**`terminal_commands.dart`** (replaces the D6 copy)

- `matching(query)` — prefix completion over every command name. `se` surfaces
  `settings`. Prefix rather than fuzzy because that is the shell convention:
  app names are things you half-remember, command names are things you know.
- `describe(name)` — one line per command, phrased as the OUTCOME, since
  someone reading it has typed three letters and wants to know what enter does.
- `resolve(query)` — exact match, else a UNIQUE prefix. `se` runs `settings`.
  `c` runs nothing, because `config`, `conky`, `cal` and `clear` all start with
  it, and ambiguity resolving to "not a command" means you are never surprised
  by which of four things fired.
- `handles()` is now `resolve() != null`, so the list and the key cannot
  disagree.

**`terminal_matches.dart`** (new) — the builtin rows.

## Wiring, one line

In `tui_shell.dart`'s `ListView`, above `_Matches`:

```dart
_Prompt(...),
const SizedBox(height: 12),
TerminalMatches(theme: widget.theme, query: _controller.text),   // <- add
_Matches(results: results),
```

with:

```dart
import '../features/desklets/terminal_matches.dart';
```

`_controller.text` rather than `paletteQueryProvider` on purpose: the provider
is what feeds the fuzzy app matcher and is cleared on launch, whereas this wants
exactly what is in the field right now.

## And the hint line

This is the other half. Nobody types a command they do not know exists, so the
hint is the only discovery surface before the first keystroke:

```dart
'free · df · ls · top · settings · themes · help'
```

`help` prints the full list via `context.showMessage`, so the hint can stay
short without hiding anything.

## Worth considering later

**Tab to complete.** `matching()` already returns the candidates in order, so
completing to the first hit is a few lines on a hardware keyboard. On a soft
keyboard there is no tab key, which is why this is a note and not a patch.

**A `commands` command.** `help` shows a toast; a builtin that spawns a
persistent pane block listing everything would be more in keeping with the rest
of D6, and it would survive a restart the way the other blocks do.
