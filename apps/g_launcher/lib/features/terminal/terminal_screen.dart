/// The Terminal app.
///
/// ─── WHY THIS IS NOT THE TUI SHELL ──────────────────────────────────────────
///
/// The TUI shell is a LAUNCHER: type two letters, press enter, an app opens.
/// It has no scrollback because its output is live desklets in a persisted
/// pane, and giving it scrollback would make it a worse launcher.
///
/// This is a TERMINAL. It has scrollback, it echoes what you typed, and it
/// prints. It reaches gnome, plasma, tiling and aqua distros, none of which run
/// the TUI shell. Kali is `shell: gnome`; without this screen a Kali user has
/// no terminal at all.
///
/// Both read one [TerminalRegistry], so `settings` means the same thing at
/// either prompt. Only dispatch differs, and it differs because the surfaces
/// genuinely differ, not because there are two tables. `TerminalCommands` is
/// this screen's sibling: it dispatches the same registry for the TUI shell,
/// and a change to either is worth a look at the other.
///
/// ─── LOCAL OUTPUT TAKES THE SSH PATH ────────────────────────────────────────
///
/// Every printed line goes through [AnsiParser] rather than being styled
/// directly, even though this screen knows exactly what it just produced.
/// Local use then exercises the parser constantly instead of it lying dormant
/// until a remote session exists, and a colour bug can only live in one place.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../design/terminal_tokens.dart' show deviceInfoProvider;
import '../../engine/effective_theme.dart';
import '../../engine/terminal_spec.dart';
import '../../platform/keys_api.g.dart';
import '../../system/system_stats.dart';
import '../settings/settings_screen.dart';
import '../themes/themes_screen.dart';
import 'ansi.dart';
import 'command_registry.dart';
import 'prompt.dart';
import 'ssh_connection.dart';
import 'ssh_host.dart';
import 'ssh_host_store.dart';
import 'ssh_key_store.dart';
import 'ssh_keystore_key.dart';
import 'ssh_sheets.dart';
import 'terminal_buffer.dart';
import 'terminal_emulator.dart';
import 'terminal_entitlement.dart';
import 'terminal_key_row.dart';
import 'terminal_output.dart';
import 'terminal_pro_sheet.dart';
import 'terminal_view.dart';

/// Open the Terminal app.
///
/// A plain push rather than a named route, matching how the drawer already
/// opens Settings and the theme picker.
void openTerminal(
  BuildContext context,
  EffectiveTheme theme, {
  String? initialCommand,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TerminalScreen(
        theme: theme,
        initialCommand: initialCommand,
      ),
    ),
  );
}

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({
    super.key,
    required this.theme,
    this.initialCommand,
  });

  final EffectiveTheme theme;

  /// A command typed somewhere else and handed over.
  ///
  /// The TUI shell has no scrollback, so `ssh` there cannot render a session.
  /// Rather than refuse, it opens this screen and passes the line through, so
  /// on the Terminal distro `ssh myserver` at the home prompt does what it
  /// obviously should: connects.
  final String? initialCommand;

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  late final TerminalSpec _spec = widget.theme.spec.terminal ??
      TerminalSpec.defaultForShell(widget.theme.spec.shell);

  late final TerminalBuffer _buffer =
      TerminalBuffer(maxLines: _spec.scrollbackLines);

  late final AnsiParser _parser = AnsiParser(onBell: _bell);

  final _input = TextEditingController();
  final _focus = FocusNode();

  /// Command history, newest last, walked with the arrow keys.
  final _history = <String>[];
  int _historyAt = -1;

  /// The sticky control modifier.
  ///
  /// Owned HERE rather than by the key row, because this is what has to clear
  /// it after the next key and what would have to reconcile it with a physical
  /// keyboard. The row reports intent and decides nothing.
  bool _ctrl = false;

  int _exitCode = 0;

  /// What a remote program called itself, via OSC 0 or 2.
  ///
  /// A phone has no title bar, so this goes in the session's own header: `vim:
  /// main.dart` says more about where you are than a hostname repeated from the
  /// line above.
  String? _remoteTitle;

  /// The remote screen, alive only while a session is.
  ///
  /// ─── TWO OUTPUT MODELS, AND BOTH ARE RIGHT ────────────────────────────
  ///
  /// Local commands PRINT: a growing list of lines, which is what [_parser] and
  /// [_buffer] are, and what scrollback means.
  ///
  /// A remote program DRAWS: it positions the cursor, overwrites, scrolls a
  /// region while leaving the rest still, and switches to a second screen. None
  /// of that is expressible as a list of finished lines, so a session gets a
  /// [TerminalEmulator] and the view switches to grid mode for its lifetime.
  ///
  /// The local buffer is NOT cleared when a session opens. What you ran before
  /// connecting is still yours, and it is back the moment you disconnect.
  TerminalEmulator? _emu;

  /// The live remote session, or null when everything is local.
  ///
  /// While this is open the prompt is a PIPE: input goes to the remote shell
  /// and the local command table is not consulted at all. A terminal that kept
  /// intercepting `clear` while you were on someone else's machine would be
  /// lying about where you are.
  SshConnection? _ssh;

  /// The PTY size last reported to the remote, so a rebuild that did not change
  /// the geometry does not send a redundant window change.
  int _cols = 80;
  int _rows = 24;

  bool get _remote => _ssh?.isOpen ?? false;

  /// Whether the post-first-frame rebuild has happened.
  ///
  /// Exists only to force that one rebuild. A bundled font is loaded lazily on
  /// first use, so a measurement taken during the first layout is taken against
  /// a fallback.
  bool _remeasured = false;

  @override
  void initState() {
    super.initState();
    _greet();
    // Straight to the prompt. A terminal you have to tap to focus is a
    // screenshot, not a tool.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showKeyboard();

      // Retake the PTY measurement now the font is resolved. One rebuild, once,
      // and `_reportSize` ignores it if the number did not move.
      if (!_remeasured) {
        setState(() => _remeasured = true);
      }

      final handed = widget.initialCommand?.trim();
      if (handed == null || handed.isEmpty) return;
      // AFTER the stores have loaded, not before. Running it immediately is the
      // bug this whole change exists to fix: an empty host list looks exactly
      // like a host that was never saved.
      unawaited(_runHandedOver(handed));
    });
  }

  Future<void> _runHandedOver(String line) async {
    await _hosts();
    if (!mounted) return;
    _write('\x1b[1m$_promptText\x1b[0m$line');
    _history.add(line);
    _historyAt = _history.length;
    _run(line);
    if (!mounted) return;
    _showKeyboard();
    setState(() {});
  }

  @override
  void dispose() {
    // The connection is owned by this screen and dies with it. Leaving a socket
    // open behind a closed terminal would hold the server's session and the
    // phone's radio for nothing.
    unawaited(_ssh?.close());
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Bring the keyboard back.
  ///
  /// ─── requestFocus IS NOT ENOUGH ─────────────────────────────────────────
  ///
  /// Dismissing the keyboard with the back gesture hides the IME and leaves the
  /// field FOCUSED. `requestFocus` on a node that already has focus does
  /// nothing at all, so tapping the output did nothing at all, over and over.
  ///
  /// When the node already holds focus the only way back is to ask the platform
  /// directly. When it does not, requesting focus opens the keyboard as a side
  /// effect, which is the ordinary path.
  void _showKeyboard() {
    if (_focus.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return;
    }
    _focus.requestFocus();
  }

  void _bell() {
    // The theme decides what a bell is. Haptic is the only one that works with
    // the phone face down in a pocket, and a sound from a launcher is a
    // surprise nobody asked for.
    HapticFeedback.selectionClick();
  }

  void _write(String text) {
    _parser.feed(text.endsWith('\n') ? text : '$text\n');
    _buffer.drain(_parser);
  }

  void _writeLines(Iterable<String> lines) {
    for (final l in lines) {
      _write(l);
    }
  }

  void _greet() {
    final name = widget.theme.spec.name;
    _write('\x1b[90m$name terminal. Type help, or ? for the palette.\x1b[0m');
    _write('');
  }

  String get _promptText {
    // WHILE REMOTE THERE IS NO LOCAL PROMPT. The far side sends its own, and
    // drawing ours in front of it would put two prompts on one line and imply
    // the local one still means something.
    if (_remote) return '';
    return renderPrompt(
      _spec.prompt,
      distro: widget.theme.spec.name,
      exitCode: _exitCode,
    );
  }

  // ── running a line ─────────────────────────────────────────────────────────

  /// What the input field held last time we looked.
  ///
  /// ─── WHY THIS IS A DIFF AND NOT A RESET ─────────────────────────────────
  ///
  /// A remote program needs each keystroke as it happens: `vim` acts on `i`
  /// immediately, and waiting for enter would make it unusable. The first
  /// version therefore sent whatever appeared and then REWROTE the field to a
  /// known value, ready for the next character.
  ///
  /// That rewrite is what broke the keyboard. A programmatic change to a text
  /// field tells the IME the content was replaced and a new sentence has begun,
  /// so it re-arms shift, and every character after the first arrives capital.
  /// It reached the server as `vIM /ETC/MOTD`, which is the sort of bug that
  /// looks like a keyboard setting and is not.
  ///
  /// So nothing is written back. The field accumulates as any field does, and
  /// what gets SENT is the difference from the last time it changed. The IME is
  /// left alone and behaves like it does everywhere else.
  String _typed = '';

  /// Send whatever changed, as keystrokes.
  ///
  /// Handles insertion, deletion and replacement, because an IME does all three:
  /// autocorrect and gesture typing replace whole words, and the honest reading
  /// of a replacement is backspaces followed by the new text.
  void _sendTyped(String value) {
    final conn = _ssh;
    if (conn == null || !conn.isOpen) {
      _typed = value;
      return;
    }

    // How much of the front is unchanged.
    var prefix = 0;
    final limit = value.length < _typed.length ? value.length : _typed.length;
    while (prefix < limit && value[prefix] == _typed[prefix]) {
      prefix++;
    }

    final removed = _typed.length - prefix;
    if (removed > 0) {
      // DEL rather than BS, because that is what a terminal sends for the key
      // marked backspace and what readline expects.
      conn.write('\x7f' * removed);
    }

    if (prefix < value.length) {
      conn.write(value.substring(prefix));
    }

    _typed = value;
  }

  void _submit() {
    final raw = _input.text;

    if (_remote) {
      // Enter is a carriage return to the far side, and nothing else: anything
      // still in the field has already been sent keystroke by keystroke.
      _ssh!.write('\r');
      // The one programmatic reset, and it happens where a sentence genuinely
      // ended, so an IME re-arming shift here is what it should do anyway.
      _input.clear();
      _typed = '';
      // `TextInputAction.go` closes the keyboard on submit, which is right for
      // a search box and wrong for a terminal: the next thing anyone does after
      // a command is type another one.
      _showKeyboard();
      setState(() {});
      return;
    }

    final line = raw.trim();

    // The echo happens whatever the outcome, including for an empty line,
    // because a prompt that swallows a bare enter does not look like a
    // terminal.
    _write('\x1b[1m$_promptText\x1b[0m$raw');
    _input.clear();

    if (line.isEmpty) {
      setState(() {});
      return;
    }

    _history.add(line);
    _historyAt = _history.length;

    _run(line);
    _showKeyboard();
    setState(() {});
  }

  /// Everything after the command word, for the commands that take arguments.
  ///
  /// Local commands ignore their arguments by design: `free -h` and `free` do
  /// the same thing because no flag would change anything the launcher can
  /// actually do. `ssh` and `host` are the first commands where the tail IS the
  /// instruction, so it is kept rather than discarded by `canonical`.
  String _args = '';

  void _run(String line) {
    final space = line.indexOf(RegExp(r'\s'));
    _args = space < 0 ? '' : line.substring(space + 1).trim();
    // Profile aliases resolve FIRST, ahead of the builtins, which is the order
    // `which` documents. A pack cannot shadow a builtin by accident, because
    // the validator rejects a colliding alias name at build time; if one ever
    // reaches a device anyway, the builtin still wins here.
    final alias = _aliasFor(line);
    if (alias != null && TerminalRegistry.command(alias.name) == null) {
      final action = CommandAction.byId(alias.actionId);
      if (action == null) {
        // A pack authored against a newer build. Naming the id is what turns a
        // silent no-op into a bug someone can report.
        _fail('${alias.name}: unknown action ${alias.actionId}');
        return;
      }
      _perform(action, _spawnKindFor(alias), name: alias.name);
      return;
    }

    final name = TerminalRegistry.resolve(
      line,
      surface: CommandSurface.terminal,
    );
    if (name == null) {
      _fail('${TerminalRegistry.canonical(line)}: command not found');
      return;
    }

    final command = TerminalRegistry.command(name)!;
    _perform(command.action, command.spawnKind, name: name);
  }

  TerminalAlias? _aliasFor(String line) {
    final q = TerminalRegistry.canonical(line);
    for (final a in _spec.aliases) {
      if (a.name == q) return a;
    }
    return null;
  }

  String? _spawnKindFor(TerminalAlias alias) {
    final k = alias.args['kind'];
    return k is String ? k : null;
  }

  void _perform(CommandAction action, String? spawnKind, {required String name}) {
    _exitCode = 0;

    // ─── THE GATE, AND WHERE IT IS ────────────────────────────────────────
    //
    // At EXECUTION, not at parse. The command resolved, autocompleted and
    // appeared in `help` wearing a lock, and only now does it stop. That is
    // deliberate: a Pro command that cannot be found teaches people the feature
    // does not exist, and they cannot want what they cannot see.
    //
    // Entitlement is read from `terminalProProvider`, which is set membership
    // over the SKUs Play reports. It is FALSE until Play answers, which is the
    // correct direction to fail on a paywall.
    final command = TerminalRegistry.command(name);
    if (command != null &&
        command.tier == CommandTier.pro &&
        !ref.read(terminalProProvider)) {
      unawaited(_offerPro(name));
      return;
    }

    switch (action) {
      case CommandAction.openSettings:
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(theme: widget.theme),
          ),
        );

      case CommandAction.openThemes:
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ThemesScreen()),
        );

      case CommandAction.clearPane:
        // On the pane this removes desklets. Here it clears scrollback, which
        // is the same intent expressed against a different surface.
        _buffer.clear();
        _parser.reset();

      case CommandAction.help:
        // PRINTED, not shown as a message. The TUI shell uses a toast because
        // it has nowhere to put a wall of text; this has scrollback. Same
        // command, different surface, and the surface is the reason.
        _writeLines(helpOutput([
          for (final c in TerminalRegistry.all)
            if (c.appearsOn(CommandSurface.terminal))
              (
                category: c.category.label,
                name: c.name,
                description: c.description,
                locked: c.tier == CommandTier.pro,
              ),
        ]));
        if (_spec.aliases.isNotEmpty) {
          _write('');
          _write('\x1b[90m${widget.theme.spec.name.toUpperCase()}\x1b[0m');
          for (final a in _spec.aliases) {
            _write('  \x1b[1m${a.name.padRight(12)}\x1b[0m${a.summary ?? ''}');
          }
        }

      case CommandAction.spawnDesklet:
        if (spawnKind == null) {
          _fail('$name: nothing to print');
          return;
        }
        // ARGS REACH THE COMMAND. Every other local command ignores its
        // arguments by design, because no flag would change anything the
        // launcher can do. `ls` is the exception: -a, -l and the rest genuinely
        // change what is listed.
        _writeLines(outputForKind(spawnKind, _facts(), args: _args));

      case CommandAction.sshHosts:
        unawaited(_printHosts());

      case CommandAction.sshHost:
        unawaited(_runHostCommand(_args));

      case CommandAction.sshConnect:
        unawaited(_runSsh(_args));

      case CommandAction.sshKey:
        unawaited(_runKeyCommand(_args));

      case CommandAction.openTerminal:
        // Unreachable: declared `surfaces: {tui}`, so this surface never
        // resolves it. You are already here.
        _fail('$name: already in the terminal');
    }
  }

  void _fail(String message) {
    // The exit code is real and the prompt can show it, which is the sort of
    // detail the audience for a Linux launcher checks within a minute.
    _exitCode = 127;
    _write('\x1b[31m$message\x1b[0m');
  }

  TerminalFacts _facts() => TerminalFacts(
        stats: ref.read(systemStatsProvider).asData?.value,
        apps: ref.read(shellAppsProvider(widget.theme)),
        // The unfiltered list, for `ls -a`. Empty while the app list is still
        // loading, and `_ls` falls back to the visible one rather than
        // reporting nothing.
        allApps: ref.read(appListProvider).asData?.value ?? const [],
        spec: widget.theme.spec,
        now: ref.read(clockProvider).asData?.value ?? DateTime.now(),
        deviceModel: ref.read(deviceInfoProvider).asData?.value.deviceModel,
      );

  // ── remote ─────────────────────────────────────────────────────────────────

  /// The saved hosts, GUARANTEED LOADED.
  ///
  /// ─── WHY NOT ref.read(provider).value ───────────────────────────────────
  ///
  /// Nothing on this screen watches the host store, so Riverpod disposes the
  /// notifier once a `read` finishes. The next `read` builds a fresh one whose
  /// `build()` is still going to SharedPreferences, and its `.value` is empty
  /// for that moment.
  ///
  /// That is not a race that shows up under load. It happened on the first
  /// device it ran on: `host add gphone ...` reported `added`, and `ssh gphone`
  /// on the next line could not find it, parsed `gphone` as a bare hostname and
  /// complained there was no username.
  ///
  /// Awaiting `.future` waits for the load. `build()` also watches the provider
  /// so it stays alive between commands rather than being rebuilt per read.
  Future<List<SshHost>> _hosts() => ref.read(sshHostsProvider.future);

  SshHost? _findHost(List<SshHost> hosts, String alias) {
    for (final h in hosts) {
      if (h.alias == alias) return h;
    }
    return null;
  }

  Future<void> _printHosts() async {
    final hosts = await _hosts();
    if (!mounted) return;
    if (hosts.isEmpty) {
      _write('\x1b[90mNo saved hosts. Try: host add <alias> <user@host>'
          '\x1b[0m');
      return;
    }

    final pro = ref.read(terminalProProvider);
    for (var i = 0; i < hosts.length; i++) {
      final h = hosts[i];
      // The locked ones are LISTED, not hidden. A ceiling you can see with your
      // own second server on it is a decision; one that hides the row is a bug
      // report about a host that vanished.
      final locked = !pro && i >= kFreeHostLimit;
      final mark = locked ? ' \x1b[33m[pro]\x1b[0m' : '';
      _write('  \x1b[1m${h.alias.padRight(14)}\x1b[0m${h.target}$mark');
    }
  }

  Future<void> _runHostCommand(String args) async {
    final parts = args.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) {
      _fail('host: usage: host <add|rm|forget> <alias> [user@host[:port]]');
      setState(() {});
      return;
    }

    final sub = parts.first.toLowerCase();
    final alias = parts.length > 1 ? parts[1].toLowerCase() : '';

    switch (sub) {
      case 'add':
        if (parts.length < 3) {
          _fail('host add: usage: host add <alias> <user@host[:port]>');
        } else if (!SshHost.isValidAlias(alias)) {
          _fail('host add: "$alias" is not a usable alias. Lowercase, '
              'starting with a letter.');
        } else if (TerminalRegistry.command(alias) != null) {
          // An alias that shadows a command would resolve to the command and
          // silently never connect.
          _fail('host add: "$alias" is already a command.');
        } else {
          final parsed = SshHost.parseTarget(parts[2], alias: alias);
          if (parsed == null) {
            _fail('host add: cannot read "${parts[2]}".');
          } else if (parsed.user.isEmpty) {
            _fail('host add: no username in "${parts[2]}".');
          } else {
            await _hosts();
            await ref.read(sshHostsProvider.notifier).save(parsed);
            _write('\x1b[32madded\x1b[0m ${parsed.alias} '
                '${parsed.target}');
          }
        }

      case 'rm':
        await _hosts();
        final removed =
            await ref.read(sshHostsProvider.notifier).remove(alias);
        removed
            ? _write('\x1b[32mremoved\x1b[0m $alias')
            : _fail('host rm: no host called "$alias".');

      case 'forget':
        // Drops the PINNED KEY, not the host. This is the deliberate act that
        // lets someone reconnect to a genuinely rebuilt server, and the reason
        // a key mismatch refuses instead of prompting.
        final host = _findHost(await _hosts(), alias);
        if (host == null) {
          _fail('host forget: no host called "$alias".');
        } else {
          final forgot = await ref
              .read(knownHostsProvider.notifier)
              .forget(host.host, host.port);
          forgot
              ? _write('\x1b[33mforgot the saved key for\x1b[0m '
                  '${host.host}:${host.port}')
              : _write('\x1b[90mno saved key for ${host.host}\x1b[0m');
        }

      default:
        _fail('host: unknown subcommand "$sub".');
    }

    setState(() {});
  }

  /// Show the paywall for the command that was just refused.
  Future<void> _offerPro(String command) async {
    _write('\x1b[33m$command needs Terminal Pro.\x1b[0m');
    setState(() {});

    final started = await showTerminalProSheet(
      context,
      ref,
      command: command,
      palette: _spec.palette,
      fontFamily: widget.theme.typography.mono,
    );

    if (!mounted) return;
    if (started) {
      // NOT unlocked. Play's flow can take minutes on the cash and carrier
      // billing this market uses, and the entitlement arrives on its own
      // stream. Saying it is done here would be a lie that resolves itself
      // eventually, which is the worst kind.
      _write('\x1b[90mPurchase started. The unlock arrives when Play '
          'confirms it.\x1b[0m');
    }
    _showKeyboard();
    setState(() {});
  }

  // ── keys ───────────────────────────────────────────────────────────────────

  Future<void> _runKeyCommand(String args) async {
    final parts =
        args.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final sub = parts.isEmpty ? 'ls' : parts.first.toLowerCase();
    final name = parts.length > 1 ? parts[1] : '';

    final api = ref.read(keysApiProvider);

    switch (sub) {
      case 'ls':
        final keys = await ref.read(sshKeysProvider.future);
        if (!mounted) return;
        if (keys.isEmpty) {
          _write('\x1b[90mNo keys. Try: key gen <name>\x1b[0m');
        } else {
          final active = await activeKeyAlias();
          if (!mounted) return;
          for (final k in keys) {
            // The active one is marked rather than sorted to the top: the list
            // is short and moving it would make it hard to find twice.
            final mark = k == active ? ' \x1b[32m(in use)\x1b[0m' : '';
            _write('  \x1b[1m$k\x1b[0m$mark');
          }
        }

      case 'gen':
        if (name.isEmpty) {
          _fail('key gen: usage: key gen <name>');
        } else if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,31}$').hasMatch(name)) {
          _fail('key gen: "$name" is not a usable name. Lowercase, no spaces.');
        } else {
          _write('\x1b[90mCreating a key in the secure chip ...\x1b[0m');
          setState(() {});
          final error = await ref.read(sshKeysProvider.notifier).generate(name);
          if (!mounted) return;
          if (error != null) {
            _fail('key gen: $error');
          } else {
            _write('\x1b[32mcreated\x1b[0m $name');
            await _printPublicKey(api, name);
          }
        }

      case 'show':
        final target = name.isEmpty ? (await activeKeyAlias() ?? '') : name;
        if (!mounted) return;
        if (target.isEmpty) {
          _fail('key show: no key. Try: key gen <name>');
        } else {
          await _printPublicKey(api, target);
        }

      case 'use':
        final keys = await ref.read(sshKeysProvider.future);
        if (!mounted) return;
        if (!keys.contains(name)) {
          _fail('key use: no key called "$name".');
        } else {
          await setActiveKeyAlias(name);
          if (!mounted) return;
          _write('\x1b[32musing\x1b[0m $name');
        }

      case 'rm':
        // DESTROYED, not deleted from a list. The private key is gone from the
        // secure chip and cannot be recovered, so the reminder about
        // authorized_keys is part of the output rather than a doc.
        final removed = await ref.read(sshKeysProvider.notifier).remove(name);
        if (!mounted) return;
        if (!removed) {
          _fail('key rm: no key called "$name".');
        } else {
          _write('\x1b[33mdestroyed\x1b[0m $name');
          _write('\x1b[90mRemove its line from authorized_keys on any server '
              'that had it.\x1b[0m');
        }

      default:
        _fail('key: usage: key <gen|ls|show|use|rm> [name]');
    }

    _showKeyboard();
    setState(() {});
  }

  Future<void> _printPublicKey(KeysHostApi api, String alias) async {
    final info = await api.publicKey(alias);
    if (!mounted) return;
    if (info == null) {
      _fail('key show: no key called "$alias".');
      return;
    }

    final pair = SshKeystoreKeyPair(alias: alias, info: info, api: api);
    _write('');
    _write('\x1b[90mAdd this line to ~/.ssh/authorized_keys:\x1b[0m');
    _write(pair.authorizedKeysLine);
    _write('');
    // The claim is stated only when it is true. A key that landed in software,
    // on an emulator or an odd ROM, must not be described as hardware-backed.
    _write(info.hardwareBacked
        ? '\x1b[32mheld in hardware\x1b[0m'
            '${info.strongBoxBacked ? ' (StrongBox)' : ''}'
        : '\x1b[33mheld in software on this device\x1b[0m');
  }

  Future<void> _runSsh(String args) async {
    if (_ssh != null) {
      _fail('ssh: already connected. Type exit first.');
      setState(() {});
      return;
    }
    if (args.isEmpty) {
      _fail('ssh: usage: ssh <alias|user@host[:port]>');
      setState(() {});
      return;
    }

    final target = args.split(RegExp(r'\s+')).first;

    // AWAITED. See _hosts: reading the notifier's state here is what made
    // `ssh gphone` fail on the line after `host add gphone` succeeded.
    final saved = _findHost(await _hosts(), target.toLowerCase());
    if (!mounted) return;

    // A SAVED ALIAS WINS over parsing the same string as a target. Someone who
    // saved a host called `build` means that host, not a machine called build
    // on the local domain.
    final host = saved ?? SshHost.parseTarget(target);
    if (host == null) {
      _fail('ssh: cannot read "$target".');
      setState(() {});
      return;
    }
    if (host.user.isEmpty) {
      _fail('ssh: no username. Try ssh user@${host.host}');
      setState(() {});
      return;
    }

    if (saved != null) {
      final access = ref.read(hostAccessProvider(saved.alias));
      if (access == HostAccess.needsPro) {
        _fail('ssh: ${saved.alias} is beyond the free limit of '
            '$kFreeHostLimit host. Terminal Pro connects to all of them.');
        setState(() {});
        return;
      }
    }

    // The pinned keys have to be in memory before the handshake asks about
    // them, and the handshake starts inside `open` below.
    await ref.read(knownHostsProvider.future);
    if (!mounted) return;

    _write('\x1b[90mConnecting to ${host.target} ...\x1b[0m');
    setState(() {});

    // The key, when there is one. Null falls through to a password, which is
    // also what a key destroyed by a fingerprint enrolment does: the connection
    // still works and the key manager is where that gets fixed.
    final identity = await activeIdentity(ref.read(keysApiProvider));
    if (!mounted) return;

    final conn = SshConnection(
      host: host,
      identity: identity,
      onData: (text) {
        // Into the EMULATOR, not the line parser. Both share `applySgr`, so a
        // remote program's colour and a `free` printed a second ago are still
        // read by one implementation; what differs is that this one has a
        // cursor and a screen.
        _emu?.feed(text);
        if (mounted) setState(() {});
      },
      onPhase: (phase) {
        if (mounted) setState(() {});
      },
      onPassword: (h) => askSshPassword(context, h, _spec.palette,
          fontFamily: widget.theme.typography.mono),
      onHostKey: (h, type, fp, verdict) => confirmSshHostKey(
        context,
        h,
        keyType: type,
        fingerprint: fp,
        verdict: verdict,
        palette: _spec.palette,
        fontFamily: widget.theme.typography.mono,
      ),
      // Loaded in _runSsh before the connection is built, so this synchronous
      // read is safe. A pin that had not loaded would present as a first
      // connection and ask about a key already trusted, which is the prompt
      // people learn to tap through.
      lookupPinned: (h, port) =>
          (ref.read(knownHostsProvider).value ?? const {})['$h:$port'],
      pin: (key) => ref.read(knownHostsProvider.notifier).trust(key),
    );

    // Built BEFORE the connection opens, because the first bytes can arrive
    // inside `open` and a null emulator would drop the login banner.
    _emu = TerminalEmulator(
      cols: _cols,
      rows: _rows,
      maxScrollback: _spec.scrollbackLines,
      onBell: _bell,
      onTitle: (t) {
        if (mounted) setState(() => _remoteTitle = t);
      },
    );

    _ssh = conn;
    final ok = await conn.open(columns: _cols, rows: _rows);
    if (ok) {
      _input.clear();
      _typed = '';
    }

    if (!ok) {
      _emu = null;
      _write('\x1b[31m${conn.failure ?? 'Connection failed.'}\x1b[0m');
      _ssh = null;
      _exitCode = 255;
    } else {
      _exitCode = 0;
    }

    if (!mounted) return;
    // TAKE THE KEYBOARD BACK.
    //
    // The password sheet owned the focus, and popping it hands focus to nobody:
    // the keyboard closes and the prompt looks dead at the exact moment the
    // session becomes usable. Reclaiming it here covers both outcomes, because
    // a failed connect leaves you at a local prompt you were about to type at
    // anyway.
    _showKeyboard();
    setState(() {});
  }

  Future<void> _disconnect({bool announce = true}) async {
    final conn = _ssh;
    if (conn == null) return;
    _ssh = null;
    _emu = null;
    _remoteTitle = null;
    _input.clear();
    _typed = '';
    await conn.close();
    if (announce) _write('\x1b[90mdisconnected\x1b[0m');
    if (mounted) setState(() {});
  }

  /// Report a new PTY size to the remote.
  ///
  /// A remote full-screen program only redraws correctly when it is told the
  /// window changed, which is the difference between rotating into a usable
  /// screen and rotating into a smeared one. Guarded on a real change so a
  /// rebuild that moved nothing does not send a window-change every frame.
  void _reportSize(int columns, int rows) {
    if (columns == _cols && rows == _rows) return;
    _cols = columns;
    _rows = rows;
    // The emulator first. If the remote redraws before our own screen has been
    // resized, the frame lands in a grid of the old shape and clips.
    _emu?.resize(cols: columns, rows: rows);
    _ssh?.resize(columns: columns, rows: rows);
  }

  // ── keys ───────────────────────────────────────────────────────────────────

  void _onKey(TerminalKeyEvent e) {
    switch (e) {
      case TerminalKeyCtrl():
        setState(() => _ctrl = !_ctrl);

      case TerminalKeyText(:final text):
        if (_ctrl) {
          _applyCtrl(text);
          return;
        }
        _insert(text);

      case TerminalKeySpecial(:final key):
        // On a remote session the special keys are BYTES, not editor commands.
        // Tab is completion on the far side, the arrows walk the remote shell's
        // own history, and escape is escape. Handling them locally would mean a
        // terminal where tab completes the wrong filesystem.
        if (_remote) {
          _ssh!.write(bytesForSpecial(key));
          return;
        }
        switch (key) {
          case TerminalSpecialKey.up:
            _walkHistory(-1);
          case TerminalSpecialKey.down:
            _walkHistory(1);
          case TerminalSpecialKey.tab:
            _complete();
          case TerminalSpecialKey.escape:
            _input.clear();
            setState(() {});
          case TerminalSpecialKey.left:
          case TerminalSpecialKey.right:
          case TerminalSpecialKey.home:
          case TerminalSpecialKey.end:
            _moveCaret(key);
        }
    }
  }

  void _applyCtrl(String char) {
    setState(() => _ctrl = false);
    final chord = ctrlChord(char);

    if (_remote) {
      // A REAL control byte to a real process. This is the whole reason the
      // sticky modifier exists: ctrl-c on a remote `tail -f` has to interrupt
      // it, and locally there is no process to interrupt.
      if (chord != null) {
        _ssh!.write(chord);
      } else {
        _insert(char);
      }
      return;
    }

    if (chord == null) {
      // No meaningful chord. Insert the plain character rather than inventing a
      // byte, which is the rule `ctrlChord` returning null exists to enforce.
      _insert(char);
      return;
    }

    // Locally there is no process to signal, so the two chords that mean
    // something on their own are handled and the rest are accepted quietly.
    // Sending 0x03 into a text field would be worse than doing nothing.
    if (chord == '\x03') {
      _write('\x1b[1m$_promptText\x1b[0m${_input.text}^C');
      _input.clear();
      _exitCode = 130;
      setState(() {});
      return;
    }
    if (chord == '\x04' && _input.text.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    if (chord == '\x0c') {
      _buffer.clear();
      _parser.reset();
      setState(() {});
    }
  }

  void _insert(String text) {
    final sel = _input.selection;
    final base = _input.text;
    final at = sel.isValid ? sel.start : base.length;
    final end = sel.isValid ? sel.end : base.length;
    _input.value = TextEditingValue(
      text: base.replaceRange(at, end, text),
      selection: TextSelection.collapsed(offset: at + text.length),
    );
    setState(() {});
  }

  void _moveCaret(TerminalSpecialKey key) {
    final len = _input.text.length;
    final at = _input.selection.isValid ? _input.selection.start : len;
    final to = switch (key) {
      TerminalSpecialKey.left => (at - 1).clamp(0, len),
      TerminalSpecialKey.right => (at + 1).clamp(0, len),
      TerminalSpecialKey.home => 0,
      _ => len,
    };
    _input.selection = TextSelection.collapsed(offset: to);
    setState(() {});
  }

  void _walkHistory(int delta) {
    if (_history.isEmpty) return;
    final next = (_historyAt + delta).clamp(0, _history.length);
    _historyAt = next;
    // Walking past the newest entry returns to an EMPTY line rather than
    // sticking on the last command, which is what every shell does and what
    // anyone pressing down twice is asking for.
    _input.text = next >= _history.length ? '' : _history[next];
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    setState(() {});
  }

  void _complete() {
    final hits = TerminalRegistry.matching(
      _input.text,
      surface: CommandSurface.terminal,
    );
    if (hits.isEmpty) return;

    if (hits.length == 1) {
      _input.text = hits.first;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      setState(() {});
      return;
    }

    // Ambiguous: print the candidates and leave the line alone, which is what
    // a shell does on a second tab and is far less annoying than cycling.
    _write('\x1b[1m$_promptText\x1b[0m${_input.text}');
    _write(hits.join('  '));
    setState(() {});
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = _spec.palette;
    final mono = widget.theme.typography.mono;

    // Rebuild on a stats tick so a `free` typed a second ago is not stale in
    // the scrollback... it deliberately IS stale, because scrollback is a
    // record. This watch exists only so the NEXT command reads fresh values.
    ref.watch(systemStatsProvider);

    // WATCHED so they stay alive for the life of the screen. Without a
    // listener an AsyncNotifier is disposed after each read and rebuilt on the
    // next one, which is how a host saved by one command was invisible to the
    // one typed after it.
    ref.watch(sshHostsProvider);
    ref.watch(knownHostsProvider);

    return Scaffold(
      backgroundColor: palette.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _TitleBar(
              // The title says WHERE YOU ARE. A terminal that looks identical
              // whether the next command runs on the phone or on a production
              // server is the one thing this screen must never be.
              // A remote program that named itself wins over the hostname:
              // `vim: main.dart` says more about where you are than repeating
              // the target already shown on the line you typed.
              title: _remote
                  ? (_remoteTitle ?? _ssh!.host.target)
                  : _spec.appLabel,
              remote: _remote,
              palette: palette,
              mono: mono,
              onClose: _remote
                  ? () => unawaited(_disconnect())
                  : () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // MEASURE, do not assume. The remote needs the real column
                  // count or `htop` draws for an 80-column terminal and every
                  // line wraps on a phone. Measured from the actual mono glyph
                  // rather than a guessed advance, because the family comes
                  // from the theme and a pack can ship its own.
                  // ─── MEASURED OVER A RUN, NOT ONE GLYPH ─────────────
                  //
                  // A single character rounds to whole pixels, and that error
                  // is multiplied by the column count. Averaging over a
                  // hundred gives the true advance.
                  //
                  // The FIRST measurement is still a lie, and this was found on
                  // a device: at first layout the theme's mono family has not
                  // loaded, so this measures a narrower fallback glyph. It read
                  // 54 columns on a screen that fits 48, the server formatted
                  // for 54, and the MOTD wrapped where nothing could show it.
                  // `initState` schedules one rebuild after the first frame, by
                  // which point the real font is resolved. See _remeasured.
                  const sample = 100;
                  final probe = TextPainter(
                    text: TextSpan(
                      text: 'M' * sample,
                      style: TextStyle(fontFamily: mono, fontSize: 13),
                    ),
                    textDirection: TextDirection.ltr,
                    // ─── THE SYSTEM FONT SCALE, WHICH IS NOT OPTIONAL ─────
                    //
                    // TextPainter does NOT apply the system text scale by
                    // default; a rendered Text does. So on a phone set to 1.1x
                    // the glyphs on screen are eleven percent wider than the
                    // ones measured here, and every column count is that much
                    // too generous.
                    //
                    // The server then formats for a width the screen does not
                    // have and wraps mid-field, which is what `1,1` and `All`
                    // landing on separate lines in vim's status bar actually
                    // means.
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();

                  final charWidth =
                      probe.width <= 0 ? 8.0 : probe.width / sample;
                  final lineHeight =
                      probe.height <= 0 ? 18.0 : probe.height * 1.45;

                  final columns =
                      ((constraints.maxWidth - 28) / charWidth).floor().clamp(20, 500);
                  final rows =
                      (constraints.maxHeight / lineHeight).floor().clamp(5, 200);

                  // Post-frame: a provider or a socket must not be written
                  // during build, and the size is only interesting after layout
                  // has settled anyway.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _reportSize(columns, rows);
                  });

                  final emu = _emu;

                  return Listener(
                    // A LISTENER, NOT A GestureDetector.
                    //
                    // `SelectionArea` lives inside this subtree and competes in
                    // the gesture arena, and a child wins. A parent
                    // GestureDetector's onTap can therefore be claimed away
                    // before it fires, which is the other half of why tapping
                    // the output did nothing.
                    //
                    // A Listener does not enter the arena: it sees the pointer
                    // regardless, and long-press selection still works because
                    // nothing is being consumed.
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) => _showKeyboard(),
                    child: emu == null
                        ? TerminalView(
                            buffer: _buffer,
                            palette: palette,
                            fontFamily: mono,
                            showCursor: false,
                          )
                        : TerminalView.grid(
                            emulator: emu,
                            palette: palette,
                            fontFamily: mono,
                          ),
                  );
                },
              ),
            ),
            // ALWAYS PRESENT, even under a full-screen program.
            //
            // Hiding it while `vim` is drawing looks tidier and takes the
            // keyboard away with it: the field is the only thing holding focus,
            // and on a phone there is no other way to type. What changes on a
            // remote session is what the field DOES, not whether it exists. It
            // shows no prompt, because the far side draws its own.
            _PromptRow(
              controller: _input,
              focus: _focus,
              prompt: _promptText,
              palette: palette,
              mono: mono,
              onSubmit: _submit,
              onChanged: _remote ? _sendTyped : null,
            ),
            TerminalKeyRow(
              palette: palette,
              fontFamily: mono,
              ctrlActive: _ctrl,
              onKey: _onKey,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.palette,
    required this.mono,
    required this.onClose,
    this.remote = false,
  });

  final String title;
  final bool remote;
  final TerminalPalette palette;
  final String? mono;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Painted from the TERMINAL palette rather than ChromeData, unlike every
    // other pushed screen. A chrome-coloured header over a green canvas would
    // read as two apps stacked, and the terminal is the whole screen here.
    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.dim, width: 0.5)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            remote ? Icons.cloud_queue : Icons.terminal,
            size: 17,
            // Remote is drawn in the palette's warning colour, which is not
            // decoration: it is the one persistent signal that the next command
            // lands on someone else's machine.
            color: remote ? palette.warn : palette.fg,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: mono,
                fontSize: 13,
                color: palette.fg,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              remote ? Icons.link_off : Icons.close,
              size: 19,
              color: palette.dim,
            ),
            tooltip: remote ? 'Disconnect' : 'Close',
          ),
        ],
      ),
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.controller,
    required this.focus,
    required this.prompt,
    required this.palette,
    required this.mono,
    required this.onSubmit,
    this.onChanged,
  });

  /// Set only on a remote session, where the field is a keystroke tap rather
  /// than an input buffer.

  final TextEditingController controller;
  final FocusNode focus;
  final String prompt;
  final TerminalPalette palette;
  final String? mono;
  final VoidCallback onSubmit;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    // ─── INVISIBLE WHILE REMOTE, AND STILL THERE ────────────────────────
    //
    // The field accumulates what you type, because rewriting it per keystroke
    // is what re-armed the keyboard's shift. The remote echoes those same
    // characters back and the grid draws them, so painting the field as well
    // would show every command twice, a character apart.
    //
    // Transparent rather than removed: it holds the focus, and on a phone the
    // focus is the keyboard.
    final remote = onChanged != null;
    final style = TextStyle(
      fontFamily: mono,
      fontSize: 13,
      height: 1.45,
      color: remote ? Colors.transparent : palette.fg,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt, style: style.copyWith(fontWeight: FontWeight.w700)),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,

              // ─── ASKING NICELY IS NOT ENOUGH ───────────────────────────
              //
              // `textCapitalization: none` is a HINT, and Samsung's keyboard
              // ignores it: its own auto-capitalise setting wins, so every
              // command starts with a capital and every one of them fails.
              //
              // `visiblePassword` is not about passwords. It maps to Android's
              // TYPE_TEXT_VARIATION_VISIBLE_PASSWORD, which turns
              // capitalisation, autocorrect and suggestions off at the IME
              // rather than requesting it, and the text stays visible. It is
              // what terminal apps use for exactly this reason.
              //
              // The smart dashes and quotes are off for the same class of
              // reason: an IME that helpfully turns a straight quote into a
              // curly one produces a command no shell has ever understood.
              keyboardType: TextInputType.visiblePassword,
              textCapitalization: TextCapitalization.none,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              textInputAction: TextInputAction.go,
              // The remote draws its own cursor into the grid, so ours would be
              // a second one in a different place.
              cursorColor: remote ? Colors.transparent : palette.cursor,
              cursorWidth: 8,
              cursorRadius: Radius.zero,
              maxLines: null,
              style: style,
              onChanged: onChanged,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ],
      ),
    );
  }
}
