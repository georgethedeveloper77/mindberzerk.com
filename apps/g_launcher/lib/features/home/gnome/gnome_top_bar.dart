import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../system/system_stats.dart';
import '../quick_settings.dart';

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
          // ─── STILL DECLINED, AND FOR THE ORIGINAL REASON ────────────────
          //
          // Kickoff is Plasma's start menu and a pager is Plasma's desktop
          // switcher. Neither belongs on any GNOME-family panel, top edge or
          // bottom, so these two decline everywhere rather than on an edge
          // test.
          PanelModule.kickoff || PanelModule.pager => const SizedBox.shrink(),

          // ─── DECLINED FOR A DIFFERENT REASON: THERE IS NO SOURCE ────────
          //
          // A task strip lists what is RUNNING, and nothing in the Pigeon
          // surface reports that. `AppEntry` is an installed app,
          // `frequentAppsProvider` is a frecency ranking, and neither answers
          // the question. Drawing the most-used apps here and calling it Tasks
          // would be a dock wearing a taskbar's label, and the running
          // indicator under each tile would be decoration that means nothing.
          //
          // So this stays empty until there is something true to draw, which
          // needs a `UsageStatsManager` reader on the native side. A distro
          // authoring `tasks` gets a gap rather than a lie.
          PanelModule.tasks => const SizedBox.shrink(),

          // ─── ON ANY EDGE, AND THE MODULE LIST IS THE OPT-IN ─────────────
          //
          // These two were refused outright, then refused on the TOP edge
          // only, and both rules were wrong for the same reason.
          //
          // The original argument was duplication: Android's clock sits four
          // pixels above a top bar. True, and it was decisive while the tray
          // was decoration. It stopped being decisive when the tray became the
          // way into Quick Settings, which is a control Android's own status
          // bar cannot reach.
          //
          // The edge rule that replaced it broke Pop!_OS, whose top bar
          // authors a centred clock and a tray on the right, which is what
          // GNOME's top bar actually IS. It drew an Activities button, a gap,
          // a network readout and a second gap, while the pack's feature row
          // described the bar it was not getting.
          //
          // The rule was in the theme all along: a distro that does not want a
          // clock on its bar DOES NOT AUTHOR ONE. Refusing it for the distros
          // that do was this file overriding the author. Ubuntu, KDE and every
          // other pack that never listed these are untouched, because they
          // never asked.
          PanelModule.tray => _Tray(palette: palette, stacked: stacked),
          PanelModule.clock => _OpensQuickSettings(
              label: 'Quick settings',
              child: _Clock(
                palette: palette,
                fontFamily: displayFontFamily,
                stacked: stacked,
              ),
            ),
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

/// Anything in the panel that opens Quick Settings.
///
/// ─── WHY THE CLOCK OPENS IT TOO ─────────────────────────────────────────────
///
/// Every desktop this launcher imitates puts the calendar behind the clock and
/// the indicators behind the tray, and a phone user coming from Android has the
/// same habit from the status bar. Making only the tray live means the right
/// half of the panel is half live and half dead, and which half is which is
/// invisible until you have tapped both.
///
/// The whole cluster is 44dp tall either way, so this costs nothing and closes
/// the gap between them: tray, clock, or the space they sit in.
class _OpensQuickSettings extends ConsumerWidget {
  const _OpensQuickSettings({required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(quickSettingsProvider.notifier).toggle(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// The tray cluster, and the way into Quick Settings.
///
/// ─── IT SHOWS NO STATE, DELIBERATELY ────────────────────────────────────────
///
/// The obvious build paints a live Wi-Fi arc, a volume level and a battery
/// percentage. Two of those Android is already drawing a few pixels away in its
/// own status bar, which is the argument this file's header makes for the top
/// bar and which does not stop being true lower down the screen. And a launcher
/// cannot read Wi-Fi signal strength without location permission, so the arc
/// would be a picture of a number nobody measured.
///
/// So this is a BUTTON that looks like a tray, which is also what Zorin's own
/// tray is: three glyphs you press to get the panel. The state lives inside the
/// panel, where every reading in it is one the launcher genuinely owns.
class _Tray extends ConsumerWidget {
  const _Tray({required this.palette, required this.stacked});

  final ThemePalette palette;
  final bool stacked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(quickSettingsProvider);
    final ink = open ? palette.bgBottom : palette.onDark.withValues(alpha: 0.85);

    final glyphs = [
      Icons.wifi,
      Icons.volume_up_outlined,
      Icons.battery_std_outlined,
    ];

    return Semantics(
      button: true,
      label: 'Quick settings',
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
                if (i > 0) SizedBox(width: stacked ? 0 : 7, height: stacked ? 6 : 0),
                Icon(glyphs[i], size: 16, color: ink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The panel clock.
///
/// ─── AND WHY THIS ONE IS ALLOWED TO DUPLICATE ANDROID'S ─────────────────────
///
/// The header argues that a second clock on the top bar is the opposite of
/// authentic, and it is: Android's own is four pixels above it. A BOTTOM panel
/// is the other end of the screen, and every desktop that puts its panel down
/// there puts a clock on it. Reading the time at the bottom right is the single
/// most practised habit a Windows or Zorin user has, and the status bar being
/// 700dp away does not serve it.
///
/// So the rule is the same one the modules follow: on top it declines, on any
/// other edge it draws.
class _Clock extends StatefulWidget {
  const _Clock({
    required this.palette,
    required this.stacked,
    this.fontFamily,
  });

  final ThemePalette palette;
  final bool stacked;
  final String? fontFamily;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _tick;
  late DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Aligned to the next MINUTE, not a 60s repeat from mount. A repeating
    // timer started at 9:41:47 flips the display at 47 seconds past every
    // minute, so the clock is wrong for most of each minute by up to a minute.
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute)
        .add(const Duration(minutes: 1));
    _tick = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 24-hour or 12-hour follows the DEVICE, via MediaQuery, rather than a
    // setting of our own. Someone who has set their phone to 24-hour has
    // already answered this question and should not be asked twice.
    final t = TimeOfDay.fromDateTime(_now);
    final label = MediaQuery.alwaysUse24HourFormatOf(context)
        ? '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}'
        : t.format(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.stacked ? 2 : 8,
        vertical: widget.stacked ? 6 : 0,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: widget.fontFamily,
          // A vertical panel is 40dp wide and "10:35 pm" does not fit, so the
          // stacked case drops a point the way the readouts above do.
          fontSize: widget.stacked ? 10 : 13,
          color: widget.palette.onDark,
        ),
      ),
    );
  }
}
