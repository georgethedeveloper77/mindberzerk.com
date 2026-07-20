import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/prefs_repository.dart';
import '../../../engine/theme_engine.dart';

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
  static const fallback = 3; // The mockup shows three dots.

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
    return (prefs?.workspaceCount ?? fallback).clamp(min, max);
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
    ref.listen<int>(workspaceCountProvider, (_, count) {
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
    final count = ref.read(workspaceCountProvider);
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
