import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'prefs_repository.dart';

/// Has the user been through initial setup?
///
/// GLOBAL, not per-theme, and for the same reason `selectedThemeId` is: it sits
/// ABOVE the per-theme store. Putting it in [LauncherPrefs] would mean the
/// answer changed depending on which distro you were wearing — switch to KDE and
/// the launcher would decide you had never set it up.
///
/// One boolean under one key. Absent = never set up, which is exactly what a
/// fresh install reads as, so no migration is needed for existing users… except
/// that existing users HAVE effectively completed setup by using the app. See
/// [SetupNotifier.build] for how that is handled.
const _setupKey = 'setupCompleted.v1';

/// Someone already using the launcher must not be dropped into a setup wizard
/// by an update. If they have already chosen a theme, they have plainly been
/// here before, so treat that as setup done.
const _selectedThemeKeyForMigration = 'selectedThemeId.v1';

class SetupNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final store = ref.watch(prefsStoreProvider);

    final raw = await store.read(_setupKey);
    if (raw != null) return raw == 'true';

    // No flag. Either a fresh install, or an existing user updating into the
    // build that added setup. A theme selection is proof of the latter.
    final chosen = await store.read(_selectedThemeKeyForMigration);
    if (chosen != null && chosen.isNotEmpty) {
      // Write it through so the check costs nothing next time.
      await store.write(_setupKey, 'true');
      return true;
    }

    return false;
  }

  /// Optimistic, same contract as every other notifier here: state moves now,
  /// disk catches up. The app swaps from setup to the desktop on the state
  /// change, not on the write completing.
  Future<void> complete() async {
    state = const AsyncData(true);
    await ref.read(prefsStoreProvider).write(_setupKey, 'true');
  }

  /// For a "run setup again" row, and for testing on a device without a
  /// reinstall — which is the only way anyone would notice setup was broken.
  Future<void> reset() async {
    state = const AsyncData(false);
    await ref.read(prefsStoreProvider).delete(_setupKey);
  }
}

final setupCompletedProvider =
    AsyncNotifierProvider<SetupNotifier, bool>(SetupNotifier.new);

/// One-shot: "setup just finished, play the full first-run boot".
///
/// Transient by design — NOT persisted. It exists only to carry a hand-off
/// across the single rebuild where the app swaps from setup to the desktop.
/// Persisting it would mean a crash mid-boot leaves the user watching an
/// install sequence on every launch until something cleared it.
///
/// Written by [SetupScreen] immediately before completing, read and cleared by
/// `home_screen._maybeAutoBoot` on the mount that follows.
final firstRunBootPendingProvider = StateProvider<bool>((ref) => false);
