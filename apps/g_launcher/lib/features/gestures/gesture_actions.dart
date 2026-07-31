import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_repository.dart';
import '../../data/usage/usage_repository.dart';
import '../../engine/effective_theme.dart';

/// The gestures a user can bind.
///
/// [doubleTapLeftEdge] is preserved from v1 deliberately — people who used the
/// old G Launcher have it in their muscle memory, and silently dropping a
/// gesture someone used daily is how you lose an existing user base during a
/// rewrite.
enum Gesture {
  doubleTapLeftEdge('doubleTapLeftEdge', 'Double-tap left edge'),
  swipeUp('swipeUp', 'Swipe up'),
  swipeDown('swipeDown', 'Swipe down'),
  swipeLeft('swipeLeft', 'Swipe left'),
  swipeRight('swipeRight', 'Swipe right'),
  doubleTapHome('doubleTapHome', 'Double-tap home'),
  twoFingerSwipeDown('twoFingerSwipeDown', 'Two-finger swipe down');

  const Gesture(this.id, this.label);
  final String id;
  final String label;
}

/// What a gesture can do.
///
/// Anything needing [needsService] no-ops when the accessibility service is
/// off. Never a crash, never a nag — the Settings screen is where we ask, not
/// the home screen.
enum GestureAction {
  none('none', 'Nothing', false),
  activities('activities', 'Open Activities', false),
  showDock('showDock', 'Show dock', false),
  search('search', 'Search apps', false),
  notifications('notifications', 'Notification shade', true),
  quickSettings('quickSettings', 'Quick settings', true),
  recents('recents', 'Recent apps', true),
  lockScreen('lockScreen', 'Lock screen', true);

  const GestureAction(this.id, this.label, this.needsService);
  final String id;
  final String label;

  /// True = requires the AccessibilityService. Android gives launchers no other
  /// way to reach the shade or lock the device.
  final bool needsService;

  static GestureAction? parse(String? raw) {
    if (raw == null) return null;
    for (final a in GestureAction.values) {
      if (a.id == raw) return a;
    }
    return null;
  }
}

/// A binding is either a GestureAction or an app to launch ("app:<componentKey>").
class GestureBinding {
  const GestureBinding.action(this.action) : componentKey = null;
  const GestureBinding.app(this.componentKey) : action = GestureAction.none;

  final GestureAction action;
  final String? componentKey;

  bool get isApp => componentKey != null;

  String encode() => isApp ? 'app:$componentKey' : action.id;

  static GestureBinding decode(String? raw) {
    if (raw == null) return const GestureBinding.action(GestureAction.none);
    if (raw.startsWith('app:')) {
      return GestureBinding.app(raw.substring(4));
    }
    return GestureBinding.action(
      GestureAction.parse(raw) ?? GestureAction.none,
    );
  }
}

/// Defaults — **changed with the vertical-workspaces decision.**
///
/// The workspaces PageView is now VERTICAL, which the mockup was saying all
/// along: the workspace dots are a vertical strip on the right edge, and
/// vertical dots mean vertical movement. So:
///
///  - **Swipe up / down belong to the workspaces** and are unbound by default.
///    Binding them means the gesture layer and the PageView fight over the same
///    drag, and the loser is whichever one you weren't testing that day. Users
///    CAN still bind them in Settings (their phone, their fight) — the Settings
///    row should carry a one-line warning when they do.
///  - **The drawer is on swipe LEFT (Activities).** Horizontal is free now that
///    the workspaces own vertical, and swipe-left is the primary reach for the
///    app surface.
///  - **Swipe right gets the notification shade**, keeping it one-hand reachable
///    now that swipe-down belongs to the workspaces. (Left/right were swapped
///    from the earlier default — flip these two lines to undo.)
///  - `doubleTapLeftEdge` → showDock is v1 muscle memory. Never touch it.
const defaultGestures = <String, String>{
  'doubleTapLeftEdge': 'showDock',
  'swipeLeft': 'activities',
  'swipeRight': 'notifications',
  'swipeUp': 'none',
  'swipeDown': 'none',
  'doubleTapHome': 'lockScreen',
  'twoFingerSwipeDown': 'quickSettings',
};

/// The ONE place a gesture resolves to a binding: the user's entry, else the
/// distro's authored default, else [defaultGestures].
///
/// ─── THE HARD RULE ──────────────────────────────────────────────────────────
///
/// A user entry wins UNCONDITIONALLY, even one this build cannot decode (it
/// reads as [GestureAction.none] and the gesture goes dead until they rebind).
/// Falling through an unknown user value to the theme would let a distro
/// rebind a gesture the user deliberately set, and several actions ride an
/// accessibility service the user granted for a purpose; a distro is never
/// allowed near that. The touched marker is entry PRESENCE: the Settings sheet
/// always writes an explicit entry and never deletes one, so absence really
/// does mean "never chosen".
///
/// A THEME entry, by contrast, is screened: an action id from a newer
/// catalogue, or anything else undecodable, falls through to
/// [defaultGestures] rather than shadowing a working default with a dead
/// gesture. An `app:` theme default passes the screen and is inert when the
/// app is not installed, via the existing uninstalled guard in [runGesture];
/// service-gated theme defaults are allowed and simply no-op when the service
/// is off, which is the contract every binding already lives under.
GestureBinding bindingFor(EffectiveTheme theme, Gesture gesture) {
  final user = theme.prefs.gestures[gesture.id];
  if (user != null) return GestureBinding.decode(user);

  final themed = theme.spec.gestures[gesture.id];
  final themedKnown = themed != null &&
      (themed.startsWith('app:') || GestureAction.parse(themed) != null);
  if (themedKnown) return GestureBinding.decode(themed);

  return GestureBinding.decode(defaultGestures[gesture.id]);
}

/// Fires a binding. Returns false when nothing happened — the caller can then
/// surface the opt-in prompt instead of leaving the user tapping at a dead
/// gesture and concluding the app is broken.
Future<bool> runGesture(
  WidgetRef ref,
  GestureBinding binding, {
  required void Function() onActivities,
  required void Function() onShowDock,
  required void Function() onSearch,
}) async {
  final api = ref.read(launcherHostApiProvider);

  if (binding.isApp) {
    final apps = ref.read(appListProvider).asData?.value ?? const [];
    final entry =
        apps.where((a) => a.componentKey == binding.componentKey).firstOrNull;
    // A gesture bound to an app that was later uninstalled must do nothing,
    // not throw.
    if (entry == null) return false;
    await ref.read(appListProvider.notifier).launch(entry);
    // Gesture launches count toward frequency too — a gesture-bound app is by
    // definition one of your most-used, and the dock's default should know it.
    await ref.read(usageProvider.notifier).record(entry.componentKey);
    return true;
  }

  switch (binding.action) {
    case GestureAction.none:
      return false;
    case GestureAction.activities:
      onActivities();
      return true;
    case GestureAction.showDock:
      onShowDock();
      return true;
    case GestureAction.search:
      onSearch();
      return true;
    case GestureAction.notifications:
    case GestureAction.quickSettings:
    case GestureAction.recents:
    case GestureAction.lockScreen:
      return api.performGlobalAction(binding.action.id);
  }
}
