import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/launcher_api.g.dart';
import '../repositories/app_repository.dart';
import 'prefs_repository.dart';

/// The wire vocabulary of `userAuthAvailability` and `confirmUser`.
///
/// MIRRORED IN KOTLIN in `system/UserAuth.kt`. An unknown status is treated
/// as a refusal, never a pass.
abstract final class UserAuthStatus {
  static const ready = 'ready';
  static const noLock = 'no_lock';
  static const unsupported = 'unsupported';
  static const ok = 'ok';
  static const cancelled = 'cancelled';
  static const lockout = 'lockout';
  static const noWindow = 'no_window';
}

/// Whether this phone can confirm its owner. Re-read whenever the Hide apps
/// page opens, because a screen lock can be added or removed in between.
final userAuthAvailabilityProvider =
    FutureProvider.autoDispose<String>((ref) async {
  try {
    return await ref.read(launcherHostApiProvider).userAuthAvailability();
  } catch (_) {
    return UserAuthStatus.unsupported;
  }
});

/// The hidden apps lock: on or off, launcher-wide.
///
/// ─── ITS OWN KEY, NOT A PREFS FIELD ─────────────────────────────────────────
///
/// It is global by nature (the hidden set is global), and it has never lived
/// per theme, so it needs none of the promotion machinery in GlobalPrefs. A
/// single stored flag is the whole of it, and it stays out of backups, which
/// only read the `prefs.` keys: restoring onto a new phone must not arrive
/// locked behind a fingerprint that phone has never seen.
class HiddenLockNotifier extends AsyncNotifier<bool> {
  static const storageKey = 'hiddenApps.lock.v1';

  @override
  Future<bool> build() async =>
      await ref.watch(prefsStoreProvider).read(storageKey) == '1';

  Future<void> set(bool on) async {
    state = AsyncData(on);
    final store = ref.read(prefsStoreProvider);
    if (on) {
      await store.write(storageKey, '1');
    } else {
      await store.delete(storageKey);
    }
  }
}

final hiddenLockProvider =
    AsyncNotifierProvider<HiddenLockNotifier, bool>(HiddenLockNotifier.new);

/// The one gate every protected action goes through.
///
/// Answers true straight away when the lock is off. When it is on, asks the
/// system prompt and answers true only for [UserAuthStatus.ok], with one
/// exception: a phone whose screen lock has since been REMOVED cannot answer
/// at all, and locking the owner out of their own hidden apps would make the
/// feature a trap. That case passes, and the Hide apps page shows the lock as
/// unavailable so the state is never silent.
Future<bool> confirmHiddenAccess(Ref ref, {required String title}) async {
  final locked = await ref.read(hiddenLockProvider.future);
  if (!locked) return true;
  return _confirm(ref.read(launcherHostApiProvider), title);
}

/// [confirmHiddenAccess] for widgets, which hold a WidgetRef.
Future<bool> confirmHiddenAccessFromWidget(
  WidgetRef ref, {
  required String title,
}) async {
  final locked = await ref.read(hiddenLockProvider.future);
  if (!locked) return true;
  return _confirm(ref.read(launcherHostApiProvider), title);
}

Future<bool> _confirm(LauncherHostApi api, String title) async {
  try {
    final status = await api.confirmUser(title, null);
    return status == UserAuthStatus.ok ||
        status == UserAuthStatus.noLock ||
        status == UserAuthStatus.unsupported;
  } catch (_) {
    return false;
  }
}
