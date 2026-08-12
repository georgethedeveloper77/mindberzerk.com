import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/accent.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../app/theme/tokens.dart';
import '../../bridge/apps_api.g.dart';
import '../../bridge/apps_bridge.dart';
import '../../bridge/hardware_bridge.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/format.dart';
import '../../ui/art/escape_art.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_logo_mark.dart';
import '../../ui/g_sheet.dart';
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

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with WidgetsBindingObserver {
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // The lifecycle hook exists for one reason: All Files Access is granted on
    // a SETTINGS screen, in another task. There is no result to await and no
    // callback. The only moment this app can learn the answer is when it comes
    // back to the foreground.
    WidgetsBinding.instance.addObserver(this);

    // Kick the pre-scan the moment onboarding mounts, not when the permission
    // screen appears. Reading the provider rather than watching it starts the
    // work without rebuilding this widget when it lands.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(prescanProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(recoveryAccessProvider);
    // Usage access is granted the same way and read back the same way: a
    // settings screen in another task, no result, no callback.
    ref.invalidate(appsStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
          child: Column(
            children: <Widget>[
              _Progress(step: _step, of: 3),
              Expanded(
                child: switch (_step) {
                  0 => _AboutStep(onNext: () => setState(() => _step = 1)),
                  1 => _ThemeStep(onNext: () => setState(() => _step = 2)),
                  _ => const _AccessStep(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three marks, one filled.
///
/// Onboarding without a length is a corridor with no end in sight, and the
/// commonest reason someone abandons one is not knowing how much is left.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.of});

  final int step;
  final int of;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.only(top: GSpace.md, bottom: GSpace.sm),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < of; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: GSpace.sm),
                child: AnimatedContainer(
                  duration: GMotion.fast,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= step ? t.accent : t.panelAlt,
                    borderRadius: GRadius.all(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What this app is, in one screen, before it asks for anything.
///
/// It used to ask for a theme first, which is a question about the app rather
/// than an answer about it. Nobody knows whether they want to customise
/// something they have not been told the purpose of.
class _AboutStep extends StatelessWidget {
  const _AboutStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Spacer(),
        const EscapeArt(),
        const SizedBox(height: GSpace.lg),
        Text(
          'Deleted is not\nalways gone',
          style: GType.display.copyWith(color: t.text),
        ),
        const SizedBox(height: GSpace.md),
        Text(
          // States the scope up front, because every competitor overstates it
          // and the first screen is where the difference is worth drawing.
          'Your phone keeps deleted files in several places before it lets '
          'them go. G Recovery finds every one of them and tells you exactly '
          'what quality you would get back.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const Spacer(),
        GButton(label: 'Get started', onPressed: onNext),
        const SizedBox(height: GSpace.xl),
      ],
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
                Text(
                  'G Recovery',
                  style: GType.heading.copyWith(color: t.text),
                ),
                Text(
                  'Make it yours',
                  style: GType.micro.copyWith(color: t.muted),
                ),
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
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: t.onAccent,
                            )
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
                Expanded(child: Container(height: 26, color: preview.panelAlt)),
                const SizedBox(width: 5),
                Expanded(child: Container(height: 26, color: preview.panelAlt)),
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

class _AccessStep extends ConsumerStatefulWidget {
  const _AccessStep();

  @override
  ConsumerState<_AccessStep> createState() => _AccessStepState();
}

class _AccessStepState extends ConsumerState<_AccessStep> {
  /// True once the user has been sent to the settings screen at least once.
  ///
  /// The skip only appears after that. Offering a way out beside the very first
  /// ask trains people to take it, and offering none at all traps anyone who has
  /// decided no. Showing it on the second look is the honest middle.
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final RecoveryAccess? access = ref.watch(recoveryAccessProvider).value;
    final AppsState? apps = ref.watch(appsStateProvider).value;
    final bool granted = access?.allFilesAccess ?? false;
    final RecoverySummary? summary = ref.watch(prescanProvider).value;
    final int found = summary?.totalItems ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: GSpace.lg),
        Text(
          // A real count converts and a description does not. When it is zero
          // the copy changes rather than printing a nought, because "We found 0
          // files" is the worst first impression this app could make and it is
          // also untrue: nothing has been looked at yet.
          found > 0
              ? 'We found ${GFormat.count(found)} files\nyou can bring back'
              : 'Let us look through\nyour whole phone',
          style: GType.display.copyWith(color: t.text),
        ),
        const SizedBox(height: GSpace.md),
        Text(
          // ─── ONE SENTENCE, AND THE REST BEHIND AN ICON ────────────────────
          //
          // This screen was four paragraphs of reasoning stacked above four
          // more inside the rows. All of it true, none of it read: a permission
          // screen is skimmed for what it wants and whether it can be skipped,
          // and burying both under an argument makes people tap the first
          // button to make the wall go away.
          //
          // The reasoning has not been deleted. It moved to a sheet, where it
          // is available to anyone who wants it and invisible to everyone else.
          'All of it is optional and all of it can be changed later.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const SizedBox(height: GSpace.lg),

        _Grant(
          label: 'All files access',
          detail: granted ? 'On' : 'Recommended',
          info: 'Android only shows an app the files it deleted itself. '
              'Without this, everything your other apps left behind stays '
              'invisible: trash folders, app leftovers and the thumbnail '
              'cache.',
          without: 'Counts are a floor rather than a total, and most of what '
              'this phone could recover is never seen.',
          on: granted,
          onTap: granted
              ? null
              : () async {
                  await ref
                      .read(recoveryBridgeProvider)
                      .requestAllFilesAccess();
                  if (mounted) setState(() => _asked = true);
                },
        ),
        const SizedBox(height: GSpace.sm + 1),
        // Third, and last, because it is the only one that is genuinely
        // optional. File access decides whether recovery works at all; this
        // decides whether one screen in Storage can answer.
        _Grant(
          label: 'App sizes',
          detail: (apps?.usageAccess ?? false) ? 'On' : 'Optional',
          info: 'Lets the Storage tab show what each app is taking and how '
              'much of that is cache. It reads sizes only, never what you do '
              'in them.',
          without: 'The Apps list shows names without sizes. Nothing else '
              'changes.',
          on: apps?.usageAccess ?? false,
          onTap: (apps?.usageAccess ?? false)
              ? null
              : () async {
                  await ref.read(appsBridgeProvider).requestUsageAccess();
                  if (mounted) setState(() => _asked = true);
                },
        ),
        const SizedBox(height: GSpace.sm + 1),
        // OPTIONAL, and grouped after the two that are not.
        //
        // File access decides whether recovery works at all and app sizes
        // decide whether one screen can answer. These two unlock rows on a
        // detail page, so they are offered here and asked for again on the page
        // itself if skipped.
        _Grant(
          label: 'Wi-Fi details',
          detail: 'Optional',
          info: 'Android treats the network name and MAC address as location '
              'data, so any app that shows them has to ask for location. This '
              'app never reads where you are.',
          without: 'The Wi-Fi page shows the connection without naming the '
              'network.',
          on: false,
          onTap: () async {
            await ref.read(hardwareBridgeProvider).requestLocation();
            if (mounted) setState(() => _asked = true);
          },
        ),
        const SizedBox(height: GSpace.sm + 1),
        _Grant(
          label: 'Notifications',
          // Not a toggle. Nothing in this app can read whether notifications
          // are granted without a new native call, and a switch that shows a
          // state it cannot verify is worse than a sentence that admits it.
          detail: 'Asked later',
          info: 'Asked for when the first scan starts, so a scan or a video '
              'encode can report progress while you are looking at something '
              'else.',
          without: 'Long jobs still run. You just have to come back to the app '
              'to see how far they have got.',
          on: null,
          onTap: null,
        ),

        const Spacer(),

        GButton(
          label: granted ? 'Scan my phone' : 'Allow file access',
          onPressed: () async {
            if (!granted) {
              // Stays on this screen. The settings screen is a separate task
              // with no result to await, and the lifecycle observer upstairs
              // re-reads the grant on resume, so the toggle flips by itself and
              // the button changes with it.
              await ref.read(recoveryBridgeProvider).requestAllFilesAccess();
              if (mounted) setState(() => _asked = true);
              return;
            }
            await ref.read(recoveryBridgeProvider).startBackgroundScan();
            ref.read(onboardingDoneProvider.notifier).complete();
          },
        ),

        SizedBox(height: _asked && !granted ? GSpace.md : 0),
        if (_asked && !granted)
          GestureDetector(
            onTap: () async {
              // Still scans. Without the grant it reaches the thumbnail cache
              // and nothing else, which is a thin app rather than a broken one,
              // and it is better than a home screen of zeroes.
              await ref.read(recoveryBridgeProvider).startBackgroundScan();
              ref.read(onboardingDoneProvider.notifier).complete();
            },
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                'Continue without it',
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

/// One permission: a name, a word, a switch, and an icon for the rest.
///
/// ─── THE EXPLANATION IS ONE TAP AWAY, NOT IN THE WAY ─────────────────────────
///
/// Four rows each carrying two sentences turned this screen into a wall, and a
/// wall is skimmed rather than read. What somebody needs at a glance is which
/// permission this is and whether they have to give it; what it does and what
/// declining costs are real questions, and they belong where a real question is
/// asked rather than in front of everyone who did not ask it.
class _Grant extends StatelessWidget {
  const _Grant({
    required this.label,
    required this.detail,
    required this.on,
    required this.onTap,
    this.info,
    this.without,
  });

  final String label;

  /// One word. "On", "Recommended", "Optional", "Asked later".
  final String detail;

  /// What it does, in the sheet.
  final String? info;

  /// What is lost by declining, in the sheet.
  ///
  /// Kept separate from [info] because it is the half people actually want and
  /// the half most apps leave out. A recommendation nobody can price is a
  /// demand with better manners.
  final String? without;

  /// Null where the state cannot be read. The row then carries no switch at
  /// all rather than a switch that is guessing.
  final bool? on;

  final VoidCallback? onTap;

  void _explain(BuildContext context) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: label,
      children: <Widget>[
        if (info != null)
          GSheetPoint(
            icon: Icons.check_circle_outline_rounded,
            tone: t.accent,
            text: info!,
          ),
        if (without != null)
          GSheetPoint(icon: Icons.block_rounded, text: 'Without it: ${without!}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: GType.heading.copyWith(color: t.text)),
                const SizedBox(height: 2),
                Text(detail, style: GType.micro.copyWith(color: t.muted)),
              ],
            ),
          ),
          if (info != null) ...<Widget>[
            const SizedBox(width: GSpace.sm),
            GestureDetector(
              onTap: () => _explain(context),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(GSpace.xs),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: t.dim,
                ),
              ),
            ),
          ],
          const SizedBox(width: GSpace.sm),
          if (on != null)
            AnimatedContainer(
              duration: GMotion.fast,
              width: 44,
              height: 26,
              padding: const EdgeInsets.all(3),
              alignment: on! ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: on! ? t.accent : t.panelAlt,
                borderRadius: GRadius.all(GRadius.chip),
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: on! ? t.onAccent : t.dim,
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Icon(Icons.schedule_rounded, size: 18, color: t.dim),
        ],
      ),
    );
  }
}
