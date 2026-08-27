/// What the folder overlay needs from whatever is holding the folder.
///
/// ─── TWO STORES, ONE SCREEN, AND WHY THE STORES DO NOT MERGE ────────────────
///
/// There are two folder models in this app and `DrawerLayout`'s own doc makes
/// the case for both: home folders live in SLOTS, so dissolving one has to hand
/// its slot back or the apps fall off the screen, while drawer folders are a
/// set with no geometry at all. Merging them would drag slot arithmetic into a
/// surface that has none.
///
/// What was never defensible is that the two had separate SCREENS. `folder_
/// overlay.dart` grew a full-screen panel with in-place rename, a multi-select
/// add dialog, drag reordering with edge page-flip, and a context menu at the
/// pointer. The desktop got a bare `Dialog` with a `TextField` and a grid where
/// long press meant instant removal with no menu and no undo. One of those was
/// maintained and the other was not, and nothing about the difference was a
/// decision.
///
/// So the model stays split and the screen stops being. Everything the overlay
/// does is expressible as: read this folder, write to it, and tell me what it
/// could absorb. That is this interface.
///
/// ─── WHY REF AND THEME ARE PARAMETERS RATHER THAN FIELDS ────────────────────
///
/// A store holds NO state, which is what lets both be `const` and lets the
/// overlay take one as a plain constructor argument. The theme in particular
/// must not be captured: the overlay deliberately re-reads it live on every
/// build, because renaming or adding an app has to land under your finger
/// rather than on the next open, and a store holding a push-time snapshot would
/// undo that at the one point it matters.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/home_layout.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';

/// A folder as the overlay needs to render it: a name and its members already
/// resolved to real apps.
///
/// Resolved rather than raw component keys, because the two stores resolve them
/// differently. The drawer's folders arrive from `drawerItemsProvider` with the
/// entries already attached and the dead ones already filtered; home folders
/// hold bare keys and have to be joined against `shellAppsProvider`. Handing
/// the overlay a common shape is the point of the seam.
class FolderSnapshot {
  const FolderSnapshot({required this.name, required this.members});

  final String name;
  final List<AppEntry> members;
}

/// The seam. See the library doc.
abstract class FolderStore {
  const FolderStore();

  /// Read the folder for a BUILD. Subscribes, so the overlay repaints when a
  /// member is added, removed or reordered.
  ///
  /// Null means the folder is gone, which the overlay treats as "dissolved
  /// while open" and closes on.
  FolderSnapshot? watch(WidgetRef ref, EffectiveTheme theme, String id);

  /// The same read WITHOUT subscribing, for callbacks.
  ///
  /// Both exist rather than one, because calling `ref.watch` outside build
  /// throws and calling `ref.read` inside build silently stops the screen
  /// updating. Naming them apart makes the choice visible at each call site
  /// instead of leaving it to whoever edits the line next.
  FolderSnapshot? read(WidgetRef ref, EffectiveTheme theme, String id);

  /// Is this a GENERATED folder, which owns nothing until it is edited?
  ///
  /// Only the drawer has them: its category folders are rebuilt from what each
  /// app declares about itself, so an edit written against one is undone on the
  /// next launch. A home folder is always real, so [HomeFolderStore] answers
  /// false and [editable] is the identity.
  bool isGenerated(String id) => false;

  /// The id to write against, materialising a generated folder first.
  ///
  /// Callers must use the RETURN VALUE and not the id they held, which after a
  /// conversion names a folder that no longer describes anything.
  Future<String> editable(
    WidgetRef ref,
    EffectiveTheme theme,
    String id,
    FolderSnapshot live,
  ) async =>
      id;

  /// Apps this folder could absorb: everything not already filed in one.
  ///
  /// Both stores exclude the same thing for the same reason, and both leave
  /// apps that are merely PLACED (in a desktop slot) in the list, since filing
  /// one simply frees its slot.
  List<AppEntry> candidates(WidgetRef ref, EffectiveTheme theme);

  Future<void> rename(
      WidgetRef ref, EffectiveTheme theme, String id, String name);

  Future<void> addMembers(
      WidgetRef ref, EffectiveTheme theme, String id, Iterable<String> keys);

  Future<void> reorder(
    WidgetRef ref,
    EffectiveTheme theme,
    String id,
    String sourceKey,
    String targetKey, {
    required bool after,
  });

  Future<void> removeMember(
      WidgetRef ref, EffectiveTheme theme, String id, String componentKey);

  /// Could Ungroup succeed right now?
  ///
  /// ─── ASKED BEFORE THE ROUTE POPS, WHICH IS WHY IT IS SEPARATE ───────────
  ///
  /// The overlay pops FIRST and writes second, so the exit animation runs
  /// instead of the panel blinking out a frame early. That ordering is only
  /// safe while the write cannot refuse. `HomeLayout.dissolve` can: a folder of
  /// six on a desktop with four free slots is refused whole rather than
  /// dropping two apps, so the overlay has to find out before it makes a
  /// promise it cannot keep.
  ///
  /// The drawer has no such limit and always answers true.
  bool canDissolve(WidgetRef ref, EffectiveTheme theme, String id) => true;

  /// The i18n key explaining a false [canDissolve]. Never read when it is true,
  /// so the drawer inherits it and never shows it.
  String get dissolveRefusalKey => 'drawer.ungroupNoRoom';

  Future<void> dissolve(WidgetRef ref, EffectiveTheme theme, String id);
}

/// The drawer's folders: `LauncherPrefs.drawerFolders`, plus the generated
/// category folders that materialise on first edit.
///
/// This is the behaviour the overlay already had, lifted out unchanged. Every
/// method below is the line that used to sit inline at the call site.
class DrawerFolderStore extends FolderStore {
  const DrawerFolderStore();

  FolderSnapshot? _find(List<DrawerItem> items, String id) {
    for (final i in items) {
      if (i is FolderDrawerItem && i.folder.id == id) {
        return FolderSnapshot(name: i.folder.name, members: i.members);
      }
    }
    return null;
  }

  @override
  FolderSnapshot? watch(WidgetRef ref, EffectiveTheme theme, String id) =>
      _find(ref.watch(drawerItemsProvider(theme)), id);

  @override
  FolderSnapshot? read(WidgetRef ref, EffectiveTheme theme, String id) =>
      _find(ref.read(drawerItemsProvider(theme)), id);

  @override
  bool isGenerated(String id) => isCategoryFolder(id);

  @override
  Future<String> editable(
    WidgetRef ref,
    EffectiveTheme theme,
    String id,
    FolderSnapshot live,
  ) async {
    if (!isGenerated(id)) return id;

    final next = newDrawerFolderId();
    await ref.read(prefsProvider(theme.spec.id).notifier).edit(
          (p) => DrawerLayout.materialise(
            p,
            live.name,
            [for (final m in live.members) m.componentKey],
            newFolderId: () => next,
          ),
        );
    return next;
  }

  @override
  List<AppEntry> candidates(WidgetRef ref, EffectiveTheme theme) {
    final folded = DrawerLayout.foldedKeys(theme.prefs);
    return [
      for (final a in ref.read(shellAppsProvider(theme)))
        if (!folded.contains(a.componentKey)) a,
    ];
  }

  @override
  Future<void> rename(
          WidgetRef ref, EffectiveTheme theme, String id, String name) =>
      ref
          .read(prefsProvider(theme.spec.id).notifier)
          .edit((p) => DrawerLayout.rename(p, id, name));

  @override
  Future<void> addMembers(
    WidgetRef ref,
    EffectiveTheme theme,
    String id,
    Iterable<String> keys,
  ) =>
      // ONE edit, not one per app. Each edit is a write and a rebuild; folding
      // the whole selection into a single transform means the drawer animates
      // once.
      ref.read(prefsProvider(theme.spec.id).notifier).edit((p) {
        var next = p;
        for (final k in keys) {
          next = DrawerLayout.addToFolder(next, id, k);
        }
        return next;
      });

  @override
  Future<void> reorder(
    WidgetRef ref,
    EffectiveTheme theme,
    String id,
    String sourceKey,
    String targetKey, {
    required bool after,
  }) =>
      ref.read(prefsProvider(theme.spec.id).notifier).edit(
            (p) => DrawerLayout.reorderMembers(
              p,
              id,
              sourceKey,
              targetKey,
              after: after,
            ),
          );

  @override
  Future<void> removeMember(
    WidgetRef ref,
    EffectiveTheme theme,
    String id,
    String componentKey,
  ) =>
      ref.read(prefsProvider(theme.spec.id).notifier).edit(
            (p) => DrawerLayout.removeFromFolder(p, id, componentKey),
          );

  @override
  Future<void> dissolve(WidgetRef ref, EffectiveTheme theme, String id) =>
      // NO CONVERSION FIRST, deliberately. `dissolve` against a `cat:` id is a
      // no-op, and a no-op is the CORRECT result: a generated folder that is
      // ungrouped is simply rebuilt by the categories, which is what ungrouping
      // it should do. Materialising it only to delete it would be two writes to
      // reach the state it was already in.
      ref
          .read(prefsProvider(theme.spec.id).notifier)
          .edit((p) => DrawerLayout.dissolve(p, id));
}

/// The desktop's folders: `LauncherPrefs.folders`, which occupy a home slot.
///
/// ─── WHAT THE SLOT CHANGES, AND WHAT IT DOES NOT ────────────────────────────
///
/// Reading, renaming, adding and reordering are the same operations the drawer
/// performs, because a folder's CONTENTS are a list whatever surface holds it.
/// Only the two that touch the grid differ: adding frees the app's slot, and
/// dissolving has to find slots for everything coming back out, which is the
/// one operation here that can refuse.
class HomeFolderStore extends FolderStore {
  const HomeFolderStore();

  /// The page capacity this store places against.
  ///
  /// Derived from the resolved theme rather than passed in, so it follows a
  /// user who changes their grid while a folder is open. Same arithmetic
  /// `drawer_actions` uses for Add to home.
  int _capacity(EffectiveTheme theme) => theme.rows * theme.cols;

  FolderSnapshot? _snapshot(
    EffectiveTheme theme,
    String id,
    List<AppEntry> apps,
  ) {
    final f = HomeLayout.folder(theme.prefs, id);
    if (f == null) return null;
    final byKey = {for (final a in apps) a.componentKey: a};
    return FolderSnapshot(
      name: f.name,
      // whereType drops members whose app has been uninstalled but not yet
      // pruned. The drawer's provider already does this for its own folders, so
      // doing it here keeps a dead key from rendering as a blank tile on one
      // surface and nothing on the other.
      members: [
        for (final k in f.members) byKey[k],
      ].whereType<AppEntry>().toList(),
    );
  }

  @override
  FolderSnapshot? watch(WidgetRef ref, EffectiveTheme theme, String id) =>
      _snapshot(theme, id, ref.watch(shellAppsProvider(theme)));

  @override
  FolderSnapshot? read(WidgetRef ref, EffectiveTheme theme, String id) =>
      _snapshot(theme, id, ref.read(shellAppsProvider(theme)));

  @override
  List<AppEntry> candidates(WidgetRef ref, EffectiveTheme theme) {
    final folded = HomeLayout.foldedKeys(theme.prefs);
    return [
      for (final a in ref.read(shellAppsProvider(theme)))
        if (!folded.contains(a.componentKey)) a,
    ];
  }

  @override
  Future<void> rename(
          WidgetRef ref, EffectiveTheme theme, String id, String name) =>
      ref
          .read(prefsProvider(theme.spec.id).notifier)
          .edit((p) => HomeLayout.renameFolder(p, id, name));

  @override
  Future<void> addMembers(
    WidgetRef ref,
    EffectiveTheme theme,
    String id,
    Iterable<String> keys,
  ) =>
      ref.read(prefsProvider(theme.spec.id).notifier).edit((p) {
        var next = p;
        for (final k in keys) {
          next = HomeLayout.addToFolder(next, id, k);
        }
        return next;
      });

  @override
  Future<void> reorder(
    WidgetRef ref,
    EffectiveTheme theme,
    String id,
    String sourceKey,
    String targetKey, {
    required bool after,
  }) =>
      ref.read(prefsProvider(theme.spec.id).notifier).edit(
            (p) => HomeLayout.reorderMembers(
              p,
              id,
              sourceKey,
              targetKey,
              after: after,
            ),
          );

  @override
  Future<void> removeMember(
    WidgetRef ref,
    EffectiveTheme theme,
    String id,
    String componentKey,
  ) =>
      ref.read(prefsProvider(theme.spec.id).notifier).edit(
            (p) => HomeLayout.removeFromFolder(
              p,
              id,
              componentKey,
              capacity: _capacity(theme),
            ),
          );

  @override
  bool canDissolve(WidgetRef ref, EffectiveTheme theme, String id) {
    final f = HomeLayout.folder(theme.prefs, id);
    if (f == null) return true;
    return f.members.length <=
        HomeLayout.dissolveRoom(theme.prefs, id, capacity: _capacity(theme));
  }

  @override
  Future<void> dissolve(WidgetRef ref, EffectiveTheme theme, String id) =>
      ref.read(prefsProvider(theme.spec.id).notifier).edit(
            (p) => HomeLayout.dissolve(p, id, capacity: _capacity(theme)),
          );
}
