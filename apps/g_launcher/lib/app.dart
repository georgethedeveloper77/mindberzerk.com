import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/crash_context.dart';
import 'data/prefs/setup_state.dart';
import 'data/billing/entitlements.dart';
import 'data/update/update_repository.dart';
import 'design/theme.dart';
import 'features/desklets/widget_stage.dart';
import 'features/home/home_intent.dart';
import 'features/home/home_screen.dart';
import 'features/setup/setup_screen.dart';
import 'i18n/i18n.dart';

class GLauncherApp extends ConsumerWidget {
  const GLauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The active language. Watching it here means a change in the language step
    // (or Settings) rebuilds MaterialApp with the new locale, which flips text
    // direction for RTL languages and re-resolves every ref.t below it.
    final i18n = ref.watch(i18nProvider);

    return MaterialApp(
      title: 'G Launcher',
      debugShowCheckedModeBanner: false,

      // ── THE STAGE HAS TO KNOW WHEN IT IS COVERED ────────────────────────
      //
      // Hosted widgets live in a native layer BEHIND Flutter, and
      // `LauncherActivity.dispatchTouchEvent` gives a press inside one to that
      // widget before Flutter sees it. That is right for a desktop at rest and
      // wrong under anything layered over it: the desklet menu opens anchored
      // to the widget, so its rows sat on the hit rect and could not be tapped,
      // and every pushed route had the same hole wherever a widget happened to
      // be underneath.
      //
      // HERE rather than per screen, because the Navigator already knows the
      // answer for every route that will ever exist, and a flag per surface is
      // a list the next screen forgets to join. See `StageRouteObserver`.
      navigatorObservers: [stageRouteObserver],

      // ── LANGUAGE ────────────────────────────────────────────────────────
      //
      // Our own copy comes from the JSON system (ref.t / context.t). These
      // three lines are the FRAMEWORK half: they localise Material's built-in
      // strings and, more importantly, set the text direction so an Arabic or
      // Hebrew user gets a right-to-left layout for free. supportedLocales must
      // list every bundled language or Material falls back to the first one.
      locale: i18n.locale,
      supportedLocales: [for (final l in kBundledLocales) l.locale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // House theme. This is for Settings / Themes / dialogs ONLY — the desktop
      // shells do not use it. They are painted from the active ThemeSpec.
      //
      // The copyWith is the third leg of wallpaper transparency, and the one
      // that is pure Dart. Even with a translucent window (styles.xml) and a
      // translucent Flutter surface (BackgroundMode.transparent), Material
      // paints scaffoldBackgroundColor and canvasColor on top and you get an
      // opaque desktop anyway. The wallpaper is behind THREE opaque layers by
      // default; all three have to be cleared.
      //
      // Every shell Scaffold must ALSO pass backgroundColor: Colors.transparent
      // — Scaffold reads the theme value at construction, and any screen that
      // hardcodes a colour re-introduces the bug locally.
      theme: buildGTheme().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
      ),
      home: const _Root(),
    );
  }
}

/// Initial setup, or the desktop.
///
/// The gate lives here rather than inside HomeScreen deliberately. Setup ending
/// must MOUNT HomeScreen fresh, because that first mount is what plays the boot
/// for the theme just chosen (see `_maybeAutoBoot`). If setup were a screen
/// pushed over an already-running HomeScreen, popping it would reveal a desktop
/// that had booted before the user picked anything.
///
/// While the flag resolves, render nothing rather than a spinner. It is one
/// SharedPreferences read on an already-warmed engine, so it lands within a
/// frame or two — and a launcher that flashes a progress indicator before the
/// home screen feels broken, which is the same call home_screen makes for the
/// theme itself.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── THE PACK BRIDGE ──────────────────────────────────────────────────
    //
    // Watched for its construction, not its value: this is what calls
    // `PackFlutterApi.setUp`, and Riverpod providers are lazy, so without a
    // watcher the registration never happens and every `onPackInstalled` fires
    // into nowhere. A pack would download, verify and install correctly, and
    // the desktop would not repaint until the process died — indistinguishable
    // from the download having failed.
    //
    // HERE rather than in a storefront screen, and here rather than in
    // `GLauncherApp`. A store screen is not always open, and `PackSyncWorker`
    // installs in the background while the launcher is foregrounded. `_Root`
    // outlives both setup and the desktop, so the channel is live from the
    // first frame to the last.
    //
    // Deliberately not awaited or branched on. If it ever threw, a broken
    // storefront must not stop the home screen from rendering.
    //
    // MOVED from `data/repositories/pack_bridge.dart`, which is deleted. There
    // were two providers of this name, in two files, each calling `setUp`, and
    // this line chose one of them — so the other's progress reports and
    // catalogue invalidations went to notifiers nothing was watching. The
    // surviving one also carries the purchase-completed listener, which was in
    // the half that never ran. See the merge note in `cdn/pack_repository.dart`.
    ref.watch(packBridgeProvider);

    // ── CRASHLYTICS CUSTOM KEYS ──────────────────────────────────────────
    //
    // Watched for its side effect, exactly like the line above, and mounted
    // here for exactly the same reason: `Crash.setContext` was written, correct
    // and called from nowhere, so every report so far has arrived with no idea
    // which of fourteen distros produced it. A provider nothing watches never
    // runs, which is the bug this line exists to not repeat.
    //
    // `_Root` rather than a shell, because a shell is torn down and rebuilt on
    // every theme switch and the keys must survive that. See
    // `core/crash_context.dart`.
    ref.watch(crashContextProvider);

    // ── THE PLAY UPDATE CHECK ────────────────────────────────────────────
    //
    // The third line watched for its side effect, and mounted here for the
    // same two reasons as the two above it: a provider nothing watches never
    // runs, and a shell is torn down on every theme switch while this must
    // survive one. A downloaded-but-not-installed update is a fact about the
    // process, not about whichever distro is on screen when it finishes.
    //
    // WATCH, not read, and that is load-bearing rather than stylistic.
    // `ref.read` creates no dependency, so under auto-dispose the update state
    // would be collected the moment the Settings screen closed and a completed
    // download would be forgotten. Watching from `_Root` pins it for the life
    // of the process.
    //
    // The check itself is deferred to a microtask inside the provider, and it
    // is throttled: see `kUpdateCheckInterval`. This is one SharedPreferences
    // read on the common path, not a Play round trip on every launch.
    //
    // WHAT THIS DELIBERATELY IS NOT: `crash_context.dart` ends with a long note
    // on why a synchronous Provider in `_Root` must not watch an async one, and
    // that rule is obeyed here. `appUpdateWatchProvider` mounts a synchronous
    // `Notifier` and nothing else; the prefs read and the platform call both
    // happen after the build phase has ended.
    ref.watch(appUpdateWatchProvider);

    // ── BILLING, WARMED BEFORE ANYONE ASKS ───────────────────────────────
    //
    // The fourth side-effect line, and the one with money attached. Until this
    // existed, `EntitlementService.start` ran whenever some screen first read
    // `ownedSkusProvider`, which on a warm engine could be before any Activity
    // was attached: `isAvailable` then threw fatally, fifty times across nine
    // users. When it did not crash, the whole connect-query-restore sequence
    // happened at store-open with the user watching it.
    //
    // This mounts a resume listener instead, so the connection is made the
    // moment an Activity exists and the storefront opens onto answers that are
    // already there. See `billingWarmupProvider`.
    ref.watch(billingWarmupProvider);

    final done = ref.watch(setupCompletedProvider);

    // ── THE HOME PRESS ───────────────────────────────────────────────────
    //
    // `LauncherActivity.onNewIntent` has been sending "home" down
    // `g_launcher/home_press` on every home press, into a Dart tree where
    // nothing was listening. See `HomeIntent`: the channel name did not appear
    // anywhere in lib/ except in a comment describing the handler.
    //
    // HERE rather than in a shell, for the reason the crash-context line above
    // gives: a shell is torn down on every theme switch, and the home button is
    // not allowed to stop working for a frame. Above the gate, so it is also
    // live during setup, where popping a stray route is the correct response to
    // a home press too.
    //
    // A widget rather than another `ref.watch` line, because it needs a
    // Navigator and a WidgetRef. That is argued in the file.
    return HomeIntent(
      child: done.when(
        loading: () => const SizedBox.shrink(),
        // A failed read must not strand the user in a wizard they cannot leave.
        // Assume set-up and let them reach Settings.
        error: (_, __) => const HomeScreen(),
        data: (complete) => complete ? const HomeScreen() : const SetupScreen(),
      ),
    );
  }
}
