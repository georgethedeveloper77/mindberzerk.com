import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// The launcher's analytics surface.
///
/// **One file, named events, no free-form call sites.** Analytics rots when
/// every screen invents its own event name — six months later nobody knows
/// whether it is `setup_done`, `setupComplete` or `onboarding_finished`, and the
/// dashboard silently under-counts. Every event this app sends is declared here.
///
/// **What we measure, and why only this.** The home role is the launcher's
/// entire funnel: an install that never grants it is an install that never sees
/// the product. Knowing how many people grant it on the first prompt, how many
/// need the warning, and how many refuse outright is the difference between
/// guessing at the setup copy and knowing. Nothing here identifies anyone, and
/// nothing here records what apps are installed.
///
/// Every call is wrapped: an analytics failure must never break setup. A
/// telemetry library taking the first-run experience down with it would be an
/// absurd way to lose a user.
class Analytics {
  const Analytics._();

  static FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  /// Firebase Analytics accepts ONLY String and num parameter values — a bool
  /// throws ArgumentError inside logEvent. Combined with the catch below that
  /// is the worst possible failure: the event vanishes and nothing says so,
  /// which is precisely the silent under-count this file exists to prevent.
  /// So booleans are recorded as 1/0, which also aggregates properly in the
  /// console (you get a mean, i.e. the grant rate, for free).
  static num _flag(bool v) => v ? 1 : 0;

  static Future<void> _log(String name, Map<String, Object> params) async {
    try {
      await _fa.logEvent(name: name, parameters: params);
    } catch (e) {
      // Debug-only breadcrumb. In release this is silence by design.
      debugPrint('analytics: $name failed ($e)');
    }
  }

  /// The user reached the home-role step and pressed Next.
  ///
  /// [attempt] is 1 on the first press, 2 on the second, 3 when we finally let
  /// them through. Split by attempt, this single event answers "how many people
  /// do we lose to the home-role prompt, and does the warning recover any of
  /// them" — which is the number that decides whether the copy is right.
  static Future<void> homeRolePrompt({
    required int attempt,
    required bool granted,
  }) =>
      _log('setup_home_role', {
        'attempt': attempt,
        'granted': _flag(granted),
      });

  /// Setup finished. [granted] records whether they ever gave us the role, so
  /// the completion rate can be read against the funnel above.
  static Future<void> setupComplete({
    required String themeId,
    required bool granted,
  }) =>
      _log('setup_complete', {
        'theme': themeId,
        'home_role': _flag(granted),
      });

  /// A distro was chosen. Tells us which themes are worth building next, and
  /// later which are worth charging for.
  static Future<void> themeSelected(String themeId) =>
      _log('theme_selected', {'theme': themeId});
}
