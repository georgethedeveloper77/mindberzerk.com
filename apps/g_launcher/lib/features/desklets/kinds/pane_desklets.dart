import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/launcher_prefs.dart';
import '../../../data/repositories/shell_apps.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/desklet_spec.dart';
import '../../../engine/effective_theme.dart';
import '../../../system/system_stats.dart';
import '../desklet_frame.dart';

/// The commands that stay on screen. PHASE D6.
///
/// ─── WHY THESE ARE DESKLETS AND NOT A CONSOLE BUFFER ────────────────────────
///
/// The obvious implementation is a list of strings appended to a scrollback.
/// It is also the wrong one: the output would be a snapshot frozen at the
/// moment you typed, so a `free -h` from four minutes ago would be a lie
/// sitting on your screen.
///
/// Making them desklets means each block is LIVE — it watches the same stats
/// provider everything else does and updates on the same three-second tick. And
/// because a desklet is a persisted placement, it survives a restart, which is
/// the D6 exit gate and would have needed its own storage otherwise.
///
/// ─── THE OUTPUT IS SHAPED LIKE THE REAL COMMAND ─────────────────────────────
///
/// `free -h` has a header row and a `Mem:` row. `df -h` has Filesystem/Size/
/// Used/Avail/Use%. Getting those shapes right is most of what makes the
/// terminal theme land, and getting them approximately right would be worse
/// than not shipping them: anyone who would enjoy this feature knows what the
/// real output looks like.

/// `free -h`
class FreeDesklet extends ConsumerWidget {
  const FreeDesklet({
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
    final s = ref.watch(systemStatsProvider).asData?.value;
    if (s == null || !s.hasMemory) {
      // NOT silence. The terminal surface still echoes `~ ❯ free -h` and prints
      // this underneath, so an unwired command and a device that will not
      // report memory are distinguishable at a glance. That distinction is the
      // whole reason emptyNote exists.
      return DeskletFrame(
        theme: theme,
        skin: skin,
        body: const DeskletBody(
          command: 'free -h',
          emptyNote: 'free: cannot read memory info',
        ),
      );
    }

    final total = s.memTotalGb!;
    final used = s.memUsedGb!;
    final avail = total - used;

    String g(double v) => '${v.toStringAsFixed(1)}Gi';

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        command: 'free -h',
        rows: [
          // The header, as a row with no value, so it inherits the label colour
          // and reads as the dimmed column titles real `free` prints.
          const DeskletRow('               total    used   avail'),
          DeskletRow(
            'Mem:',
            value: '${g(total)}  ${g(used)}  ${g(avail)}',
          ),
        ],
      ),
    );
  }
}

/// `df -h`
class DfDesklet extends ConsumerWidget {
  const DfDesklet({
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
    final s = ref.watch(systemStatsProvider).asData?.value;
    if (s == null || !s.hasStorage) {
      return DeskletFrame(
        theme: theme,
        skin: skin,
        body: const DeskletBody(
          command: 'df -h',
          emptyNote: 'df: cannot stat /data',
        ),
      );
    }

    final total = s.storageTotalBytes!;
    final used = s.storageUsedBytes!;
    final pct = total == 0 ? 0 : (used * 100 / total).round();

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        command: 'df -h',
        rows: [
          const DeskletRow('Filesystem   Size  Used  Use%  Mounted'),
          DeskletRow(
            '/dev/block',
            // The DATA partition, which is what Settings shows and what G
            // Recovery will report. Those three agreeing is worth more than
            // enumerating every mount the OS will not let us see anyway.
            value: '  ${SystemStats.bytes(total)}  '
                '${SystemStats.bytes(used)}  $pct%  /data',
            accent: pct > 90,
          ),
        ],
      ),
    );
  }
}

/// `uptime`
class UptimeDesklet extends ConsumerWidget {
  const UptimeDesklet({
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
    final s = ref.watch(systemStatsProvider).asData?.value;
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        command: 'uptime',
        emptyNote: 'uptime: no stats channel',
        rows: [
          if (s?.uptime != null)
            DeskletRow(
              ' ${formatTime(now)}',
              value: 'up ${formatUptime(s!.uptime)}',
            ),
        ],
      ),
    );
  }
}

/// `ls`
///
/// The app list as a directory listing. There is no real filesystem to walk
/// (scoped storage sees to that, and a launcher has no business asking for
/// broad file access), so listing installed apps is both the honest answer and
/// the funnier one.
class LsDesklet extends ConsumerWidget {
  const LsDesklet({
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
    final apps = ref.watch(shellAppsProvider(theme));
    final limit = DeskletKinds.appsList
        .read<num>(desklet.config, 'limit', 12)
        .toInt()
        .clamp(1, 60);

    final shown = apps.take(limit).toList();
    final p = theme.palette;

    return DeskletFrame(
      theme: theme,
      skin: skin,
      body: DeskletBody(
        command: 'ls',
        emptyNote: 'ls: app list not loaded',
        // Columns rather than one per line, because a real `ls` fills the width
        // and a 260-app phone printing one per line would be a scroll and not a
        // listing.
        custom: Wrap(
          spacing: 14,
          runSpacing: 2,
          children: [
            for (final a in shown)
              Text(
                // Lowercased, spaces stripped: it is meant to read as a
                // filename, and "Google Play Store" does not.
                a.label.toLowerCase().replaceAll(' ', '-'),
                style: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: skin.num_('rowSize', 12.5),
                  height: 1.6,
                  color: p.onDark.withValues(alpha: 0.85),
                ),
              ),
            if (apps.length > shown.length)
              Text(
                '... ${apps.length - shown.length} more',
                style: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: skin.num_('rowSize', 12.5),
                  height: 1.6,
                  color: p.onDark.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
