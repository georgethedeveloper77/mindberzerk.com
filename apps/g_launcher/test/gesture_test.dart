import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/data/prefs/launcher_prefs.dart';
import 'package:g_launcher/features/gestures/gesture_actions.dart';

void main() {
  group('GestureBinding', () {
    test('round-trips an action', () {
      const b = GestureBinding.action(GestureAction.lockScreen);
      expect(GestureBinding.decode(b.encode()).action, GestureAction.lockScreen);
    });

    test('round-trips an app', () {
      const b = GestureBinding.app('com.foo/.Main#0');
      final back = GestureBinding.decode(b.encode());
      expect(back.isApp, isTrue);
      expect(back.componentKey, 'com.foo/.Main#0');
    });

    test('an unknown action decodes to none, not a crash', () {
      // A prefs file written by a newer build must not take the home screen
      // down with it.
      expect(GestureBinding.decode('teleport').action, GestureAction.none);
      expect(GestureBinding.decode(null).action, GestureAction.none);
    });
  });

  group('defaults', () {
    test('double-tap-left-edge shows the dock — the v1 behaviour', () {
      final b =
          resolveGestureBinding(const {}, const {}, Gesture.doubleTapLeftEdge);
      expect(b.action, GestureAction.showDock);
    });

    test('every gesture has a default', () {
      for (final g in Gesture.values) {
        expect(defaultGestures[g.id], isNotNull, reason: g.id);
      }
    });

    test('a user binding beats the default', () {
      const g = {'swipeUp': 'lockScreen'};
      expect(
        resolveGestureBinding(g, const {}, Gesture.swipeUp).action,
        GestureAction.lockScreen,
      );
      // Untouched gestures keep their defaults. The notification shade lives on
      // swipe-RIGHT now that the vertical swipes belong to the workspaces.
      expect(
        resolveGestureBinding(g, const {}, Gesture.swipeRight).action,
        GestureAction.notifications,
      );
    });

    test('vertical swipes are unbound by default — the workspaces own them', () {
      // The vertical-workspaces decision: swipe up/down are the PageView's, so
      // they carry no default action. A user can still bind them (with the
      // one-line override warning in Settings).
      expect(
        resolveGestureBinding(const {}, const {}, Gesture.swipeUp).action,
        GestureAction.none,
      );
      expect(
        resolveGestureBinding(const {}, const {}, Gesture.swipeDown).action,
        GestureAction.none,
      );
    });

    test('gestures survive a prefs round-trip', () {
      const p = LauncherPrefs(gestures: {'swipeUp': 'app:com.foo/.M#0'});
      final back = LauncherPrefs.fromJson(p.toJson());
      final b = resolveGestureBinding(back.gestures, const {}, Gesture.swipeUp);
      expect(b.isApp, isTrue);
      expect(b.componentKey, 'com.foo/.M#0');
    });
  });

  group('theme defaults', () {
    test('a theme default applies only when the user never bound it', () {
      final b = resolveGestureBinding(
        const {},
        const {'swipeRight': 'search'},
        Gesture.swipeRight,
      );
      expect(b.action, GestureAction.search);
    });

    test('a user binding beats the theme, always', () {
      // The hard rule: switching distro never rebinds a set gesture.
      final b = resolveGestureBinding(
        const {'swipeRight': 'showDock'},
        const {'swipeRight': 'search'},
        Gesture.swipeRight,
      );
      expect(b.action, GestureAction.showDock);
    });

    test('an unknown theme action falls through to the default, not none', () {
      // A newer catalogue must not shadow a working default with a dead
      // gesture; only a USER value is honoured even when undecodable.
      final b = resolveGestureBinding(
        const {},
        const {'swipeRight': 'flurble'},
        Gesture.swipeRight,
      );
      expect(b.action, GestureAction.notifications);
    });
  });

  group('needsService', () {
    test('only shade/QS/recents/lock need accessibility', () {
      expect(GestureAction.notifications.needsService, isTrue);
      expect(GestureAction.quickSettings.needsService, isTrue);
      expect(GestureAction.recents.needsService, isTrue);
      expect(GestureAction.lockScreen.needsService, isTrue);

      // These must keep working with the service off — otherwise refusing the
      // permission breaks the launcher, and that is coercion, not consent.
      expect(GestureAction.activities.needsService, isFalse);
      expect(GestureAction.showDock.needsService, isFalse);
      expect(GestureAction.search.needsService, isFalse);
      expect(GestureAction.none.needsService, isFalse);
    });
  });
}
