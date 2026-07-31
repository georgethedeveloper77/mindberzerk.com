import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../data/prefs/folder_suggestions.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/setup_state.dart';
import '../../data/prefs/starter_desktop.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../design/components/components.dart';
import '../../design/device_preview.dart';
import '../../engine/effective_theme.dart';
// AppEntry, for resolving a suggestion's componentKeys into icons.
import '../../platform/launcher_api.g.dart';
import '../../system/wallpaper_source.dart';
import '../drawer/app_icon.dart';
import '../drawer/folder_glyph.dart';
import '../../engine/theme_registry.dart';
import '../../engine/theme_spec.dart';
import '../../i18n/i18n.dart';
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
/// Returns a KEY, not a sentence.
///
/// The strings were extracted into en.json a while ago and this switch kept
/// returning the English ones, so a French install read every distro's
/// description in English. Returning the key and resolving at the call site is
/// what lets a switch like this be translated at all: `ref.t` needs a WidgetRef
/// and a switch on an enum has no business taking one.
String _taglineKeyFor(ShellKind shell) => switch (shell) {
      ShellKind.gnome => 'setup.topBarDockDown',
      ShellKind.plasma => 'setup.bottomPanelKickoffMenu',
      ShellKind.tiling => 'setup.noDockAStatus',
      ShellKind.tui => 'setup.noDesktopAtAll',
      ShellKind.aqua => 'setup.menuBarAcrossThe',
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

  /// Folders step: ON BY DEFAULT. The suggested folders (Games first among
  /// them) are created when the user advances past the step unless they
  /// untick it — creation is the default outcome, not a button they must
  /// find. Cleared folders remain available later in Settings > Folders.
  bool _createFolders = true;

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
    if (_step == _SetupStep.welcome) {
      final mayPass = await _homeGate();
      if (!mayPass) return;
    }

    // Leaving the folders step with the toggle still on creates the suggested
    // folders. On advance, not on a button: the default outcome should not
    // require finding a button, and unticking the row is the opt-out.
    // Best-effort like the desktop seeding — a grouping failure must never
    // block setup.
    if (_step == _SetupStep.folders && _createFolders) {
      try {
        final theme = ref.read(effectiveThemeProvider).asData?.value;
        if (theme != null) {
          final apps = ref.read(shellAppsProvider(theme));
          final suggestions = FolderSuggestions.propose(apps, theme.prefs);
          if (suggestions.isNotEmpty) {
            await ref.read(prefsProvider(theme.spec.id).notifier).edit(
                  (p) => FolderSuggestions.acceptAll(
                    p,
                    suggestions,
                    newFolderId: newDrawerFolderId,
                  ),
                );
          }
        }
      } catch (e, s) {
        debugPrint('setup: creating suggested folders failed: $e\n$s');
      }
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

  ShellKind? get _shell => ref.read(effectiveThemeProvider).asData?.value.shell;

  /// Called by the install step when its progress completes, never by a button.
  Future<void> _finish() async {
    final themeId =
        ref.read(selectedThemeIdProvider).asData?.value ?? fallbackThemeId;
    Analytics.setupComplete(themeId: themeId, granted: _isDefault);

    // Furnish the first desktop BEFORE it is ever shown, so a fresh install
    // reads as a set-up desktop rather than a blank one. This is also the only
    // place `StarterDesktop.apply` is wired in — without it, an authored
    // `desklets.starter` block in a theme.json would never take effect.
    //
    // BEST-EFFORT, and never allowed to block completion. A desktop that comes
    // up empty is recoverable (add from the picker); a setup that never finishes
    // because furnishing threw is not. So a failure here is swallowed and the
    // wizard still hands off to the desktop.
    try {
      await _seedFirstDesktop();
    } catch (e, s) {
      debugPrint('setup: seeding first desktop failed: $e\n$s');
    }

    // Hand-off flag first, then the completion that swaps this screen out: the
    // desktop mounts fresh and reads the flag on that very build.
    ref.read(firstRunBootPendingProvider.notifier).state = true;
    await ref.read(setupCompletedProvider.notifier).complete();
  }

  /// Apply the chosen distro's authored starter desklets, once, at the end of
  /// setup. A no-op until a theme ships a `desklets.starter` block — and this
  /// is the only place `StarterDesktop.apply` is wired in, so without this
  /// call an authored block would never take effect.
  ///
  /// The old Glance-tile fallback (seed a default widget onto any empty
  /// graphical desktop) was REMOVED deliberately: a fresh desktop now comes up
  /// clean, and widgets are something the user adds, not something the
  /// installer leaves behind. Only content a distro explicitly authors gets
  /// placed.
  Future<void> _seedFirstDesktop() async {
    final theme = ref.read(effectiveThemeProvider).asData?.value;
    if (theme == null) return;

    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    var n = 0;
    String newId() => 'dk${DateTime.now().microsecondsSinceEpoch}_${n++}';

    await notifier.edit(
      (p) => StarterDesktop.apply(
        p,
        theme.spec.desklets,
        cols: theme.cols,
        rows: theme.rows,
        newId: newId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // hasValue, not asData: asData is null through a RELOAD, and every prefs
    // write is a reload. See home_screen.dart.
    final themeAsync = ref.watch(effectiveThemeProvider);
    final theme = themeAsync.hasValue ? themeAsync.requireValue : null;

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
            opacity: theme.surfaceOpacity,
          );

    final skin = theme == null
        ? SetupSkin.defaultForShell(ShellKind.gnome)
        : SetupSkin.defaultForShell(theme.shell);

    return ChromeScope(
      data: chrome,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // ─── THE INSTALLER RUNS OVER THE LIVE SESSION'S WALLPAPER ────────
        //
        // It used to be a flat two-stop gradient of the palette, and that is
        // the single biggest reason the wizard read as a phone form rather than
        // a desktop. You do not install Ubuntu on a purple rectangle; you
        // install it from a live session, with the distro's own wallpaper
        // behind the window and the installer floating on top. The frame was
        // ALREADY drawing a floating window over this; there was just nothing
        // underneath worth floating over.
        //
        // The gradient stays as the layer beneath, so a theme with no
        // wallpaper, or one whose image has not decoded yet, looks exactly as
        // it does today rather than flashing black.
        //
        // `spec.asset` is what knows whether this distro's files are in the APK
        // or in `packs/<id>/`, and it is the only thing that does. Handing the
        // raw string to an AssetImage works for a bundled theme and silently
        // renders nothing for a downloaded one, which is the same trap
        // `wallpaper_source.dart` documents at length.
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: theme == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [theme.palette.bgTop, theme.palette.bgBottom],
                  ),
            image: _wallpaperFor(theme),
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
                      final i =
                          !steps.contains(_step) ? 0 : steps.indexOf(_step);
                      final current = steps[i];

                      return SetupInstallerFrame(
                        skin: skin,
                        steps: [
                          for (final st in steps) ref.t('setup.step.${st.name}')
                        ],
                        step: i,
                        windowTitle: _windowTitle(theme, skin),
                        title: _title(current),
                        subtitle: _subtitle(current),
                        status: ref.t('setup.status', {
                          'n': '${i + 1}',
                          'total': '${steps.length}',
                        }),
                        footerNote:
                            !_isDefault && i > steps.indexOf(_SetupStep.welcome)
                                ? _NagLine(onFix: _openHomePicker)
                                : null,
                        onBack: i == 0 || current == _SetupStep.install
                            ? null
                            : _back,
                        onNext: _next,
                        nextLabel: switch (current) {
                          _SetupStep.welcome => ref.t('setup.next.getStarted'),
                          // The step before install, whichever it is: on the
                          // terminal that is the distro step, not folders.
                          final st when st == steps[steps.length - 2] =>
                            ref.t('setup.next.install'),
                          _ => ref.t('setup.next.continue'),
                        },
                        body: _body(theme, skin, current),
                        // The welcome step is the one built around a LIST, so
                        // it is the one that should grow into the window. The
                        // rest are a handful of rows and look wrong stretched.
                        fills: current == _SetupStep.welcome,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// The distro's own wallpaper, dimmed, as the installer's backdrop.
  ///
  /// Null whenever there is nothing safe to show: no theme yet, no wallpaper
  /// authored, or a source that is not a theme reference (a user photo cannot
  /// exist during setup, but the predicate is the one place that rule lives and
  /// reusing it beats reimplementing it here).
  ///
  /// Dimmed hard, because this is a BACKDROP. An undimmed photo behind a
  /// translucent window makes the installer text unreadable, and the real live
  /// session dims the desktop behind its installer for exactly that reason.
  DecorationImage? _wallpaperFor(EffectiveTheme? theme) {
    if (theme == null) return null;

    final source = theme.spec.wallpapers.isNotEmpty
        ? theme.spec.wallpapers.first
        : null;
    if (source == null || !isThemeAssetRef(source)) return null;

    return DecorationImage(
      image: theme.spec.asset(source).image,
      fit: BoxFit.cover,
      // The SPEC's palette, not the resolved one, for the same reason the
      // splash uses it: this is a scrim over a photograph, and dimming a
      // photograph with a near-white wash does not dim it, it bleaches it.
      // Light mode made `theme.palette.bgBottom` pale, so the installer's
      // backdrop went from a dark aubergine veil to a white haze.
      //
      // A live session dims the desktop behind its installer whichever theme
      // the session is running.
      colorFilter: ColorFilter.mode(
        theme.spec.palette.bgBottom.withValues(alpha: 0.72),
        BlendMode.srcOver,
      ),
    );
  }

  /// "Install Ubuntu". Reads the distro's own name, so a CDN pack titles its
  /// own installer with no code change.
  String _windowTitle(EffectiveTheme theme, SetupSkin skin) {
    if (skin.kind == SetupFrameKind.console) {
      return ref
          .t('setup.window.console', {'name': theme.spec.name.toLowerCase()});
    }
    // The reference titles its first page "Welcome to Ubuntu" and only later
    // pages "Install ...", so the window title tracks the step.
    return _step == _SetupStep.welcome
        ? ref.t('setup.window.welcome', {'name': theme.spec.name})
        : ref.t('setup.window.install', {'name': theme.spec.name});
  }

  String _title(_SetupStep step) => switch (step) {
        _SetupStep.welcome => ref.t('setup.welcome.chooseLanguage'),
        _SetupStep.distro => ref.t('setup.title.distro'),
        _SetupStep.appearance => ref.t('setup.title.appearance'),
        _SetupStep.dock => ref.t('setup.title.dock'),
        _SetupStep.drawer => ref.t('setup.title.drawer'),
        _SetupStep.folders => ref.t('setup.title.folders'),
        _SetupStep.install => ref.t('setup.title.install'),
      };

  String? _subtitle(_SetupStep step) => switch (step) {
        // The reference has no line under "Choose your language:".
        _SetupStep.welcome => null,
        _SetupStep.distro => ref.t('setup.subtitle.distro'),
        _SetupStep.appearance => ref.t('setup.subtitle.appearance'),
        _SetupStep.dock => ref.t('setup.subtitle.dock'),
        _SetupStep.drawer => ref.t('setup.subtitle.drawer'),
        _SetupStep.folders => ref.t('setup.subtitle.folders'),
        _SetupStep.install => ref.t('setup.subtitle.install'),
      };

  Widget _body(EffectiveTheme theme, SetupSkin skin, _SetupStep step) =>
      switch (step) {
        _SetupStep.welcome => _StepWelcome(
            mono: skin.mono,
            isDefault: _isDefault,
            showWarning: _showHomeWarning,
            onRequest: _openHomePicker,
          ),
        _SetupStep.distro => _StepDistro(mono: skin.mono),
        _SetupStep.appearance =>
          _StepAppearance(theme: theme, mono: skin.mono),
        _SetupStep.dock => _StepDock(theme: theme, mono: skin.mono),
        _SetupStep.drawer => _StepDrawer(theme: theme, mono: skin.mono),
        _SetupStep.folders => _StepFolders(
            theme: theme,
            mono: skin.mono,
            createFolders: _createFolders,
            onCreateFoldersChanged: (v) => setState(() => _createFolders = v),
          ),
        _SetupStep.install =>
          _StepInstall(theme: theme, skin: skin, onDone: _finish),
      };
}

/// Every step this wizard can show. Which of them it DOES show is
/// [_stepsFor].
enum _SetupStep {
  welcome('Welcome'),
  distro('Desktop'),
  appearance('Appearance'),
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
/// [_SetupStep.welcome] and [_SetupStep.install] are in every list: the first
/// is language plus the home role (both about Android rather than the desktop),
/// and the third is the hand-off to the boot sequence.
List<_SetupStep> _stepsFor(ShellKind? shell) {
  if (shell == ShellKind.tui) {
    return const [
      _SetupStep.welcome,
      _SetupStep.distro,
      _SetupStep.install,
    ];
  }
  return const [
    _SetupStep.welcome,
    _SetupStep.distro,
    // BEFORE the layout steps, deliberately. Dock and drawer both preview
    // themselves, and a preview painted in the mode you are about to leave is
    // worse than no preview. After distro because the preview needs a palette.
    _SetupStep.appearance,
    _SetupStep.dock,
    _SetupStep.drawer,
    _SetupStep.folders,
    _SetupStep.install,
  ];
}

// ── Steps ────────────────────────────────────────────────────────────────────

/// Welcome: the whole opening screen, matching the modern Ubuntu installer's
/// first page — the distro mark, then "Choose your language:" over a bordered
/// SCROLLABLE list of native language names, active one in the accent colour.
///
/// The list scrolls inside a fixed-height box (like the reference) rather than
/// growing the page, because the language count is data: `kBundledLocales` can
/// grow to dozens of Google-Translate-backed languages without this screen
/// changing shape. Selection applies LIVE, so the wizard re-titles itself in
/// the chosen language under the finger.
///
/// Below the box sits the one thing a launcher must settle before anything
/// else works: the home role. The three-strike gate still lives on the state
/// and fires from the footer's action; this widget only renders the control.
class _StepWelcome extends ConsumerWidget {
  const _StepWelcome({
    required this.mono,
    required this.isDefault,
    required this.showWarning,
    required this.onRequest,
  });

  final bool mono;
  final bool isDefault;
  final bool showWarning;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    // hasValue, not asData: asData is null through a RELOAD, and every prefs
    // write is a reload. See home_screen.dart.
    final themeAsync = ref.watch(effectiveThemeProvider);
    final theme = themeAsync.hasValue ? themeAsync.requireValue : null;
    final i18n = ref.watch(i18nProvider);
    // Preselect what is on screen: the explicit choice, else the device
    // language the app booted with.
    final activeCode = i18n.selectedCode ?? i18n.translations.code;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The distro's REAL mark, centred like the reference's Ubuntu wordmark.
        //
        // This used to be a typeset stand-in: an accent-coloured square beside
        // the distro's name, with a comment saying the SVG was not wired
        // because app_icon.dart was not in hand. It looked exactly like what it
        // was, a placeholder, and it was the first thing on the first screen.
        //
        // LauncherBrandIcon reads `spec.logo` and picks the variant that reads
        // on this surface, so a CDN distro shipping its own logo gets it here
        // with no code change, and a distro shipping none falls back to the
        // Mindhunter mark rather than to a coloured rectangle.
        if (theme != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LauncherBrandIcon(theme: theme, size: 34),
                  const SizedBox(width: 10),
                  Text(
                    theme.spec.name,
                    style: d.text.display.copyWith(fontSize: 30),
                  ),
                ],
              ),
            ),
          ),

        // The language box: bordered, rounded, SCROLLABLE, and it now GROWS.
        //
        // It was a fixed 288, which is what left a third of the window empty
        // beneath the home-role button. The frame gives this step the full
        // height (SetupInstallerFrame.fills), so the box takes whatever the
        // header and the rows below do not, on every screen size, instead of
        // being right on one phone and wrong on the rest.
        //
        // Plain text rows: the reference has no radios and no cards, just
        // names, with the active one in the accent colour.
        Expanded(
          child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: d.colors.line),
            borderRadius: BorderRadius.circular(9),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                for (final l in localesForDisplay())
                  _LanguageLine(
                    label: l.nativeName,
                    active: l.code == activeCode,
                    mono: mono,
                    onTap: () => ref.read(i18nProvider.notifier).select(l),
                  ),
              ],
            ),
          ),
          ),
        ),
        const SizedBox(height: 18),
        if (isDefault)
          SetupRow(
            title: ref.t('setup.welcome.homeSet'),
            subtitle: ref.t('setup.welcome.homeSetSub'),
            selected: true,
            marker: SetupMarker.check,
            mono: mono,
            onTap: () {},
          )
        else ...[
          if (showWarning) ...[
            Text(
              ref.t('setup.welcome.homeWarn'),
              softWrap: true,
              style: d.text.caption.copyWith(color: d.colors.warn),
            ),
            const SizedBox(height: 12),
          ],
          ThemedButton(
            label: showWarning
                ? ref.t('setup.welcome.setHome')
                : ref.t('setup.welcome.chooseHome'),
            icon: Icons.home_outlined,
            expand: true,
            onPressed: onRequest,
          ),
          const SizedBox(height: 8),
          Text(
            ref.t('setup.welcome.homeHelper'),
            softWrap: true,
            style: d.text.caption.copyWith(color: d.colors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// One language name in the welcome box. Text-only, the reference's idiom:
/// active = accent + a shade heavier, everything else = plain text colour.
/// The console skin keeps its cursor: a `>` at the active line.
class _LanguageLine extends StatelessWidget {
  const _LanguageLine({
    required this.label,
    required this.active,
    required this.mono,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool mono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final base = mono ? d.text.label : d.text.body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Text(
          mono ? '${active ? '> ' : '  '}$label' : label,
          style: base.copyWith(
            color: active ? d.colors.accent : d.colors.text,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
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

    // The console skin keeps the text list: a TTY installer does not draw
    // pictures of desktops, and a preview thumbnail there would be the one
    // detail that gives the whole thing away.
    if (mono) {
      return Column(
        children: [
          for (final spec in specs)
            SetupRow(
              title: spec.name,
              subtitle: ref.t(_taglineKeyFor(spec.shell)),
              trailing: spec.version.isEmpty ? null : spec.version,
              selected: spec.id == active,
              mono: true,
              marker: SetupMarker.chevron,
              onTap: () {
                Analytics.themeSelected(spec.id);
                ref.read(selectedThemeIdProvider.notifier).select(spec.id);
              },
            ),
        ],
      );
    }

    return Column(
      children: [
        for (final spec in specs)
          _DistroCard(
            spec: spec,
            selected: spec.id == active,
            onTap: () {
              Analytics.themeSelected(spec.id);
              ref.read(selectedThemeIdProvider.notifier).select(spec.id);
            },
          ),
      ],
    );
  }
}

/// Light, dark, or follow the phone.
///
/// ─── WHY THIS STEP EXISTS AT ALL, AND WHY IT IS NOT PER DISTRO ──────────────
///
/// Wanting a light phone is a fact about the person and the room they are in,
/// not about which desktop they are imitating. So [LauncherPrefs.themeMode] is
/// promoted to the global bucket, and this step and the Appearance section in
/// Settings write the SAME value. Setting it here and setting it later are the
/// same act, which is why the subtitle says so out loud.
///
/// ─── A DISTRO THAT SHIPS NO LIGHT PALETTE ───────────────────────────────────
///
/// It stays dark, and the step SAYS SO rather than hiding itself. Two reasons.
/// Hiding it would make the wizard change length when you go back and pick a
/// different distro, which is exactly the failure `_stepsFor` is built as an
/// enum to survive, and the preference is worth recording anyway: it applies
/// the moment any distro with a light block is installed.
/// One distro, with a picture of the desktop it gives you.
///
/// ─── WHY A PREVIEW AND NOT A ROW OF TEXT ────────────────────────────────────
///
/// "Top bar, dock down the left, activities overview" is an accurate sentence
/// and it is useless to the person it is aimed at. This is the screen where
/// someone decides what their phone will look like for the next year, and the
/// list gave them three taglines to imagine from. The dock step three screens
/// later drew them a picture for a decision an order of magnitude smaller.
///
/// [DevicePreview] costs almost nothing here, which is why this is a small
/// change rather than a project: it paints from six palette colours and four
/// layout scalars, all of which `setupDistrosProvider` has already loaded. No
/// wallpaper decode, no icon lookup, no EffectiveTheme to build. Three of them
/// on one screen is three gradients and some rectangles.
class _DistroCard extends StatelessWidget {
  const _DistroCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final ThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? c.accent.withValues(alpha: 0.10) : null,
            border: Border.all(
              color: selected ? c.accent : c.line,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The distro's OWN palette and dock side, so the three cards are
              // visibly three different desktops rather than three labels.
              SizedBox(
                height: 62,
                child: DevicePreview(
                  palette: spec.palette,
                  mode: DevicePreviewMode.desktop,
                  dock: spec.layout.dock,
                  cols: spec.layout.cols,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(spec.name, style: d.text.title),
                        ),
                        if (spec.version.isNotEmpty)
                          Text(
                            spec.version,
                            style: d.text.caption.copyWith(color: c.textFaint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      // context.t, not ref.t: _DistroCard is a StatelessWidget
                      // and has no WidgetRef. A language switch rebuilds the
                      // tree through MaterialApp.locale, so it still updates.
                      context.t(_taglineKeyFor(spec.shell)),
                      style: d.text.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepAppearance extends ConsumerWidget {
  const _StepAppearance({required this.theme, required this.mono});

  final EffectiveTheme theme;
  final bool mono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final mode = theme.prefs.themeMode ?? 'system';
    final hasLight = theme.spec.paletteLight != null;

    // The dock preview, reused: it paints from EffectiveTheme.palette, which is
    // already the resolved variant, so it shows the choice rather than
    // describing it. No new preview widget, and no second idea of what a
    // desktop looks like.
    return Column(
      children: [
        _Preview(theme: theme, mode: DevicePreviewMode.desktop),
        const SizedBox(height: 14),
        for (final e in const [
          ('system', 'Match the system', 'Follows the phone\'s own light and dark switch.'),
          ('light', 'Always light', null),
          ('dark', 'Always dark', null),
        ])
          SetupRow(
            title: e.$2,
            subtitle: e.$3,
            selected: mode == e.$1,
            mono: mono,
            marker: mono ? SetupMarker.chevron : SetupMarker.radio,
            // Written through the ordinary per-theme notifier even though the
            // value is global. `PrefsNotifier.edit` routes it; a call site that
            // knew which bucket a field lived in would be a call site that can
            // pick wrong.
            onTap: () => notifier.edit((p) => p.copyWith(themeMode: e.$1)),
          ),
        if (!hasLight) ...[
          const SizedBox(height: 10),
          Text(
            ref.t('setup.appearance.darkOnly', {'name': theme.spec.name}),
            softWrap: true,
            style: d.text.caption.copyWith(color: d.colors.textMuted),
          ),
        ],
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
          title: ref.t('setup.downTheLeftEdge'),
          subtitle: ref.t('setup.dock.leftSub', {'name': theme.spec.name}),
          selected: theme.dock == DockSide.left,
          mono: mono,
          marker: mono ? SetupMarker.chevron : SetupMarker.radio,
          onTap: () => notifier.edit((p) => p.copyWith(dockSide: 'left')),
        ),
        SetupRow(
          title: ref.t('setup.alongTheBottom'),
          selected: theme.dock == DockSide.bottom,
          mono: mono,
          marker: mono ? SetupMarker.chevron : SetupMarker.radio,
          onTap: () => notifier.edit((p) => p.copyWith(dockSide: 'bottom')),
        ),
        SetupRow(
          title: ref.t('setup.noDock'),
          subtitle: ref.t('setup.theDrawerIsStill'),
          selected: theme.dock == DockSide.off,
          mono: mono,
          marker: mono ? SetupMarker.chevron : SetupMarker.radio,
          onTap: () => notifier.edit((p) => p.copyWith(dockSide: 'off')),
        ),
        if (theme.dock != DockSide.off) ...[
          const SizedBox(height: 8),
          _MiniLabel(text: ref.t('setup.appGridButton')),
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
    // The RESOLVED style, so what Setup preselects is exactly what the
    // drawer will do, including a distro's own authored default. Setup
    // showing 'List' preselected while the drawer actually came up paged
    // was a lie the user would only catch after finishing.
    final style = theme.drawerScrollStyle;

    return Column(
      children: [
        _Preview(
          theme: theme,
          mode: DevicePreviewMode.drawer,
          cols: theme.drawerCols,
        ),
        const SizedBox(height: 14),
        const _MiniLabel(text: 'Columns'),
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
        const _MiniLabel(text: 'How it moves'),
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
  const _StepFolders({
    required this.theme,
    required this.mono,
    required this.createFolders,
    required this.onCreateFoldersChanged,
  });

  final EffectiveTheme theme;
  final bool mono;

  /// The default-on toggle, owned by the wizard state so that _next can read
  /// it when the user advances (the moment creation actually happens).
  final bool createFolders;
  final ValueChanged<bool> onCreateFoldersChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final apps = ref.watch(shellAppsProvider(theme));
    final suggestions = FolderSuggestions.propose(apps, theme.prefs);

    if (suggestions.isEmpty) {
      return Text(
        ref.t('setup.nothingWorthGroupingYet'),
        softWrap: true,
        style: d.text.body.copyWith(color: d.colors.textMuted),
      );
    }

    // ─── THE FOLDERS ARE SHOWN, NOT COUNTED ──────────────────────────────
    //
    // This step used to be one checkbox reading "Create 8 folders", and the
    // comment here admitted the better screen needed FolderSuggestion's name
    // and members exposed. They always were: `name`, `componentKeys` and
    // `size` have been on the class the whole time.
    //
    // So it draws them. Eight folders with their real names and the apps
    // actually going into each is the difference between agreeing to a number
    // and seeing what you are about to get, and it is the one screen in the
    // wizard with the room to do it.
    final byKey = {for (final a in apps) a.componentKey: a};

    // GAMES FIRST, which is what the copy has always claimed.
    //
    // `propose` sorts biggest-first, so a Google block of twenty-five outranks
    // a Games folder of four and the promise was quietly false. Reordering here
    // rather than in the engine, because size-first is right for a settings
    // list and recognisability is right for a first run: this is the only place
    // someone has never seen any of these folders before.
    final ordered = [
      ...suggestions.where((s) => s.kind == SuggestionKind.games),
      ...suggestions.where((s) => s.kind != SuggestionKind.games),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final s in ordered)
              SizedBox(
                width: 68,
                child: FolderTile(
                  theme: theme,
                  name: s.name,
                  size: 60,
                  // Resolved against the live app list, so a member that has
                  // been uninstalled between propose and paint is absent rather
                  // than a gap. whereType drops the nulls in one pass.
                  members: s.componentKeys
                      .map((k) => byKey[k])
                      .whereType<AppEntry>()
                      .toList(),
                  labelColor: d.colors.text,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SetupRow(
          title: ref.t(
            'setup.folders.create',
            {'n': '${suggestions.length}'},
          ),
          subtitle: '${ref.t('setup.groupedByWhatThe')} '
              '${ref.t('setup.folders.createdWhenYouContinue')}',
          selected: createFolders,
          marker: SetupMarker.check,
          mono: mono,
          onTap: () => onCreateFoldersChanged(!createFolders),
        ),
        const SizedBox(height: 6),
        Text(
          ref.t('setup.skippingLosesNothingThey'),
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
              context.t('settings.gLauncherIsNot'),
              softWrap: true,
              style: d.text.caption.copyWith(color: c.warn),
            ),
          ),
          Text(
            context.t('setup.fix'),
            style: d.text.caption
                .copyWith(color: c.warn, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
