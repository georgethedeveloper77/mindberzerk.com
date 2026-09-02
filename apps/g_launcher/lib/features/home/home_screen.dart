import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/boot_spec.dart';
import '../../engine/splash_spec.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_source.dart';
import '../../engine/theme_spec.dart';
import '../../data/cdn/pack_repository.dart';
import '../../data/prefs/setup_state.dart';
import '../../design/branded_message.dart';
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
import '../desklets/widget_stage.dart';
import 'workspaces/workspace_controller.dart';
import 'quick_settings.dart';
import 'workspaces/workspace_overview.dart';

/// Resolves the effective theme (distro defaults + user overrides), then hands
/// off to the shell it names.
///
/// Adding a distro should mean adding a ShellKind branch here AT MOST, and
/// usually not even that, since most distros reuse an existing shell with a
/// different palette. That is the whole "themes are data, not code" bet.
///
/// Also the home for the verbose-boot overlay: [BootGate] wraps the shell so a
/// boot log can cover it and fade away. Nothing plays until someone calls
/// `bootControllerProvider.notifier.play(...)`; cold start and theme switch do
/// that here (gated on the per-theme `verboseBoot` pref); first-run onboarding
/// does it once, explicitly, from its own flow.
///
/// ─── HOW EDIT MODE IS ENTERED AND LEFT ──────────────────────────────────────
///
/// Long-pressing a desklet turns on edit mode (desklet_surface): the tile shows
/// its resize and remove handles, and the dashed add-grid appears across the
/// desktop, which is signal enough that the desktop is being arranged. There is
/// no "Editing workspace" bar. The way out is the system BACK gesture, wired
/// here once so it works on every shell. Edit mode also disables workspace
/// swiping while it is on, so back doubling as its exit is the single thing a
/// user needs to know, and it is the gesture they already reach for.
///
/// The [PopScope] here is the ONLY one in the tree, and it owns back for every
/// shell in priority order: drawer first, then edit mode, then nothing. See the
/// note at the widget itself for why it lives here rather than in a shell, and
/// for the five it replaced. It watches nothing, so the Consumer never rebuilds
/// and the shell subtree is passed through as a captured child.
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

  /// The splash mark, RESOLVED rather than passed as a path.
  ///
  /// `spec.asset` is `source.asset`, which is the one thing that knows whether
  /// a theme's files live in the APK or in an installed pack directory. It has
  /// to be called here because this is the wiring point: [SplashChrome] is
  /// built here and nothing downstream has the [ThemeSpec] any more.
  ///
  /// This line used to read `t.spec.splash?.logo ?? t.spec.logo?.dark` and hand
  /// the raw string over. That was correct for exactly as long as every theme
  /// shipped in the APK. The moment a free distro could be REPUBLISHED over the
  /// CDN, the same field started arriving as a bare `logo_dark.webp`, the
  /// renderer's `Image.asset` could not find it, and the distro that had just
  /// been updated came up with no mark on its splash. The pipeline worked and
  /// the artwork did not arrive, which is the same class of bug the render
  /// bridge in theme_engine was written to fix; this was the last call site
  /// still holding a String.
  ///
  /// No `existsSync` here. It is cheap, but this runs in `build` and
  /// [ThemeAsset] says so explicitly: a stat per frame for a file that has been
  /// verified at install time is the wrong trade. A missing file lands on the
  /// wordmark through the renderer's errorBuilder instead.
  ThemeAsset? _splashLogo(ThemeSpec spec) {
    // The splash's own artwork wins when a theme authors it, and it is resolved
    // the same way. Everything else defers to [ThemeSpec.logoAsset], which is
    // now the one place that turns a logo into something openable: this method
    // composed `logo?.dark` itself, which was correct and was also the pattern
    // two other readers copied incorrectly.
    final own = spec.splash?.logo;
    if (own != null && own.isNotEmpty) return spec.asset(own);
    // Dark surface: a splash paints on the distro's darkest colour.
    return spec.logoAsset(onDarkSurface: true);
  }

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

          final rawShell = switch (t.shell) {
            ShellKind.gnome => GnomeShell(theme: t),
            ShellKind.plasma => PlasmaShell(theme: t),
            ShellKind.tiling => TilingShell(theme: t),
            ShellKind.tui => TuiShell(theme: t),
            ShellKind.aqua => AquaShell(theme: t),
          };

          // ─── THE WIDGET STAGE, FOR EVERY SHELL, FOR THE SAME REASON AS
          //     THE ONE PopScope BELOW ────────────────────────────────────
          //
          // Hosted third-party widgets are real Android views in a layer behind
          // Flutter. Dart tells that layer where they are; without the sync the
          // layer stays empty and every widget is a transparent hole.
          //
          // This lived in `WorkspaceCanvas` first, which was wrong in exactly
          // the way six PopScopes were wrong: Plasma, tiling and Aqua share
          // that canvas, GnomeShell keeps its own inline pager, and TUI has no
          // workspaces at all. So the default distro was the one shell where
          // widgets never appeared. `AppWidgetHost: updateAppWidgetView,
          // appWidgetId = 23, v = null` is the host saying nobody ever asked it
          // for a view.
          //
          // Every shell passes through here. That is the whole argument.
          //
          // ─── AND WHY THE SCROLL LISTENER IS HERE TOO ──────────────────
          //
          // The stage cannot follow Flutter's scroll without a message per
          // frame, and one frame of lag shears visibly against the desklets
          // beside it, so it hides while the workspace moves. Scroll
          // notifications bubble, so one listener at the top catches every
          // shell's pager without knowing which pager any of them uses.
          //
          // It also catches the drawer's own scrolling, which is harmless: an
          // open drawer already hides the stage. Notifications do not cross
          // route boundaries, so a pushed settings screen never reaches this.
          final shell = NotificationListener<ScrollNotification>(
            onNotification: (n) {
              final moving = ref.read(stageMovingProvider.notifier);
              if (n is ScrollEndNotification) {
                moving.set(false);
              } else if (n is ScrollStartNotification ||
                  n is ScrollUpdateNotification) {
                moving.set(true);
              }
              // FALSE, always: this observes, it does not consume. Returning
              // true would stop the notification here and break anything above
              // that also listens.
              return false;
            },
            child: Stack(
              children: [
                rawShell,
                // ─── THE OVERVIEW SITS ABOVE THE SHELL, NOT INSIDE IT ────
                //
                // GNOME inlines its own pager and the other three mount
                // `WorkspaceCanvas`, so there is no one place inside the shells
                // to put this. Here it is above all four, and every shell's
                // pager carries on underneath without learning it exists.
                //
                // Always mounted, drawing `SizedBox.shrink()` while closed.
                // Mounting it conditionally would change the Stack's shape on
                // every open and close, and this Stack contains the shell: a
                // shape change unmounts the pager and rebuilds its
                // PageController, which is the workspace-one snap this file
                // already documents under skipLoadingOnReload.
                WorkspaceOverview(theme: t),
                // Same reasoning as the overview above: mounted always, drawing
                // nothing while closed, so the Stack that contains the shell
                // never changes shape.
                QuickSettingsPanel(theme: t),
                // Renders nothing. Mounted inside the shell's own subtree so it
                // lives and dies with the desktop.
                const WidgetStageSync(),
              ],
            ),
          );

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
            child: _PackUpdateMessenger(
              name: t.spec.name,
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
                logoAsset: _splashLogo(t.spec),
                displayFontFamily: t.typography.display,
                monoFontFamily: t.typography.mono ?? 'UbuntuMono',
              ),
              monoFontFamily: t.spec.typography.mono ?? 'UbuntuMono',
              // ─── THE ONE BACK OWNER, FOR EVERY SHELL ─────────────────
              //
              // There were SIX PopScopes in this tree and they all fired on the
              // same press, which is the bug gnome_shell's own comment warns
              // about and then reproduces: this one, gnome_shell's, and one
              // inside each of Kickoff, the tiling launcher and Launchpad.
              //
              // The visible symptom needed two things open at once. Enter edit
              // mode, then open the drawer, then press back: this scope exited
              // edit mode and the drawer's scope closed the drawer, so one
              // press did two things and the user lost a mode they were still
              // using. Nobody reports that, because it looks like back working
              // slightly too well.
              //
              // Owning it HERE rather than in gnome_shell, which is where the
              // previous attempt put it. This widget wraps every shell; that
              // one wraps GNOME. Four of the five shells had no edit-mode
              // handler of their own at all, and tui_shell has no PopScope
              // whatsoever, so the shell-level answer was only ever going to be
              // correct on one desktop out of five.
              //
              // canPop is FALSE unconditionally, which is the contract the
              // shells already documented: back must never leave the launcher.
              // LauncherActivity.onBackPressed calls super, which only sends
              // popRoute, so refusing here is what keeps that promise.
              //
              // Nothing is watched, so this Consumer never rebuilds and the
              // shell below is untouched by a back press that does nothing.
              child: Consumer(
                child: shell,
                builder: (context, ref, child) {
                  return PopScope(
                    canPop: false,
                    // TOP DOWN, and the order is the behaviour: the most
                    // recently entered thing is the one back should leave. Edit
                    // mode is entered from the desktop and survives the drawer
                    // opening over it, so a press with both open closes the
                    // drawer first and leaves edit mode on the second press.
                    onPopInvokedWithResult: (didPop, _) {
                      if (didPop) return;
                      // ─── "IS THE APP LIST UP" HAS TWO ANSWERS NOW ─────
                      //
                      // This read `activitiesOpenProvider` directly, which is
                      // the right question on a distro whose app list is an
                      // overlay and meaningless on one whose app list is a
                      // page: there is no flag to be true, so back would have
                      // fallen through to edit mode while the user was staring
                      // at their apps.
                      //
                      // [appsShowing] and [closeApps] answer for both, so this
                      // scope keeps owning back for every shell without
                      // learning which kind of launcher it is looking at.
                      // TOP DOWN, and the overview is the top. It is entered
                      // from the desktop and can be entered while the drawer is
                      // shut, so it is the most recently entered thing whenever
                      // it is open.
                      // Above the overview, because it is opened FROM the
                      // desktop with one tap and the overview is a pinch, so
                      // whichever is open, this one was entered last whenever
                      // both could be.
                      if (ref.read(quickSettingsProvider)) {
                        ref.read(quickSettingsProvider.notifier).close();
                      } else if (ref.read(workspaceOverviewProvider)) {
                        ref.read(workspaceOverviewProvider.notifier).close();
                      } else if (appsShowing(ref)) {
                        closeApps(ref);
                      } else if (ref.read(deskletEditProvider).active) {
                        ref.read(deskletEditProvider.notifier).exit();
                      }
                      // No final else, deliberately. Back on a bare desktop
                      // does nothing, which is what a launcher's back means.
                    },
                    child: child!,
                  );
                },
                ),
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
    // Linux system, so you watch it come up: the whole boot log, then the
    // distro's splash, then your desktop. The flag is one-shot and consumed
    // here, so the second launch is the ordinary quiet path.
    if (ref.read(firstRunBootPendingProvider)) {
      final boot = t.spec.boot ?? BootSpec.defaultForShell(t.shell);
      final splash = t.spec.splash ?? SplashSpec.defaultForShell(t.shell);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // CLEARED HERE, not above. This method runs during build, and Riverpod
        // forbids writing to a provider mid-build: reading is fine, mutating
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

/// Says so when a background sync replaces the distro under the desktop.
///
/// ─── WHY IT IS A WIDGET AND WHY IT IS HERE ──────────────────────────────────
///
/// `PackFlutterApiImpl` fires in provider land with no [BuildContext], and the
/// branded message needs one that sits inside the [ChromeScope] so the strip is
/// dressed in the distro's own palette rather than Material's defaults. This is
/// the shallowest place that satisfies both: below the scope, above every
/// shell, and mounted for as long as the desktop is.
///
/// [name] comes from the theme that is already resolved above it, which is
/// better than looking the pack up in the catalogue: a background install can
/// happen on a device whose storefront has never been opened, so the catalogue
/// may hold nothing at all, and the distro's own name is exactly the word the
/// user would use for it.
///
/// The signal is CONSUMED rather than expiring, so the message survives the
/// launcher being backgrounded when the sync lands. A notification the user
/// never saw is not a notification.
class _PackUpdateMessenger extends ConsumerWidget {
  const _PackUpdateMessenger({required this.name, required this.child});

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // listen, not watch. This must never rebuild the shell subtree: the child
    // is captured, and a rebuild here would remount every desktop below it for
    // the sake of a one-line message.
    ref.listen<String?>(activeDistroUpdatedProvider, (_, next) {
      if (next == null) return;
      // Post-frame, because this fires from a provider write and showing a
      // message mounts an overlay entry.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.showMessage('$name updated');
        ref.read(activeDistroUpdatedProvider.notifier).consume();
      });
    });

    return child;
  }
}
