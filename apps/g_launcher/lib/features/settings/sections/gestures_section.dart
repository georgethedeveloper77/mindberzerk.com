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

    final label = binding.isApp ? 'Custom app' : binding.action.label;

    // Swipe up/down belong to the workspaces PageView. Binding them is allowed
    // (their phone, their fight) but must be flagged — the handoff calls for
    // exactly this one-line warning.
    final isVertical =
        gesture == Gesture.swipeUp || gesture == Gesture.swipeDown;
    final bound = binding.isApp || binding.action != GestureAction.none;
    final warn = isVertical && bound;

    return SettingsRow(
      icon: Icons.gesture,
      title: gesture.label,
      subtitle: warn ? 'Overrides workspace scrolling' : null,
      subtitleTint: warn ? s.warn : null,
      trailing: ValueLabel(label),
      onTap: () => _showGestureSheet(context, notifier, gesture),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets
// ─────────────────────────────────────────────────────────────────────────────

/// Show a themed modal sheet. A modal is pushed OUTSIDE this screen's
/// ChromeScope, so we capture the chrome here and re-provide it inside; without
/// that, the sheet would fall back to house chrome over a themed screen.

void _showGestureSheet(
  BuildContext context,
  PrefsNotifier notifier,
  Gesture gesture,
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
                  label:
                      a.needsService ? '${a.label}  ·  needs access' : a.label,
                  onTap: () {
                    notifier.edit(
                      (p) => p.copyWith(
                        gestures: {...p.gestures, gesture.id: a.id},
                      ),
                    );
                    Navigator.pop(context);
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
  /// It is genuinely worth reading — the accessibility prompt says G Launcher
  /// can "observe your actions", and someone who reads that without context is
  /// right to refuse. But a five-line disclaimer sitting permanently above the
  /// gesture list taxes everyone forever to reassure the few who ask. So the
  /// card states the offer in one line and the reasoning goes one tap away.
  static const _explainer =
      'Android only lets a launcher pull down the shade, open quick settings, show recents or lock the screen through an accessibility service.\n\nThe next screen warns that G Launcher can "observe your actions". That is the standard wording for every app that uses this API.\n\nG Launcher does not read your screen and does not watch other apps. It asks only for the ability to perform the gestures you set here.\n\nGestures that do not need it, such as Activities, launching an app or showing the dock, work either way.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(launcherHostApiProvider);
    final s = SettingsSkin.of(context);

    return FutureBuilder<bool>(
      future: api.isGestureServiceEnabled(),
      builder: (context, snap) {
        if (snap.data == true) return const SizedBox.shrink();

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
                      'Shade, quick settings, recents and lock',
                      style: TextStyle(
                        color: s.tx,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Needs an accessibility service',
                      style: TextStyle(color: s.mut, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    // ── PROMINENT DISCLOSURE, NOT A DIRECT INTENT ──────
                    //
                    // This button used to fire the settings intent straight
                    // through, with the explanation parked behind the
                    // (i) beside it. Play rejected that: a disclosure the user
                    // has to go looking for is not prominent, and the policy
                    // wants consent taken in the app before the request, not
                    // an explanation available on request.
                    //
                    // `requestGestureService` fires the intent itself, and only
                    // after an explicit Continue. Do not reintroduce a direct
                    // call here.
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
      },
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

// ─────────────────────────────────────────────────────────────────────────────
// Label helpers
// ─────────────────────────────────────────────────────────────────────────────

/// The Icons row's subtitle: which SOURCE is on top right now.
///
/// Reads the two prefs and nothing async, because a settings row that waits on
/// a package-manager call renders blank on first paint and then pops. The
/// screen behind it does the resolving.
///
/// ORDER MATTERS AND MIRRORS THE RENDERER. A third-party pack layers ABOVE the
/// icon theme, so when both are set the installed pack is what the user is
/// mostly looking at, and that is what this names.

List<Widget> gesturesSection(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  int workspaces,
  String q,
) {
  // Read and discarded, which instantiates the provider here rather than making
  // this function's signature name the Pigeon host API type.
  //
  // The prefs notifier that used to sit beside it is GONE. It was bound for the
  // group's own Reset action, and that moved to RestoreScreen when
  // `SettingsGroup.onReset` stopped being passed anywhere, so it has been unused ever
  // since. The comment claiming it was "BOUND now" outlived the thing it
  // described by a whole feature, which is the usual way a stale comment
  // survives: it was true when written.
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
