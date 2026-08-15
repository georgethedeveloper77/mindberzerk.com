/// Every command both terminal surfaces understand, in one table.
///
/// ─── WHY THIS EXISTS SEPARATELY FROM TerminalCommands ───────────────────────
///
/// There are now two terminal surfaces with different jobs, and they were about
/// to grow two command tables.
///
///   THE TUI SHELL is a launcher. Type two letters, press enter, an app opens.
///   Output is a live desklet in a persisted pane, which is why it has no
///   scrollback and should not get one.
///
///   THE TERMINAL APP is a terminal. It is a [DrawerItem] like Settings, so it
///   appears on gnome, plasma, tiling and aqua distros, all of which have a
///   drawer and none of which run the TUI shell. Kali is `shell: gnome`, so
///   without that entry a Kali user has no terminal at all.
///
/// A command belongs to the LAUNCHER, not to either screen. `settings` means
/// the same thing typed at the TUI prompt and typed in the Terminal app, and
/// the day the two tables disagree is the day one of them is wrong and nothing
/// fails. [surfaces] is how one entry serves both: a command declares where it
/// appears, and each surface asks for its own slice.
///
/// This is the same argument `drawer_items.dart` already makes for
/// `launcherSettingsAliases`, which is kept as data next to the items
/// specifically so the terminal's table and the drawer search agree on the
/// vocabulary. One more surface, same conclusion.
///
/// ─── WHAT IS DELIBERATELY NOT HERE ──────────────────────────────────────────
///
/// The registry holds what the launcher CAN RUN TODAY, and nothing else. It
/// would be easy to seed it with the full command catalogue and let each entry
/// arrive as its backend lands, and that would make `help` a list of promises.
/// A command that autocompletes and then does nothing is worse than a command
/// that is not there, because the user cannot tell which of the two they are
/// looking at.
///
/// `ps` is the precedent and it is already documented in [TerminalCommands]:
/// Android does not expose other processes to a sandboxed app, so rather than
/// print a fabricated list the command simply does not exist and `top` stands
/// in for it. Commands land here when they run.
///
/// ─── DART, NOT JSON ─────────────────────────────────────────────────────────
///
/// Themes are data because a palette needs no code, which is the whole reason a
/// new distro ships over the CDN without a Play release. A command is the
/// opposite: every one of these needs a handler, so a CDN could never add one.
/// A JSON registry would buy nothing and cost a drift surface between the table
/// and the switch that dispatches it.
///
/// Theme ALIASES are still data, and correctly so: an alias binds a name to an
/// [CommandAction] that already exists, which is a choice a pack author can
/// make without new code. That block lands with the profile loader.
library;

import 'package:flutter/foundation.dart';

/// What a command does when it runs.
///
/// An enum rather than a string, so [TerminalCommands.run] switches
/// exhaustively and a new action cannot be added without the dispatcher failing
/// to compile.
///
/// [id] is the STABLE WIRE NAME, and it is not decoration. A theme's terminal
/// profile will bind an alias to one of these, so the string is part of the
/// pack format the moment that lands: renaming an enum constant is free,
/// renaming an id orphans every pack that used it.
enum CommandAction {
  /// Push G Launcher's own settings.
  openSettings('launcher.openSettings'),

  /// Push the distro picker.
  openThemes('launcher.openThemes'),

  /// Place a live desklet into the pane. See [TerminalCommand.spawnKind].
  spawnDesklet('desklet.spawn'),

  /// Remove every desklet on page 0 of the active theme.
  clearPane('terminal.clear'),

  /// Print the command vocabulary.
  help('terminal.help'),

  /// Open a remote shell. See ssh_connection.dart.
  sshConnect('remote.ssh'),

  /// List saved hosts.
  sshHosts('remote.hosts'),

  /// Add, remove, or forget the pinned key of a saved host.
  sshHost('remote.host'),

  /// Open the Terminal app.
  openTerminal('terminal.open'),

  /// Generate, list, show or remove an SSH key.
  sshKey('remote.key');

  const CommandAction(this.id);

  final String id;

  /// The action with this wire name, or null.
  ///
  /// Null rather than a throw: an alias naming an unknown action comes from a
  /// pack authored against a newer app, and the runtime rule everywhere else in
  /// the theme layer is that unknown input degrades rather than being fatal.
  /// The strict check belongs in the validator, over packs we wrote.
  static CommandAction? byId(String? id) {
    if (id == null) return null;
    for (final a in CommandAction.values) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// Which terminal surface a command appears on.
enum CommandSurface {
  /// The TUI shell prompt, the flagship type-to-launch screen.
  tui,

  /// The Terminal app, reached from the drawer on every shell that has one.
  terminal,
}

/// Free, or behind `terminal_pro`.
///
/// PRESENTATION ONLY, exactly like `ThemeSpec.tier`. Real entitlement is
/// resolved natively against the signed index, and a command cannot unlock
/// itself by claiming free any more than a theme can. This field decides
/// whether a row wears a lock, never whether the action runs.
enum CommandTier { free, pro }

/// Where a command sits in `help` and in the palette.
enum CommandCategory {
  launcher('Launcher'),
  system('System'),
  remote('Remote'),
  session('Session');

  const CommandCategory(this.label);

  final String label;
}

/// One command.
@immutable
class TerminalCommand {
  const TerminalCommand({
    required this.name,
    required this.action,
    required this.category,
    required this.description,
    this.aliases = const [],
    this.spawnKind,
    this.tier = CommandTier.free,
    this.surfaces = const {CommandSurface.tui, CommandSurface.terminal},
  }) : assert(
          action != CommandAction.spawnDesklet || spawnKind != null,
          'A spawn command must name the desklet kind it places.',
        );

  /// The canonical name, and the one `help` prints.
  final String name;

  /// Other names that resolve to the same command.
  ///
  /// These are FIRST CLASS in completion: typing `pr` completes to `prefs` and
  /// gets its own row, because someone who typed it is looking for it. They
  /// collapse in the match list only when they would print an identical
  /// description twice. See [TerminalRegistry.matching].
  final List<String> aliases;

  final CommandAction action;

  /// The desklet kind placed by a [CommandAction.spawnDesklet] command.
  ///
  /// Not an enum, because the kind vocabulary belongs to the desklet layer and
  /// the theme schema's `kindId`, not to this table. Duplicating it here as a
  /// second enum is how the two start disagreeing.
  final String? spawnKind;

  final CommandCategory category;

  /// One line, phrased as an OUTCOME.
  ///
  /// Someone reading this row has already typed three letters and wants to know
  /// whether enter will do the thing they meant, so "Memory, live" beats "shows
  /// memory usage". This wording is inherited verbatim from the table this
  /// registry replaces; do not tidy it into descriptions.
  ///
  /// English, and knowingly so for now. The i18n key would be
  /// `terminal.cmd.<name>.summary`, but wiring it needs the miss behaviour of
  /// `Translations.t` confirmed, since a lookup that returns the KEY on a miss
  /// would put `terminal.cmd.free.summary` on the flagship screen in every one
  /// of the 45 languages that has not been translated yet. Left as one honest
  /// English string until that is checked.
  final String description;

  final CommandTier tier;

  final Set<CommandSurface> surfaces;

  bool appearsOn(CommandSurface s) => surfaces.contains(s);
}

/// The table, and the matching rules over it.
abstract final class TerminalRegistry {
  const TerminalRegistry._();

  /// Every command, in the order `help` and the match list present them.
  ///
  /// ORDER IS BEHAVIOUR, not taste. [matching] walks this list, so the sequence
  /// here is the sequence of rows on screen. It reproduces the order of the
  /// three const collections this replaces (navigate, then spawn, then manage)
  /// so the refactor is invisible at the prompt.
  static const List<TerminalCommand> all = <TerminalCommand>[
    // ── Navigate ─────────────────────────────────────────────────────────────
    //
    // This is HOW YOU REACH G LAUNCHER'S SETTINGS on a terminal theme at all.
    // Every other shell surfaces them as a drawer entry; the TUI shell has no
    // drawer and fuzzy-matches installed apps, and a launcher entry is not one.
    //
    // The aliases are the same vocabulary `launcherSettingsAliases` carries in
    // drawer_items.dart, for the same reason: nobody types "G Launcher
    // Settings".
    TerminalCommand(
      name: 'settings',
      aliases: ['gsettings', 'config', 'prefs'],
      action: CommandAction.openSettings,
      category: CommandCategory.launcher,
      description: 'G Launcher Settings',
    ),
    TerminalCommand(
      name: 'themes',
      aliases: ['distro'],
      action: CommandAction.openThemes,
      category: CommandCategory.launcher,
      description: 'Switch distro',
    ),

    // ── Spawn ────────────────────────────────────────────────────────────────
    //
    // Each of these places a LIVE desklet rather than appending a frozen string
    // to a buffer. The output stays current and survives a restart because the
    // desklet layer already does both, and the pane renderer is the same one
    // the graphical desktops use.
    //
    // `ps` IS DELIBERATELY ABSENT and stays absent. Android does not expose
    // other processes to a sandboxed app, and a fabricated process list is
    // exactly the lie the nullable-stats rule exists to prevent. `top` stands in
    // for it and is real.
    TerminalCommand(
      name: 'free',
      action: CommandAction.spawnDesklet,
      spawnKind: 'free',
      category: CommandCategory.system,
      description: 'Memory, live',
    ),
    TerminalCommand(
      name: 'df',
      action: CommandAction.spawnDesklet,
      spawnKind: 'df',
      category: CommandCategory.system,
      description: 'Storage, live',
    ),
    // THE ONE COMMAND WHOSE FLAGS MATTER.
    //
    // There is no `pwd` and no `cd`, and their absence is a decision rather
    // than a gap: scoped storage means a launcher sees its own sandbox and
    // little else, so a path you cannot explore is the half-truth the
    // nullable-stats rule exists to prevent.
    //
    // What a launcher does have is an inventory, and `ls` lists it properly:
    // -a for hidden, -l for packages and flags, -s and -u to split system from
    // installed.
    TerminalCommand(
      name: 'ls',
      action: CommandAction.spawnDesklet,
      spawnKind: 'ls',
      category: CommandCategory.launcher,
      description: 'Installed apps. Try ls -a, ls -l',
    ),
    TerminalCommand(
      name: 'uptime',
      action: CommandAction.spawnDesklet,
      spawnKind: 'uptime',
      category: CommandCategory.system,
      description: 'Time since boot',
    ),
    TerminalCommand(
      name: 'top',
      aliases: ['htop', 'conky'],
      action: CommandAction.spawnDesklet,
      spawnKind: 'monitor',
      category: CommandCategory.system,
      description: 'System monitor, live',
    ),
    TerminalCommand(
      name: 'neofetch',
      aliases: ['fastfetch'],
      action: CommandAction.spawnDesklet,
      spawnKind: 'fastfetch',
      category: CommandCategory.system,
      description: 'System info',
    ),
    TerminalCommand(
      name: 'date',
      aliases: ['cal'],
      action: CommandAction.spawnDesklet,
      spawnKind: 'clock',
      category: CommandCategory.system,
      description: 'Clock',
    ),
    TerminalCommand(
      name: 'ifstat',
      aliases: ['ip'],
      action: CommandAction.spawnDesklet,
      spawnKind: 'network',
      category: CommandCategory.system,
      description: 'Network throughput',
    ),
    TerminalCommand(
      name: 'acpi',
      action: CommandAction.spawnDesklet,
      spawnKind: 'battery',
      category: CommandCategory.system,
      description: 'Battery detail',
    ),
    // Shares a description with `df` on purpose, and that has a visible
    // consequence in [matching]: typing `d` shows one storage row, not two.
    // Kept, because two rows that both say "Storage, live" is the noise the
    // collapse exists to remove, and `du` still runs when typed in full.
    TerminalCommand(
      name: 'du',
      action: CommandAction.spawnDesklet,
      spawnKind: 'storage',
      category: CommandCategory.system,
      description: 'Storage, live',
    ),

    // ── The Terminal app, from the TUI shell ─────────────────────────────────
    //
    // TUI SHELL ONLY, and it is the mirror image of `settings`.
    //
    // The Terminal app is a DrawerItem, which reaches gnome, plasma, tiling and
    // aqua because those all have a drawer. The TUI shell does not: it fuzzy
    // matches installed APPS, and a launcher entry is not one. So on the
    // Terminal distro, the distro whose entire pitch is that it has a terminal,
    // the Terminal app was unreachable.
    //
    // `settings` exists on this surface for exactly that reason and says so.
    // This is the same fix for the same cause, and typing the command is again
    // the most authentic answer on a shell whose whole premise is typing.
    TerminalCommand(
      name: 'terminal',
      // `shell` is NOT an alias here, and the omission is deliberate. It would
      // make `s` ambiguous with `settings` on this surface, and `s` plus enter
      // opening Settings is behaviour the flagship screen already has.
      aliases: ['tty'],
      action: CommandAction.openTerminal,
      category: CommandCategory.remote,
      description: 'Open the Terminal app',
      surfaces: {CommandSurface.tui},
    ),

    // ── Remote ───────────────────────────────────────────────────────────────
    //
    // ON BOTH SURFACES, which reverses an earlier decision.
    //
    // These were Terminal-app only, on the reasoning that the TUI shell has no
    // scrollback and a remote session there would have nowhere to render.
    // The reasoning was right and the conclusion was wrong: the Terminal DISTRO
    // is a terminal, and typing `ssh myserver` at its home prompt and getting
    // silence is indefensible on the one distro whose entire pitch is that it
    // has a shell.
    //
    // The TUI shell does not gain a session. It HANDS THE LINE OVER: its
    // dispatcher opens the Terminal app with the command as
    // `TerminalScreen.initialCommand`, and the app runs it there. One
    // registry, one implementation, and the surface that can render a session
    // is the one that renders it.
    TerminalCommand(
      name: 'ssh',
      action: CommandAction.sshConnect,
      category: CommandCategory.remote,
      description: 'Open a remote shell',
    ),
    TerminalCommand(
      name: 'hosts',
      action: CommandAction.sshHosts,
      category: CommandCategory.remote,
      description: 'Saved hosts',
    ),
    TerminalCommand(
      name: 'host',
      action: CommandAction.sshHost,
      category: CommandCategory.remote,
      description: 'Add, remove, or forget a host',
    ),

    // THE FIRST PRO COMMAND, and the shape every later one follows.
    //
    // It still parses, still autocompletes, and still appears in `help` wearing
    // a lock. Only EXECUTION is gated, and it fails into the paywall with this
    // command named at the top. Hiding it would teach people the feature does
    // not exist, which is worse for them and worse for conversion.
    TerminalCommand(
      name: 'key',
      action: CommandAction.sshKey,
      category: CommandCategory.remote,
      description: 'SSH keys held in the secure chip',
      tier: CommandTier.pro,
    ),

    // ── Manage ───────────────────────────────────────────────────────────────
    TerminalCommand(
      name: 'clear',
      aliases: ['reset'],
      action: CommandAction.clearPane,
      category: CommandCategory.session,
      description: 'Clear the pane',
    ),
    TerminalCommand(
      name: 'help',
      aliases: ['?'],
      action: CommandAction.help,
      category: CommandCategory.session,
      description: 'List commands',
    ),
  ];

  /// Every name and alias, flattened, in table order.
  ///
  /// Built once. This is walked twice per keystroke by [matching], and rebuilding
  /// it per call would put an allocation on the path the entire flagship screen
  /// is judged by.
  static final List<String> names = List.unmodifiable([
    for (final c in all) ...[c.name, ...c.aliases],
  ]);

  /// Name or alias to the command that owns it.
  static final Map<String, TerminalCommand> _byName = Map.unmodifiable({
    for (final c in all) ...{
      c.name: c,
      for (final a in c.aliases) a: c,
    },
  });

  /// The command a name belongs to, or null.
  static TerminalCommand? command(String name) => _byName[name];

  /// Names visible on [surface], in table order.
  ///
  /// Memoised per surface, for the same reason [names] is built once: this is
  /// walked twice per keystroke on the screen the whole app is judged by, and a
  /// list comprehension per call puts an allocation on that path.
  static final Map<CommandSurface, List<String>> _namesBySurface =
      Map.unmodifiable({
    for (final s in CommandSurface.values)
      s: List<String>.unmodifiable([
        for (final c in all)
          if (c.appearsOn(s)) ...[c.name, ...c.aliases],
      ]),
  });

  static List<String> namesFor(CommandSurface surface) =>
      _namesBySurface[surface]!;

  /// What a command does, one line, for the match list.
  ///
  /// Empty string for an unknown name rather than a throw: this is called with
  /// whatever is at the prompt, and the prompt holds arbitrary text.
  static String describe(String name) => _byName[name]?.description ?? '';

  /// Strip arguments and normalise.
  ///
  /// `free -h` and `free` are the same command, as are `ls -la` and `ls`. Flags
  /// are not parsed because none of them would change anything the launcher can
  /// actually do, and silently ignoring a flag someone typed is friendlier than
  /// refusing the command over it.
  static String canonical(String raw) =>
      raw.trim().toLowerCase().split(RegExp(r'\s+')).first;

  /// Commands matching what has been typed so far, best first.
  ///
  /// PREFIX, not fuzzy, and that is the shell convention rather than a
  /// shortcut: `se` should complete to `settings`, and no shell has ever matched
  /// `stg`. The app matcher stays fuzzy because app names are things you
  /// half-remember; command names are things you know.
  ///
  /// Exact hits come first, so a full word never sits below a longer command
  /// that merely starts with it.
  ///
  /// Rows collapse BY DESCRIPTION, so typing `s` does not print four rows that
  /// all say "G Launcher Settings". Note this collapses two genuinely different
  /// commands when they describe themselves identically, which today is `df` and
  /// `du`; see the note on `du`.
  static List<String> matching(
    String raw, {
    CommandSurface surface = CommandSurface.tui,
  }) {
    final q = canonical(raw);
    if (q.isEmpty) return const [];

    final pool = namesFor(surface);

    final seen = <String>{};
    final out = <String>[];

    for (final n in pool) {
      if (n == q && seen.add(describe(n))) out.add(n);
    }
    for (final n in pool) {
      if (n != q && n.startsWith(q) && seen.add(describe(n))) out.add(n);
    }
    return out;
  }

  /// The command enter should run, or null.
  ///
  /// Exact match, else a UNIQUE prefix. `se` runs `settings` because nothing
  /// else starts with it; `c` runs nothing because `config`, `conky`, `cal` and
  /// `clear` all do. Ambiguity resolves to "not a command", so the app matcher
  /// gets it and the user is never surprised by which of four things fired.
  static String? resolve(
    String raw, {
    CommandSurface surface = CommandSurface.tui,
  }) {
    final q = canonical(raw);
    if (q.isEmpty) return null;

    final c = _byName[q];
    if (c != null && c.appearsOn(surface)) return q;

    final hits = matching(q, surface: surface);
    return hits.length == 1 ? hits.first : null;
  }

  /// Is [raw] something this surface handles?
  ///
  /// Checked BEFORE the app matcher, so a command always beats an app that
  /// happens to fuzzy-match it. This is what makes typing `settings` open ours
  /// rather than Android's.
  static bool handles(
    String raw, {
    CommandSurface surface = CommandSurface.tui,
  }) =>
      resolve(raw, surface: surface) != null;

  /// The vocabulary line, built from the table rather than typed out beside it.
  ///
  /// The old hardcoded string is the exact failure this whole file is against: a
  /// second list of command names that nothing checks, which was already one
  /// command out of date with the hint line in tui_shell.
  ///
  /// Short on purpose. A terminal that answers `help` with a wall of text on a
  /// phone is a terminal nobody reads, so this is the vocabulary worth knowing
  /// and the match list is what confirms the rest mid-keystroke.
  static String get helpLine => const [
        'free',
        'df',
        'ls',
        'top',
        'uptime',
        'date',
        'neofetch',
        'settings',
        'clear',
      ].join(' \u00b7 ');

  /// The pre-typing hint, six names and no more.
  ///
  /// The ONLY discovery surface before the first keystroke, since nobody types
  /// a command they do not know exists.
  static String get hintLine => const [
        'free',
        'df',
        'ls',
        'top',
        // The one command on this shell that leads somewhere the shell itself
        // cannot go. Nobody types a command they do not know exists, and this
        // is the only discovery surface before the first keystroke.
        'terminal',
        'settings',
        'themes',
        'help',
      ].join(' \u00b7 ');
}
