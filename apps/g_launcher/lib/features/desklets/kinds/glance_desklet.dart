import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/launcher_prefs.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/effective_theme.dart';
import '../../../system/system_stats.dart';
import '../desklet_frame.dart';
import 'stat_desklets.dart' show thermalLabel;

/// The desktop's glance. ONE tile that IS the default desktop. PHASE D5+.
///
/// ─── WHY A COMBINED KIND AND NOT SIX SEPARATE ONES ──────────────────────────
///
/// The first thing a user sees after install should not be an empty desktop,
/// and it should not be six tiles they have to arrange either. So the default
/// starter drops exactly one thing on the right side, and that thing GROWS: its
/// contents are keyed to its own [Desklet.spanY], so dragging the resize handle
/// reveals or hides information rather than just scaling a fixed layout.
///
///   up to 2 rows   time, date
///   3 to 4         + cpu, ram          the first-install default
///   5 to 6         + network
///   7 and up       + disk, temp
///
/// Those are FINE-GRID rows; see [_tierFor], which is the one place the mapping
/// lives. Resize is already the tested engine ([DeskletLayout.resize] clamps to
/// the kind's own bounds). This widget just reads the committed span and
/// decides how many rows to draw. The tiers SNAP on release, same as every
/// other resize in the app — the tile shows its old contents mid-drag and the
/// new ones the instant you let go.
///
/// ─── THE SAME TWO RULES EVERY STAT DESKLET OBEYS ────────────────────────────
///
///   * A row that its tier has unlocked STILL disappears when the stat is null.
///     On a locked-down Galaxy where CPU is unavailable, spanY 2 shows time,
///     date and ram — cpu was never promised. No `--%`, ever.
///   * A desklet earns its place only if Android does not show it at a glance.
///     The time here is a desktop OBJECT (large, on the wallpaper), not the
///     status-bar clock; the stats are the conky numbers, not the battery
///     percentage the status bar already owns.
class GlanceDesklet extends ConsumerWidget {
  const GlanceDesklet({
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
    // The one shared minute ticker and the one shared stats snapshot. A glance
    // on every workspace costs the same one timer and one poll as a bare clock.
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();
    final s = ref.watch(systemStatsProvider).asData?.value;

    final p = theme.palette;

    // ─── SPANS ARE FINE-GRID ROWS, NOT TIERS ──────────────────────────────
    //
    // This read `desklet.spanY` AS the tier, which was true while a row was a
    // fifth of the screen: spans ran 1 to 4 and so did the tiers. The desklet
    // grid is now three times finer, so the starter tile's spanY is 3 and a
    // tall one is 12, and every stack of information unlocked at once. The tile
    // has been showing disk and temperature since the grid changed, whatever
    // size it was dragged to, which is exactly the resize-reveals-information
    // behaviour this kind exists for, inverted.
    //
    // Thresholds rather than a division, because the tiers are about how much
    // ROOM there is and the boundaries are a design decision, not arithmetic.
    final tier = _tierFor(desklet.spanY);

    final bare = skin.surface == DeskletSurface.bare;

    // The skin names a family SLOT, never a typeface — the theme owns the
    // string. Same resolution the clock desklet uses.
    final headFamily =
        skin.font == DeskletFont.mono ? theme.typography.mono : theme.typography.display;
    final mono = theme.typography.mono;

    // A drop shadow only on the bare (GNOME / Aqua) surface, where text sits
    // straight on a photograph. Card and panel surfaces have their own plate,
    // so a shadow there would be muddy. Mirrors NotesDesklet exactly.
    final shadows = bare
        ? <Shadow>[
            Shadow(
              color: p.bgBottom.withValues(alpha: 0.55),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ]
        : null;

    final rows = <Widget>[];

    void addRow(String label, String value, {bool accent = false}) {
      rows.add(_StatLine(
        label: label,
        value: value,
        mono: mono,
        onDark: p.onDark,
        accent: accent ? p.accent : null,
        shadows: shadows,
      ));
    }

    // ── tier 2: cpu, ram ──────────────────────────────────────────────────
    if (tier >= 2 && s?.cpuPercent != null) {
      addRow('cpu', '${s!.cpuPercent}%', accent: true);
    }
    if (tier >= 2 && (s?.hasMemory ?? false)) {
      addRow('mem', s!.memLabel);
    }

    // ── tier 3: network ───────────────────────────────────────────────────
    if (tier >= 3 && (s?.hasNet ?? false)) {
      addRow(
        'net',
        '\u2193 ${SystemStats.rate(s!.netDownBytesPerSec)}'
        '  \u2191 ${SystemStats.rate(s.netUpBytesPerSec)}',
      );
    }

    // ── tier 4: disk, temp ────────────────────────────────────────────────
    if (tier >= 4 && (s?.hasStorage ?? false)) {
      addRow(
        'disk',
        '${SystemStats.bytes(s!.storageUsedBytes)}'
        ' / ${SystemStats.bytes(s.storageTotalBytes)}',
      );
    }
    if (tier >= 4 && thermalLabel(s?.thermalStatus) != null) {
      addRow('temp', thermalLabel(s!.thermalStatus)!);
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatTime(now),
          style: TextStyle(
            fontFamily: headFamily,
            fontSize: skin.num_('timeSize', 40),
            fontWeight: FontWeight.values[
                (skin.num_('timeWeight', 300) ~/ 100 - 1).clamp(0, 8)],
            height: 1.0,
            letterSpacing: -1,
            color: p.onDark,
            shadows: shadows,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatDateShort(now),
          style: TextStyle(
            fontFamily: headFamily,
            fontSize: skin.num_('dateSize', 12),
            color: p.onDark.withValues(alpha: 0.75),
            shadows: shadows,
          ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...rows,
        ],
      ],
    );

    // `glances` is a real terminal monitor, so on the off chance a theme puts
    // this on the pane surface the echoed command reads honestly.
    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(command: 'glances', custom: content),
    );
  }
}

/// Which stat tier a height in fine-grid rows unlocks.
///
/// Keyed to the same numbers `DeskletKinds.glance` is bounded by: the default
/// is 3 rows and shows cpu and ram, the maximum is 12 and shows everything.
///
///   up to 2   time, date
///   3 to 4    + cpu, ram          the first-install default
///   5 to 6    + network
///   7 and up  + disk, temp
int _tierFor(int spanY) {
  if (spanY <= 2) return 1;
  if (spanY <= 4) return 2;
  if (spanY <= 6) return 3;
  return 4;
}

/// One `label   value` line, styled to sit under the time. Dim label, bright
/// value, accent when the caller asks (cpu). Kept private and local rather than
/// reaching for DeskletRow, because the frame's row renderer draws gauge bars
/// this compact tile has no room for.
class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.label,
    required this.value,
    required this.mono,
    required this.onDark,
    required this.shadows,
    this.accent,
  });

  final String label;
  final String value;
  final String? mono;
  final Color onDark;
  final Color? accent;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: mono,
                fontSize: 12,
                color: onDark.withValues(alpha: 0.55),
                shadows: shadows,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: mono,
              fontSize: 12.5,
              color: accent ?? onDark.withValues(alpha: 0.9),
              shadows: shadows,
            ),
          ),
        ],
      ),
    );
  }
}
