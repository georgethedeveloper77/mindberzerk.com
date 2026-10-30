import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
import '../../i18n/i18n.dart';
import '../../platform/launcher_api.g.dart';
import '../prefs/hidden_apps.dart';
import '../prefs/hidden_lock.dart';
import '../prefs/prefs_repository.dart';
import '../prefs/query_learning.dart';
import '../search/search_text.dart';

/// No codegen. Plain Riverpod 3.
///
/// If this file ever grows enough families that the boilerplate hurts, that is
/// the moment to add riverpod_generator — not before.

final launcherHostApiProvider = Provider<LauncherHostApi>((ref) {
  return LauncherHostApi();
});

/// The app list, as the rest of the launcher sees it.
///
/// Native pushes the *full* list on every change (install / uninstall / update /
/// suspend / profile switch) and we swap it wholesale. No deltas, no merge
/// logic, no way to drift out of sync with the system.
final appListProvider =
    AsyncNotifierProvider<AppList, List<AppEntry>>(AppList.new);

class AppList extends AsyncNotifier<List<AppEntry>> {
  @override
  Future<List<AppEntry>> build() async {
    // Register the FlutterApi *before* the first host call, so a package change
    // landing mid-startup isn't dropped on the floor.
    LauncherFlutterApi.setUp(_AppListSink(_swap));

    return ref.read(launcherHostApiProvider).getInstalledApps();
  }

  void _swap(List<AppEntry> apps) => state = AsyncData(apps);

  /// Launch [entry]. A HIDDEN app behind the hidden apps lock asks for the
  /// owner's fingerprint first, wherever the launch came from: hidden apps
  /// are only reachable by typing their whole name, and every search surface
  /// ends here, so this one gate covers rofi, the terminal and the search
  /// page alike.
  Future<void> launch(AppEntry entry, {Rect? iconBounds}) async {
    final hidden = ref.read(globalPrefsProvider).asData?.value.hiddenApps;
    if (hidden != null && hidden.contains(entry.componentKey)) {
      final title = ref
          .read(translationsProvider)
          .t('hidden.confirmOpen', {'name': entry.label});
      if (!await confirmHiddenAccess(ref, title: title)) return;
    }
    return ref.read(launcherHostApiProvider).launchApp(
          entry.componentKey,
          iconBounds?.left,
          iconBounds?.top,
          iconBounds?.right,
          iconBounds?.bottom,
        );
  }

  Future<void> openInfo(AppEntry entry) =>
      ref.read(launcherHostApiProvider).openAppInfo(entry.componentKey);

  /// Start the system's uninstall confirmation. Returns a [UninstallStatus]
  /// value; the caller is expected to say something when it is not a success.
  ///
  /// This is a request, never a result: the user still has to confirm in the
  /// system dialog, and a `launched` status says only that the dialog opened.
  /// The app actually disappearing arrives separately, through
  /// `onAppsChanged`, because the OS is the thing that knows.
  Future<String> uninstall(AppEntry entry) =>
      ref.read(launcherHostApiProvider).requestUninstall(entry.componentKey);
}

/// The vocabulary [AppList.uninstall] answers in.
///
/// MIRRORED IN KOTLIN in `apps/AppRepository.kt`, and listed once more in the
/// Pigeon schema's doc comment, which is the file a reader of either side will
/// actually open. Adding a status means adding it in all three; miss this one
/// and the specific reason native went to the trouble of computing is thrown
/// away for the generic message.
///
/// Strings and not an enum on the wire, because Pigeon numbers enums ahead of
/// classes in the codec and a new one would renumber every existing class.
abstract final class UninstallStatus {
  /// Started from the Activity. The expected success.
  static const launched = 'launched';

  /// Started from the application context because no Activity was attached.
  ///
  /// Treated as success by [succeeded] because the dialog may well have opened,
  /// but kept distinct on purpose: this is the path that was silently failing
  /// before, and it should be visible rather than blended into the happy case.
  static const launchedDetached = 'launched_detached';

  static const unknownApp = 'unknown_app';
  static const systemApp = 'system_app';
  static const workProfile = 'work_profile';
  static const noInstaller = 'no_installer';
  static const refused = 'refused';

  /// A web app: a site added from a browser and held by this launcher.
  ///
  /// There is no package, so there is nothing for Android to uninstall and no
  /// system dialog to wait on. NOT a success for [succeeded], because nothing
  /// has been started and nothing will arrive through `onAppsChanged`; the
  /// caller removes it directly and says so itself.
  static const webApp = 'web_app';

  /// An UNRECOGNISED status is a failure, never a success. If native gains a
  /// status this build has never heard of, the honest response is the generic
  /// message rather than pretending the uninstall is under way.
  static bool succeeded(String status) =>
      status == launched || status == launchedDetached;
}

class _AppListSink implements LauncherFlutterApi {
  _AppListSink(this._onApps);

  final void Function(List<AppEntry>) _onApps;

  @override
  void onAppsChanged(AppChangeEvent event) => _onApps(event.apps);
}

/// Drawer + search view.
///
/// Suspended apps stay visible (greyed, per Android convention). Hiding them
/// makes users think the app was uninstalled.
///
/// ─── WHY THIS TOOK A THEME ──────────────────────────────────────────────────
///
/// It used to be keyed by the query alone, and read `appListProvider` straight,
/// which meant HIDDEN APPS CAME BACK THE MOMENT YOU TYPED. That was a defensible
/// reading of "hiding is off my drawer, not uninstalled" right up until it
/// wasn't: typing two letters is not a deliberate act of retrieval, and an app
/// you hid appearing under `ti` in front of someone else is the whole reason
/// the setting exists.
///
/// Hidden apps are PER THEME, so the rule needs the theme, so the family key is
/// now a record. Records have structural equality in Dart, which is what makes
/// them safe as a Riverpod family key — the same (query, theme) pair resolves to
/// the same provider rather than a new one per keystroke.
///
/// [HiddenApps.forSearch] owns the admission rule. Do not reimplement it here.
typedef VisibleAppsKey = ({String query, EffectiveTheme theme});

final visibleAppsProvider =
    Provider.family<List<AppEntry>, VisibleAppsKey>((ref, key) {
  final all = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
  final query = key.query;

  final apps = HiddenApps.forSearch(all, key.theme.prefs, query);
  if (query.isEmpty) return apps;

  // Prefix, then word start, then anywhere, all on SearchText's folded form
  // so "gvpn", "G VPN" and "GVPN" land the same app in the same slot. The
  // fuzzy matcher for the terminal command palette is a separate thing.
  final prefix = <AppEntry>[];
  final wordStart = <AppEntry>[];
  final anywhere = <AppEntry>[];
  // Fourth tier: one or two typos ("telgram"), closest first, after every
  // correctly spelled hit so a typo never outranks what was really typed.
  final typos = <(AppEntry, int)>[];
  for (final a in apps) {
    switch (SearchText.rank(a.label, query)) {
      case 0:
        prefix.add(a);
      case 1:
        wordStart.add(a);
      case 2:
        anywhere.add(a);
      default:
        final d = SearchText.typoDistance(a.label, query);
        if (d != null) typos.add((a, d));
    }
  }
  typos.sort((x, y) => x.$2.compareTo(y.$2));
  // Learned answers first: if "bank" has opened Equity before, Equity leads
  // "bank". Reorders only; admission above is untouched.
  final learning = ref.watch(queryLearningProvider).asData?.value;
  final ranked = [
    ...prefix,
    ...wordStart,
    ...anywhere,
    for (final t in typos) t.$1,
  ];
  return learning == null
      ? ranked
      : learning.boost(ranked, query, (a) => a.componentKey);
});
