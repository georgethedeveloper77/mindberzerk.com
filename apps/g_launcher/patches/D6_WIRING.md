# D6 is not wired yet — here is the tell, and the checklist

The hint line in your screenshots reads:

```
type to launch · settings · ↵ opens top match · esc clears
```

That is the pre-D6 string. So `tui_shell.dart` still holds the old
`_commands` set, which is why `settings` works and `free -h` does nothing.

## Two files in this zip

`desklet_frame.dart` and `kinds/pane_desklets.dart` supersede D5/D6. Apply them
BEFORE wiring the shell, because they are what makes a failure visible.

## The three edits to `lib/shells/tui_shell.dart`

### 1. Delete the old set

```dart
static const _commands = <String>{'settings', 'gsettings', 'config', 'prefs'};
```

### 2. Rewrite `_submit`

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

### 3. Add the pane, and update the hint

In the `ListView`:

```dart
_FastfetchHeader(theme: widget.theme),
const SizedBox(height: 18),
DeskletPane(theme: widget.theme, page: 0),   // <- add
_Prompt(
```

and in `_Hint`:

```dart
'type to launch · free · df · ls · top · settings · esc clears'
```

Imports:

```dart
import '../features/desklets/desklet_surface.dart';
import '../features/desklets/terminal_commands.dart';
```

## What you should see after

Typing `free -h` and pressing enter leaves a block above the prompt:

```
~ ❯ free -h
               total    used   avail
Mem:           7.6Gi   4.1Gi   3.5Gi
```

or, if D1's native side is not returning memory on this device:

```
~ ❯ free -h
free: cannot read memory info
```

**Those two outcomes are the diagnostic.** Before this change both looked
identical to "nothing happened", which is exactly what image 3 shows.

If you get the second one, the problem is D1 rather than D6: check
Settings → Maintenance → Device stats, which lists every source and says
whether the device refuses it.

## One free win visible in your screenshots

The fastfetch header has no `uptime` row. That is `deviceInfoProvider
.uptimeLabel` returning null — the deferred MethodChannel that D1 superseded.
Uptime now rides the stats snapshot. In `_FastfetchHeader`:

```dart
final s = ref.watch(systemStatsProvider).asData?.value;
...
if (s?.uptime != null)
  _FetchRow('uptime', formatUptime(s!.uptime)),
```

`formatUptime` is already exported from `system_stats.dart`, which that file
imports. Delete the `device?.uptimeLabel` branch.

## Also visible: `ls` currently launches LocalSend

Image 1 shows `ls` fuzzy-matching LocalSend as the top match, so pressing enter
launches it. After edit 2, `handles('ls')` is checked first and the app never
gets a look in. Worth testing that one specifically — it is the case the
commands-beat-apps ordering exists for.
