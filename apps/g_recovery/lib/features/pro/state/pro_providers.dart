import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/prefs_keys.dart';
import '../../../core/prefs/prefs_store.dart';

/// WHETHER THIS PHONE HAS PRO.
///
/// ─── A LOCAL FLAG, AND SAYING SO IS THE POINT ────────────────────────────────
///
/// There is no Play Billing in this app yet. This reads and writes one boolean,
/// which is enough to build and test every screen that depends on the answer,
/// and is not enough to charge anybody.
///
/// It is written this way on purpose rather than stubbed with a hardcoded true:
/// the whole feature can be walked through in both states, and when billing
/// lands it replaces exactly one method here and nothing else in the app moves.
///
/// ─── AND IT MUST NEVER BECOME THE REAL CHECK ─────────────────────────────────
///
/// A preference is editable by anyone with a rooted phone and a text editor.
/// That is fine for a flag mirroring a purchase Play already verified, and it
/// is not fine as the only record of one. When billing arrives, the truth comes
/// from Play's purchase state and this becomes a cache of it.
class ProState {
  const ProState({required this.unlocked});

  final bool unlocked;
}

class ProController extends Notifier<ProState> {
  @override
  ProState build() {
    final PrefsStore prefs = ref.watch(prefsStoreProvider);
    return ProState(unlocked: prefs.readBool(GPrefsKeys.proUnlocked));
  }

  /// Records the unlock. Called after a purchase, and from the developer row
  /// while there is no purchase to be had.
  Future<void> set({required bool unlocked}) async {
    await ref
        .read(prefsStoreProvider)
        .writeBool(GPrefsKeys.proUnlocked, value: unlocked);
    state = ProState(unlocked: unlocked);
  }
}

final NotifierProvider<ProController, ProState> proProvider =
    NotifierProvider<ProController, ProState>(ProController.new);

/// The single question every gated surface asks.
///
/// A derived provider rather than each screen reaching into [proProvider] and
/// reading a field, so that when the answer stops being one boolean there is
/// one place to change.
final Provider<bool> proUnlockedProvider = Provider<bool>(
  (Ref ref) => ref.watch(proProvider).unlocked,
);
