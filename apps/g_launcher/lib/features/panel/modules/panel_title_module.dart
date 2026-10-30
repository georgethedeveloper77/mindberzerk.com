/// Plasma's window title applet, on a phone.
///
/// ─── THE WORKSPACE, BECAUSE THERE IS NO WINDOW ─────────────────────────────
///
/// Garuda's top panel names the focused window next to the launcher. A phone
/// home screen has no focused window, but it does have a place you are: the
/// workspace. So the slot keeps its job, saying where you are, and the top bar
/// keeps the shape the desktop has instead of a logo and a button 300dp apart.
///
/// Text only and not a target. The pager and the page dots already move
/// between workspaces, and a third control for the same thing would be one
/// more thing to hit by accident on a bar under the thumb's reach.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../engine/effective_theme.dart';
import '../../home/workspaces/workspace_controller.dart';

class PanelTitleModule extends ConsumerWidget {
  const PanelTitleModule({
    super.key,
    required this.theme,
    required this.vertical,
  });

  final EffectiveTheme theme;

  /// A vertical panel is about 40dp wide, which no workspace name fits. It
  /// draws nothing there rather than a name set sideways.
  final bool vertical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (vertical) return const SizedBox.shrink();
    final active = ref.watch(activeWorkspaceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        context.t('home.workspaceN', {'n': '${active + 1}'}),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: theme.typography.display,
          fontSize: 13 * theme.textScale,
          fontWeight: FontWeight.w500,
          color: theme.palette.onDark.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
