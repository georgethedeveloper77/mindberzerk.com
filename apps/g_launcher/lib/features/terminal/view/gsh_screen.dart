/// The terminal screen.
///
/// One interaction is still the point: type two letters, press enter, the right
/// thing happens. What changed is that the right thing is now a COMMAND as often
/// as an app, and that the screen has somewhere to put what a command said.
///
/// ─── THE DISCOVERY SURFACES, AND WHY THERE ARE FOUR ─────────────────────────
///
/// Nobody types a command they do not know exists, and the old hint line was
/// six words of a forty-seven word vocabulary. Four surfaces, each doing a
/// different job:
///
///   1. rows as you type      the primary one. `d` shows df, du and date with
///                            their meanings, before the user has read anything
///   2. suggestions when idle solves cold start, and STOPS at eight runs, so
///                            the shell teaches and then gets out of the way
///   3. the ? key             the permanent complete reference, so it never has
///                            to fade
///   4. did you mean          a miss is when a user is most willing to learn
///
/// Only the first two decay. The other two cost one key and one branch.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/terminal_tokens.dart';
import '../../../engine/effective_theme.dart';
import '../../../system/system_stats.dart';
import '../adapter/launcher_term_host.dart';
import '../term_command.dart';
import '../term_host.dart';
import '../term_output.dart';
import '../term_registry.dart';
import '../term_session.dart';
import 'terminal_skin.dart';

/// The shell, with its host bound.
///
/// `termHostProvider` is declared as an override point so that no command file
/// imports a repository. THIS is where it is overridden, in a scope around the
/// screen, which is also what makes the session per-terminal rather than global.
class GshShell extends ConsumerWidget {
  const GshShell({
    super.key,
    required this.theme,
    required this.onLauncherPage,
  });

  final EffectiveTheme theme;

  /// REQUIRED, deliberately.
  ///
  /// `settings`, `themes`, `wall` and `icons` already work through
  /// TerminalCommands. An optional callback here would let the terminal be
  /// swapped in with those four silently opening nothing, which is a
  /// regression dressed as a feature. Required makes that a compile error.
  final TermPageOpener onLauncherPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Assigning a field on the adapter, not writing a provider, so this is safe
    // during build. Idempotent: the same closure every time.
    ref.read(launcherTermHostProvider(theme)).pageOpener = onLauncherPage;

    return ProviderScope(
      // No explicit <Override>: the same list fails to resolve that name from a
      // test library, and inference gives the identical type from
      // ProviderScope.overrides either way.
      overrides: [
        termHostProvider.overrideWith(
          (ref) => ref.watch(launcherTermHostProvider(theme)),
        ),
      ],
      child: GshScreen(theme: theme),
    );
  }
}

/// The app list, resolved ONCE per theme rather than per keystroke.
///
/// A FutureBuilder in the match list would build a new future on every
/// character, which throws away the slug cache and flickers the rows. The
/// adapter already returns the same list when the underlying one has not
/// changed, so this provider is the cheap way to say that.
final _termAppsProvider =
    FutureProvider.family<List<TermApp>, EffectiveTheme>((ref, theme) {
  return ref.watch(launcherTermHostProvider(theme)).apps();
});

class GshScreen extends ConsumerStatefulWidget {
  const GshScreen({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<GshScreen> createState() => _GshScreenState();
}

class _GshScreenState extends ConsumerState<GshScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  /// Where up and down are in the history. Length means "at the prompt".
  int _historyCursor = 0;

  @override
  void initState() {
    super.initState();
    // The keyboard opens on entry and stays open. A terminal you have to tap to
    // focus is a screenshot, not a tool.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String line = _input.text.trim();
    if (line.isEmpty) return;
    _input.clear();
    setState(() {});
    await ref.read(termSessionProvider.notifier).run(line);
    _historyCursor = ref.read(termSessionProvider).history.length;
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _insert(String text) {
    final int caret = _input.selection.baseOffset;
    if (caret < 0) {
      _input.text = _input.text + text;
    } else {
      _input.text = _input.text.replaceRange(caret, caret, text);
      _input.selection = TextSelection.collapsed(offset: caret + text.length);
    }
    setState(() {});
    _focus.requestFocus();
  }

  void _walkHistory(int direction) {
    final List<String> history = ref.read(termSessionProvider).history;
    if (history.isEmpty) return;
    _historyCursor =
        (_historyCursor + direction).clamp(0, history.length);
    _input.text =
        _historyCursor >= history.length ? '' : history[_historyCursor];
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    setState(() {});
    _focus.requestFocus();
  }

  /// Tab completes the command word, then a name in the current folder.
  Future<void> _complete() async {
    final String value = _input.text;
    final List<String> words = value.split(' ');
    final String last = words.isEmpty ? '' : words.last;

    List<String> pool;
    if (words.length <= 1) {
      pool = TermRegistry.instance.startingWith(last);
    } else {
      final host = ref.read(launcherTermHostProvider(widget.theme));
      final entries = await host.list(ref.read(termSessionProvider).cwd);
      pool = entries == null
          ? const <String>[]
          : entries
              .map((e) => e.name)
              .where((String n) => n.toLowerCase().startsWith(last.toLowerCase()))
              .toList();
    }
    if (pool.isEmpty) return;
    if (pool.length == 1) {
      words[words.length - 1] = pool.first;
      _input.text = '${words.join(' ')} ';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      setState(() {});
    } else {
      // More than one, so the shell shows them rather than guessing. This is
      // the one place tab prints instead of completing, exactly as it does
      // everywhere else.
      _showSheet(prefix: last);
    }
    _focus.requestFocus();
  }

  void _showSheet({String? prefix}) {
    final TerminalSkin? skin = _lastSkin;
    if (skin == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: skin.background,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _CommandSheet(
        skin: skin,
        prefix: prefix,
        unwired: ref.read(termSessionProvider).unwired,
        onPick: (String name) {
          Navigator.of(sheetContext).pop();
          _insert(_input.text.isEmpty ? name : ' $name');
        },
      ),
    );
  }

  /// The skin last built. Callbacks that open a sheet cannot watch a provider,
  /// and rebuilding a skin from `ref.read` there would drop the device info the
  /// build already had.
  TerminalSkin? _lastSkin;

  @override
  Widget build(BuildContext context) {
    final DeviceInfo? info = ref.watch(deviceInfoProvider).asData?.value;
    final TerminalSkin skin = TerminalSkin.from(
      widget.theme,
      user: info?.user,
      host: info?.host,
      // authored: widget.theme.spec.terminal, one line once ThemeSpec carries
      // the block. Until then every distro takes the defaults, which reproduce
      // exactly what the terminal looks like today.
    );
    _lastSkin = skin;
    final TermSessionState session = ref.watch(termSessionProvider);
    final String query = _input.text.trim();

    return Scaffold(
      backgroundColor: skin.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.escape): _ClearIntent(),
            SingleActivator(LogicalKeyboardKey.tab): _CompleteIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): _HistoryIntent(-1),
            SingleActivator(LogicalKeyboardKey.arrowDown): _HistoryIntent(1),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _ClearIntent: CallbackAction<_ClearIntent>(onInvoke: (_) {
                _input.clear();
                setState(() {});
                return null;
              }),
              _CompleteIntent: CallbackAction<_CompleteIntent>(onInvoke: (_) {
                _complete();
                return null;
              }),
              _HistoryIntent: CallbackAction<_HistoryIntent>(onInvoke: (i) {
                _walkHistory(i.direction);
                return null;
              }),
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _StatusLine(skin: skin),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _focus.requestFocus,
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                      children: <Widget>[
                        _FetchHeader(skin: skin, theme: widget.theme),
                        if (skin.spec.motd.isNotEmpty) _Motd(skin: skin),
                        const SizedBox(height: 14),

                        // Scrollback. Each block keeps the folder it RAN in, so
                        // a `cd` does not retroactively move where earlier
                        // output appears to have come from.
                        for (var i = 0; i < session.blocks.length; i++)
                          _Block(
                            skin: skin,
                            block: session.blocks[i],
                            live: i == session.blocks.length - 1,
                          ),

                        _Prompt(
                          skin: skin,
                          cwd: session.cwd.display,
                          controller: _input,
                          focus: _focus,
                          onChanged: (_) => setState(() {}),
                          onSubmit: _submit,
                        ),

                        // Surface 2, and it decays. Only while nothing is typed
                        // and only for the first eight runs.
                        if (query.isEmpty && session.showsSuggestions)
                          _Suggestions(
                            skin: skin,
                            commands: ref
                                .read(termSessionProvider.notifier)
                                .suggestions(),
                            onPick: (String c) {
                              _input.text = c;
                              _submit();
                            },
                          ),

                        // Surface 1, the primary one.
                        if (query.isNotEmpty)
                          _Matches(
                            skin: skin,
                            theme: widget.theme,
                            query: query,
                            unwired: session.unwired,
                            onRun: (String value) {
                              _input.text = value;
                              _submit();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                _SymbolRow(
                  skin: skin,
                  onKey: _insert,
                  onTab: _complete,
                  onHistory: _walkHistory,
                  onSheet: _showSheet,
                  onEscape: () {
                    _input.clear();
                    setState(() {});
                  },
                ),
                _Hint(skin: skin),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}

class _CompleteIntent extends Intent {
  const _CompleteIntent();
}

class _HistoryIntent extends Intent {
  const _HistoryIntent(this.direction);
  final int direction;
}

/// `george@infinix` and `19:42 · 86%`.
class _StatusLine extends ConsumerWidget {
  const _StatusLine({required this.skin});

  final TerminalSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now =
        ref.watch(clockProvider).asData?.value ?? DateTime.now();
    final DeviceInfo? device = ref.watch(deviceInfoProvider).asData?.value;
    final int? battery = device?.batteryPercent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 12),
      child: DefaultTextStyle(
        style: skin.style(role: TermInk.dim, size: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(device?.prompt ?? skin.user),
            // Absent, never a placeholder: a device that will not report its
            // charge drops the segment rather than printing a dash.
            Text(battery == null
                ? formatTime(now)
                : '${formatTime(now)} \u00b7 $battery%'),
          ],
        ),
      ),
    );
  }
}

class _FetchHeader extends ConsumerWidget {
  const _FetchHeader({required this.skin, required this.theme});

  final TerminalSkin skin;
  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeviceInfo? device = ref.watch(deviceInfoProvider).asData?.value;
    final stats = ref.watch(systemStatsProvider).asData?.value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(skin.logo, style: skin.style(role: TermInk.accent, size: 13).copyWith(
              height: 1.15,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _FetchRow(skin: skin, k: 'os', v: 'G Launcher'),
              // The theme's own name, never the string Terminal: this shell
              // backs more than one distro, which is the whole reason the skin
              // exists.
              _FetchRow(skin: skin, k: 'theme', v: theme.spec.name),
              _FetchRow(skin: skin, k: 'shell', v: 'gsh'),
              if (device?.deviceModel != null)
                _FetchRow(skin: skin, k: 'device', v: device!.deviceModel!),
              if (stats?.uptime != null)
                _FetchRow(
                  skin: skin,
                  k: 'uptime',
                  v: formatUptime(stats!.uptime),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FetchRow extends StatelessWidget {
  const _FetchRow({required this.skin, required this.k, required this.v});

  final TerminalSkin skin;
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          style: skin.style(size: 12.5).copyWith(height: 1.7),
          children: <InlineSpan>[
            TextSpan(
              text: k,
              style: TextStyle(
                color: skin.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: ' ~ ', style: TextStyle(color: skin.ink(TermInk.dim))),
            TextSpan(text: v),
          ],
        ),
      );
}

class _Motd extends StatelessWidget {
  const _Motd({required this.skin});

  final TerminalSkin skin;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.only(left: 11),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: skin.rule, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final String line in skin.spec.motd)
              Text(line, style: skin.style(role: TermInk.dim, size: 12)),
          ],
        ),
      );
}

/// One scrollback entry: the echoed line, then what came back.
class _Block extends StatelessWidget {
  const _Block({required this.skin, required this.block, required this.live});

  final TerminalSkin skin;
  final TermEntryBlock block;

  /// Only the newest block keeps sampling. An older `free` is a reading from
  /// when it ran, and animating it would rewrite history.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final String cwd = block.cwd.display;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (skin.promptTopLine != null)
            Text(
              skin.render(skin.promptTopLine!, cwd),
              style: skin.style(role: TermInk.dim, size: 13),
            ),
          Text.rich(
            TextSpan(
              style: skin.style(size: 13),
              children: <InlineSpan>[
                TextSpan(
                  text: '${skin.render(skin.promptLine, cwd)} ',
                  style: TextStyle(
                    color: skin.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: block.line),
              ],
            ),
          ),
          for (final TermChunk chunk in block.chunks)
            if (chunk is TermTextChunk)
              _Lines(skin: skin, lines: chunk.lines)
            else if (chunk is TermLiveChunk)
              _LiveBlock(skin: skin, chunk: chunk, live: live),
        ],
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.skin, required this.lines});

  final TerminalSkin skin;
  final List<TermLine> lines;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final TermLine line in lines)
            Text.rich(
              TextSpan(
                style: skin.style(size: 12.5).copyWith(height: 1.55),
                children: <InlineSpan>[
                  for (final TermSpan span in line.spans)
                    TextSpan(
                      text: span.text,
                      style: TextStyle(color: skin.ink(span.ink)),
                    ),
                ],
              ),
            ),
        ],
      );
}

/// `free`, `df` and `top` keep sampling while they are the newest block.
class _LiveBlock extends ConsumerWidget {
  const _LiveBlock({
    required this.skin,
    required this.chunk,
    required this.live,
  });

  final TerminalSkin skin;
  final TermLiveChunk chunk;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    double? fraction = chunk.fraction;

    if (live) {
      final stats = ref.watch(systemStatsProvider).asData?.value;
      if (stats != null) {
        fraction = switch (chunk.kind) {
          TermLiveKind.memory => stats.hasMemory
              ? (stats.memUsedGb! / stats.memTotalGb!).clamp(0.0, 1.0)
              : null,
          TermLiveKind.storage => stats.hasStorage
              ? (stats.storageUsedBytes! / stats.storageTotalBytes!)
                  .clamp(0.0, 1.0)
              : null,
          // Null when this ROM will not report CPU, which is most of them. The
          // bar disappears rather than resting at zero, because a zero bar is a
          // claim that the CPU is idle.
          TermLiveKind.cpu => stats.cpuPercent == null
              ? null
              : stats.cpuPercent! / 100,
        };
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        border: Border.all(color: skin.rule),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Lines(skin: skin, lines: chunk.lines),
          if (fraction != null) ...<Widget>[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: skin.rule,
                valueColor: AlwaysStoppedAnimation<Color>(skin.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.skin,
    required this.cwd,
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onSubmit,
  });

  final TerminalSkin skin;
  final String cwd;
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final String? top = skin.promptTopLine;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (top != null)
            Text(
              skin.render(top, cwd),
              style: skin.style(role: TermInk.dim, size: 13),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                skin.render(skin.promptLine, cwd),
                style: skin.style(size: 13.5, weight: FontWeight.w700)
                    .copyWith(color: skin.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  // A terminal that autocapitalises is a terminal nobody
                  // believes in.
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.go,
                  cursorColor: skin.foreground,
                  cursorWidth: skin.cursorWidth,
                  cursorRadius: Radius.zero,
                  style: skin.style(size: 13.5),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: onChanged,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Surface 2. Six commands with a meaning each, while the prompt is empty.
class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.skin,
    required this.commands,
    required this.onPick,
  });

  final TerminalSkin skin;

  /// Chosen by the session, which filters out anything this build cannot run.
  final List<TermCommand> commands;

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('try', style: skin.style(role: TermInk.dim, size: 11.5)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final TermCommand command in commands)
              GestureDetector(
                onTap: () => onPick(command.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: skin.rule),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: skin.style(size: 12),
                      children: <InlineSpan>[
                        TextSpan(text: command.name),
                        TextSpan(
                          text: '  ${command.help}',
                          style: TextStyle(color: skin.ink(TermInk.dim)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Surface 1. Commands first, the way a shell resolves them, then apps.
class _Matches extends ConsumerWidget {
  const _Matches({
    required this.skin,
    required this.theme,
    required this.query,
    required this.unwired,
    required this.onRun,
  });

  final TerminalSkin skin;
  final EffectiveTheme theme;
  final String query;

  /// Names this build cannot perform. Hidden here rather than removed from the
  /// registry, so typing one still resolves and explains itself.
  final Set<String> unwired;

  final ValueChanged<String> onRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only the first word matches. Once there is an argument the user is
    // already inside a command and a list of apps under it is noise.
    if (query.contains(' ')) return const SizedBox.shrink();

    final List<String> commands = TermRegistry.instance
        .startingWith(query)
        .where((String name) => !unwired.contains(name))
        .take(4)
        .toList();

    final List<TermApp> apps =
        ref.watch(_termAppsProvider(theme)).asData?.value ?? const <TermApp>[];
    final String needle = query.toLowerCase();
    final List<TermApp> hits = apps
        .where((TermApp a) => a.label.toLowerCase().startsWith(needle))
        .take(4)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < commands.length; i++)
          _MatchRow(
            skin: skin,
            kind: 'run',
            name: commands[i],
            note: TermRegistry.instance.lookup(commands[i])!.help,
            query: query,
            // A command owns the enter key whenever one matches. Two rows
            // wearing the marker is the same lie the builtin rows exist to fix.
            top: i == 0,
            onTap: () => onRun(commands[i]),
          ),
        for (var i = 0; i < hits.length; i++)
          _MatchRow(
            skin: skin,
            kind: commands.isEmpty && i == 0 ? 'launch' : 'app',
            name: hits[i].label,
            note: null,
            query: query,
            top: commands.isEmpty && i == 0,
            // The SLUG, not the label. A label with a space in it would be
            // parsed as a command and an argument, so `G Recovery` would run
            // `G` and report that it does not exist.
            onTap: () => onRun(hits[i].slug),
          ),
      ],
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.skin,
    required this.kind,
    required this.name,
    required this.note,
    required this.query,
    required this.top,
    required this.onTap,
  });

  final TerminalSkin skin;
  final String kind;
  final String name;
  final String? note;
  final String query;
  final bool top;
  final VoidCallback onTap;

  /// The matched head is however much of the query the name actually carries.
  int get _cut => query.length < name.length ? query.length : name.length;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: top ? skin.selection : null,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 46,
              child: Text(kind, style: skin.style(role: TermInk.dim, size: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: skin.style(size: 13.5),
                  children: <InlineSpan>[
                    // The matched head, painted. This is also the feature's own
                    // debug view: if the highlight looks wrong, the matching is
                    // wrong, and you can see it without a print statement.
                    TextSpan(
                      text: name.substring(0, _cut),
                      style: TextStyle(
                        color: skin.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: name.substring(_cut)),
                    if (note != null)
                      TextSpan(
                        text: '   $note',
                        style: TextStyle(
                          color: skin.ink(TermInk.dim),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (top)
              Text('\u21B5',
                  style: skin.style(size: 13.5).copyWith(color: skin.accent)),
          ],
        ),
      ),
    );
  }
}

/// Surface 3. The permanent reference, grouped, tappable.
class _CommandSheet extends StatelessWidget {
  const _CommandSheet({
    required this.skin,
    required this.unwired,
    required this.onPick,
    this.prefix,
  });

  final TerminalSkin skin;
  final Set<String> unwired;
  final ValueChanged<String> onPick;

  /// Set when tab found more than one completion, so the sheet opens narrowed
  /// to what the user was already typing rather than at the top of everything.
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      builder: (BuildContext context, ScrollController controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: <Widget>[
          Text(
            prefix == null
                ? 'commands, tap one to insert it'
                : 'commands starting with $prefix',
            style: skin.style(role: TermInk.dim, size: 11.5),
          ),
          const SizedBox(height: 10),
          for (final TermGroup group in TermGroup.values)
            _SheetGroup(
              skin: skin,
              group: group,
              prefix: prefix,
              unwired: unwired,
              onPick: onPick,
            ),
        ],
      ),
    );
  }
}

class _SheetGroup extends StatelessWidget {
  const _SheetGroup({
    required this.skin,
    required this.group,
    required this.prefix,
    required this.unwired,
    required this.onPick,
  });

  final TerminalSkin skin;
  final TermGroup group;
  final String? prefix;
  final Set<String> unwired;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final List<TermCommand> commands = TermRegistry.instance
        .inGroup(group)
        .where((TermCommand c) => !unwired.contains(c.name))
        .where((TermCommand c) => prefix == null || c.name.startsWith(prefix!))
        .toList();
    if (commands.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            group.label,
            style: skin.style(role: TermInk.accent, size: 11)
                .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.4),
          ),
        ),
        for (final TermCommand command in commands)
          GestureDetector(
            onTap: () => onPick(command.name),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: skin.rule)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 96,
                    child: Text(command.name, style: skin.style(size: 12.5)),
                  ),
                  Expanded(
                    child: Text(
                      command.usage ?? command.help,
                      style: skin.style(role: TermInk.dim, size: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// THE ONE THING A PHONE SHELL NEEDS AND A DESKTOP NEVER DID.
///
/// Every character below is one an Android keyboard buries behind a modifier
/// layer, and a shell is unusable without them. `?` is here rather than in a
/// menu because the complete reference has to be one tap from the prompt.
class _SymbolRow extends StatelessWidget {
  const _SymbolRow({
    required this.skin,
    required this.onKey,
    required this.onTab,
    required this.onHistory,
    required this.onSheet,
    required this.onEscape,
  });

  final TerminalSkin skin;
  final ValueChanged<String> onKey;
  final VoidCallback onTab;
  final ValueChanged<int> onHistory;
  final VoidCallback onSheet;
  final VoidCallback onEscape;

  @override
  Widget build(BuildContext context) {
    final List<_Key> keys = <_Key>[
      _Key('?', onSheet, accent: true),
      _Key('tab', onTab),
      _Key('-', () => onKey('-')),
      _Key('/', () => onKey('/')),
      _Key('~', () => onKey('~')),
      _Key('..', () => onKey('..')),
      _Key('|', () => onKey(' | ')),
      _Key('&&', () => onKey(' && ')),
      _Key('\u2191', () => onHistory(-1)),
      _Key('\u2193', () => onHistory(1)),
      _Key('esc', onEscape),
    ];

    return Container(
      decoration: BoxDecoration(
        color: skin.bar.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: skin.rule)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final _Key key in keys)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: key.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 34),
                    height: 30,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: skin.rule),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      key.label,
                      style: skin
                          .style(
                            role: key.accent ? TermInk.accent : TermInk.dim,
                            size: 12.5,
                          )
                          .copyWith(height: 1.0),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Key {
  const _Key(this.label, this.onTap, {this.accent = false});
  final String label;
  final VoidCallback onTap;
  final bool accent;
}

class _Hint extends StatelessWidget {
  const _Hint({required this.skin});

  final TerminalSkin skin;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 9, 18, 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: skin.rule)),
        ),
        child: Text(skin.hint, style: skin.style(role: TermInk.dim, size: 11.5)),
      );
}
