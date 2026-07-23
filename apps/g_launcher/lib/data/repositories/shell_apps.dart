import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
import '../../features/dock/dock_metrics.dart';
import '../../platform/launcher_api.g.dart';
import 'app_repository.dart';

/// The app list, as the shells want it: unwrapped, filtered, sorted.
///
/// **This used to live in `gnome_shell.dart`.** It shouldn't have. Three
/// features read it — the drawer, the home grid, the folder view — and none of
/// them is GNOME. A shell owning the app list means Plasma, the tiling shell and
/// the terminal palette would each either import `gnome_shell.dart` (absurd) or
/// duplicate this (worse). It belongs next to `appListProvider`, which is where
/// it now is.
///
/// Keyed by [EffectiveTheme] because filtering and sorting are theme-scoped:
/// hidden apps are a per-theme preference (§5.3 — hiding an app in Ubuntu must
/// not hide it in KDE).
///
/// ⚠️ **[EffectiveTheme] must implement `==` and `hashCode`.** Riverpod families
/// key on argument equality; if EffectiveTheme uses identity equality, every
/// rebuild creates a *new* provider, the app list re-resolves, every icon
/// re-decodes, and you get a launcher that rebuilds itself into the ground. If
/// it isn't already equatable, that is the single most important thing to fix in
/// this patch.
final shellAppsProvider =
    Provider.family<List<AppEntry>, EffectiveTheme>((ref, theme) {
  // asData?.value — Riverpod 3 removed valueOrNull.
  final apps = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];

  // ── HIDDEN APPS ────────────────────────────────────────────────────────────
  // Per-theme: `prefs.hiddenApps` is a Set<String> of componentKeys, scoped to
  // the active theme (plan §5.3 — hiding an app in Ubuntu must not hide it in
  // KDE). Because `prefs` is now part of EffectiveTheme's `==`, editing this set
  // yields a different key and this provider re-resolves; the filter can't go
  // stale behind the family cache.
  //
  // Set membership is O(1), so this stays cheap even on the ~130-app drawers the
  // budget phones carry. The empty-set fast path skips the allocation entirely
  // for the overwhelmingly common "nothing hidden" case.
  //
  // NOTE: this is the SHELL/drawer/home surface, and it removes hidden apps
  // unconditionally — there is no query here to admit one against.
  //
  // The old note here said hidden apps "stay fully launchable by the terminal
  // palette and by search". That is no longer true as written, and the change
  // was deliberate: reachable on ANY typing meant two letters brought a hidden
  // app back in front of whoever it was hidden from. The rule now lives in
  // `HiddenApps.admits` and is the same on every search surface — a hidden app
  // is never ranked, and is admitted only when the query is its whole name.
  // See `hidden_apps.dart` for why that strictness is the feature.
  final hidden = theme.prefs.hiddenApps;
  final visible = hidden.isEmpty
      ? apps
      : apps.where((a) => !hidden.contains(a.componentKey)).toList();

  final sorted = [...visible]..sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );

  return sorted;
});

/// The dock's contents.
///
/// **The authentic decision raised the stakes on this.** With no icons on the
/// desktop, the dock is the *only* app surface on home. It cannot stay a
/// hardcoded slice of the alphabet.
///
/// NOTE: GNOME no longer reads this provider — `gnome_shell.dart` builds its
/// dock straight from `HomeLayout.dockKeys` + `shellAppsProvider`. This stays as
/// the placeholder the OTHER shells (Plasma, tiling) will lean on until they
/// grow their own dock wiring, so it's kept in step: the default is
/// `DockMetrics.defaultCount` (four), not a hardcoded six.
///
/// What it still needs to become real: a `dockItems: List<String>` in
/// LauncherPrefs — component keys, ordered — plus a Settings row, "Pin to dock"
/// in the drawer's long-press sheet, and drag-to-reorder (`edge_pager.dart` is
/// dormant and was written for exactly that).
final dockEntriesProvider =
    Provider.family<List<AppEntry>, EffectiveTheme>((ref, theme) {
  final apps = ref.watch(shellAppsProvider(theme));

  // TODO(george): read theme.prefs.dockItems, resolve componentKeys against
  // `apps`, and drop any that no longer resolve (uninstalled). Until then:
  return apps.take(DockMetrics.defaultCount).toList();
});
