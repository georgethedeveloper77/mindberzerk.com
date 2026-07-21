import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
// `show ThemePalette` is mandatory: DockSide is declared in BOTH theme_spec.dart
// and dock_metrics.dart, and an unrestricted import is an ambiguous-import error
// that reads as if neither declaration exists.
import '../../engine/theme_spec.dart' show ThemePalette;
import 'terminal_commands.dart';

/// Builtin matches, above the app matches. PHASE D6 follow-up.
///
/// ─── THE BUG THIS EXISTS TO FIX ─────────────────────────────────────────────
///
/// Typing `settings` at the prompt showed:
///
///     launch  Settings      ↵
///
/// which is ANDROID's Settings app, found by the fuzzy matcher. Pressing enter
/// did not open it — it opened G Launcher's settings, because commands are
/// checked before apps. The screen said one thing and the key did another, and
/// the reasonable conclusion from the outside is that the launcher's own
/// settings do not exist on this theme.
///
/// A real shell has never had this problem, because a real shell distinguishes
/// builtins from binaries. `type settings` tells you which you are about to
/// run. So this row is marked `builtin`, sits above the apps, and carries the
/// `↵` — which is now true, since [TerminalCommands.resolve] is what enter
/// actually consults.
///
/// ─── AND THE DISCOVERABILITY HALF ───────────────────────────────────────────
///
/// It also answers "how would anyone know to type this". Prefix completion
/// means typing `s` surfaces `settings`, `set` surfaces it alone, and the
/// description says what enter will do. The hint line lists the vocabulary; this
/// confirms it mid-keystroke, which is the moment it matters.
class TerminalMatches extends ConsumerWidget {
  const TerminalMatches({
    super.key,
    required this.theme,
    required this.query,
  });

  final EffectiveTheme theme;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hits = TerminalCommands.matching(query);
    if (hits.isEmpty) return const SizedBox.shrink();

    final p = theme.palette;
    final mono = theme.typography.mono;

    // Only the FIRST row gets the marker, because only the first row is what
    // enter runs — and only when it resolves unambiguously. Two builtins both
    // wearing a `↵` would be the same lie in a new place.
    final enterRuns = TerminalCommands.resolve(query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < hits.length; i++)
          _Row(
            name: hits[i],
            description: TerminalCommands.describe(hits[i]),
            isTop: hits[i] == enterRuns,
            palette: p,
            mono: mono,
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    required this.description,
    required this.isTop,
    required this.palette,
    required this.mono,
  });

  final String name;
  final String description;
  final bool isTop;
  final ThemePalette palette;
  final String? mono;

  @override
  Widget build(BuildContext context) {
    final onDark = palette.onDark;
    final accent = palette.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        // The same selection wash the top app match uses, so the two lists read
        // as one ranked list rather than two competing ones.
        color: isTop ? accent.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              // The word a shell would use. `app` on the rows below is already
              // the other half of this vocabulary.
              'builtin',
              style: TextStyle(
                fontFamily: mono,
                fontSize: 11,
                color: onDark.withValues(alpha: 0.45),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontFamily: mono, fontSize: 14),
                children: [
                  TextSpan(
                    text: name,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description.isNotEmpty)
                    TextSpan(
                      text: '   $description',
                      style: TextStyle(
                        color: onDark.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isTop)
            Text(
              '\u21b5',
              style: TextStyle(fontFamily: mono, fontSize: 14, color: accent),
            ),
        ],
      ),
    );
  }
}
