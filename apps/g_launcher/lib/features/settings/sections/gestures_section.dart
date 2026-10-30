/// Gestures: every swipe, and the accessibility service that makes them work.
///
/// A section builder, plus the two widgets only it uses: the row that opens a
/// binding picker, and the card that asks for the service. The card carries
/// Play's prominent-disclosure requirement and its history; it stays with the
/// section it belongs to rather than in the shared row vocabulary, because
/// nothing else may render it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/prefs_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../design/components/components.dart';
import '../../../engine/effective_theme.dart';
import '../../gestures/accessibility_disclosure.dart';
import '../../gestures/gesture_actions.dart';
import '../settings_rows.dart';
import '../settings_sheets.dart';

class _GestureRow extends ConsumerWidget {
  const _GestureRow({required this.theme, required this.gesture});

  final EffectiveTheme theme;
  final Gesture gesture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SettingsSkin.of(context);
    final binding = bindingFor(theme, gesture);
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final serviceOn = ref.watch(gestureServiceEnabledProvider).value;

    final label = binding.isApp ? 'Custom app' : binding.action.label;

    // A gated action with the service known to be off is a binding that does
    // nothing. Saying so here is the difference between "my gesture is
    // broken" and "my gesture is waiting for one switch". Unknown (still
    // loading) says nothing rather than flashing a warning that may be wrong.
    final dormant =
        !binding.isApp && binding.action.needsService && serviceOn == false;

    // Swipe up/down belong to the workspaces PageView. Binding them is allowed
    // (their phone, their fight) but must be flagged.
    final isVertical =
        gesture == Gesture.swipeUp || gesture == Gesture.swipeDown;
    final bound = binding.isApp || binding.action != GestureAction.none;
    final warn = isVertical && bound;

    // A dormant binding outranks the scrolling warning: a gesture that does
    // nothing at all is the more urgent of the two facts.
    final String? subtitle;
    final Color? tint;
    if (dormant) {
      subtitle = context.t('gestures.turnOnToUse');
      tint = s.acc;
    } else if (warn) {
      subtitle = 'Overrides workspace scrolling';
      tint = s.warn;
    } else {
      subtitle = null;
      tint = null;
    }

    return SettingsRow(
      icon: Icons.gesture,
      title: gesture.label,
      subtitle: subtitle,
      subtitleTint: tint,
      trailing: ValueLabel(label),
      onTap: () => _showGestureSheet(
        context,
        ref,
        notifier,
        gesture,
        binding,
        serviceOn,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets
// ─────────────────────────────────────────────────────────────────────────────

/// The binding picker.
///
/// Choosing a gated action while the service is off is the moment Play's
/// policy is written around: the user has just asked for the capability, so
/// the disclosure follows the choice directly. The binding is saved either
/// way; declining leaves it dormant, and the row says so.
void _showGestureSheet(
  BuildContext context,
  WidgetRef ref,
  PrefsNotifier notifier,
  Gesture gesture,
  GestureBinding current,
  bool? serviceOn,
) {
  settingsSheet<void>(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        settingsSheetHead(context, gesture.label),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final a in GestureAction.values)
                SheetOption(
                  label: a.label,
                  selected: !current.isApp && current.action == a,
                  description: a.needsService && serviceOn != true
                      ? context.t('gestures.needsPermission')
                      : null,
                  onTap: () async {
                    notifier.edit(
                      (p) => p.copyWith(
                        gestures: {...p.gestures, gesture.id: a.id},
                      ),
                    );
                    Navigator.pop(context);

                    // requestGestureService re-checks the service itself and
                    // returns early when it is on, so a stale [serviceOn]
                    // can never show the disclosure to someone already done.
                    if (a.needsService && context.mounted) {
                      await requestGestureService(context, ref);
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _GestureServiceCard extends ConsumerWidget {
  const _GestureServiceCard();

  /// The full explanation, kept OUT of the card.
  ///
  /// It is genuinely worth reading, since the accessibility prompt says G
  /// Launcher can "observe your actions", and someone who reads that without
  /// context is right to refuse. But a five-line disclaimer sitting
  /// permanently above the gesture list taxes everyone forever to reassure the
  /// few who ask. So the card states the offer in one line and the reasoning
  /// goes one tap away.
  static const _explainer =
      'Android only lets a launcher pull down the shade, open quick settings, show recents or lock the screen through an accessibility service.\n\nThe next screen warns that G Launcher can "observe your actions". That is the standard wording for every app that uses this API.\n\nG Launcher does not read your screen and does not watch other apps. It asks only for the ability to perform the gestures you set here.\n\nGestures that do not need it, such as Activities, launching an app or showing the dock, work either way.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SettingsSkin.of(context);

    // Shown only once the service is KNOWN to be off. While the first check is
    // in flight it stays hidden, so someone who already granted it never sees
    // the offer flash up and vanish. The provider re-checks on resume, so the
    // card disappears by itself when the user comes back from Settings.
    if (ref.watch(gestureServiceEnabledProvider).value != false) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.fromLTRB(
        s.framing.cardInset,
        0,
        s.framing.cardInset,
        16,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(s.framing.cardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('settings.shadeQuickSettingsRecents'),
                  style: TextStyle(
                    color: s.tx,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.t('settings.needsAnAccessibilityService'),
                  style: TextStyle(color: s.mut, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                // ── PROMINENT DISCLOSURE, NOT A DIRECT INTENT ──────────
                //
                // `requestGestureService` fires the intent itself, and only
                // after an explicit accept on the disclosure screen. Do not
                // reintroduce a direct call here.
                ThemedButton(
                  label: context.t('settings.turnItOn'),
                  onPressed: () => requestGestureService(context, ref),
                ),
              ],
            ),
          ),
          _InfoButton(
            title: context.t('settings.whyAnAccessibilityService'),
            body: _explainer,
          ),
        ],
      ),
    );
  }
}

/// A small (i) that opens its explanation in a themed sheet.
///
/// The pattern for anything needing more than a line of justification: the row
/// stays scannable, and the reasoning is there for whoever wants it instead of
/// being read past by everyone who does not.
class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);

    return IconButton(
      icon: Icon(Icons.info_outline, size: 20, color: s.mut),
      tooltip: title,
      onPressed: () => ThemedSheet.show<void>(
        context,
        title: title,
        isScrollControlled: true,
        builder: (sheet) {
          final d = ChromeScope.of(sheet);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Text(
              body,
              style: d.text.body.copyWith(
                color: d.colors.textMuted,
                height: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }
}

List<Widget> gesturesSection(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  int workspaces,
  String q,
) {
  // Read and discarded, which instantiates the provider here rather than making
  // this function's signature name the Pigeon host API type.
  ref.read(launcherHostApiProvider);

  return [
    // ── Gestures ───────────────────────────────────────────────────
    const _GestureServiceCard(),
    SettingsGroup(
      label: context.t('settings.gestures'),
      scope: 'This distro',
      query: q,
      rows: [
        for (final g in Gesture.values)
          FilterRow(
            [g.label.toLowerCase(), 'gesture', 'swipe'],
            _GestureRow(theme: theme, gesture: g),
          ),
      ],
    ),
  ];
}
