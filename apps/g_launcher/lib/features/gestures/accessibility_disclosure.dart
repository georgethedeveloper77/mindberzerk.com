import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_repository.dart';
import '../../design/components/chrome_theme.dart';
import '../../design/components/themed_button.dart';
import '../../design/components/themed_scaffold.dart';

/// THE ONLY DOOR TO THE ACCESSIBILITY SETTINGS INTENT.
///
/// ─── WHY THIS FILE EXISTS AT ALL ────────────────────────────────────────────
///
/// Play rejected 6.0.x twice on the same day: "Accessibility API policy:
/// Missing prominent disclosure". The launcher had a perfectly honest
/// explanation sitting behind an (i) button on the Gestures settings card, and
/// that is not what the policy asks for. A prominent disclosure must be shown
/// IN THE APP, BEFORE the permission is requested, must not be buried behind a
/// tap that most users never make, must not live only in a privacy policy or
/// terms screen, and must be accepted by an affirmative action.
///
/// So `openAccessibilitySettings()` is now unreachable except through
/// [requestGestureService]. Treat that as a hard invariant, the same shape as
/// the no-SnackBar and no-bare-update rules:
///
///   grep -rn "openAccessibilitySettings" lib/ \
///     | grep -v "accessibility_disclosure.dart"
///
/// must come back empty. A second call site that skips this screen is a second
/// rejection, and it will look identical to working code.
///
/// ─── WHY A ROUTE AND NOT A SHEET OR A DIALOG ────────────────────────────────
///
/// [ThemedSheet] and [ThemedDialog] are both dismissible by tapping the scrim.
/// A scrim tap is not a decision, so a consent surface that can be dismissed by
/// one cannot be said to have been accepted OR declined by an affirmative act.
/// A full-screen route has no scrim, and system back resolves to null, which
/// this file treats as a decline. There is no path off this screen that fires
/// the intent except the Continue button.

/// Shows the disclosure, then opens Android's accessibility settings if and
/// only if the user affirmatively accepts.
///
/// Returns true when the service is ALREADY on, in which case no disclosure is
/// shown because there is no permission left to request. It returns false in
/// every other case, including a successful accept: at that moment the user is
/// looking at Android's own settings page and has not switched anything on yet.
/// Callers must not read the return value as "the gesture will work now".
Future<bool> requestGestureService(BuildContext context, WidgetRef ref) async {
  final api = ref.read(launcherHostApiProvider);

  // Already granted. Asking again would be noise, and re-disclosing a
  // permission the user already reasoned about is its own small insult.
  if (await api.isGestureServiceEnabled()) return true;

  // The await above crossed a platform channel. The desktop can be torn down
  // and rebuilt in that window (a theme switch, a home press), so the context
  // has to be re-checked before it is used to push.
  if (!context.mounted) return false;

  final accepted = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => const AccessibilityDisclosureScreen(),
      fullscreenDialog: true,
    ),
  );

  // NULL IS A DECLINE. System back and the close button both pop with no
  // result, and both mean the user did not agree. Only an explicit true here
  // is consent.
  if (accepted != true) return false;

  await api.openAccessibilitySettings();
  return false;
}

/// The disclosure itself. Plain English, no legalese, and specific enough that
/// someone could check every claim on this screen against the service config.
class AccessibilityDisclosureScreen extends StatelessWidget {
  const AccessibilityDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ThemedScaffold(
      title: 'Accessibility service',
      body: _DisclosureBody(),
    );
  }
}

class _DisclosureBody extends StatelessWidget {
  const _DisclosureBody();

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              children: [
                Text(
                  'G Launcher wants to use Android\'s accessibility service',
                  style: d.text.display.copyWith(color: c.text),
                ),
                const SizedBox(height: 10),
                Text(
                  'It is off right now, and it stays off unless you switch it on yourself.',
                  style: d.text.body.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 26),

                // ── WHAT IT IS FOR ────────────────────────────────────
                _Block(
                  icon: Icons.swipe_outlined,
                  tone: c.accent,
                  title: 'What it is for',
                  body:
                      'Four gesture actions need it: open the notification shade, open quick settings, show recent apps, and lock the screen. Android gives a third-party launcher no other way to do those four things.\n\nEvery other part of G Launcher works without it, including all the other gesture actions.',
                ),

                // ── WHAT IT DOES ──────────────────────────────────────
                _Block(
                  icon: Icons.check_circle_outline,
                  tone: c.ok,
                  title: 'What it will do',
                  body:
                      'Perform those four actions, and only when you trigger a gesture you bound to one of them yourself. Nothing runs in the background.',
                ),

                // ── WHAT IT DOES NOT DO ───────────────────────────────
                //
                // The load-bearing paragraph. Every line here is checkable
                // against accessibility_service_config.xml, which requests no
                // event types, no package list and no canRetrieveWindowContent.
                _Block(
                  icon: Icons.visibility_off_outlined,
                  tone: c.ok,
                  title: 'What it will not do',
                  body:
                      'It does not read what is on your screen. It does not record what you type. It does not watch what you do in other apps. It does not collect, store, or share any data, and it sends nothing anywhere.\n\nG Launcher asks for no accessibility events, watches no packages, and does not request permission to retrieve window content.',
                ),

                // ── THE SCARY SYSTEM DIALOG ───────────────────────────
                //
                // Warning people about the next screen is the difference
                // between an informed yes and a startled no. Android's wording
                // is generic to the API and reads like an accusation.
                _Block(
                  icon: Icons.info_outline,
                  tone: c.warn,
                  title: 'About the next screen',
                  body:
                      'Continue opens Android\'s own accessibility settings. That page warns that G Launcher can "observe your actions". Android shows that line for every app that uses this API. It describes what the API can do, not what G Launcher does.\n\nNothing is enabled until you switch it on there, and you can switch it off again at any time in Settings, Accessibility.',
                ),
              ],
            ),
          ),

          // ── THE DECISION ──────────────────────────────────────────────
          //
          // Bottom-right, in the GNOME/Adwaita order the rest of this app's
          // chrome uses, and pinned outside the scroll view so the choice is
          // reachable without reading to the end. Play requires that consent
          // be an affirmative act; it does not require that we hide the
          // buttons until the user has scrolled.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: c.bar,
              border: Border(top: BorderSide(color: c.line, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ThemedButton(
                  label: 'Not now',
                  kind: ThemedButtonKind.text,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 10),
                ThemedButton(
                  label: 'Continue',
                  kind: ThemedButtonKind.primary,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One titled paragraph with a tinted glyph. Four of them make the screen
/// scannable by someone who will not read it, which is most people.
class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: tone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: d.text.label.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  softWrap: true,
                  style: d.text.body.copyWith(color: c.textMuted, height: 1.42),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
