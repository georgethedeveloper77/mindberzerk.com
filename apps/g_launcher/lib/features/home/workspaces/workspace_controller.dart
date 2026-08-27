import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/prefs_repository.dart';
import '../../../engine/effective_theme.dart';
import '../../../engine/theme_engine.dart';
import '../../../engine/theme_spec.dart';
import '../../drawer/drawer_state.dart';

/// Active workspace + how many there are.
///
/// ─── The bug this file used to have, because it is worth not repeating ──────
///
/// `ActiveWorkspace.build()` read `state` in order to clamp it:
///
///     int build() {
///       final count = ref.watch(workspaceCountProvider);
///       return state > count - 1 ? count - 1 : state;   // ✗
///     }
///
/// `build()` is what *creates* the initial state. Reading `state` inside it asks
/// the provider for a value that does not exist yet — so Riverpod reports it as
/// exactly what it is: a provider that depends on itself.
///
/// The `ref.watch` was a second bug wearing the first one as a coat. Watching a
/// provider from `Notifier.build()` means the notifier is **rebuilt** whenever
/// that provider changes — state discarded, `build()` re-run. So on a count
/// change the workspace would have snapped back to its initial value regardless.
/// The clamp would never have run; it would have been a reset in a trenchcoat.
///
/// `ref.listen` is the tool for "react to another provider without being torn
/// down by it". That is the fix, and it is also just the correct model: the
/// active workspace is not *derived from* the count, it is merely *constrained
/// by* it.
/// ───────────────────────────────────────────────────────────────────────────

/// How many workspaces. A user preference under the authentic reading — there
/// are no icons on the desktop, so the layout has nothing to say about how many
/// pages there should be.
///
/// Now read/written through the active theme's per-theme prefs JSON, with a 1–5
/// stepper in Settings. Capped at 5 — nobody swipes to workspace 7, and every
/// extra dot is clutter on a screen whose entire argument is that it's empty.
final workspaceCountProvider =
    NotifierProvider<WorkspaceCount, int>(WorkspaceCount.new);

class WorkspaceCount extends Notifier<int> {
  static const min = 1;
  static const max = 5;
  /// The engine's answer when neither the user nor the distro has one.
  ///
  /// Was the only answer, with a comment reading "the mockup shows three
  /// dots". Every distro therefore started with three, including the ones whose
  /// apps live on the page AFTER the last workspace, where two of those three
  /// are empty swipes standing between you and your app list. See
  /// [ThemeLayout.workspaces].
  static const fallback = 3;

  /// Derived from the ACTIVE theme's per-theme prefs. Watching (not reading) is
  /// correct here: this notifier IS the count, so when the stored count changes
  /// — including from [set] below — it should rebuild to the new value. That is
  /// the exact opposite of ActiveWorkspace, which must survive count changes and
  /// therefore only listens. Returning an unchanged int doesn't notify, so an
  /// unrelated prefs edit (icon size, a gesture) doesn't churn the workspaces.
  @override
  int build() {
    final specId = ref.watch(activeThemeSpecProvider).value?.id;
    if (specId == null) return fallback; // theme still loading — 3 for now
    final prefs = ref.watch(prefsProvider(specId)).value;
    // PREFS, then the distro, then the engine. The user's number wins because
    // the stepper is live and a setting that silently loses to a theme is worse
    // than no setting; the distro's is what a fresh install starts from.
    final theme = ref.watch(activeThemeSpecProvider).value?.layout.workspaces;
    return (prefs?.workspaceCount ?? theme ?? fallback).clamp(min, max);
  }

  /// Persists to the active theme's prefs; state follows by rebuild once the
  /// write lands (optimistically, so it feels instant). A stepper commits once
  /// per tap — discrete, not the 60Hz drag §8 warns about — so writing straight
  /// through here is fine, no debounce needed.
  Future<void> set(int n) async {
    final clamped = n.clamp(min, max);
    if (clamped == state) return;
    final specId = ref.read(activeThemeSpecProvider).value?.id;
    if (specId == null) return;
    await ref
        .read(prefsProvider(specId).notifier)
        .edit((p) => p.copyWith(workspaceCount: clamped));
  }
}

/// The live workspace, 0-indexed.
final activeWorkspaceProvider =
    NotifierProvider<ActiveWorkspace, int>(ActiveWorkspace.new);

class ActiveWorkspace extends Notifier<int> {
  @override
  int build() {
    // listen, NOT watch. watch would rebuild this notifier — and rebuilding a
    // notifier throws its state away.
    //
    // Why the clamp exists at all: drop the count from 5 to 2 while sitting on
    // workspace 5 and the index dangles. The PageView then animates to a page
    // that no longer exists and you get a blank desktop that only a restart
    // fixes. Cheap guard, unpleasant bug.
    // pagerCount, NOT workspaceCount. On a distro whose apps are a page, the
    // last valid index is one further along, and clamping to the desktop count
    // would evict the user from the apps page every time anything rebuilt the
    // count.
    ref.listen<int>(pagerCountProvider, (_, count) {
      final last = count - 1;
      if (state > last) {
        state = last < 0 ? 0 : last;
      }
    });

    // Always workspace 1 on a cold start. GNOME does the same, and there is
    // nothing on a workspace to come back TO — they're empty by design.
    return 0;
  }

  void goTo(int page) {
    // Same reason as the listen above: this is the clamp that decides whether
    // the apps page is reachable at all.
    final count = ref.read(pagerCountProvider);
    final clamped = page.clamp(0, count - 1);
    if (clamped != state) state = clamped;
  }

  void next() => goTo(state + 1);
  void previous() => goTo(state - 1);

  /// HOME press. `LauncherActivity.onNewIntent` already sends `"home"` down the
  /// `g_launcher/home_press` channel — that handler should close the drawer,
  /// dismiss the palette, and land here: workspace 1.
  void reset() => goTo(0);
}

/// The index of the APP LIST page, or null when the app list is an overlay.
///
/// ─── WHY THE APPS PAGE IS NOT A WORKSPACE ───────────────────────────────────
///
/// It would have been cheaper to add one to [workspaceCountProvider] and be
/// done. That number is a USER PREFERENCE with a stepper in Settings, so adding
/// to it would make the stepper read four while the user has three, and every
/// caller that means "how many desktops" would silently start meaning something
/// else.
///
/// So the count stays the count, and the pager is one longer than it on a distro
/// whose apps live on a page. The apps page is the LAST one, which is what makes
/// the swipe read as "further along" rather than as "before the beginning".
///
/// Null on every distro shipping today, since [AppsSurface.overlay] is the
/// default and two shells are clamped to it regardless. A null here is what
/// keeps every behaviour below unchanged for them.
final appsPageProvider = Provider<int?>((ref) {
  // `.value`, so a theme still resolving answers null rather than throwing. The
  // desktop paints black on that frame anyway; see `home_screen.dart`.
  final theme = ref.watch(effectiveThemeProvider).value;
  if (theme == null) return null;
  if (theme.appsSurface != AppsSurface.workspace) return null;
  return ref.watch(workspaceCountProvider);
});

/// How many pages the pager actually has: the workspaces, plus the app list
/// when it is one of them.
///
/// [ActiveWorkspace] clamps against THIS rather than against
/// [workspaceCountProvider], which is the difference between the apps page
/// being reachable and `goTo` quietly rounding it back down to the last
/// desktop. That clamp is not decoration: it is what stops a shrunken count
/// from stranding the pager on a page that no longer exists.
final pagerCountProvider = Provider<int>((ref) {
  final desktops = ref.watch(workspaceCountProvider);
  return ref.watch(appsPageProvider) == null ? desktops : desktops + 1;
});

/// Show the app list, however THIS distro shows one.
///
/// ─── ONE DECISION, SIX CALL SITES ───────────────────────────────────────────
///
/// Six places asked for the app list and all six did it by writing
/// `activitiesOpenProvider = true`: four shells, the drawer's own Locate helper,
/// and the launcher desklet. That was correct while an overlay was the only
/// kind of app list there was.
///
/// With two kinds, a raw write at each site would mean six copies of the same
/// branch, and the one that got missed would open an overlay on a distro that
/// has no overlay to close, over a page that is already showing the apps. So
/// the branch lives here and the call sites ask for the OUTCOME.
///
/// Nothing here closes anything. On an overlay distro that is the existing
/// behaviour; on a workspace distro there is nothing to close, which is the
/// whole idea.
void openApps(WidgetRef ref) {
  final page = ref.read(appsPageProvider);
  if (page == null) {
    ref.read(activitiesOpenProvider.notifier).state = true;
    return;
  }
  // Through the controller, not the PageController: every shell already listens
  // to this and animates its own pager, so a dock button, a desklet and a
  // gesture all arrive the same way.
  ref.read(activeWorkspaceProvider.notifier).goTo(page);
}

/// Is the app list on screen right now, on either kind of distro?
///
/// Read by the one PopScope in `home_screen.dart`, which has to know what back
/// should leave. An overlay distro answers from the flag; a workspace distro
/// answers from the page, because the apps page is not open in any sense that
/// a flag could record.
bool appsShowing(WidgetRef ref) {
  final page = ref.read(appsPageProvider);
  if (page == null) return ref.read(activitiesOpenProvider);
  return ref.read(activeWorkspaceProvider) == page;
}

/// Leave the app list, however this distro leaves one.
void closeApps(WidgetRef ref) {
  final page = ref.read(appsPageProvider);
  if (page == null) {
    ref.read(activitiesOpenProvider.notifier).state = false;
    return;
  }
  // Back off the apps page goes to workspace one rather than to the page before
  // it. That matches what HOME does, and on a three-workspace distro "back" from
  // the apps meaning "workspace three" would be a place the user never chose.
  ref.read(activeWorkspaceProvider.notifier).reset();
}
