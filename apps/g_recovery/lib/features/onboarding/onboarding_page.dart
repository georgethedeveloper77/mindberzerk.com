import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/accent.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/format.dart';
import '../../ui/art/bin_rise_painter.dart';
import '../../ui/art/g_art_slot.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_logo_mark.dart';
import '../recovery/state/recovery_providers.dart';
import 'state/onboarding_providers.dart';

/// Two screens. No value proposition carousel.
///
/// Screen one is the theme picker, which is a delight moment that costs nothing
/// and buys the seconds the pre-scan needs. Screen two asks for the one
/// permission that matters and pays for it immediately with a real count.
///
/// The ordering is the whole design: by the time anyone reads the permission
/// ask, the number in it is already true.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // Kick the pre-scan the moment onboarding mounts, not when the permission
    // screen appears. Reading the provider rather than watching it starts the
    // work without rebuilding this widget when it lands.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(prescanProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
          child: _step == 0
              ? _ThemeStep(onNext: () => setState(() => _step = 1))
              : const _AccessStep(),
        ),
      ),
    );
  }
}

class _ThemeStep extends ConsumerWidget {
  const _ThemeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final GThemeState theme = ref.watch(gThemeProvider);
    final GThemeController controller = ref.read(gThemeProvider.notifier);
    final AsyncValue<RecoverySummary?> prescan = ref.watch(prescanProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: GSpace.xl),
        Row(
          children: <Widget>[
            const GLogoMark(size: 40),
            const SizedBox(width: GSpace.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('G Recovery', style: GType.heading.copyWith(color: t.text)),
                Text('Make it yours', style: GType.micro.copyWith(color: t.muted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: GSpace.xl),
        Text('Pick a look', style: GType.display.copyWith(color: t.text)),
        const SizedBox(height: GSpace.sm),
        Text(
          'You can change this any time from settings.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const SizedBox(height: GSpace.lg),
        Row(
          children: <Widget>[
            for (final ThemeMode mode in ThemeMode.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: GSpace.sm),
                  child: _ModeSwatch(
                    mode: mode,
                    selected: theme.mode == mode,
                    onTap: () => controller.setMode(mode),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: GSpace.xl),
        Text('Accent', style: GType.overline.copyWith(color: t.dim)),
        const SizedBox(height: GSpace.md),
        Row(
          children: <Widget>[
            for (final GAccent accent in gAccentOrder)
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.setAccent(accent),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedContainer(
                      duration: GMotion.fast,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.base,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.accent == accent
                              ? t.text
                              : const Color(0x00000000),
                          width: 2,
                        ),
                      ),
                      child: theme.accent == accent
                          ? Icon(Icons.check_rounded, size: 18, color: t.onAccent)
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        // The pre-scan status, shown honestly. It is not a fake progress bar:
        // either it is still counting or it has a number.
        GCard(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 18,
                height: 18,
                child: prescan.hasValue
                    ? Icon(Icons.check_rounded, size: 18, color: t.success)
                    : CircularProgressIndicator(strokeWidth: 2, color: t.dim),
              ),
              const SizedBox(width: GSpace.md),
              Expanded(
                child: Text(
                  prescan.hasValue
                      ? 'Checked your device'
                      : 'Checking your device',
                  style: GType.bodySmall.copyWith(color: t.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: GSpace.lg),
        GButton(label: 'Continue', onPressed: onNext),
        const SizedBox(height: GSpace.xl),
      ],
    );
  }
}

class _ModeSwatch extends StatelessWidget {
  const _ModeSwatch({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final String label = switch (mode) {
      ThemeMode.system => 'Auto',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
    // Each swatch previews its own mode's surfaces rather than the current
    // theme's, so the choice is visible before it is made.
    final GTokens preview = switch (mode) {
      ThemeMode.light => GTokens.light(t.accentKey),
      _ => GTokens.dark(t.accentKey),
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: GMotion.fast,
        height: 104,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: preview.ink,
          borderRadius: GRadius.all(GRadius.card),
          border: Border.all(
            color: selected ? t.accent : t.lineStrong,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(height: 7, width: 46, color: preview.lineStrong),
            const SizedBox(height: 6),
            Container(height: 7, width: 30, color: preview.line),
            const SizedBox(height: 11),
            Row(
              children: <Widget>[
                Expanded(
                  child: Container(height: 26, color: preview.panelAlt),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Container(height: 26, color: preview.panelAlt),
                ),
              ],
            ),
            const Spacer(),
            Text(
              label,
              style: GType.monoSmall.copyWith(
                color: selected ? t.accentText : preview.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessStep extends ConsumerWidget {
  const _AccessStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final RecoverySummary? summary = ref.watch(prescanProvider).value;
    final int found = summary?.totalItems ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: GSpace.lg),
        GArtSlot(
          painter: BinRisePainter(tokens: t),
          height: 200,
          semanticsLabel: 'Files rising out of a bin',
        ),
        const SizedBox(height: GSpace.lg),
        Text(
          // A real count converts, a description does not. And when the count is
          // zero the copy has to change rather than showing a zero, because
          // "We found 0 files" is the worst first impression this app could
          // make and it is also not the truth: nothing has been looked at yet.
          found > 0
              ? 'We found ${GFormat.count(found)} files\nyou can bring back'
              : 'Let us look for files\nyou can bring back',
          style: GType.display.copyWith(color: t.text),
        ),
        const SizedBox(height: GSpace.md),
        Text(
          'Android only shows an app the files it deleted itself. Turn on file '
          'access and G Recovery can see what your other apps left behind.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const SizedBox(height: GSpace.lg),
        GCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'All files access',
                      style: GType.heading.copyWith(color: t.text),
                    ),
                    Text(
                      'Scan trash folders, restore files, find duplicates',
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GSpace.sm),
              GBadge.partial('Needed'),
            ],
          ),
        ),
        GCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Notifications',
                      style: GType.heading.copyWith(color: t.text),
                    ),
                    Text(
                      'Keeps deleted chat messages readable',
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GSpace.sm),
              GBadge(label: 'Later'),
            ],
          ),
        ),
        const Spacer(),
        GButton(
          label: 'Allow and continue',
          onPressed: () async {
            await ref.read(recoveryBridgeProvider).requestAllFilesAccess();
            // The settings screen is a separate task with no result to await.
            // Finish onboarding either way: holding the user here until they
            // come back would strand anyone who taps Back.
            ref.read(onboardingDoneProvider.notifier).complete();
          },
        ),
        const SizedBox(height: GSpace.md),
        GestureDetector(
          onTap: () => ref.read(onboardingDoneProvider.notifier).complete(),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: double.infinity,
            child: Text(
              'Skip for now',
              textAlign: TextAlign.center,
              style: GType.bodySmall.copyWith(color: t.dim),
            ),
          ),
        ),
        const SizedBox(height: GSpace.xl),
      ],
    );
  }
}
