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

  static Future<void> _log(String name, Map<String, Object> params) async {
    try {
      await _fa.logEvent(name: name, parameters: _coerce(params));
    } catch (e) {
      // Debug-only breadcrumb. In release this is silence by design.
      debugPrint('analytics: $name failed ($e)');
    }
  }

  /// Firebase accepts String and num ONLY. Anything else is coerced here.
  ///
  /// ─── TWO EVENTS HAVE NEVER BEEN RECORDED ────────────────────────────────
  ///
  /// `setup_home_role` passes `granted` and `setup_complete` passes `home_role`,
  /// both `bool`, and `logEvent` asserts:
  ///
  ///   'string' OR 'number' must be set as the value of the parameter: granted.
  ///   false found instead
  ///
  /// The wrapper's try/catch swallowed it, so the failure was a debugPrint
  /// nobody was reading and the dashboard simply showed fewer events than there
  /// were. Worse in release: Dart strips assertions, so the bool crosses the
  /// platform channel and Firebase discards it natively with no breadcrumb at
  /// all. Debug mode was the only reason this was ever visible.
  ///
  /// ─── HERE RATHER THAN AT THE CALL SITES ─────────────────────────────────
  ///
  /// Fixing `homeRolePrompt` and `setupComplete` to pass `granted ? 1 : 0` would
  /// work today and last until the next event that wants a flag — and this file
  /// exists precisely so that "every event is declared in one place" is enough
  /// to trust them. A call site cannot reintroduce the bug if the wrapper will
  /// not let a bool through.
  ///
  /// BOOLS BECOME 1 AND 0, not "true" and "false". BigQuery can sum a number;
  /// counting a string means a CASE in every query, and the C10 coverage work
  /// reads these numerically.
  static Map<String, Object> _coerce(Map<String, Object> params) => {
        for (final e in params.entries)
          e.key: switch (e.value) {
            final bool b => b ? 1 : 0,
            final String v => v,
            final num v => v,
            // A future caller passing something exotic gets a readable string
            // rather than a dropped event. Still wrong, still visible.
            final Object v => v.toString(),
          },
      };

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
      _log('setup_home_role', {'attempt': attempt, 'granted': granted});

  /// Setup finished. [granted] records whether they ever gave us the role, so
  /// the completion rate can be read against the funnel above.
  static Future<void> setupComplete({
    required String themeId,
    required bool granted,
  }) =>
      _log('setup_complete', {'theme': themeId, 'home_role': granted});

  /// A distro was chosen. Tells us which themes are worth building next, and
  /// later which are worth charging for.
  static Future<void> themeSelected(String themeId) =>
      _log('theme_selected', {'theme': themeId});
}
