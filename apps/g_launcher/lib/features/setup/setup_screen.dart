import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../engine/theme_registry.dart';
import '../../engine/theme_spec.dart';
import '../drawer/drawer_actions.dart';
import 'setup_chrome.dart';

/// **Initial setup, as a distro installer.** T1.
///
/// The previous version was a live full-bleed desktop with a translucent panel
/// of controls floating over it. It read as vibe-coded for a reason that is
/// worth writing down rather than re-litigating: it had no chrome, so it had no
/// identity. A preview of the product is not the product, and a panel with no
/// frame is a form.
///
/// This is an installer. [SetupInstallerFrame] owns the window, the step rail
/// and the footer; [SetupSkin] decides which installer, keyed by SHELL, so
/// choosing the terminal distro at step 3 turns the remaining steps into a
/// console and choosing Aqua turns them into a centred assistant. That live
/// re-skin is the single best demonstration the launcher has, and it costs
/// nothing extra because the theme already applies the moment it is picked.
///
/// ─── WHAT SETUP DELIBERATELY DOES NOT DO ───────────────────────────────────
///
/// **No "try it first".** Android cannot preview a home screen without the app
/// holding the home role, so the option would be a promise the launcher cannot
/// keep. It is shown, disabled, with the reason, rather than hidden: someone
/// who expects the choice should see that it was considered.
///
/// **No fiction about destroying anything.** The frame, the rail, the progress
/// and the language of an install are all here. The words "erase", "format" and
/// "partition" are not, and must not be added. A budget-phone user who
/// half-reads a screen that says "erase disk" will uninstall in a panic, and
/// they will be right to.
///
/// **The install step runs once, ever.** It is the first-run payoff, not a
/// loading screen: it is not on the theme-switch path, and switching distro in
/// Settings later shows only the boot log or the splash. See [_stepsFor].
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

/// The distros offered during setup: whatever is bundled.
///
/// There is no curated list here any more, and that is the point. Bundled
/// implies free (see theme_registry), so the set setup may offer and the set
/// that ships in the APK are the same set by construction, and a fourth
/// bundled distro appears in setup with no edit to this file.
///
/// The tier is still checked on load rather than assumed. It costs one string
/// compare and it means a paid theme accidentally left in the APK does not
/// quietly become free at first run.
/// One line describing what the desktop looks like, keyed by SHELL.
///
/// Keyed by shell for the same reason every other default in the theme layer
/// is: a new GNOME distro should inherit "top bar, dock down the left" without
/// authoring anything, and only override where it genuinely differs.
///
/// It belongs in theme.json eventually, as a `tagline` beside `name` and
/// `version`. It is here because adding a ThemeSpec field to ship one sentence
/// per shell is the wrong order to do things in.
String _taglineFor(ShellKind shell) => switch (shell) {
      ShellKind.gnome => 'Top bar, dock down the left, activities overview',
      ShellKind.plasma => 'Bottom panel, kickoff menu, system tray',
      ShellKind.tiling => 'No dock. A status bar and a keyboard launcher',
      ShellKind.tui => 'No desktop at all. A prompt, and commands that stay',
      ShellKind.aqua => 'Menu bar across the top, magnifying dock below',
    };

/// The specs behind [bundledThemes], loaded from their assets.
///
/// Reads the REAL [ThemeSpec] rather than a catalogue card, because the rows
/// need `name`, `version`, `tier` and `palette`, and those already exist in
/// data. A row that says "Ubuntu 24.04 LTS" should be reading 24.04 out of the
/// theme, not out of a table in Dart that will disagree with it by Christmas.
final setupDistrosProvider = FutureProvider<List<ThemeSpec>>((ref) async {
  final out = <ThemeSpec>[];
  for (final bundled in bundledThemes.values) {
    try {
      final raw = await rootBundle.loadString(bundled.assetPath);
      final spec = ThemeSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (spec.tier != 'free') continue;
      out.add(spec);
    } catch (_) {
      // A distro that will not parse is simply not offered. The floor is
      // guaranteed elsewhere: activeThemeSpecProvider always lands on Ubuntu.
    }
  }
  return out;
});

class _SetupScreenState extends ConsumerState<SetupScreen>
    with WidgetsBindingObserver {
  /// The CURRENT step, held as the enum rather than as an index.
  ///
  /// Load-bearing. The step list is derived from the shell and SHRINKS when the
  /// user picks the terminal at the distro step, so an index would suddenly
  /// point at a different screen (or off the end) the moment they tapped. The
  /// enum survives the list changing under it.
  _SetupStep _step = _SetupStep.welcome;

  bool _isDefault = false;

  /// How many times Continue has been pressed on the home-role step.
  ///
  /// Deliberately NOT persisted: it counts presses within this wizard, and a
  /// user who reinstalls deserves the same three chances rather than inheriting
  /// a grudge from a previous install.
  int _homeAttempts = 0;
  bool _showHomeWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDefaultLauncher();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// THE ONLY MOMENT THE ANSWER CAN HAVE CHANGED.
  ///
  /// This fixes a real bug: the launcher kept insisting it was not the home app
  /// after the user had just made it the home app.
  ///
  /// `requestDefaultLauncher` is a void Pigeon method. It fires an intent and
  /// returns immediately, NOT when the user finishes choosing. So the old
  /// `await request(); await refresh();` asked the question while Android's
  /// picker was still on screen, got `false`, and kept the nag for the rest of
  /// the session. The detection was always correct; the timing was not.
  ///
  /// Coming back from the picker is an app RESUME, so that is where the
  /// re-check belongs. Anywhere else in the app that shows this nag needs the
  /// same observer for the same reason.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDefaultLauncher();
  }

  Future<void> _refreshDefaultLauncher() async {
    final ok = await ref.read(launcherHostApiProvider).isDefaultLauncher();
    if (mounted) setState(() => _isDefault = ok);
  }

  /// Fire and forget, deliberately.
  ///
  /// No re-check here on purpose: see [didChangeAppLifecycleState]. Asking
  /// straight after this call is what caused the bug, so the call site is left
  /// with a comment rather than a tempting blank line.
  Future<void> _openHomePicker() async {
    await ref.read(launcherHostApiProvider).requestDefaultLauncher();
  }

  /// The three-strike gate. Returns true when the wizard may advance.
  Future<bool> _homeGate() async {
    if (_isDefault) return true;

    _homeAttempts++;
    Analytics.homeRolePrompt(attempt: _homeAttempts, granted: false);

    if (_homeAttempts == 1) {
      // Straight to Android's picker. No dialog of ours in front of it: an
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
    if (_step == _SetupStep.home) {
      final mayPass = await _homeGate();
      if (!mayPass) return;
    }

    final steps = _stepsFor(_shell);
    final i = steps.indexOf(_step);
    if (i >= 0 && i < steps.length - 1) {
      setState(() => _step = steps[i + 1]);
    }
  }

  void _back() {
    final steps = _stepsFor(_shell);
    final i = steps.indexOf(_step);
    if (i > 0) setState(() => _step = steps[i - 1]);
  }

  ShellKind? get _shell =>
      ref.read(effectiveThemeProvider).asData?.value.shell;

  /// Called by the install step when its progress completes, never by a button.
  Future<void> _finish() async {
    final themeId =
        ref.read(selectedThemeIdProvider).asData?.value ?? fallbackThemeId;
    Analytics.setupComplete(themeId: themeId, granted: _isDefault);

    // Hand-off flag first, then the completion that swaps this screen out: the
    // desktop mounts fresh and reads the flag on that very build.
    ref.read(firstRunBootPendingProvider.notifier).state = true;
    await ref.read(setupCompletedProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(effectiveThemeProvider).asData?.value;

    // ChromeScope is normally installed by ThemedScaffold. This screen builds
    // its own frame, so it has to provide the chrome itself, otherwise every
    // ChromeScope.of below throws. Bootstrap while the theme loads, exactly as
    // ThemedScaffold does, so there is no un-themed flash.
    final chrome = theme == null
        ? ChromeData.bootstrap
        : ChromeData.fromPalette(
            theme.palette,
            typography: theme.typography,
            textScale: theme.textScale,
            family: theme.chromeFamily,
          );

    final skin = theme == null
        ? SetupSkin.defaultForShell(ShellKind.gnome)
        : SetupSkin.defaultForShell(theme.shell);

    return ChromeScope(
      data: chrome,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: theme == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [theme.palette.bgTop, theme.palette.bgBottom],
                  ),
          ),
          child: SafeArea(
            child: theme == null
                ? const SizedBox.shrink()
                : Builder(
                    builder: (_) {
                      final steps = _stepsFor(theme.shell);
                      // The list can shrink under the user (terminal drops four
                      // steps), so never trust a stale enum: fall back to the
                      // first step rather than rendering nothing.
                      final i = steps.indexOf(_step) < 0
                          ? 0
                          : steps.indexOf(_step);
                      final current = steps[i];

                      return SetupInstallerFrame(
                        skin: skin,
                        steps: [for (final st in steps) st.label],
                        step: i,
                        windowTitle: _windowTitle(theme, skin),
                        title: _title(current),
                        subtitle: _subtitle(current),
                        status: 'Step ${i + 1} of ${steps.length}',
                        footerNote: !_isDefault && i > steps.indexOf(_SetupStep.home)
                            ? _NagLine(onFix: _openHomePicker)
                            : null,
                        onBack: i == 0 || current == _SetupStep.install
                            ? null
                            : _back,
                        onNext: _next,
                        nextLabel: switch (current) {
                          _SetupStep.welcome => 'Get started',
                          // The step before install, whichever it is: on the
                          // terminal that is the distro step, not folders.
                          final st when st == steps[steps.length - 2] =>
                            'Install',
                          _ => 'Continue',
                        },
                        body: _body(theme, skin, current),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// "Install Ubuntu". Reads the distro's own name, so a CDN pack titles its
  /// own installer with no code change.
  String _windowTitle(EffectiveTheme theme, SetupSkin skin) =>
      skin.kind == SetupFrameKind.console
          ? '${theme.spec.name.toLowerCase()}-install'
          : 'Install ${theme.spec.name}';

  String _title(_SetupStep step) => switch (step) {
        _SetupStep.welcome => 'Welcome',
        _SetupStep.home => _isDefault
            ? 'Home screen set'
            : (_showHomeWarning ? 'Really skip this?' : 'Home screen'),
        _SetupStep.distro => 'Choose your desktop',
        _SetupStep.dock => 'Dock',
        _SetupStep.drawer => 'App drawer',
        _SetupStep.folders => 'Folders',
        _SetupStep.install => 'Installing system',
      };

  String? _subtitle(_SetupStep step) => switch (step) {
        _SetupStep.welcome => 'A Linux desktop on your phone.',
        _SetupStep.home => _isDefault
            ? 'The rest is how it should look.'
            : 'Android only hands the full app list to the app holding the '
                'home role.',
        _SetupStep.distro => 'More desktops are available later in Settings.',
        _SetupStep.dock => 'Where your pinned apps live.',
        _SetupStep.drawer =>
          'How the full app list is laid out and how it moves.',
        _SetupStep.folders =>
          'Group apps automatically. You can undo any of this.',
        _SetupStep.install => 'This only happens once.',
      };

  Widget _body(EffectiveTheme theme, SetupSkin skin, _SetupStep step) =>
      switch (step) {
        _SetupStep.welcome => _StepWelcome(mono: skin.mono),
        _SetupStep.home => _StepHome(
            isDefault: _isDefault,
            showWarning: _showHomeWarning,
            mono: skin.mono,
            onRequest: _openHomePicker,
          ),
        _SetupStep.distro => _StepDistro(mono: skin.mono),
        _SetupStep.dock => _StepDock(theme: theme, mono: skin.mono),
        _SetupStep.drawer => _StepDrawer(theme: theme, mono: skin.mono),
        _SetupStep.folders => _StepFolders(theme: theme, mono: skin.mono),
        _SetupStep.install =>
          _StepInstall(theme: theme, skin: skin, onDone: _finish),
      };
}

/// Every step this wizard can show. Which of them it DOES show is
/// [_stepsFor].
enum _SetupStep {
  welcome('Welcome'),
  home('Home screen'),
  distro('Desktop'),
  dock('Dock'),
  drawer('App drawer'),
  folders('Folders'),
  install('Install');

  const _SetupStep(this.label);

  /// The rail label. On the enum so the rail and the switch cannot drift.
  final String label;
}

/// The steps that make sense for a shell.
///
/// ─── THE TERMINAL HAS NO GUI, SO IT HAS NO GUI QUESTIONS ────────────────────
///
/// The TUI shell has no dock, no app-grid button, no drawer columns, no scroll
/// style and no folder grid. Asking about any of them would be asking the user
/// to configure things that will never appear, and then showing a rail that
/// counts them. So the terminal installs in four steps and the wizard is
/// honest about its own length.
///
/// Keyed by SHELL, like every other default in the theme layer. A future
/// GUI-less distro inherits this without authoring anything, and a new
/// graphical one inherits the full list.
///
/// [_SetupStep.welcome], [_SetupStep.home] and [_SetupStep.install] are in
/// every list: the first two are about Android rather than about the desktop,
/// and the third is the hand-off to the boot sequence.
List<_SetupStep> _stepsFor(ShellKind? shell) {
  if (shell == ShellKind.tui) {
    return const [
      _SetupStep.welcome,
      _SetupStep.home,
      _SetupStep.distro,
      _SetupStep.install,
    ];
  }
  return const [
    _SetupStep.welcome,
    _SetupStep.home,
    _SetupStep.distro,
    _SetupStep.dock,
    _SetupStep.drawer,
    _SetupStep.folders,
    _SetupStep.install,
  ];
}

// ── Steps ────────────────────────────────────────────────────────────────────

/// Welcome.
///
/// ONE row, already selected, and a second that is visibly disabled.
///
/// The disabled row is not decoration. "Try it first" is the obvious thing to
/// want and the obvious thing to offer, and it cannot work: without the home
/// role Android withholds most of the app list, so a trial mode would show a
/// half-empty drawer and read as a broken launcher rather than as a preview.
/// Showing it greyed with the reason answers the question before it is asked.
/// Hiding it invites someone to add it later without knowing why it went.
class _StepWelcome extends StatelessWidget {
  const _StepWelcome({required this.mono});

  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SetupRow(
          title: 'Install as your home screen',
          subtitle: 'Takes about a minute. Nothing is deleted.',
          selected: true,
          mono: mono,
          onTap: () {},
        ),
        SetupRow(
          title: 'Try it first',
          subtitle:
              'Not possible on Android: the app list stays hidden until an '
              'app holds the home role.',
          selected: false,
          enabled: false,
          mono: mono,
          onTap: () {},
        ),
      ],
    );
  }
}

class _StepHome extends StatelessWidget {
  const _StepHome({
    required this.isDefault,
    required this.showWarning,
    required this.mono,
    required this.onRequest,
  });

  final bool isDefault;
  final bool showWarning;
  final bool mono;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);

    if (isDefault) {
      return SetupRow(
        title: 'G Launcher is your home app',
        subtitle: 'Change this any time in Android Settings.',
        selected: true,
        marker: SetupMarker.check,
        mono: mono,
        onTap: () {},
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showWarning) ...[
          Text(
            'Without the home role the home button keeps opening your old '
            'launcher, and most of your apps stay hidden from the drawer.',
            softWrap: true,
            style: d.text.caption.copyWith(color: d.colors.warn),
          ),
          const SizedBox(height: 12),
        ],
        ThemedButton(
          label: showWarning ? 'Set as home app' : 'Choose G Launcher',
          icon: Icons.home_outlined,
          expand: true,
          onPressed: onRequest,
        ),
      ],
    );
  }
}

/// The distro step. Rows, real specs, Ubuntu preselected.
///
/// Selecting applies the theme LIVE, which re-skins this screen underneath the
/// finger: pick the terminal and the wizard becomes a console before the row
/// has finished highlighting. That is the demo, and it is why this step is
/// third rather than last.
class _StepDistro extends ConsumerWidget {
  const _StepDistro({required this.mono});

  final bool mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specs = ref.watch(setupDistrosProvider).asData?.value ?? const [];
    final active =
        ref.watch(selectedThemeIdProvider).asData?.value ?? fallbackThemeId;

    return Column(
      children: [
        for (final spec in specs)
          SetupRow(
            title: spec.name,
            subtitle: _taglineFor(spec.shell),
            // The pinned version, straight out of theme.json. A distro that
            // does not version itself (Arch is rolling, Aqua is unversioned on
            // purpose) shows nothing rather than an empty gap.
            trailing: spec.version.isEmpty ? null : spec.version,
            selected: spec.id == active,
            mono: mono,
            marker: mono ? SetupMarker.chevron : SetupMarker.radio,
            onTap: () {
              Analytics.themeSelected(spec.id);
              ref.read(selectedThemeIdProvider.notifier).select(spec.id);
            },
          ),
      ],
    );
  }
}

class _StepDock extends ConsumerWidget {
  const _StepDock({required this.theme, required this.mono});

  final EffectiveTheme theme;
  final bool mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final grid = theme.prefs.dockGridButton ?? 'end';

    return Column(
      children: [
        _Preview(
          theme: theme,
          mode: DevicePreviewMode.desktop,
          gridButton: grid,
        ),
        const SizedBox(height: 14),
        SetupRow(
          title: 'Down the left edge',
          subtitle: 'How ${theme.spec.name} ships.',
          selected: theme.dock == DockSide.left,
          mono: mono,
          marker: mono ? SetupMarker.chevron : SetupMarker.radio,
          onTap: () => notifier.edit((p) => p.copyWith(dockSide: 'left')),
        ),
        SetupRow(
          title: 'Along the bottom',
          selected: theme.dock == DockSide.bottom,
          mono: mono,
          marker: mono ? SetupMarker.chevron : SetupMarker.radio,
          onTap: () => notifier.edit((p) => p.copyWith(dockSide: 'bottom')),
        ),
        SetupRow(
          title: 'No dock',
          subtitle: 'The drawer is still one swipe away.',
          selected: theme.dock == DockSide.off,
          mono: mono,
          marker: mono ? SetupMarker.chevron : SetupMarker.radio,
          onTap: () => notifier.edit((p) => p.copyWith(dockSide: 'off')),
        ),
        if (theme.dock != DockSide.off) ...[
          const SizedBox(height: 8),
          _MiniLabel(text: 'App grid button'),
          for (final e in const {
            'end': 'At the far end of the dock',
            'start': 'First in the dock',
            'off': 'Hidden',
          }.entries)
            SetupRow(
              title: e.value,
              selected: grid == e.key,
              mono: mono,
              marker: mono ? SetupMarker.chevron : SetupMarker.radio,
              onTap: () =>
                  notifier.edit((p) => p.copyWith(dockGridButton: e.key)),
            ),
        ],
      ],
    );
  }
}

class _StepDrawer extends ConsumerWidget {
  const _StepDrawer({required this.theme, required this.mono});

  final EffectiveTheme theme;
  final bool mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    // Pages, matching the drawer's own fallback. Setup showing 'List'
    // preselected while the drawer actually came up paged was a lie the
    // user would only catch after finishing.
    final style = theme.prefs.drawerScrollStyle ?? 'pages';

    return Column(
      children: [
        _Preview(
          theme: theme,
          mode: DevicePreviewMode.drawer,
          cols: theme.drawerCols,
        ),
        const SizedBox(height: 14),
        _MiniLabel(text: 'Columns'),
        Row(
          children: [
            for (final n in const [3, 4, 5, 6])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SetupRow(
                    title: '$n',
                    selected: theme.drawerCols == n,
                    mono: mono,
                    marker: mono ? SetupMarker.chevron : SetupMarker.radio,
                    onTap: () =>
                        notifier.edit((p) => p.copyWith(drawerCols: n)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _MiniLabel(text: 'How it moves'),
        // Pages first, because it is the default and the list should read
        // top-down in the order of likelihood rather than alphabetically.
        for (final e in const {
          'pages': ('Pages', 'Swipe sideways. Wraps around at the end.'),
          'cube': ('Cube', 'The pages are faces of a solid.'),
          'vertical': ('One long list', 'Scrolls up and down.'),
        }.entries)
          SetupRow(
            title: e.value.$1,
            subtitle: e.value.$2,
            selected: style == e.key,
            mono: mono,
            marker: mono ? SetupMarker.chevron : SetupMarker.radio,
            onTap: () =>
                notifier.edit((p) => p.copyWith(drawerScrollStyle: e.key)),
          ),
      ],
    );
  }
}

class _StepFolders extends ConsumerWidget {
  const _StepFolders({required this.theme, required this.mono});

  final EffectiveTheme theme;
  final bool mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final apps = ref.watch(shellAppsProvider(theme));
    final suggestions = FolderSuggestions.propose(apps, theme.prefs);
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    if (suggestions.isEmpty) {
      return Text(
        'Nothing worth grouping yet. Drag one app onto another in the drawer '
        'to make a folder.',
        softWrap: true,
        style: d.text.body.copyWith(color: d.colors.textMuted),
      );
    }

    // ONE ROW, NOT ONE ROW PER SUGGESTION.
    //
    // Listing each proposed folder by name with its app count is the better
    // screen and it is the one this step should end up as. It needs
    // FolderSuggestions to expose a name and a member list per suggestion,
    // which is a change to folder_suggestions.dart and belongs with the
    // Social / Entertainment / Tools categories rather than being guessed at
    // here. Until then this is the shape that already worked.
    return Column(
      children: [
        SetupRow(
          title: 'Create ${suggestions.length} folders',
          subtitle: 'Grouped by what the apps say they are.',
          selected: true,
          marker: SetupMarker.check,
          mono: mono,
          onTap: () {},
        ),
        const SizedBox(height: 6),
        ThemedButton(
          label: 'Create ${suggestions.length} folders',
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
          'Skipping loses nothing. They stay available in Settings, Folders.',
          softWrap: true,
          style: d.text.caption.copyWith(color: d.colors.textMuted),
        ),
      ],
    );
  }
}

/// The fake install.
///
/// ONCE, EVER. Not on the theme-switch path, not on cold start: this is the
/// first-run payoff and nothing else. Switching distro later in Settings shows
/// the boot log or the splash, which are the repeatable ones.
///
/// Roughly two and a half seconds. Long enough to land, short enough that it
/// does not become the third theatrical screen in a row before anyone has
/// touched the desktop, which is the failure mode: the boot log and the splash
/// still follow this.
///
/// The lines are keyed by SHELL, so a console install talks like pacstrap and a
/// wizard talks like Ubiquity. Nothing here mentions erasing, formatting or
/// partitioning, and nothing here ever should.
class _StepInstall extends StatefulWidget {
  const _StepInstall({
    required this.theme,
    required this.skin,
    required this.onDone,
  });

  final EffectiveTheme theme;
  final SetupSkin skin;
  final Future<void> Function() onDone;

  @override
  State<_StepInstall> createState() => _StepInstallState();
}

class _StepInstallState extends State<_StepInstall> {
  static const _tickMs = 380;

  Timer? _timer;
  int _line = 0;
  late final List<String> _lines = _linesFor(widget.theme.shell);

  static List<String> _linesFor(ShellKind shell) => switch (shell) {
        ShellKind.tui => const [
            'mounting /proc /sys /dev',
            'installing base packages',
            'reading installed applications',
            'writing profile',
            'enabling g-tty autologin',
            'done',
          ],
        ShellKind.aqua => const [
            'Preparing your desktop',
            'Applying appearance',
            'Reading your apps',
            'Setting up the Dock',
            'Almost there',
            'Done',
          ],
        _ => const [
            'Copying desktop files',
            'Applying theme and icons',
            'Reading installed applications',
            'Building the dock',
            'Configuring folders',
            'Done',
          ],
      };

  @override
  void initState() {
    super.initState();
    // Reduce-motion is honoured by the caller chain elsewhere; here the whole
    // step is short enough that the honest opt-out is to run it anyway and let
    // the boot gate behind it handle the long one.
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (t) {
      if (!mounted) return;
      if (_line >= _lines.length - 1) {
        t.cancel();
        widget.onDone();
        return;
      }
      setState(() => _line++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final progress = (_line + 1) / _lines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: c.line,
            valueColor: AlwaysStoppedAnimation<Color>(c.accent),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i <= _line; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _lines[i],
              softWrap: true,
              style: d.text.caption.copyWith(
                color: i == _line ? c.text : c.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Chrome ───────────────────────────────────────────────────────────────────

/// A small framed phone showing the setting being changed.
///
/// FRAMED, unlike the old full-bleed backdrop. Once the installer has a window
/// of its own, a second full-bleed surface behind it fights the frame: you
/// cannot tell which of the two things on screen you are configuring. A phone
/// inside the content area is unambiguous, and it is also how every real
/// installer shows a layout choice.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.theme,
    required this.mode,
    this.cols,
    this.gridButton,
  });

  final EffectiveTheme theme;
  final DevicePreviewMode mode;
  final int? cols;
  final String? gridButton;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Center(
        child: DevicePreview(
          palette: theme.palette,
          framed: true,
          mode: mode,
          dock: theme.dock,
          gridButton: gridButton ?? theme.prefs.dockGridButton ?? 'end',
          cols: cols ?? theme.drawerCols,
          rows: theme.prefs.folderRows ?? 3,
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          text,
          style: d.text.label.copyWith(color: d.colors.textMuted),
        ),
      ),
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
      child: Row(
        children: [
          Icon(Icons.home_outlined, size: 15, color: c.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'G Launcher is not your home app',
              softWrap: true,
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
    );
  }
}
