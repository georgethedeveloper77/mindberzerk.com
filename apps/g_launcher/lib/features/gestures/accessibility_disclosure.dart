import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/repositories/app_repository.dart';
import '../../design/components/chrome_theme.dart';
import '../../design/components/themed_button.dart';
import '../../design/components/themed_scaffold.dart';
import '../../design/tokens/radii.dart';
import '../../design/tokens/spacing.dart';

/// THE ONLY DOOR TO THE ACCESSIBILITY SETTINGS INTENT.
///
/// ─── WHY THIS FILE EXISTS AT ALL ────────────────────────────────────────────
///
/// Play rejected 6.0.x twice on the same day: "Accessibility API policy:
/// Missing prominent disclosure". A prominent disclosure must be shown IN THE
/// APP, BEFORE the permission is requested, must not be buried behind a tap
/// most users never make, and must be accepted by an affirmative action.
///
/// So `openAccessibilitySettings()` is unreachable except through
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
/// A scrim tap is not a decision. A full-screen route has no scrim, and system
/// back resolves to null, which this file treats as a decline. There is no
/// path off this screen that fires the intent except the primary button.

/// Whether the gesture service is on, re-read every time the app resumes.
///
/// The user grants the service on Android's own settings page, so the only
/// moment the answer can change is while this app is in the background. An
/// [AppLifecycleListener] invalidating on resume means every watcher (the
/// settings card, the gesture rows) reflects the new state the moment the user
/// comes back, with no polling and no manual refresh.
final gestureServiceEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  return ref.read(launcherHostApiProvider).isGestureServiceEnabled();
});

/// Shows the disclosure, then opens Android's accessibility settings if and
/// only if the user affirmatively accepts.
///
/// Returns true when the service is ALREADY on, in which case no disclosure is
/// shown because there is no permission left to request. It returns false in
/// every other case, including a successful accept: at that moment the user is
/// looking at Android's own settings page and has not switched anything on yet.
/// Callers must not read the return value as "the gesture will work now";
/// [gestureServiceEnabledProvider] picks up the real answer on resume.
Future<bool> requestGestureService(BuildContext context, WidgetRef ref) async {
  final api = ref.read(launcherHostApiProvider);

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
  // result. Only an explicit true here is consent.
  if (accepted != true) return false;

  await api.openAccessibilitySettings();
  return false;
}

/// The four capabilities the service exists for, in the order the disclosure
/// lists them. Kept beside the copy so a fifth capability cannot be added to
/// the service without someone editing the screen that discloses it.
///
/// Keys are passed to `context.t` as literals, not stored in a const list, so
/// tools/i18n_audit.py can see them and never offers them up as unused.
List<(IconData, String)> _capabilities(BuildContext context) => [
      (
        Icons.notifications_none_rounded,
        context.t('gestures.actionNotifications'),
      ),
      (Icons.toggle_on_outlined, context.t('gestures.actionQuickSettings')),
      (Icons.filter_none_rounded, context.t('gestures.actionRecents')),
      (Icons.lock_outline_rounded, context.t('gestures.actionLock')),
    ];

/// The privacy promises. Every line is checkable against
/// accessibility_service_config.xml, which requests no event types, no
/// package list and no canRetrieveWindowContent.
List<String> _promises(BuildContext context) => [
      context.t('gestures.privacyNoRead'),
      context.t('gestures.privacyNoData'),
      context.t('gestures.privacyOnlyGestures'),
    ];

/// The disclosure itself: one screen, no scrolling at default text scale, the
/// four actions as a list and the privacy promise as its own card.
class AccessibilityDisclosureScreen extends StatelessWidget {
  const AccessibilityDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // No title: a bar repeating the headline is noise. The close button is
    // drawn in the body instead, so the screen is still escapable by touch.
    return const ThemedScaffold(body: _DisclosureBody());
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
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: c.textMuted),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              // Pops null, which [requestGestureService] reads as a decline.
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                GSpace.xl,
                0,
                GSpace.xl,
                GSpace.lg,
              ),
              children: [
                Text(
                  context.t('gestures.disclosureTitle'),
                  style: d.text.display.copyWith(color: c.text, height: 1.25),
                ),
                const SizedBox(height: GSpace.sm),
                Text(
                  context.t('gestures.disclosureLede'),
                  style: d.text.body.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: GSpace.xl),
                Padding(
                  padding: const EdgeInsets.only(bottom: GSpace.sm),
                  child: Text(
                    context.t('gestures.usedForTheseFour').toUpperCase(),
                    style: d.text.label.copyWith(
                      color: c.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const _CapabilityList(),
                const SizedBox(height: GSpace.md),
                const _PrivacyCard(),
              ],
            ),
          ),

          // ── THE DECISION ──────────────────────────────────────────────
          //
          // Pinned outside the scroll view so the choice is reachable without
          // reading to the end. Full width and stacked, the pattern for a
          // full-screen consent page; the primary label names where it goes.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GSpace.xl,
              GSpace.sm,
              GSpace.xl,
              GSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ThemedButton(
                  label: context.t('gestures.openAccessibilitySettings'),
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: GSpace.xs),
                ThemedButton(
                  label: context.t('settings.notNow'),
                  kind: ThemedButtonKind.text,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The four actions as one grouped card with hairline dividers.
class _CapabilityList extends StatelessWidget {
  const _CapabilityList();

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final items = _capabilities(context);

    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: GRadius.lgAll),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 0.5, thickness: 0.5, color: c.line),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GSpace.lg,
                vertical: GSpace.md,
              ),
              child: Row(
                children: [
                  Icon(items[i].$1, size: 20, color: c.accent),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: Text(
                      items[i].$2,
                      style: d.text.body.copyWith(color: c.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the service does not do. The load-bearing part of the disclosure, so
/// it gets its own surface rather than a paragraph.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final promises = _promises(context);

    return Container(
      padding: const EdgeInsets.all(GSpace.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: GRadius.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 20, color: c.accent),
              const SizedBox(width: GSpace.sm),
              Text(
                context.t('gestures.yourPrivacy'),
                style: d.text.body.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: GSpace.md),
          for (var i = 0; i < promises.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : GSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_rounded, size: 16, color: c.ok),
                  ),
                  const SizedBox(width: GSpace.sm),
                  Expanded(
                    child: Text(
                      promises[i],
                      style: d.text.body.copyWith(
                        color: c.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
