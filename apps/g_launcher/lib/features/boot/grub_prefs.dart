import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/prefs_repository.dart';

/// Whether the GRUB distro picker greets a cold start, and how long it waits.
///
/// Off by default: a launcher that adds five seconds to every reboot without
/// being asked is a launcher that gets uninstalled. The people who want it
/// will find it next to Verbose boot, which is where they already are.
///
/// Its own key, outside `prefs.`, because it is launcher-wide (it chooses
/// BETWEEN distros, so it cannot belong to one) and has never lived per theme.
class GrubPrefs {
  const GrubPrefs({
    this.enabled = false,
    this.timeoutSec = 5,
    this.shownForBootAtMs,
  });

  final bool enabled;

  /// `GRUB_TIMEOUT`. 0 waits for a tap, the way `GRUB_TIMEOUT=-1` does.
  final int timeoutSec;

  /// When the phone last booted, for the boot the menu was last shown on.
  ///
  /// ─── ONCE PER REAL REBOOT, NOT PER PROCESS ───────────────────────────────
  ///
  /// Budget phones kill a backgrounded launcher constantly, and each restart
  /// is a "cold start" to Flutter. Showing GRUB on those would put a boot
  /// menu in front of someone who only pressed Home. Boot time (now minus
  /// elapsedRealtime) is the same for every process within one boot of the
  /// phone, so the menu shows once after a real reboot and never otherwise.
  final int? shownForBootAtMs;

  static const timeouts = <int>[3, 5, 10, 0];

  /// Two boot-time readings closer than this are the same boot: the clock
  /// and elapsedRealtime are read a few milliseconds apart.
  static const _sameBootSlackMs = 120000;

  bool alreadyShownFor(int bootAtMs) =>
      shownForBootAtMs != null &&
      (shownForBootAtMs! - bootAtMs).abs() < _sameBootSlackMs;

  GrubPrefs copyWith({bool? enabled, int? timeoutSec, int? shownForBootAtMs}) =>
      GrubPrefs(
        enabled: enabled ?? this.enabled,
        timeoutSec: timeoutSec ?? this.timeoutSec,
        shownForBootAtMs: shownForBootAtMs ?? this.shownForBootAtMs,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'timeout': timeoutSec,
        if (shownForBootAtMs != null) 'shownForBootAt': shownForBootAtMs,
      };

  static GrubPrefs fromJson(Map<String, dynamic> j) => GrubPrefs(
        enabled: j['enabled'] == true,
        timeoutSec: (j['timeout'] as num?)?.toInt() ?? 5,
        shownForBootAtMs: (j['shownForBootAt'] as num?)?.toInt(),
      );
}

class GrubPrefsNotifier extends AsyncNotifier<GrubPrefs> {
  static const storageKey = 'grub.v1';

  @override
  Future<GrubPrefs> build() async {
    final raw = await ref.watch(prefsStoreProvider).read(storageKey);
    if (raw == null) return const GrubPrefs();
    try {
      return GrubPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const GrubPrefs();
    }
  }

  Future<void> set(GrubPrefs next) async {
    state = AsyncData(next);
    await ref
        .read(prefsStoreProvider)
        .write(storageKey, jsonEncode(next.toJson()));
  }
}

final grubPrefsProvider =
    AsyncNotifierProvider<GrubPrefsNotifier, GrubPrefs>(GrubPrefsNotifier.new);
