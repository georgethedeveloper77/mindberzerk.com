import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/branded_message.dart';
import '../../engine/effective_theme.dart';
import '../settings/settings_screen.dart';
import '../terminal/command_registry.dart';
import '../terminal/terminal_screen.dart';
import '../themes/themes_screen.dart';

/// What the terminal shell understands. PHASE D6, now reading from the shared
/// registry.
///
/// ─── WHAT MOVED, AND WHY IT HAD TO ──────────────────────────────────────────
///
/// The table itself is now [TerminalRegistry], and this class is the TUI
/// shell's dispatcher over it. Nothing about the prompt changes: same commands,
/// same completion, same ordering, same aliases.
///
/// It moved because a SECOND terminal surface is landing. The Terminal app is a
/// drawer entry like Settings, so it appears on gnome, plasma, tiling and aqua
/// distros, none of which run this shell. Kali is `shell: gnome`; without that
/// entry a Kali user has no terminal at all.
///
/// Two surfaces was about to mean two tables, and the day they disagree one of
/// them is wrong and nothing fails. `settings` means the same thing typed at
/// either prompt. The registry is where that fact lives once.
///
/// ─── WHAT STAYED HERE ───────────────────────────────────────────────────────
///
/// Dispatch, because dispatch is per surface and genuinely different. This
/// shell NAVIGATES by pushing a route, and SPAWNS by writing a desklet into the
/// pane. The Terminal app has no pane and no `Navigator` of this shell's, so it
/// will answer the same [CommandAction] differently. Folding both into the
/// registry would put two unrelated implementations behind one switch.
///
/// ─── WHY SPAWNING WRITES A DESKLET ──────────────────────────────────────────
///
/// The obvious implementation is appending a string to a scrollback buffer, and
/// it is wrong twice over: the output would be frozen at the moment you typed
/// it, and it would need its own persistence to survive a restart. A desklet is
/// already live and already persisted, so the terminal gets both for free and
/// the pane renderer is the same one the graphical desktops use.
///
/// ─── AND WHY SETTINGS IS IN THE TABLE AT ALL ────────────────────────────────
///
/// Every other shell surfaces G Launcher's own settings as a drawer entry.
/// `drawerItemsProvider` appends a `LauncherSettingsItem` downstream of the
/// hidden-apps filter, so the GNOME grid, KDE's Kickoff and the tiling launcher
/// all have it, and any new distro on those shells inherits it as data.
///
/// The TUI shell has no drawer. It fuzzy-matches installed APPS, and a launcher
/// entry is not one, so without the table Settings is unreachable here. Typing
/// the command is also the most authentic possible answer on a shell whose
/// entire premise is typing.
class TerminalCommands {
  const TerminalCommands._();

  /// This shell's slice of the registry.
  static const CommandSurface _surface = CommandSurface.tui;

  /// Every command name, for completion and for the match list.
  static List<String> get names => TerminalRegistry.namesFor(_surface);

  /// What a command does, one line, for the match list.
  static String describe(String name) => TerminalRegistry.describe(name);

  /// Commands matching what has been typed so far, best first.
  static List<String> matching(String raw) =>
      TerminalRegistry.matching(raw, surface: _surface);

  /// The command enter should run, or null.
  static String? resolve(String raw) =>
      TerminalRegistry.resolve(raw, surface: _surface);

  /// Is [raw] something we handle? Checked BEFORE the app matcher, so a command
  /// always beats an app that happens to fuzzy-match it.
  ///
  /// The match list has to agree, which is why `TerminalMatches` calls the same
  /// pair. Before it did, the screen showed `launch Settings` pointing at
  /// Android's app while enter opened the launcher's, which reads as ours being
  /// missing.
  static bool handles(String raw) =>
      TerminalRegistry.handles(raw, surface: _surface);

  /// Shown by `help`. Built from the table rather than typed out beside it.
  static String get helpLine => TerminalRegistry.helpLine;

  /// Run it. Returns false when the command is not ours, so the caller falls
  /// through to launching an app.
  static bool run(
    BuildContext context,
    WidgetRef ref,
    EffectiveTheme theme,
    String raw,
  ) {
    final name = resolve(raw);
    if (name == null) return false;

    final command = TerminalRegistry.command(name);
    if (command == null) return false;

    // Exhaustive on purpose. A new CommandAction stops this switch compiling,
    // which is the point of an enum here: a command that the registry advertises
    // and this shell silently ignores would autocomplete and then do nothing.
    switch (command.action) {
      case CommandAction.openSettings:
        _push(context, SettingsScreen(theme: theme));
        return true;

      case CommandAction.openThemes:
        _push(context, const ThemesScreen());
        return true;

      case CommandAction.openTerminal:
        HapticFeedback.selectionClick();
        openTerminal(context, theme);
        return true;

      case CommandAction.help:
        context.showMessage(helpLine);
        return true;

      case CommandAction.clearPane:
        _clearPane(ref, theme);
        return true;

      case CommandAction.spawnDesklet:
        _spawnKind(context, ref, theme, command.spawnKind!);
        return true;

      case CommandAction.sshConnect:
      case CommandAction.sshHosts:
      case CommandAction.sshHost:
      case CommandAction.sshKey:
        // HANDED OVER, not refused.
        //
        // This shell has no scrollback, so it cannot render a remote session or
        // a host list. What it can do is open the surface that can, carrying
        // the line the person actually typed, which is what makes `ssh myserver`
        // work at the home prompt of the Terminal distro.
        //
        // `raw` rather than the resolved name, because the arguments are the
        // whole instruction here: `ssh` alone is a usage message.
        HapticFeedback.selectionClick();
        openTerminal(context, theme, initialCommand: raw.trim());
        return true;
    }
  }

  static void _push(BuildContext context, Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  static void _spawnKind(
    BuildContext context,
    WidgetRef ref,
    EffectiveTheme theme,
    String kindId,
  ) {
    final before = ref.read(prefsProvider(theme.spec.id)).value;
    if (before == null) return;

    // The pane ignores position entirely, order is the layout, so this packs
    // with `place` and never cares where it lands. The cols/rows are passed
    // because the pure engine takes them; on a pane they only bound the clamp.
    final after = DeskletLayout.place(
      before,
      kindId: kindId,
      page: 0,
      cols: theme.deskletCols,
      rows: theme.deskletRows,
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
}
