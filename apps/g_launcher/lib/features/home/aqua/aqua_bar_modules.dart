import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/theme_mark.dart';
import '../../../engine/theme_source.dart';
import '../../../engine/theme_spec.dart' show PanelModule, ThemePalette;
import '../../../system/system_stats.dart';

/// Build an aqua bar's run from the modules its distro authored.
///
/// ─── A MIRROR OF GnomeTopBar._modules, DELIBERATELY ─────────────────────────
///
/// The three readouts share ONE widget and one stats subscription, drawn at the
/// position of the first of them in the theme's order and skipped at the others.
/// That is not an optimisation invented here; it is the rule `gnome_top_bar`
/// already states, and splitting them would mean three subscriptions to the
/// same stream on a shell that already blurs a photograph twice a frame.
///
/// Kept as a function in its own file rather than a method on the bar, because
/// the bar is a `StatelessWidget` and the readouts need a `ref`. A private
/// method would have forced the whole strip to become a Consumer, which would
/// rebuild the blur on every stats tick.
///
/// ─── AND EVERY ARM IS EXPLICIT ──────────────────────────────────────────────
///
/// No `_ =>`. `gnome_top_bar` says why at length: a catch-all is what made
/// growing the enum for the Plasma panel safe in the worst sense, because five
/// new modules compiled cleanly and rendered nothing, which is
/// indistinguishable from being broken.
List<Widget> aquaBarModules(
  List<PanelModule> modules, {
  required ThemePalette palette,
  required String? displayFontFamily,
  required ThemeAsset? logo,
  required String title,
  required VoidCallback onActivities,
}) {
  final stats = modules
      .where((m) =>
          m == PanelModule.network ||
          m == PanelModule.memory ||
          m == PanelModule.storage)
      .toList();

  return [
    for (final m in modules)
      switch (m) {
        // The distro's own mark and name, opening the launcher. On elementary
        // this is the word Applications, which is what Pantheon calls it, and
        // it comes from the theme rather than from a constant so a second aqua
        // distro is still a data change.
        PanelModule.activities => _MarkAndTitle(
            logo: logo,
            title: title,
            onDark: palette.onDark,
            displayFontFamily: displayFontFamily,
            onTap: onActivities,
          ),
        PanelModule.spacer => const Spacer(),

        PanelModule.clock => _Clock(
            palette: palette,
            fontFamily: displayFontFamily,
          ),

        PanelModule.network || PanelModule.memory || PanelModule.storage =>
          m == stats.first
              ? _Readouts(
                  palette: palette,
                  fontFamily: displayFontFamily,
                  show: stats,
                )
              : const SizedBox.shrink(),

        // A wingpanel has no application menu, no window-button strip, no tray
        // and no workspace pager. Authoring one is dropped rather than fatal,
        // the same contract `PanelModule.parse` keeps, and it is explicit here
        // so a new module cannot arrive silently.
        PanelModule.kickoff ||
        PanelModule.tasks ||
        PanelModule.tray ||
        PanelModule.pager =>
          const SizedBox.shrink(),
      },
  ];
}

/// The clock, in the middle of a wingpanel.
///
/// ─── AND YES, ANDROID ALREADY HAS ONE ───────────────────────────────────────
///
/// `AquaMenuBar`'s doc argues that the clock and the status indicators already
/// live in Android's status bar a few pixels above, so duplicating them would
/// put two clocks on one screen. That is right for a Mac, whose clock sits at
/// the far right exactly where Android's does.
///
/// Pantheon's does not. It is CENTRED, and the centre of the bar is empty on
/// every phone, so the two do not collide and the centred clock is one of the
/// two things that make a wingpanel screenshot recognisable. A distro only gets
/// it by asking for `clock` in its modules, so the Mac arrangement is unchanged.
class _Clock extends ConsumerWidget {
  const _Clock({required this.palette, required this.fontFamily});

  final ThemePalette palette;
  final String? fontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The exact form `_Waybar` uses. `clockProvider` is an AsyncValue, so the
    // first frame before it resolves falls back to now rather than drawing an
    // empty strip where a time should be.
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();

    return Text(
      formatTime(now),
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: palette.onDark.withValues(alpha: 0.9),
      ),
    );
  }
}

/// The readouts, sharing one stats subscription. See [aquaBarModules].
class _Readouts extends ConsumerWidget {
  const _Readouts({
    required this.palette,
    required this.fontFamily,
    required this.show,
  });

  final ThemePalette palette;
  final String? fontFamily;
  final List<PanelModule> show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemStatsProvider);
    final s = async.hasValue ? async.requireValue : null;
    if (s == null) return const SizedBox.shrink();

    // The same expressions `gnome_top_bar._Modules` renders, so the two bars
    // cannot disagree about what "storage" means. A stat this device will not
    // report REMOVES its module rather than printing a placeholder, which is
    // the rule every stat surface in this app follows.
    String? render(PanelModule m) => switch (m) {
          PanelModule.network when s.hasNet =>
            '\u2193 ${SystemStats.rate(s.netDownBytesPerSec)}'
                '  \u2191 ${SystemStats.rate(s.netUpBytesPerSec)}',
          PanelModule.memory when s.hasMemory => s.memLabel,
          PanelModule.storage when s.hasStorage =>
            SystemStats.bytes(s.storageTotalBytes! - s.storageUsedBytes!),
          _ => null,
        };

    final parts = <String>[
      for (final m in show)
        if (render(m) case final t?) t,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('  '),
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        color: palette.onDark.withValues(alpha: 0.72),
      ),
    );
  }
}

/// The mark and the title, lifted so the module run can place it.
///
/// A copy of the one in `aqua_menu_bar.dart` rather than an import, because
/// that one is private to a file this must not import back into. The pair is
/// eight lines and the alternative is making a private widget public purely to
/// share it, which would put a widget nobody else should build in the public
/// surface of that file.
class _MarkAndTitle extends StatelessWidget {
  const _MarkAndTitle({
    required this.logo,
    required this.title,
    required this.onDark,
    required this.displayFontFamily,
    required this.onTap,
  });

  final ThemeAsset? logo;
  final String title;
  final Color onDark;
  final String? displayFontFamily;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // `tint: null` and a neutral fallback, exactly as
            // `aqua_menu_bar` argues: a coloured mark goes muddy on frosted
            // glass, and the fallback is a desktop glyph rather than a fruit.
            ThemeMark(
              asset: logo,
              size: 14,
              tint: null,
              fallback: Icon(Icons.blur_on, size: 14, color: onDark),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontFamily: displayFontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: onDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
