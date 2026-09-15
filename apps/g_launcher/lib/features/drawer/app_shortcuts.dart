/// PHASE L6b: what a row opens to.
///
/// ─── THE PROVIDER IS PER APP AND AUTO-DISPOSING ─────────────────────────────
///
/// One family member per component key, created when a row opens and thrown
/// away when it closes. That is deliberate and it is the opposite of how the
/// app list works.
///
/// A dynamic shortcut is the publishing app's live state: the last three
/// conversations, the current playlist, whichever document was open. Caching it
/// would show a row from an hour ago, and the failure would be invisible,
/// because a stale shortcut looks exactly like a current one until it is
/// tapped. `AppShortcutReader` on the native side refuses to cache for the same
/// reason; keeping a copy here would put the staleness back one layer up.
///
/// The cost is one binder call per row the user deliberately opened, which is
/// the right place to spend it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_repository.dart';
import '../../design/components/press_pop.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';

/// The shortcuts one app publishes, or empty.
///
/// Never an error state. Every failure native can have, an old device, an app
/// that publishes none, a lost home role, comes back as an empty list, and the
/// row draws the same thing for all of them: the management actions and
/// nothing else. A caller cannot act differently on any of them, so giving it
/// three ways to be told the same thing would be three branches that all lead
/// to one widget.
final appShortcutsProvider =
    FutureProvider.autoDispose.family<List<AppShortcut>, String>(
  (ref, componentKey) async {
    try {
      return await ref.read(launcherHostApiProvider).shortcutsFor(componentKey);
    } catch (_) {
      return const [];
    }
  },
);

/// The media session this app owns, or null.
///
/// ─── ONE PROVIDER, FILTERED PER APP ─────────────────────────────────────────
///
/// `activeSessions` deliberately returns everything, because the bridge has no
/// business deciding which session matters. This is where the row's own policy
/// lives: Spotify's row shows Spotify's transport, and WhatsApp's row shows
/// none even while music is playing. Anything else would put one app's controls
/// inside another app's row.
///
/// The package is matched rather than the component key, because a session
/// belongs to an app, not to an activity.
///
/// ─── READ WHEN THE ROW OPENS, AND NOT AFTER ─────────────────────────────────
///
/// No polling and no `addOnActiveSessionsChangedListener`. A registered
/// callback lives for the whole process and fires on every track change on the
/// phone, for the few seconds one row happens to be open.
///
/// The cost is a stale title if the track changes while the row sits open. The
/// transport buttons invalidate this themselves, because pressing one is the
/// moment the state definitely changed, so the only way to see a stale line is
/// to open a row and wait for a track to end without touching anything.
final nowPlayingProvider =
    FutureProvider.autoDispose.family<NowPlaying?, String>(
  (ref, packageName) async {
    try {
      final all = await ref.read(launcherHostApiProvider).activeSessions();
      for (final s in all) {
        if (s.packageName == packageName) return s;
      }
      return null;
    } catch (_) {
      return null;
    }
  },
);

/// The payload under an open row.
///
/// ─── IT DRAWS SOMETHING BEFORE NATIVE ANSWERS ───────────────────────────────
///
/// The query is a binder call and the row is already animating open, so there
/// is a real frame or two with no data. Drawing nothing there makes the
/// expansion appear to finish and then jump taller, which is the worst version
/// of a progress state: the layout settles twice.
///
/// So the chips are laid out at their final height immediately, as empty
/// outlines, and fill in. The row grows once.
class RowExpansion extends ConsumerWidget {
  const RowExpansion({
    super.key,
    required this.componentKey,
    required this.theme,
    required this.onLaunch,
  });

  final String componentKey;
  final EffectiveTheme theme;

  /// Start a shortcut, given its id and the rect it was tapped in. The rect is
  /// what Android animates the window out of, so a shortcut launched from a
  /// chip should grow from that chip.
  final void Function(String shortcutId, Rect anchor) onLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appShortcutsProvider(componentKey));
    final shortcuts = async.value;

    // The package, not the component key: a session belongs to an app.
    final pkg = componentKey.split('/').first;
    final playing = ref.watch(nowPlayingProvider(pkg)).value;

    return Padding(
      // Indented to the label, not to the row. The chips belong to the name
      // above them, and starting them under the icon would read as a second
      // column rather than as this app's own actions.
      padding: const EdgeInsets.fromLTRB(64, 2, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ABOVE the shortcuts, because it is about right now and they are
          // about what this app can do. Absent entirely when nothing is
          // playing, which is almost always: a transport strip that appears
          // only when it has something to control is the whole reason it can
          // sit inside a row without crowding it.
          if (playing != null) ...[
            _Transport(now: playing, theme: theme, pkg: pkg),
            const SizedBox(height: 10),
          ],
          _chips(shortcuts),
        ],
      ),
    );
  }

  Widget _chips(List<AppShortcut>? shortcuts) {
    return shortcuts == null
          ? _Skeleton(theme: theme)
          : shortcuts.isEmpty
              ? const SizedBox(height: 4)
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in shortcuts)
                      _Chip(
                        label: s.label,
                        theme: theme,
                        // ─── DISABLED IS SHOWN, NOT HIDDEN ──────────────
                        //
                        // The publisher has switched it off without removing
                        // it, which is where a chat shortcut lands when you
                        // leave the conversation. Dropping it would make the
                        // row's contents shuffle every time someone archives
                        // something; greying it says what happened.
                        disabled: s.disabled,
                        onTap: s.disabled ? null : (rect) => onLaunch(s.id, rect),
                      ),
                  ],
                );
  }
}

/// Chips at their final size with no text, so the row grows once.
class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final ink = theme.palette.onDark.withValues(alpha: 0.10);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in const [96.0, 72.0])
          Container(
            width: w,
            height: 40,
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.theme,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final EffectiveTheme theme;
  final bool disabled;
  final void Function(Rect anchor)? onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;

    return PressPop(
      held: _held,
      radius: 20,
      ringColor: p.onDark,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _held = true),
        onTapCancel: () => setState(() => _held = false),
        onTap: () {
          setState(() => _held = false);
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          widget.onTap?.call(box.localToGlobal(Offset.zero) & box.size);
        },
        child: Container(
          // 40 rather than 48. A chip is inside a surface the user has already
          // opened deliberately, sitting beside its siblings with 8dp between
          // them, so the whole cluster is a much larger target than any one of
          // them. 48 each would make three chips taller than the row above.
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: widget.disabled ? 0.07 : 0.16),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: widget.theme.typography.display,
              color: p.accent.withValues(alpha: widget.disabled ? 0.45 : 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Play, pause and skip for one session.
///
/// ─── ONLY THE BUTTONS THE SESSION ADMITS TO ─────────────────────────────────
///
/// `canSkipNext` and `canSkipPrevious` come from the session's own declared
/// actions, and they vary enormously: a podcast app commonly offers neither, an
/// audiobook offers seek and no skip, a radio stream offers nothing at all.
/// Drawing three buttons and having two do nothing is the live-and-inert
/// failure the settings screen spent a whole pass removing.
///
/// Play and pause are always drawn. A session that publishes no transport at
/// all is vanishingly rare and the button reports its own refusal.
class _Transport extends ConsumerWidget {
  const _Transport({
    required this.now,
    required this.theme,
    required this.pkg,
  });

  final NowPlaying now;
  final EffectiveTheme theme;
  final String pkg;

  /// Send, then re-read. Pressing a transport button is the one moment the
  /// session state definitely changed, so it is also the only moment worth
  /// spending a second binder call on. This is what keeps the strip honest
  /// without a listener running for the life of the process.
  Future<void> _send(WidgetRef ref, String command) async {
    await ref.read(launcherHostApiProvider).sendMediaCommand(pkg, command);
    ref.invalidate(nowPlayingProvider(pkg));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = theme.palette;

    // ─── THE TITLE FALLS BACK TO NOTHING, NOT TO A PLACEHOLDER ───────────
    //
    // A player often publishes its session before its metadata, so for a beat
    // there genuinely is no title. The row already carries the app's name
    // directly above this, so an empty line here reads as "starting" rather
    // than as broken, and "Unknown track" invented here would be a small lie
    // sitting under a true one.
    final line = [
      if (now.title.isNotEmpty) now.title,
      if (now.artist.isNotEmpty) now.artist,
    ].join('  ·  ');

    return Row(
      children: [
        if (now.canSkipPrevious)
          _Button(
            icon: Icons.skip_previous,
            theme: theme,
            onTap: () => _send(ref, 'previous'),
          ),
        _Button(
          // The glyph says what pressing it DOES, which is the opposite of
          // what is happening. A playing session shows pause.
          icon: now.playing ? Icons.pause : Icons.play_arrow,
          theme: theme,
          onTap: () => _send(ref, now.playing ? 'pause' : 'play'),
        ),
        if (now.canSkipNext)
          _Button(
            icon: Icons.skip_next,
            theme: theme,
            onTap: () => _send(ref, 'next'),
          ),
        if (line.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontFamily: theme.typography.display,
                color: p.onDark.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One transport button. 44dp, which is the same reasoning the chips use: they
/// sit in a cluster inside a surface the user opened deliberately, so the group
/// is a far larger target than any one of them.
class _Button extends StatelessWidget {
  const _Button({
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final EffectiveTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 24, color: theme.palette.accent),
      ),
    );
  }
}
