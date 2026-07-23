import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../prefs/hidden_apps.dart';

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

  Future<void> launch(AppEntry entry, {Rect? iconBounds}) {
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

  Future<void> uninstall(AppEntry entry) =>
      ref.read(launcherHostApiProvider).requestUninstall(entry.componentKey);
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

  final q = query.toLowerCase();

  // Cheap prefix-then-substring ranking. The fuzzy matcher for the terminal
  // command palette is a separate, smarter thing — don't conflate the two.
  final prefix = <AppEntry>[];
  final contains = <AppEntry>[];
  for (final a in apps) {
    final label = a.label.toLowerCase();
    if (label.startsWith(q)) {
      prefix.add(a);
    } else if (label.contains(q)) {
      contains.add(a);
    }
  }
  return [...prefix, ...contains];
});
