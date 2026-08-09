import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/prefs_keys.dart';
import '../../../core/prefs/prefs_store.dart';

/// Whether the first run flow is behind us.
///
/// Read synchronously from the injected prefs store, so the very first frame
/// already knows which screen to show. An async read here would flash the shell
/// before swapping to onboarding, which looks like a bug on a slow device.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(prefsStoreProvider).readBool(GPrefsKeys.onboardingComplete);

  void complete() {
    if (state) return;
    state = true;
    ref
        .read(prefsStoreProvider)
        .writeBool(GPrefsKeys.onboardingComplete, value: true);
  }

  /// Debug only. Wired to a long press on the More header so first run can be
  /// re-tested without reinstalling.
  void reset() {
    state = false;
    ref
        .read(prefsStoreProvider)
        .writeBool(GPrefsKeys.onboardingComplete, value: false);
  }
}

final NotifierProvider<OnboardingController, bool> onboardingDoneProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);
