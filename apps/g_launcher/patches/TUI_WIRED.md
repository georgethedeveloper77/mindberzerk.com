# tui_shell.dart — wired

Drop-in replacement, patched from the copy you uploaded. Six changes.

## 1. `_commands` is gone

Replaced by `TerminalCommands`. The old four-name set only did one thing; the
terminal now navigates (`settings`, `themes`), spawns live pane blocks (`free`,
`df`, `ls`, `top`, `uptime`, `neofetch`, `date`), and manages (`clear`, `help`).

`_submit` now calls `TerminalCommands.handles(query)`, which is
`resolve() != null` — the SAME call the match list uses to decide which row
wears the `↵`. One source of truth, so the screen and the key cannot disagree.

## 2. The double-`↵` bug, which I only caught reading this file

`_MatchRow` always gives its top row the `launch` label and the `↵`. So typing
`settings` would have shown a builtin row with `↵` AND an app row with `↵`, and
only one of them true — the same lie the builtin rows exist to fix, moved down
two lines.

`_Matches` now takes `demoted`. When a command owns the enter key, no app row is
marked top. **Demoted, not hidden**: Android's Settings really is still there
and still tappable, it just is not what enter does.

```
~ ❯ settings
  builtin  settings   G Launcher Settings      ↵
  app      Settings
  app      Settings Suggestions
```

## 3. `DeskletPane` above the prompt

Where a shell puts what you already ran. New blocks append, so the newest sits
nearest the prompt. `page: 0` is correct rather than a placeholder — the
terminal has no workspace pager.

## 4. `TerminalMatches` above `_Matches`

Fed from `paletteQueryProvider` rather than `_controller.text`, so a keystroke
rebuilds through Riverpod instead of relying on the app matcher happening to
rebuild first.

## 5. The missing uptime row

Your screenshots show four fetch lines, not five. `device?.uptimeLabel` was
always null — that was the `g_launcher/uptime` MethodChannel that got deferred
and then superseded.

Now `formatUptime(stats!.uptime)` from the D1 snapshot. `elapsedRealtimeMillis`
is already in every snapshot because it doubles as the sample clock the network
deltas divide by, so this row costs nothing. **Do not add that MethodChannel.**

## 6. Hint line

```
free · df · ls · top · settings · themes · help
```

The only discovery surface before the first keystroke. `themes` earns its slot:
it goes straight to the distro picker, which is what reaching Settings was for.

## Left alone deliberately

The `Term.*` reads. `no_constants.sh` is green on your machine, so either it
does not cover this path or there is an exemption I cannot see — either way,
churning thirty constant reads inside a wiring change is how a wiring change
turns into a regression hunt. Separate commit if you want it.

## Depends on

Both must be in place first:

- `features/desklets/terminal_commands.dart` (the version with `resolve`)
- `features/desklets/terminal_matches.dart`
- `features/desklets/desklet_surface.dart` (for `DeskletPane`)

## Test this specifically

`ls` used to fuzzy-match and launch **LocalSend**. It should now print a
directory-style app listing that survives a restart. That is the case the
commands-beat-apps ordering exists for.
