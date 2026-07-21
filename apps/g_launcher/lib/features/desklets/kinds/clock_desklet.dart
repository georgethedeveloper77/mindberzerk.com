import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/launcher_prefs.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/desklet_spec.dart';
import '../../../engine/effective_theme.dart';
import '../../../system/system_stats.dart';

/// The clock. ONE widget, five desktops. PHASE D3.
///
/// The proof of the skin layer, and the reason it was built first: nothing in
/// this file knows what distro it is on. It reads a [DeskletSkin] and a
/// [ThemePalette] and draws what they say. Ubuntu's enormous hairline face,
/// Breeze's card, the waybar module, Aqua's thin Dashboard clock and the
/// terminal's `date` output are all the same 200 lines.
///
/// If a sixth desktop needs a branch in here, the skin model is missing a
/// field — add the field, not the branch.
///
/// ─── WHY A CLOCK IS A DESKLET AT ALL ────────────────────────────────────────
///
/// Android's status bar already shows the time, which is exactly why the
/// launcher's own top bar is transparent and carries nothing. A desklet earns
/// its place only if it is not one glance away, so this is NOT a status
/// readout: it is a desktop OBJECT, the thing a Linux desktop puts on the
/// wallpaper at 56px because it can. Different job, different size, no
/// duplication.
class ClockDesklet extends ConsumerWidget {
  const ClockDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The one shared minute-aligned ticker. Every clock on every workspace
    // watches the same provider, so five clocks cost one timer.
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();

    const kind = DeskletKinds.clock;
    final config = desklet.config;

    final twelve = kind.read<String>(config, 'format', '24h') == '12h';
    final seconds = kind.read<bool>(config, 'showSeconds', false);

    // The USER's config wins over the SKIN's, and the skin wins over nothing.
    // Same merge order as everywhere else in the app: distro provides the
    // default, the person always beats it.
    final showDate = config.containsKey('showDate')
        ? kind.read<bool>(config, 'showDate', true)
        : skin.flag('showDate', true);

    final time = _formatTime(now, twelve: twelve, seconds: seconds);
    final date = formatDateLong(now);

    return switch (skin.surface) {
      DeskletSurface.terminal =>
        _Terminal(theme: theme, skin: skin, time: time, date: date, show: showDate),
      DeskletSurface.panel =>
        _Panel(theme: theme, skin: skin, time: time, now: now, show: showDate),
      DeskletSurface.card =>
        _Card(theme: theme, skin: skin, time: time, date: date, show: showDate),
      DeskletSurface.bare =>
        _Bare(theme: theme, skin: skin, time: time, date: date, show: showDate),
    };
  }

  /// Local rather than `formatTime`, because that one is 24-hour by contract
  /// (it feeds the GNOME top bar and the waybar, both of which want exactly
  /// that) and a desklet is the one place a 12-hour preference is meaningful.
  static String _formatTime(
    DateTime t, {
    required bool twelve,
    required bool seconds,
  }) {
    final h24 = t.hour;
    final h = twelve ? (h24 % 12 == 0 ? 12 : h24 % 12) : h24;
    final hh = twelve ? '$h' : h.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final base = seconds
        ? '$hh:$mm:${t.second.toString().padLeft(2, '0')}'
        : '$hh:$mm';
    return twelve ? '$base ${h24 < 12 ? 'AM' : 'PM'}' : base;
  }
}

/// Resolve the skin's font choice to the THEME's family. A desklet never names
/// a typeface; `no_constants.sh` would fail it if it tried, and rightly.
String? _family(EffectiveTheme t, DeskletSkin s) =>
    s.font == DeskletFont.mono ? t.typography.mono : t.typography.display;

// ─────────────────────────────────────────────────────────────────────────────
// GNOME / Aqua: no chrome. Text on the wallpaper.
// ─────────────────────────────────────────────────────────────────────────────

class _Bare extends StatelessWidget {
  const _Bare({
    required this.theme,
    required this.skin,
    required this.time,
    required this.date,
    required this.show,
  });

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final String time;
  final String date;
  final bool show;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final ink = skin.accent ? p.accent : p.onDark;

    // A drop shadow, not a scrim. Bare text has to survive a light wallpaper,
    // and a translucent plate behind it would make this the card skin with
    // extra steps.
    final shadows = <Shadow>[
      Shadow(
        color: p.bgBottom.withValues(alpha: 0.55),
        blurRadius: 12,
        offset: const Offset(0, 2),
      ),
    ];

    final dateWidget = Text(
      date,
      style: TextStyle(
        fontFamily: _family(theme, skin),
        fontSize: skin.num_('dateSize', 13),
        color: ink.withValues(alpha: 0.78),
        letterSpacing: 0.4,
        shadows: shadows,
      ),
    );

    final timeWidget = Text(
      time,
      style: TextStyle(
        fontFamily: _family(theme, skin),
        fontSize: skin.num_('timeSize', 56),
        // A hairline weight is most of what makes a GNOME clock read as GNOME,
        // and it only exists because the Ubuntu family ships a Light face.
        fontWeight: FontWeight.values[
            (skin.num_('timeWeight', 200) ~/ 100 - 1).clamp(0, 8)],
        color: ink,
        height: 1.0,
        letterSpacing: skin.num_('letterSpacing', -2),
        shadows: shadows,
      ),
    );

    // Aqua puts the date ABOVE the time; GNOME puts it below. One flag rather
    // than two skins, because it is genuinely the only structural difference
    // between those two desktops' clocks.
    final above = skin.flag('dateAbove', false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (show && above) ...[dateWidget, const SizedBox(height: 2)],
        timeWidget,
        if (show && !above) ...[const SizedBox(height: 4), dateWidget],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plasma: a Breeze card.
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.theme,
    required this.skin,
    required this.time,
    required this.date,
    required this.show,
  });

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final String time;
  final String date;
  final bool show;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final ink = skin.accent ? p.accent : p.onDark;

    return DecoratedBox(
      decoration: BoxDecoration(
        // The theme's bar colour, not a grey: a Breeze card matches the panel
        // it belongs to, and Ubuntu's card should look like Ubuntu's chrome.
        color: p.bar.withValues(alpha: skin.num_('opacity', 0.72)),
        borderRadius: BorderRadius.circular(skin.num_('radius', 10)),
        border: Border.all(color: p.onDark.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time,
              style: TextStyle(
                fontFamily: _family(theme, skin),
                fontSize: skin.num_('timeSize', 34),
                fontWeight: FontWeight.values[
                    (skin.num_('timeWeight', 500) ~/ 100 - 1).clamp(0, 8)],
                color: ink,
                height: 1.0,
              ),
            ),
            if (show) ...[
              const SizedBox(height: 3),
              Text(
                date,
                style: TextStyle(
                  fontFamily: _family(theme, skin),
                  fontSize: skin.num_('dateSize', 12),
                  color: p.onDark.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tiling: a waybar module that happens to sit on the desktop.
// ─────────────────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.theme,
    required this.skin,
    required this.time,
    required this.now,
    required this.show,
  });

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final String time;
  final DateTime now;
  final bool show;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final mono = theme.typography.mono;

    // waybar collapses date and time onto one line; it has one row to work
    // with and no interest in a second.
    final label = show ? '${formatDateShort(now)}  $time' : time;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bar.withValues(alpha: skin.num_('opacity', 0.9)),
        borderRadius: BorderRadius.circular(skin.num_('radius', 4)),
        border: Border(
          // The accent edge is the module marker: every waybar module is a flat
          // block distinguished by one coloured border, never by a shape.
          left: BorderSide(color: p.accent, width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: mono,
              fontSize: skin.num_('timeSize', 18),
              fontWeight: FontWeight.values[
                  (skin.num_('timeWeight', 700) ~/ 100 - 1).clamp(0, 8)],
              color: skin.accent ? p.accent : p.onDark,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TUI: not a clock widget. A command and its output.
// ─────────────────────────────────────────────────────────────────────────────

class _Terminal extends StatelessWidget {
  const _Terminal({
    required this.theme,
    required this.skin,
    required this.time,
    required this.date,
    required this.show,
  });

  final EffectiveTheme theme;
  final DeskletSkin skin;
  final String time;
  final String date;
  final bool show;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final mono = theme.typography.mono;
    final size = skin.num_('timeSize', 13);

    // The whole reason the terminal shell needed its own SURFACE rather than
    // its own skin: this is not a card with different paint, it is a different
    // object. The command you typed is still above the output, because that is
    // what a scrollback looks like and it is the only honest rendering.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontFamily: mono, fontSize: size, height: 1.6),
            children: [
              TextSpan(
                text: '~ \u276f ',
                style: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: skin.text('command', 'date'),
                style: TextStyle(color: p.onDark.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
        Text(
          show ? '$date  $time' : time,
          style: TextStyle(
            fontFamily: mono,
            fontSize: size,
            height: 1.6,
            color: p.onDark,
          ),
        ),
      ],
    );
  }
}
