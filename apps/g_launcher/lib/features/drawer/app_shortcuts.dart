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

    return Padding(
      // Indented to the label, not to the row. The chips belong to the name
      // above them, and starting them under the icon would read as a second
      // column rather than as this app's own actions.
      padding: const EdgeInsets.fromLTRB(64, 2, 16, 14),
      child: shortcuts == null
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
                ),
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
