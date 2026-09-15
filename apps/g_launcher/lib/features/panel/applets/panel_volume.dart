/// Sound, as a panel chip that opens the sound settings screen.
///
/// ─── WHY THERE IS NO SLIDER HERE ────────────────────────────────────────────
///
/// A panel that sets the volume needs `AudioManager` over the platform bridge,
/// and `quick_settings.dart` already states the cost: the Pigeon codec's field
/// ordering is load-bearing, so volume is a bridge change with its own review
/// rather than something to add beside a parse fix. It is named there as the
/// first thing to add to that panel, and this applet is where the slider lands
/// when it does.
///
/// Until then this is the glyph and the route, which is the same trade the
/// network applet makes and for the same reason: a launcher can open the screen
/// it cannot control. It is still strictly better than what it replaced, which
/// was this glyph drawn inside a tray that did nothing when tapped.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../engine/effective_theme.dart';
import 'panel_applet_menu.dart';

const _soundSettings = 'android.settings.SOUND_SETTINGS';

void showVolumeMenu(BuildContext context, WidgetRef ref) {
  showAppletMenu(
    context: context,
    title: context.t('shell.moduleVolume'),
    rows: (menu) => [
      // ONE ROW. There were two above this one saying that Android owns the
      // volume and that this opens the screen which sets it, which is the same
      // sentence twice and neither is a reading. Until the `AudioManager` call
      // exists there is nothing to report, and a popover with nothing to report
      // should be the route and no more.
      androidSettingsRow(
        menuContext: menu,
        title: menu.t('shell.soundSettings'),
        action: _soundSettings,
        open: ref.read(launcherHostApiProvider).openAndroidSettings,
      ),
    ],
  );
}

class PanelVolumeModule extends ConsumerWidget {
  const PanelVolumeModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(effectiveThemeProvider).value;
    if (theme == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => showVolumeMenu(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Icon(
          Icons.volume_up_outlined,
          size: 13,
          color: theme.palette.onDark,
        ),
      ),
    );
  }
}
