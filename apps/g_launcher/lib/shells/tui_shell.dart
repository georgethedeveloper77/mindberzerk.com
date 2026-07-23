import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/app_repository.dart';
import '../data/repositories/shell_apps.dart';
import '../design/terminal_tokens.dart';
import '../engine/effective_theme.dart';
import '../features/desklets/desklet_surface.dart';
import '../features/desklets/terminal_commands.dart';
import '../features/desklets/terminal_matches.dart';
import '../features/palette/fuzzy.dart';
import '../features/palette/palette_controller.dart';
import '../platform/launcher_api.g.dart';
import '../system/system_stats.dart';

/// The terminal. **The flagship** — the one screen in this app you cannot get
/// from any other launcher, and the reason the whole project isn't Nova with a
/// Linux wallpaper.
///
/// Everything here is subordinate to one interaction: *type two letters, press
/// enter, the right app opens.* The ASCII art and the green-on-black are what
/// make people download it; that one interaction is what makes them keep it.
/// Which is why `fuzzy.dart` is a DP with 18 tests and this file is mostly paint.
///
/// Mockup, exactly:
///
///   george@infinix                          19:42 · 86%
///
///     .--.        os     ~ G Launcher
///    |o_o |       theme  ~ Terminal
///    |:_/ |       device ~ Infinix NOTE 40
///   //   \ \      apps   ~ 142 installed
///  (|     | )     uptime ~ 3h 12m
///  /'\_   _/`\
///  \___)=(___/
///
///   ~ ❯ fi█
///
///     launch  Firefox      ↵
///     app     Files
///     app     Fitness Insights
///
///   ─────────────────────────────────────
///   type to launch · ↵ opens the top match · esc clears
///
/// The keyboard opens on entry and stays open. That is not an oversight — a
/// terminal you have to tap to focus is a screenshot, not a tool.
class TuiShell extends ConsumerStatefulWidget {
  const TuiShell({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<TuiShell> createState() => _TuiShellState();
}

class _TuiShellState extends ConsumerState<TuiShell> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Straight to the prompt. The whole screen is an input.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Commands are checked BEFORE the app matcher, and that ordering is the
  /// whole reason `settings` opens ours rather than Android's.
  ///
  /// **This is how you reach G Launcher's settings on a terminal theme at all.**
  /// Every other shell surfaces them as drawer entries — the GNOME grid, the
  /// Kickoff footer, the tiling launcher's list. The terminal has no drawer: it
  /// fuzzy-matches installed APPS, and a launcher entry is not one. Typing a
  /// command is also the most authentic possible answer on a shell whose entire
  /// premise is typing.
  ///
  /// The four-name set that used to live here became [TerminalCommands],
  /// because the terminal now does three different things: navigate
  /// (`settings`, `themes`), spawn a live pane block (`free`, `df`, `ls`,
  /// `top`), and manage (`clear`, `help`).
  void _submit() {
    final query = _controller.text.trim();

    // `handles` is `resolve() != null`, the SAME call [TerminalMatches] uses to
    // decide which row wears the `↵`. One source of truth, so the screen and
    // the key cannot disagree — which they did before, showing Android's
    // Settings under the marker while enter opened the launcher's.
    if (TerminalCommands.handles(query)) {
      _clear();
      TerminalCommands.run(context, ref, widget.theme, query);
      return;
    }

    if (launchTopMatch(ref, widget.theme)) {
      _controller.clear();
    }
    // No toast on an empty match list. Someone mid-typo does not need to be told
    // they are mid-typo.
  }

  void _clear() {
    _controller.clear();
    ref.read(paletteQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(paletteResultsProvider(widget.theme));

    // Watched rather than read off `_controller.text`, so a keystroke rebuilds
    // this subtree through Riverpod rather than relying on the app matcher
    // happening to rebuild first.
    final query = ref.watch(paletteQueryProvider);

    // Does a command own the enter key right now? If so the app list must NOT
    // also mark a top match: two rows wearing `↵` is the same lie the builtin
    // rows exist to fix.
    final commandWins = TerminalCommands.handles(query);

    return Scaffold(
      backgroundColor: Term.bg,
      // The match list must ride above the keyboard, not under it.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): _ClearIntent(),
          },
          child: Actions(
            actions: {
              _ClearIntent: CallbackAction<_ClearIntent>(
                onInvoke: (_) {
                  _clear();
                  return null;
                },
              ),
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StatusLine(),
                Expanded(
                  child: ListView(
                    reverse: false,
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
                    children: [
                      _FastfetchHeader(theme: widget.theme),
                      const SizedBox(height: 18),

                      // PHASE D6 — persistent command output.
                      //
                      // ABOVE the prompt and below the fetch header, which is
                      // where a shell puts what you already ran. New blocks
                      // append, so the newest sits nearest the prompt.
                      //
                      // `page: 0` is correct and not a placeholder: the
                      // terminal has no workspace pager, so it renders
                      // workspace 1's pane and nothing else.
                      DeskletPane(theme: widget.theme, page: 0),

                      _Prompt(
                        controller: _controller,
                        focus: _focus,
                        onSubmit: _submit,
                      ),
                      const SizedBox(height: 12),

                      // Builtins first, the way a shell resolves them.
                      TerminalMatches(theme: widget.theme, query: query),
                      _Matches(results: results, demoted: commandWins),

                      const SizedBox(height: 16),
                      const _Hint(),
                    ],
                  ),
                ),
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

/// `george@infinix` · `19:42 · 86%`
class _StatusLine extends ConsumerWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();
    final device = ref.watch(deviceInfoProvider).asData?.value;
    final battery = device?.batteryPercent;

    final right = battery == null
        ? formatTime(now)
        : '${formatTime(now)} · $battery%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 12),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: Term.mono,
          fontSize: 12,
          color: Term.dim,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(device?.prompt ?? 'user'),
            Text(right),
          ],
        ),
      ),
    );
  }
}

/// The fastfetch block. Logo left, `key ~ value` right.
class _FastfetchHeader extends ConsumerWidget {
  const _FastfetchHeader({required this.theme});

  final EffectiveTheme theme;

  /// The mockup's logo, character for character. Keep the raw string — an
  /// escaped one is unreadable and someone will "fix" the backslashes.
  static const _logo = '  .--.\n |o_o |\n |:_/ |\n//   \\ \\\n(|     | )\n/\'\\_   _/`\\\n\\___)=(___/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceInfoProvider).asData?.value;
    final apps = ref.watch(shellAppsProvider(theme));

    // PHASE D1 — uptime now rides the stats snapshot.
    //
    // `elapsedRealtimeMillis` is already in every snapshot because it doubles
    // as the sample clock the network and CPU deltas divide by, so the uptime
    // row costs nothing extra. This SUPERSEDES the `g_launcher/uptime`
    // MethodChannel that was once planned and never built — do not add it. The
    // row was simply absent until now, which is why the fetch block had four
    // lines instead of five.
    final stats = ref.watch(systemStatsProvider).asData?.value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          _logo,
          style: TextStyle(
            fontFamily: Term.mono,
            fontSize: 13,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: Term.accent,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FetchRow('os', 'G Launcher'),
              // The theme's own name, not the string "Terminal" — the terminal
              // shell will eventually back more than one theme (Kali is a
              // terminal too), and hardcoding this here is how it stops being
              // data-driven.
              _FetchRow('theme', theme.spec.name),
              if (device?.deviceModel != null)
                _FetchRow('device', device!.deviceModel!),
              _FetchRow('apps', '${apps.length} installed'),
              if (stats?.uptime != null)
                _FetchRow('uptime', formatUptime(stats!.uptime)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FetchRow extends StatelessWidget {
  const _FetchRow(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontFamily: Term.mono,
          fontSize: 12.5,
          height: 1.7,
          color: Term.green,
        ),
        children: [
          TextSpan(
            text: k,
            style: const TextStyle(
              color: Term.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: ' ~ ', style: TextStyle(color: Term.dim)),
          TextSpan(text: v),
        ],
      ),
    );
  }
}

/// `~ ❯ ` + the input + a blinking block cursor.
class _Prompt extends ConsumerWidget {
  const _Prompt({
    required this.controller,
    required this.focus,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Text(
          '~ ❯',
          style: TextStyle(
            fontFamily: Term.mono,
            fontSize: Term.size,
            fontWeight: FontWeight.w700,
            color: Term.amber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            // A terminal that autocapitalises is a terminal nobody believes in.
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.go,
            cursorColor: Term.green,
            cursorWidth: 8,
            cursorRadius: Radius.zero,
            style: const TextStyle(
              fontFamily: Term.mono,
              fontSize: Term.size,
              color: Term.green,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) =>
                ref.read(paletteQueryProvider.notifier).state = v,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
      ],
    );
  }
}

/// The live match list. Top match gets the wash, the `launch` marker and the `↵`.
class _Matches extends ConsumerWidget {
  const _Matches({required this.results, this.demoted = false});

  final List<Ranked<AppEntry>> results;

  /// A command owns the enter key, so no app row is the top match.
  ///
  /// Without this, typing `settings` shows a builtin row with `↵` AND an app
  /// row with `↵`, and only one of them is true. Demoting is more honest than
  /// hiding the apps entirely — Android's Settings really is still there and
  /// still tappable, it just is not what enter does.
  final bool demoted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (results.isEmpty) return const SizedBox.shrink();

    // Ten is plenty. If the right app isn't in the top ten, the answer is another
    // keystroke, not more scrolling.
    final shown = results.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          _MatchRow(
            ranked: shown[i],
            isTop: i == 0 && !demoted,
            onTap: () {
              ref.read(appListProvider.notifier).launch(shown[i].item);
              ref.read(paletteQueryProvider.notifier).state = '';
            },
          ),
      ],
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.ranked,
    required this.isTop,
    required this.onTap,
  });

  final Ranked<AppEntry> ranked;
  final bool isTop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isTop ? Term.selection : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                isTop ? 'launch' : 'app',
                style: const TextStyle(
                  fontFamily: Term.mono,
                  fontSize: 11,
                  color: Term.muted,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Highlighted(
                text: ranked.item.label,
                indices: ranked.match.indices,
              ),
            ),
            if (isTop)
              const Text(
                '↵',
                style: TextStyle(
                  fontFamily: Term.mono,
                  fontSize: Term.size,
                  color: Term.amber,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints the matched characters amber and bold.
///
/// This is the payoff for `FuzzyMatch.indices`, and it is also the feature's own
/// debug view: if the highlight looks wrong, the *ranking* is wrong, and you can
/// see it without a print statement. Worth the DP on its own.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.indices});

  final String text;
  final List<int> indices;

  @override
  Widget build(BuildContext context) {
    final hit = indices.toSet();

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < text.length; i++)
            TextSpan(
              text: text[i],
              style: hit.contains(i)
                  ? const TextStyle(
                      color: Term.amber,
                      fontWeight: FontWeight.w700,
                    )
                  : const TextStyle(color: Term.green),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: Term.mono,
        fontSize: Term.size,
        height: Term.lineHeight,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Term.rule)),
      ),
      child: const Text(
        // The ONLY discovery surface before the first keystroke — nobody types
        // a command they do not know exists. Kept to the six worth knowing;
        // `help` prints the rest, so this stays short without hiding anything.
        'free · df · ls · top · settings · themes · help',
        style: TextStyle(
          fontFamily: Term.mono,
          fontSize: 11.5,
          color: Term.dim,
        ),
      ),
    );
  }
}
