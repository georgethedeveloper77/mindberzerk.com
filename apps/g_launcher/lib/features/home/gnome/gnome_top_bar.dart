import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../system/system_stats.dart';

import '../../../design/ubuntu_tokens.dart';
import '../../../engine/theme_spec.dart'
    show PanelModule, PanelSpec, ThemePalette, TopBarSide;

/// The GNOME top bar, phone-adapted.
///
/// On a real GNOME desktop this strip carries Activities (left), the clock
/// (centre) and the tray — wifi, volume, battery — (right). On a phone, the
/// clock and every one of those indicators are ALREADY on screen: they live in
/// Android's own status bar, a few pixels above this. Duplicating them here
/// would put two clocks and two battery readouts on the same screen, which is
/// the opposite of authentic.
///
/// So this bar keeps only the one thing Android does NOT provide: the
/// Activities button, the shell's way into the app drawer. Everything else is
/// deliberately gone, and the strip is transparent — the wallpaper runs edge to
/// edge and Android's status bar does the indicator job it already does well.
///
/// The "Activities" label is doing the heavy lifting: it is the GNOME tell, the
/// single most recognisable thing about the shell, so keeping it (icon + word,
/// top-left) is what makes this still read as GNOME rather than as a launcher
/// with a floating word. Losing the solid fill does not lose the identity.
///
/// Consequence worth knowing: because it no longer watches the clock or the
/// system stats, this widget effectively never rebuilds. The old version
/// repainted on every clock tick and every battery / wifi change; now it is
/// static after first layout — a small, free perf win on the budget phones this
/// app targets.
///
/// Colour is still per-theme: the Activities label takes [ThemePalette.onDark]
/// so it reads on each distro's wallpaper. The typeface and the bar height stay
/// constant — those are GNOME's shell geometry, shared across the family.
class GnomeTopBar extends ConsumerWidget {
  const GnomeTopBar({
    super.key,
    required this.palette,
    required this.onActivities,
    this.displayFontFamily,
    required this.panel,
  });

  /// What this panel is and what it carries.
  ///
  /// ─── THE MODULE LIST REPLACED A BOOLEAN ─────────────────────────────────
  ///
  /// It used to be `showStats`, which gave every distro that wanted readouts
  /// the same three in the same order forever. A waybar feels authored because
  /// its author chose which modules and in what sequence; a yes-or-no cannot
  /// express that, and Xfce could not have a second panel at all.
  ///
  /// The rule the old doc laid down still holds and is now enforced by
  /// [PanelModule] having no entries for them: no clock, no battery percentage.
  /// Android shows both a few pixels away and duplicating them is the opposite
  /// of authentic.
  final PanelSpec panel;


  /// The active theme's palette. Supplies the on-dark label colour
  /// ([ThemePalette.onDark]). There is no bar fill any more — it is transparent.
  final ThemePalette palette;
  final VoidCallback onActivities;

  /// The theme's display family. Was `Ubuntu.display`, which meant Fedora's
  /// Activities label rendered in Ubuntu's typeface — invisible in a screenshot
  /// and wrong in exactly the way this whole layer exists to prevent.
  final String? displayFontFamily;

  /// The panel's modules, in the order the theme wrote them.
  ///
  /// A [PanelModule.spacer] becomes a real [Spacer], which is what lets a
  /// distro say "Activities at this end, readouts at the other" or pack
  /// everything tight against one edge. The old bar hardcoded that Spacer, so
  /// there was only ever one arrangement.
  ///
  /// The readouts are ONE widget rather than one per module, because they share
  /// a single stats snapshot and splitting them would mean three subscriptions
  /// to the same stream. It is drawn at the position of the FIRST readout in
  /// the list and skipped at the others, so a theme still controls where in the
  /// run they appear.
  List<Widget> _modules({required bool stacked}) {
    final stats = panel.modules
        .where((m) =>
            m == PanelModule.network ||
            m == PanelModule.memory ||
            m == PanelModule.storage)
        .toList();

    return [
      for (final m in panel.modules)
        switch (m) {
          PanelModule.activities => _Activities(
              onTap: onActivities,
              color: palette.onDark,
              fontFamily: displayFontFamily,
              // Glyph only on a vertical panel: the word does not fit in 40dp
              // and setting it sideways would be the one thing on screen a
              // person has to tilt their head for.
              compact: stacked,
            ),
          PanelModule.spacer => const Spacer(),

          // The three readouts share one widget and one stats subscription, so
          // it is drawn at the FIRST of them in the theme's order and skipped
          // at the others. `stats.first` cannot throw here: reaching this arm
          // means `m` is one of the three, so `stats` contains at least `m`.
          PanelModule.network ||
          PanelModule.memory ||
          PanelModule.storage =>
            m == stats.first
                ? _Modules(
                    palette: palette,
                    fontFamily: displayFontFamily,
                    stacked: stacked,
                    show: stats,
                  )
                : const SizedBox.shrink(),

          // ─── EXPLICIT, WHERE A `_` USED TO BE ────────────────────────────
          //
          // This arm was `_ =>`, and that catch-all is why growing the enum for
          // the Plasma panel was safe in the worst sense: five new modules
          // compiled cleanly and rendered NOTHING here, silently, which is
          // indistinguishable from the modules being broken.
          //
          // `DockSide` states the rule this file was quietly opted out of: an
          // enum grows, the compiler lists every site that decides, and each
          // one answers on purpose. Now it does. A sixth module added tomorrow
          // will not compile until this bar says what it does with it.
          //
          // And what it does is nothing, deliberately. This is GNOME's bar. A
          // task strip on it would be a Windows taskbar, and a kickoff button
          // would be a start menu. A theme listing them here has authored
          // something GNOME is not, so the bar declines rather than obliging.
          PanelModule.kickoff ||
          PanelModule.tasks ||
          PanelModule.pager ||
          PanelModule.tray ||
          PanelModule.clock =>
            const SizedBox.shrink(),
        },
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The bar clears the system inset on whichever edge it is on: the notch and
    // status-bar row at the top, the gesture pill at the bottom. Activities is a
    // real tap target and cannot sit under either.
    final insets = MediaQuery.viewPaddingOf(context);

    // ─── VERTICAL IS A STACK, NOT A ROTATION ──────────────────────────────
    //
    // A rotated bar reads sideways and nothing on a phone does that. A polybar
    // down an edge stacks its modules and drops its labels, which is the same
    // decision this makes: the word "Activities" goes, the glyph stays, and the
    // readouts sit one above another at the far end.
    if (panel.side.isVertical) {
      // The edge inset it must clear is the one it is ON. A left bar under the
      // curved corner of a display loses its top glyph otherwise.
      final lead = panel.side == TopBarSide.left ? insets.left : insets.right;

      return SizedBox(
        width: _verticalWidth + lead, // theme-exempt: shell geometry, not a palette value
        child: Padding(
          padding: EdgeInsets.only(
            left: panel.side == TopBarSide.left ? lead : 0,
            right: panel.side == TopBarSide.right ? lead : 0,
            top: insets.top + 10,
            bottom: insets.bottom + 10,
          ),
          child: Column(
            children: [
              ..._modules(stacked: true),
            ],
          ),
        ),
      );
    }

    final atBottom = panel.side == TopBarSide.bottom;
    final inset = atBottom ? insets.bottom : insets.top;

    return SizedBox(
      height: Ubuntu.topBarHeight + inset, // theme-exempt: GNOME shell geometry, shared across the family, not a palette value
      child: Padding(
        padding: EdgeInsets.only(
          top: atBottom ? 0 : inset,
          bottom: atBottom ? inset : 0,
          left: 15,
          right: 15,
        ),
        child: Row(
          children: [
            ..._modules(stacked: false),
          ],
        ),
      ),
    );
  }
}

class _Activities extends StatelessWidget {
  const _Activities({
    required this.onTap,
    required this.color,
    this.fontFamily,
    this.compact = false,
  });

  /// Glyph without the word. A vertical bar is 40dp wide; "Activities" does not
  /// fit in it, and setting it sideways would be the one thing on screen a
  /// person has to tilt their head to read.
  final bool compact;

  final VoidCallback onTap;
  final String? fontFamily;

  /// On-dark foreground colour, from the theme palette.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Activities',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: compact
            ? Icon(Icons.grid_view_rounded, size: 17, color: color)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, size: 13, color: color),
                  const SizedBox(width: 6),
                  Text(
                    'Activities',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}


/// The readouts, right-aligned, mono, quiet.
///
/// Reads the SAME snapshot every desklet does, so a bar and a conky on the same
/// screen cost one poll between them and can never disagree.
///
/// A missing stat REMOVES ITS MODULE rather than printing a placeholder, which
/// is the rule every stat surface in this app follows: on a device that will
/// not report memory the bar shows throughput and storage, and the third was
/// never promised.
/// How wide a vertical bar is. Wide enough for the Activities glyph and a
/// short readout, narrow enough that it costs the desktop about one column of
/// the desklet grid rather than two.
const double _verticalWidth = 40;

class _Modules extends ConsumerWidget {
  const _Modules({
    required this.palette,
    required this.fontFamily,
    this.stacked = false,
    this.show = const [],
  });

  /// One module per line, for a vertical bar.
  final bool stacked;

  /// Which readouts this panel asked for, in the theme's order. Empty means the
  /// caller filtered nothing out, which only happens from a legacy path.
  final List<PanelModule> show;

  final ThemePalette palette;
  final String? fontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemStatsProvider);
    final s = async.hasValue ? async.requireValue : null;
    if (s == null) return const SizedBox.shrink();

    // The theme's order, not this file's. A distro that lists storage before
    // network gets storage before network; the old bar had one fixed sequence
    // baked into the literal below.
    final wanted = show.isEmpty
        ? const [PanelModule.network, PanelModule.memory, PanelModule.storage]
        : show;

    String? render(PanelModule m) => switch (m) {
          PanelModule.network when s.hasNet =>
            '\u2193 ${SystemStats.rate(s.netDownBytesPerSec)}'
                '${stacked ? '\n' : '  '}'
                '\u2191 ${SystemStats.rate(s.netUpBytesPerSec)}',
          PanelModule.memory when s.hasMemory => s.memLabel,
          PanelModule.storage when s.hasStorage =>
            SystemStats.bytes(s.storageTotalBytes! - s.storageUsedBytes!),
          // A stat this device will not report REMOVES its module rather than
          // printing a placeholder, which is the rule every stat surface in
          // this app follows.
          _ => null,
        };

    final parts = <String>[
      for (final m in wanted)
        if (render(m) case final t?) t,
    ];

    if (parts.isEmpty) return const SizedBox.shrink();

    final style = TextStyle(
      fontFamily: fontFamily,
      // A vertical bar is 40dp wide, so the readouts drop a point to fit
      // "4.6/7G" without ellipsising the number that matters.
      fontSize: stacked ? 9 : 11,
      color: palette.onDark.withValues(alpha: 0.75),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                p,
                textAlign: TextAlign.center,
                // TWO lines, because the network module is a down and an up
                // reading and a 40dp column cannot hold both side by side. The
                // horizontal bar keeps them on one line where there is room.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
        ],
      );
    }

    return Text(
      parts.join('   '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
