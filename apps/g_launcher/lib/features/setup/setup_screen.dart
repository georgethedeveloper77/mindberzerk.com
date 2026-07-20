import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../data/prefs/folder_suggestions.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/setup_state.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../design/components/components.dart';
import '../../design/device_preview.dart';
import '../../engine/effective_theme.dart';
import '../drawer/drawer_actions.dart';
import '../themes/theme_catalog.dart';

/// **Initial setup** — the Linux installer, not an onboarding carousel.
///
/// **Full bleed.** The desktop you are configuring fills the screen; the
/// controls float over it in a panel at the bottom. The earlier version put a
/// small phone in the middle of an empty page, which is a picture of the product
/// rather than the product. Here, moving the dock moves the dock you are looking
/// at, edge to edge, and your thumb never leaves the bottom third.
///
/// **The home role gets three attempts, not a wall.** Blocking on it holds the
/// phone hostage; asking once and never again leaves a half-empty drawer with no
/// explanation. So: first Next opens Android's own picker directly, second Next
/// warns, third Next lets them through with a banner that follows them. Every
/// attempt is logged — that funnel is the single most important number the app
/// has, because an install without the home role never really sees the product.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const _welcome = 0;
  static const _homeStep = 1;
  static const _lastStep = 5;

  int _step = _welcome;
  bool _isDefault = false;

  /// How many times Next has been pressed on the home-role step.
  ///
  /// Deliberately NOT persisted: it counts presses within this wizard, and a
  /// user who reinstalls deserves the same three chances rather than inheriting
  /// a grudge from a previous install.
  int _homeAttempts = 0;
  bool _showHomeWarning = false;

  @override
  void initState() {
    super.initState();
    _refreshDefaultLauncher();
  }

  Future<void> _refreshDefaultLauncher() async {
    final ok = await ref.read(launcherHostApiProvider).isDefaultLauncher();
    if (mounted) setState(() => _isDefault = ok);
  }

  Future<void> _openHomePicker() async {
    await ref.read(launcherHostApiProvider).requestDefaultLauncher();
    // The picker is a system dialog; we only learn the outcome by asking again
    // once we are back.
    await _refreshDefaultLauncher();
  }

  /// The three-strike gate. Returns true when the wizard may advance.
  Future<bool> _homeGate() async {
    if (_isDefault) return true;

    _homeAttempts++;
    Analytics.homeRolePrompt(attempt: _homeAttempts, granted: false);

    if (_homeAttempts == 1) {
      // Straight to Android's picker. No dialog of ours in front of it — an
      // interstitial explaining that a prompt is coming is one more thing to
      // dismiss before the thing that matters.
      await _openHomePicker();
      return _isDefault;
    }

    if (_homeAttempts == 2) {
      setState(() => _showHomeWarning = true);
      return false;
    }

    // Third press: their phone, their call.
    return true;
  }

  Future<void> _next() async {
    if (_step == _homeStep) {
      final mayPass = await _homeGate();
      if (!mayPass) return;
    }

    if (_step < _lastStep) {
      setState(() => _step++);
      return;
    }

    await _finish();
  }

  Future<void> _finish() async {
    final themeId =
        ref.read(selectedThemeIdProvider).asData?.value ?? 'ubuntu-24-04';
    Analytics.setupComplete(themeId: themeId, granted: _isDefault);

    // Hand-off flag first, then the completion that swaps this screen out: the
    // desktop mounts fresh and reads the flag on that very build.
    ref.read(firstRunBootPendingProvider.notifier).state = true;
    await ref.read(setupCompletedProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(effectiveThemeProvider).asData?.value;

    // ChromeScope is normally installed by ThemedScaffold. This screen uses a
    // bare Scaffold so the preview can run edge to edge behind it, so it has to
    // provide the chrome itself — otherwise every ChromeScope.of below throws.
    // Bootstrap while the theme loads, exactly as ThemedScaffold does, so there
    // is no un-themed flash of a different kind.
    final chrome = theme == null
        ? ChromeData.bootstrap
        : ChromeData.fromPalette(
            theme.palette,
            typography: theme.typography,
            textScale: theme.textScale,
            family: theme.chromeFamily,
          );

    return ChromeScope(
      data: chrome,
      child: Scaffold(
      // Transparent, like every shell Scaffold: the preview underneath IS the
      // background, and an opaque scaffold colour would sit on top of it.
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (theme != null) _Backdrop(theme: theme, step: _step),
            SafeArea(
              child: Column(
                children: [
                  _Progress(step: _step, total: _lastStep + 1),
                  const Spacer(),
                  if (theme != null) _panel(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The glass panel. Everything you touch lives here, over the live desktop.
  Widget _panel(EffectiveTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          // Not a blur: a real backdrop filter on every frame of a live,
          // animating preview is the one thing here that would actually cost
          // battery. A heavy translucent fill reads the same and is free.
          color: theme.palette.bgBottom.withValues(alpha: 0.90),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Builder(
              builder: (context) {
                final d = ChromeScope.of(context);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _body(d, theme),
                    const SizedBox(height: 14),
                    if (!_isDefault && _step > _homeStep)
                      _NagLine(onFix: _openHomePicker),
                    _Footer(
                      step: _step,
                      lastStep: _lastStep,
                      onBack:
                          _step == 0 ? null : () => setState(() => _step--),
                      onNext: _next,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ChromeData d, EffectiveTheme theme) => switch (_step) {
        _welcome => _Copy(
            d: d,
            title: 'Welcome to G Launcher',
            blurb: 'A real Linux desktop in your pocket. Two minutes to set up.',
          ),
        _homeStep => _StepHome(
            d: d,
            isDefault: _isDefault,
            showWarning: _showHomeWarning,
            onRequest: _openHomePicker,
          ),
        2 => _StepDistro(d: d),
        3 => _StepDock(d: d, theme: theme),
        4 => _StepDrawer(d: d, theme: theme),
        _ => _StepFolders(d: d, theme: theme),
      };
}

/// The live, full-bleed desktop behind the panel.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.theme, required this.step});

  final EffectiveTheme theme;
  final int step;

  @override
  Widget build(BuildContext context) {
    // The welcome step has no setting to show, so it runs the SPLASH: the same
    // logo-and-dots the distro plays when it boots. It previews the product and
    // sets the tone in one screen, instead of asking for a permission over an
    // empty background.
    if (step == 0) return _WelcomePulse(theme: theme);

    return DevicePreview(
      palette: theme.palette,
      framed: false,
      mode: switch (step) {
        4 => DevicePreviewMode.drawer,
        5 => DevicePreviewMode.folder,
        _ => DevicePreviewMode.desktop,
      },
      dock: theme.dock,
      gridButton: theme.prefs.dockGridButton ?? 'end',
      cols: step == 5 ? (theme.prefs.folderCols ?? 4) : theme.drawerCols,
      rows: theme.prefs.folderRows ?? 3,
    );
  }
}

/// The welcome backdrop: the distro's mark over its own gradient, with the
/// Plymouth dots looping underneath. Deliberately the same visual language as
/// [SplashSequence] — the first screen and the boot should look like the same
/// operating system.
class _WelcomePulse extends StatefulWidget {
  const _WelcomePulse({required this.theme});

  final EffectiveTheme theme;

  @override
  State<_WelcomePulse> createState() => _WelcomePulseState();
}

class _WelcomePulseState extends State<_WelcomePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bgTop, p.bgBottom],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.accent, width: 5),
              ),
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: p.accent),
                ),
              ),
            ),
            const SizedBox(height: 36),
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.onDark.withValues(
                            alpha: 0.25 + 0.75 * _pulse(t, i / 5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static double _pulse(double t, double offset) {
    final d = (t - offset) % 1.0;
    return d < 0.25 ? 1.0 - (d / 0.25) : 0.0;
  }
}

// ── Step bodies ──────────────────────────────────────────────────────────────

class _Copy extends StatelessWidget {
  const _Copy({
    required this.d,
    required this.title,
    required this.blurb,
    this.child,
  });

  final ChromeData d;
  final String title;
  final String blurb;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: d.text.display),
        const SizedBox(height: 6),
        Text(blurb, style: d.text.body.copyWith(color: d.colors.textMuted)),
        if (child != null) ...[const SizedBox(height: 14), child!],
      ],
    );
  }
}

class _StepHome extends StatelessWidget {
  const _StepHome({
    required this.d,
    required this.isDefault,
    required this.showWarning,
    required this.onRequest,
  });

  final ChromeData d;
  final bool isDefault;
  final bool showWarning;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final c = d.colors;

    if (isDefault) {
      return _Copy(
        d: d,
        title: "You're all set",
        blurb: 'G Launcher is your home app. The rest is how it should look.',
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 19, color: c.ok),
            const SizedBox(width: 9),
            Text('Home app set', style: d.text.body),
          ],
        ),
      );
    }

    return _Copy(
      d: d,
      title: showWarning ? 'Really skip this?' : 'Make this your home',
      blurb: showWarning
          ? 'Without the home role, Android hides most of your apps from the '
              'drawer and the home button will keep opening your old launcher.'
          : 'Android only hands the full app list to the app holding the home '
              'role.',
      child: ThemedButton(
        label: showWarning ? 'Set as home app' : 'Choose G Launcher',
        icon: Icons.home_outlined,
        onPressed: onRequest,
        expand: true,
      ),
    );
  }
}

class _StepDistro extends ConsumerWidget {
  const _StepDistro({required this.d});

  final ChromeData d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref
        .watch(themeCatalogProvider)
        .where((c) => c.bundled && c.specId != null)
        .toList();
    final active = ref.watch(selectedThemeIdProvider).asData?.value;

    return _Copy(
      d: d,
      title: 'Choose your desktop',
      blurb: 'Tap one — this screen becomes it.',
      child: Row(
        children: [
          for (final card in cards)
            Expanded(
              child: _DistroChip(
                d: d,
                card: card,
                selected: card.specId == active,
                onTap: () {
                  Analytics.themeSelected(card.specId!);
                  ref
                      .read(selectedThemeIdProvider.notifier)
                      .select(card.specId!);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DistroChip extends StatelessWidget {
  const _DistroChip({
    required this.d,
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final ChromeData d;
  final ThemeCard card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = d.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? c.accent : c.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemeSwatch(
              bg: card.preview.bg,
              bar: card.preview.bar,
              accent: card.preview.accent,
              radial: card.preview.radial,
              selected: selected,
            ),
            const SizedBox(height: 5),
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: d.text.caption.copyWith(
                color: selected ? c.text : c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDock extends ConsumerWidget {
  const _StepDock({required this.d, required this.theme});

  final ChromeData d;
  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    return _Copy(
      d: d,
      title: 'Your dock',
      blurb: 'Where pinned apps live.',
      child: Column(
        children: [
          _Seg(
            d: d,
            label: 'Dock',
            value: theme.dock.name,
            options: const {'left': 'Left', 'bottom': 'Bottom', 'off': 'Off'},
            onChanged: (v) => notifier.edit((p) => p.copyWith(dockSide: v)),
          ),
          const SizedBox(height: 11),
          _Seg(
            d: d,
            label: 'App-grid button',
            value: theme.prefs.dockGridButton ?? 'end',
            options: const {'start': 'Start', 'end': 'End', 'off': 'Off'},
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(dockGridButton: v)),
          ),
        ],
      ),
    );
  }
}

class _StepDrawer extends ConsumerWidget {
  const _StepDrawer({required this.d, required this.theme});

  final ChromeData d;
  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    return _Copy(
      d: d,
      title: 'App drawer',
      blurb: 'How many across, and how it moves.',
      child: Column(
        children: [
          _Seg(
            d: d,
            label: 'Columns',
            value: '${theme.drawerCols}',
            options: const {'3': '3', '4': '4', '5': '5', '6': '6'},
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(drawerCols: int.parse(v))),
          ),
          const SizedBox(height: 11),
          _Seg(
            d: d,
            label: 'Scrolls',
            value: theme.prefs.drawerScrollStyle ?? 'vertical',
            options: const {
              'vertical': 'List',
              'pages': 'Pages',
              'cube': 'Cube',
            },
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(drawerScrollStyle: v)),
          ),
        ],
      ),
    );
  }
}

class _StepFolders extends ConsumerWidget {
  const _StepFolders({required this.d, required this.theme});

  final ChromeData d;
  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(shellAppsProvider(theme));
    final suggestions = FolderSuggestions.propose(apps, theme.prefs);
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    if (suggestions.isEmpty) {
      return _Copy(
        d: d,
        title: 'Ready',
        blurb: 'Drag one app onto another in the drawer to make a folder.',
      );
    }

    return _Copy(
      d: d,
      title: 'Tidy the drawer',
      blurb: 'We spotted ${suggestions.length} groups worth folding up.',
      child: Column(
        children: [
          ThemedButton(
            label: 'Create all ${suggestions.length} folders',
            icon: Icons.auto_awesome_outlined,
            expand: true,
            onPressed: () => notifier.edit(
              (p) => FolderSuggestions.acceptAll(
                p,
                suggestions,
                newFolderId: newDrawerFolderId,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            // Honest about the alternative: skipping loses nothing, and the
            // Folders page can bring them back.
            'Or skip — they stay available in Settings → Folders.',
            style: d.text.caption,
          ),
        ],
      ),
    );
  }
}

// ── Chrome ───────────────────────────────────────────────────────────────────

class _Seg extends StatelessWidget {
  const _Seg({
    required this.d,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final ChromeData d;
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = d.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: d.text.label),
        const SizedBox(height: 7),
        Row(
          children: [
            for (final e in options.entries)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(e.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == value ? c.accent : c.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: d.text.body.copyWith(
                        color: e.key == value ? c.onAccent : c.text,
                        fontWeight: e.key == value
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One quiet line, not a card: by this point the user has already said no twice
/// and a second full-size plea would be nagging rather than reminding.
class _NagLine extends StatelessWidget {
  const _NagLine({required this.onFix});

  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return GestureDetector(
      onTap: onFix,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(Icons.home_outlined, size: 15, color: c.warn),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'G Launcher is not your home app',
                style: d.text.caption.copyWith(color: c.warn),
              ),
            ),
            Text(
              'Fix',
              style: d.text.caption
                  .copyWith(color: c.warn, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i <= step ? c.accent : c.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.step,
    required this.lastStep,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final int lastStep;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          ThemedButton(
            label: 'Back',
            kind: ThemedButtonKind.text,
            onPressed: onBack!,
          ),
        const Spacer(),
        ThemedButton(
          label: switch (step) {
            0 => 'Get started',
            final s when s == lastStep => 'Boot the desktop',
            _ => 'Next',
          },
          onPressed: onNext,
        ),
      ],
    );
  }
}
