/// THE ONE PLACE `PackFlutterApi` IS REGISTERED.
///
/// `bootstrap.dart` explains why it cannot live there: `setUp` needs a Riverpod
/// `Ref` and there is no container yet before `runApp(ProviderScope(...))`. It
/// names this provider as the home, and this is it.
///
/// ─── EXACTLY ONE CALLER, AND THAT IS ENFORCED BY SHAPE ──────────────────────
///
/// Pigeon's `setUp` REPLACES whatever handler is on the channel rather than
/// adding to it. Register from two places and the second silently unhooks the
/// first, with no error and no log line; the symptom is a download progress bar
/// that works right up until you open a second screen. Register from a widget's
/// `initState` and every mount re-registers, so a rebuild reassigns the channel
/// to a widget that may be about to dispose.
///
/// A provider is installed once for the life of the container and cannot be
/// double-installed, which is why `packCatalogueProvider` is a pure reader and
/// this is the only thing that calls `setUp`.
///
/// ─── IT MUST BE WATCHED AT THE ROOT, NOT BY A STORE SCREEN ──────────────────
///
/// Riverpod providers are lazy. If nothing watches this, `setUp` never runs and
/// `onPackInstalled` fires into nowhere, which is the bug this whole file exists
/// to prevent, reintroduced by absence rather than by anything visible in a
/// diff. `_Root` in `app.dart` watches it.
///
/// Watching from the storefront would be wrong even though it looks sufficient:
/// `PackSyncWorker` installs packs headlessly while the app is foregrounded and
/// no store screen is open, and that is precisely the case where a silent
/// install and no repaint is indistinguishable from a failed download.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/theme_engine.dart';
import '../../platform/pack_api.g.dart';
import '../prefs/prefs_repository.dart';
import 'pack_repository.dart';

/// Registers the native callbacks. Watch it once, at the root.
///
/// Returns nothing: it exists for its construction, not its value. That is
/// unusual enough to say out loud, because a provider whose value is unused
/// looks deletable.
final packBridgeProvider = Provider<void>((ref) {
  ref.keepAlive();

  PackFlutterApi.setUp(
    _PackSink(
      onProgress: (p) {
        if (p.bytesTotal <= 0) return;
        ref
            .read(packProgressProvider.notifier)
            .report(p.packId, p.bytesDone / p.bytesTotal);
      },
      onInstalled: (packId, version) {
        ref.read(packProgressProvider.notifier).done(packId);

        // Re-render every icon. See `iconPackGenerationProvider` for why this is
        // unconditional rather than limited to icon-bearing pack types.
        ref.read(iconPackGenerationProvider.notifier).bump();

        // Re-read what is installed, so a storefront card flips to Installed.
        ref.invalidate(packCatalogueProvider);

        // ─── THE LINE THAT MAKES A PURCHASE VISIBLE ───────────────────────
        //
        // `activeThemeSpecProvider` resolved once, at startup or at the last
        // theme switch, and cached the answer. A theme pack landing on disk
        // after that is invisible to it: the selection has not changed, so
        // nothing re-runs, and the phone keeps rendering the Ubuntu fallback it
        // correctly resolved when the pack was not yet there.
        //
        // GATED ON THE SELECTION rather than invalidated unconditionally.
        // Rebuilding the theme cascades into `effectiveThemeProvider`, which
        // re-pushes the icon style, re-keys every app-list family and re-checks
        // the wallpaper. Doing all that because an unrelated pack finished
        // downloading in the background is a visible hitch on the home screen
        // for nothing.
        //
        // The case it catches is the ordinary one: select a distro you do not
        // own yet, the launcher falls back to Ubuntu, you install it, and the
        // desktop becomes the thing you chose.
        final selected = ref.read(selectedThemeIdProvider).asData?.value;
        if (selected == packId) ref.invalidate(activeThemeSpecProvider);
      },
    ),
  );
});

/// Native's callbacks, adapted onto providers.
///
/// A plain class rather than something implementing [PackFlutterApi] inline,
/// mirroring `_AppListSink`. Pigeon's generated interface grows methods over
/// time, and a type that also implements it starts failing to compile for
/// reasons that have nothing to do with what it was written for.
class _PackSink implements PackFlutterApi {
  _PackSink({required this.onProgress, required this.onInstalled});

  final void Function(PackProgress) onProgress;
  final void Function(String packId, int version) onInstalled;

  @override
  void onPackProgress(PackProgress progress) => onProgress(progress);

  @override
  void onPackInstalled(String packId, int version) =>
      onInstalled(packId, version);
}
