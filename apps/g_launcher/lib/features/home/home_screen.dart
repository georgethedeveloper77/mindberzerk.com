import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/boot_spec.dart';
import '../../engine/splash_spec.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart';
import '../../data/prefs/setup_state.dart';
import '../../design/components/components.dart';
import '../../shells/aqua_shell.dart';
import '../../shells/gnome_shell.dart';
import '../../shells/plasma_shell.dart';
import '../../shells/tiling_shell.dart';
import '../../shells/tui_shell.dart';
import '../boot/boot_controller.dart';
import '../boot/boot_sequence.dart';
import '../boot/splash_sequence.dart';
import '../desklets/desklet_edit.dart';

/// Resolves the effective theme (distro defaults + user overrides), then hands
/// off to the shell it names.
///
/// Adding a distro should mean adding a ShellKind branch here AT MOST — and
/// usually not even that, since most distros reuse an existing shell with a
/// different palette. That is the whole "themes are data, not code" bet.
///
/// Also the home for the verbose-boot overlay: [BootGate] wraps the shell so a
/// boot log can cover it and fade away. Nothing plays until someone calls
/// `bootControllerProvider.notifier.play(...)` — cold start and theme switch do
/// that here (gated on the per-theme `verboseBoot` pref); first-run onboarding
/// does it once, explicitly, from its own flow.
///
/// ─── HOW EDIT MODE IS ENTERED AND LEFT ──────────────────────────────────────
///
/// Long-pressing a desklet turns on edit mode (desklet_surface): the tile shows
/// its resize and remove handles, and the dashed add-grid appears across the
/// desktop, which is signal enough that the desktop is being arranged. There is
/// no "Editing workspace" bar — the way out is the system BACK gesture, wired
/// here once so it works on every shell. Edit mode also disables workspace
/// swiping while it is on, so back doubling as its exit is the single thing a
/// user needs to know, and it is the gesture they already reach for.
///
/// The [PopScope] lives in a thin [Consumer] so only it rebuilds when edit mode
/// toggles; the shell subtree below is passed through as a captured child and is
/// not rebuilt.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// The theme id we have already auto-played a boot for this session. Guards
  /// against replaying on every rebuild (a prefs edit rebuilds EffectiveTheme
  /// but keeps the same id, so it will not re-fire), while still firing on a
  /// real switch to a different distro.
  String? _bootedFor;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(effectiveThemeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: theme.when(
        // ── skipLoadingOnReload IS A BUG FIX, NOT A TIDY-UP ─────────────
        //
        // `when` already skips the loading branch on a REFRESH, because that
        // flag defaults to true. It does NOT skip it on a RELOAD, and a reload
        // is what happens here: `effectiveThemeProvider` awaits
        // `prefsProvider(id).future`, so every single prefs write re-runs it,
        // and re-running an async provider means AsyncLoading again.
        //
        // Without this flag, that sent the ENTIRE DESKTOP through the black
        // branch below on every write. Create a folder, drag an icon, nudge a
        // column: the shell unmounted, black for the length of the native
        // setIconTheme round trip, then remounted from scratch. Which is the
        // flicker, and also why the drawer landed back on page one every time,
        // since a remounted PageView is a brand-new PageController.
        //
        // With it, the previous theme keeps painting until the new one lands.
        // Nothing unmounts, so nothing loses its place. The black branch now
        // means what its comment always claimed: the FIRST resolve only.
        skipLoadingOnReload: true,
        // NOT a spinner. A launcher that flashes a progress indicator on every
        // home press feels broken. Black for the few frames it takes to read one
        // bundled JSON file and one prefs blob.
        loading: () => const ColoredBox(color: Colors.black), // theme-exempt: bootstrap, the theme is what is still loading
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Theme failed to load\n\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70), // theme-exempt: bootstrap, this renders precisely when the theme failed to load
            ),
          ),
        ),
        data: (t) {
          _maybeAutoBoot(t);

          final shell = switch (t.shell) {
            ShellKind.gnome => GnomeShell(theme: t),
            ShellKind.plasma => PlasmaShell(theme: t),
            ShellKind.tiling => TilingShell(theme: t),
            ShellKind.tui => TuiShell(theme: t),
            ShellKind.aqua => AquaShell(theme: t),
          };

          // The boot canvas takes the theme's darkest base (aubergine on Ubuntu,
          // #080D08 on the terminal) so the log reads as this distro booting,
          // not a generic black screen. A theme can override the whole log via
          // its theme.json `boot` block; the background rides the palette.
          return ChromeScope(
            // Install the chrome for the whole shell subtree. Every sheet,
            // dialog, and drawer overlay a shell spawns (dock long-press, the
            // Activities menu, the desktop menu) reads THIS to dress itself in
            // the distro's palette + family. The shells themselves read
            // EffectiveTheme, not the scope, so this is purely additive for them.
            data: ChromeData.fromPalette(
              t.palette,
              typography: t.typography,
              textScale: t.textScale,
              family: t.chromeFamily,
              opacity: t.surfaceOpacity,
              // The panel material travels with the chrome, so every sheet,
              // dialog and menu this shell spawns is cut, blurred and tinted
              // the same way without any of them naming a number.
              panelBlur: t.panelBlur,
              panelTint: t.panelTint,
              panelRadius: t.panelRadius,
            ),
            child: BootGate(
              colors: BootColors.fromPalette(
                accent: t.spec.palette.accent,
                background: t.spec.palette.bgBottom,
              ),
              // The splash's half of the same mapping. One wiring point for
              // both, here, where the EffectiveTheme field names are known.
              // ─── THE SPLASH IS ALWAYS THE DISTRO'S DARK BASE ──────────
              //
              // `t.spec.palette`, not `t.palette`. The resolved palette follows
              // light mode; the splash must not.
              //
              // Two reasons, and the second is a bug I introduced with light
              // mode. Plymouth does not change with your GTK theme: a boot
              // splash is the distro's own brand moment and it is dark on every
              // desktop that ships one, whatever session you log into
              // afterwards.
              //
              // And the logo below is the DARK variant, chosen because a splash
              // paints on a dark base. The moment `t.palette` started resolving
              // to a pale surface in light mode, that comment stopped being
              // true: light-ink artwork on a near-white plate is an invisible
              // logo over a white flash. Pinning the background to the spec's
              // own dark palette makes the artwork correct again by
              // construction rather than by adding a second logo branch.
              //
              // BootColors above already reads `t.spec.palette` for exactly
              // this reason; the splash simply never got the same treatment.
              splashChrome: SplashChrome(
                background: t.spec.palette.bgBottom,
                accent: t.spec.palette.accent,
                onDark: t.spec.palette.onDark,
                title: t.spec.name,
                logoAsset: t.spec.splash?.logo ?? t.spec.logo?.dark,
                displayFontFamily: t.typography.display,
                monoFontFamily: t.typography.mono ?? 'UbuntuMono',
              ),
              monoFontFamily: t.spec.typography.mono ?? 'UbuntuMono',
              // BACK leaves edit mode. Only this Consumer rebuilds when edit
              // toggles; the shell is a captured child and is not rebuilt.
              child: Consumer(
                child: shell,
                builder: (context, ref, child) {
                  final editing = ref.watch(deskletEditProvider).active;
                  return PopScope(
                    canPop: !editing,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop && editing) {
                        ref.read(deskletEditProvider.notifier).exit();
                      }
                    },
                    child: child!,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Cold start and theme switch: bring the desktop up the way this distro
  /// would.
  ///
  /// Two paths, and they are ALTERNATIVES:
  ///   * verbose boot ON  -> the full `[  OK  ]` log, six seconds of theatre
  ///   * verbose boot OFF -> the quick splash, under a second (the default)
  ///
  /// Deduped per theme id, which is what keeps this off the HOME-press path:
  /// pressing HOME resumes the activity (launchMode=singleTask) without
  /// recreating this State, so nothing replays. A theme SWITCH changes the id
  /// and plays once. That distinction is the whole reason the plan says "on
  /// switch, not on every home press".
  void _maybeAutoBoot(EffectiveTheme t) {
    if (_bootedFor == t.spec.id) return;
    _bootedFor = t.spec.id;

    final controller = ref.read(bootControllerProvider.notifier);

    // FIRST RUN: the full install experience, once. You have just configured a
    // Linux system, so you watch it come up — the whole boot log, then the
    // distro's splash, then your desktop. The flag is one-shot and consumed
    // here, so the second launch is the ordinary quiet path.
    if (ref.read(firstRunBootPendingProvider)) {
      final boot = t.spec.boot ?? BootSpec.defaultForShell(t.shell);
      final splash = t.spec.splash ?? SplashSpec.defaultForShell(t.shell);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // CLEARED HERE, not above. This method runs during build, and Riverpod
        // forbids writing to a provider mid-build — reading is fine, mutating
        // is not. `_bootedFor` has already been set, so nothing replays in the
        // frames between the read and this clear.
        ref.read(firstRunBootPendingProvider.notifier).state = false;
        controller.playFirstRun(boot, splash);
      });
      return;
    }

    final verbose = t.prefs.verboseBoot == true;

    // Resolve before the frame callback so the theme's own block wins over the
    // shell-family default in both cases.
    final boot = verbose ? (t.spec.boot ?? BootSpec.defaultForShell(t.shell)) : null;
    final splash =
        verbose ? null : (t.spec.splash ?? SplashSpec.defaultForShell(t.shell));

    // Cannot mutate a provider during build; defer a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (boot != null) {
        controller.play(boot);
      } else if (splash != null) {
        // playSplash no-ops on SplashStyle.none, so the terminal theme comes up
        // straight into its prompt with no overlay at all.
        controller.playSplash(splash);
      }
    });
  }
}
