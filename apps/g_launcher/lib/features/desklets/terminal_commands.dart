import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../engine/effective_theme.dart';
import '../settings/settings_screen.dart';
import '../themes/themes_screen.dart';

/// What the terminal shell understands. PHASE D6.
///
/// ─── REPLACES THE `_commands` SET IN tui_shell ──────────────────────────────
///
/// That set held four synonyms for one action. This is a table, because the
/// terminal now does three different kinds of thing:
///
///   NAVIGATE   `settings`, `themes` push a screen
///   SPAWN      `free -h`, `df -h`, `ls`, `top`, `neofetch`, `date`, `uptime`
///              leave a LIVE block in the pane that survives a restart
///   MANAGE     `clear`, `help`
///
/// ─── WHY SPAWNING WRITES A DESKLET ──────────────────────────────────────────
///
/// The obvious implementation is appending a string to a scrollback buffer, and
/// it is wrong twice over: the output would be frozen at the moment you typed
/// it, and it would need its own persistence to survive a restart. A desklet is
/// already live and already persisted, so the terminal gets both for free and
/// the pane renderer is the same one the graphical desktops use.
///
/// ─── AND WHY SETTINGS IS IN THIS TABLE AT ALL ───────────────────────────────
///
/// Every other shell surfaces G Launcher's own settings as a drawer entry —
/// `drawerItemsProvider` appends a `LauncherSettingsItem` downstream of the
/// hidden-apps filter, so the GNOME grid, KDE's Kickoff and the tiling launcher
/// all have it, and any new distro on those shells inherits it as data.
///
/// The terminal has no drawer. It fuzzy-matches installed APPS, and a launcher
/// entry is not one, so without this table Settings is unreachable here. Typing
/// the command is also the most authentic possible answer on a shell whose
/// entire premise is typing.
class TerminalCommands {
  const TerminalCommands._();

  /// Canonical command -> what it does. Aliases are resolved by [lookup].
  ///
  /// `ps` IS DELIBERATELY ABSENT. Android does not expose other processes to a
  /// sandboxed app, and a fabricated process list would be exactly the lie the
  /// nullable-stats rule exists to prevent. `top` stands in for it and is real:
  /// it spawns the monitor desklet, which reads the same snapshot everything
  /// else does.
  static const _spawn = <String, String>{
    'free': 'free',
    'df': 'df',
    'ls': 'ls',
    'uptime': 'uptime',
    'top': 'monitor',
    'htop': 'monitor',
    'conky': 'monitor',
    'neofetch': 'fastfetch',
    'fastfetch': 'fastfetch',
    'date': 'clock',
    'cal': 'clock',
    'ifstat': 'network',
    'ip': 'network',
    'acpi': 'battery',
    'du': 'storage',
  };

  static const _navigate = <String>{
    'settings',
    'gsettings',
    'config',
    'prefs',
    'themes',
    'distro',
  };

  static const _manage = <String>{'clear', 'reset', 'help', '?'};

  /// Every command name, for completion and for the match list.
  static List<String> get names => [
        ..._navigate,
        ..._spawn.keys,
        ..._manage,
      ];

  /// What a command does, one line, for the match list.
  ///
  /// Deliberately phrased as OUTCOMES rather than as descriptions of the
  /// command: someone reading this row has already typed three letters and
  /// wants to know whether enter will do the thing they meant.
  static String describe(String name) => switch (name) {
        'settings' ||
        'gsettings' ||
        'config' ||
        'prefs' =>
          'G Launcher Settings',
        'themes' || 'distro' => 'Switch distro',
        'free' => 'Memory, live',
        'df' || 'du' => 'Storage, live',
        'ls' => 'Installed apps',
        'uptime' => 'Time since boot',
        'top' || 'htop' || 'conky' => 'System monitor, live',
        'neofetch' || 'fastfetch' => 'System info',
        'date' || 'cal' => 'Clock',
        'ifstat' || 'ip' => 'Network throughput',
        'acpi' => 'Battery detail',
        'clear' || 'reset' => 'Clear the pane',
        'help' || '?' => 'List commands',
        _ => '',
      };

  /// Commands matching what has been typed so far, best first.
  ///
  /// PREFIX, not fuzzy, and that is the shell convention rather than a
  /// shortcut: `se` should complete to `settings`, and no shell has ever
  /// matched `stg`. The app matcher stays fuzzy because app names are things
  /// you half-remember; command names are things you know.
  ///
  /// Aliases are collapsed by their description, so typing `s` does not print
  /// four rows that all say "G Launcher Settings".
  static List<String> matching(String raw) {
    final q = _canonical(raw);
    if (q.isEmpty) return const [];

    final seen = <String>{};
    final out = <String>[];

    // Exact first, so a full word never sits below a longer command that
    // happens to start with it.
    for (final n in names) {
      if (n == q && seen.add(describe(n))) out.add(n);
    }
    for (final n in names) {
      if (n != q && n.startsWith(q) && seen.add(describe(n))) out.add(n);
    }
    return out;
  }

  /// The command enter should run, or null.
  ///
  /// Exact match, else a UNIQUE prefix. `se` runs `settings` because nothing
  /// else starts with it; `c` runs nothing because `config`, `conky`, `cal`,
  /// `clear` and `cancel` all do. Ambiguity resolves to "not a command", so the
  /// app matcher gets it and the user is never surprised by which of five
  /// things fired.
  static String? resolve(String raw) {
    final q = _canonical(raw);
    if (q.isEmpty) return null;
    if (names.contains(q)) return q;

    final hits = matching(q);
    return hits.length == 1 ? hits.first : null;
  }

  /// Is [raw] something we handle? Checked BEFORE the app matcher, so a command
  /// always beats an app that happens to fuzzy-match it.
  ///
  /// This is what makes typing `settings` open OURS rather than Android's, and
  /// the match list has to agree — see [TerminalMatches]. Before that widget
  /// existed the screen showed `launch Settings` pointing at Android's app
  /// while enter opened the launcher's, which reads as ours being missing.
  static bool handles(String raw) => resolve(raw) != null;

  /// Strip arguments and normalise.
  ///
  /// `free -h` and `free` are the same command; so are `ls -la` and `ls`. The
  /// flags are not parsed because none of them would change anything we can
  /// actually do, and silently ignoring a flag the user typed is friendlier
  /// than refusing a command over it.
  static String _canonical(String raw) =>
      raw.trim().toLowerCase().split(RegExp(r'\s+')).first;

  /// Run it. Returns false when the command is not ours, so the caller falls
  /// through to launching an app.
  static bool run(
    BuildContext context,
    WidgetRef ref,
    EffectiveTheme theme,
    String raw,
  ) {
    final c = resolve(raw);
    if (c == null) return false;

    if (_navigate.contains(c)) {
      HapticFeedback.selectionClick();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => (c == 'themes' || c == 'distro')
              ? const ThemesScreen()
              : SettingsScreen(theme: theme),
        ),
      );
      return true;
    }

    if (_manage.contains(c)) {
      if (c == 'help' || c == '?') {
        context.showMessage(helpLine);
        return true;
      }
      _clearPane(ref, theme);
      return true;
    }

    final kind = _spawn[c];
    if (kind == null) return false;

    _spawnKind(context, ref, theme, kind);
    return true;
  }

  static void _spawnKind(
    BuildContext context,
    WidgetRef ref,
    EffectiveTheme theme,
    String kindId,
  ) {
    final before = ref.read(prefsProvider(theme.spec.id)).value;
    if (before == null) return;

    // The pane ignores position entirely — order is the layout — so this packs
    // with `place` and never cares where it lands. The cols/rows are passed
    // because the pure engine takes them; on a pane they only bound the clamp.
    final after = DeskletLayout.place(
      before,
      kindId: kindId,
      page: 0,
      cols: theme.cols,
      rows: theme.rows,
      newId: () => 'dk${DateTime.now().microsecondsSinceEpoch}',
    );

    if (identical(after, before)) {
      // The grid is notionally full. On a pane that is close to meaningless,
      // but saying so beats a command that appears to do nothing.
      context.showMessage('No room; try clear');
      return;
    }

    HapticFeedback.selectionClick();
    ref.read(prefsProvider(theme.spec.id).notifier).edit((_) => after);
  }

  /// `clear` empties the pane.
  ///
  /// Removes every desklet on page 0 of THIS theme, which on a terminal theme
  /// is the whole pane. Per-theme like everything else, so clearing the
  /// terminal's scrollback cannot touch what you have arranged under Ubuntu.
  static void _clearPane(WidgetRef ref, EffectiveTheme theme) {
    ref.read(prefsProvider(theme.spec.id).notifier).edit((p) {
      var out = p;
      for (final d in DeskletLayout.onPage(p, 0)) {
        out = DeskletLayout.remove(out, d.id);
      }
      return out;
    });
  }

  /// Shown by `help`, and short enough to fit a toast — a terminal that answers
  /// `help` with a wall of text on a phone is a terminal nobody reads.
  static const helpLine =
      'free · df · ls · top · uptime · date · neofetch · settings · clear';
}
