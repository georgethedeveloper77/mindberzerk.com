/// The tray cluster, and the way into Quick Settings.
///
/// ─── WHY IT LEFT gnome_top_bar ──────────────────────────────────────────────
///
/// There were two trays. This one, a real 44dp button that opens the panel, and
/// a second in `plasma_shell` that was three `Icon` widgets in a Row: not
/// tappable, not removable, and not addressable by a theme. A Mint user asking
/// to drop the battery readout could not, because the readout was not a thing
/// the panel knew it had.
///
/// `PanelItem.parseAll` fixed the second case by expanding `tray` into
/// [PanelModule.wifi], [PanelModule.volume] and [PanelModule.battery] on every
/// edge but the top. What survives on a top bar is this, and a widget two
/// shells draw does not belong in a file named after one of them.
///
/// ─── IT SHOWS NO STATE, DELIBERATELY ────────────────────────────────────────
///
/// The obvious build paints a live Wi-Fi arc, a volume level and a battery
/// percentage. Two of those Android is already drawing a few pixels above a top
/// bar in its own status bar. And a launcher cannot read Wi-Fi signal strength
/// without location permission, so the arc would be a picture of a number
/// nobody measured.
///
/// So this is a BUTTON that looks like a tray, which is also what Zorin's own
/// tray is: three glyphs you press to get the panel. The state lives inside the
/// panel, where every reading in it is one the launcher genuinely owns.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../engine/theme_spec.dart' show ThemePalette;
import '../../home/quick_settings.dart';

class PanelTrayButton extends ConsumerWidget {
  const PanelTrayButton({
    super.key,
    required this.palette,
    required this.stacked,
    this.compact = false,
  });

  /// ONE GLYPH INSTEAD OF THREE.
  ///
  /// ─── THE THREE WERE THE DUPLICATION ─────────────────────────────────────
  ///
  /// A wifi glyph, a speaker glyph and a battery glyph, in that order, four
  /// pixels under Android's own wifi, speaker and battery. The doc above
  /// argues this is a BUTTON rather than a readout, and that is true of what
  /// it does and was never true of what it looked like: on a phone it read as
  /// a second status bar, because it is shaped like one.
  ///
  /// Dropping the module altogether was the alternative, and it costs the only
  /// visible way into Quick Settings on a GNOME-family bar. A single control
  /// glyph keeps the door and stops the impersonation, which is the whole
  /// trade.
  ///
  /// Set by the caller from `EffectiveTheme.statusBar`: compact while the
  /// system bar is on screen, all three when the distro has hidden it and owns
  /// the row, which is what Terminal and Pocket iOS do.
  final bool compact;

  final ThemePalette palette;

  /// True on a vertical panel, where the three glyphs run down the strip
  /// instead of across it. A `width` between stacked glyphs is a no-op and the
  /// three would have touched.
  final bool stacked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(quickSettingsProvider);
    final ink =
        open ? palette.bgBottom : palette.onDark.withValues(alpha: 0.85);

    // `tune`, not a chevron or an ellipsis: it says settings rather than
    // "more", and it is the one glyph in the set that Android's status bar
    // does not also draw.
    final glyphs = compact
        ? const [Icons.tune]
        : const [
            Icons.wifi,
            Icons.volume_up_outlined,
            Icons.battery_std_outlined,
          ];

    return Semantics(
      button: true,
      label: context.t('gestures.quickSettings'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(quickSettingsProvider.notifier).toggle(),
        child: Container(
          // 44dp on the cross axis, so the cluster is a real target rather than
          // three 16dp glyphs with dead space between them.
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.symmetric(
            horizontal: stacked ? 4 : 8,
            vertical: stacked ? 8 : 4,
          ),
          decoration: BoxDecoration(
            color: open ? palette.accent : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < glyphs.length; i++) ...[
                if (i > 0)
                  SizedBox(width: stacked ? 0 : 7, height: stacked ? 6 : 0),
                Icon(glyphs[i], size: 16, color: ink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
