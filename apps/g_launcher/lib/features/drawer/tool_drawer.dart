import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/components/anchored_menu.dart';
import '../../design/components/press_pop.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../search/search_page.dart';
// `openTerminal` lives here, not in drawer_actions. That file CALLS it, and
// Dart imports are not transitive, so importing drawer_actions does not bring
// it along.
import '../terminal/terminal_screen.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_drag.dart';
import 'drawer_items.dart';
import 'drawer_state.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// The numbered category menu. Kali's Applications menu, generalised.
///
/// ─── WHY THIS IS NOT KICKOFF WITH DIFFERENT LABELS ──────────────────────────
///
/// [KickoffDrawer] can already draw a category rail, and on the face of it Kali
/// wants exactly that with thirteen names instead of seven. It does not, for
/// one reason that changes the whole widget: **Kickoff's rail only lists
/// buckets that have something in them.**
///
/// That is right for a generated vocabulary, where a category exists because
/// apps happen to declare it, and an empty Social slot would be a rail entry
/// leading to a blank list. It is wrong for an AUTHORED one. Kali's thirteen
/// are named in its theme.json and most of them hold nothing on a phone,
/// because no Android category honestly maps to "01 Information Gathering" and
/// `CategorySet` refuses to pretend otherwise. A rail that hid the empty ones
/// would show two slots out of fourteen and read as a bug.
///
/// So the rail here lists **every** name in [CategorySet.order], full or empty,
/// and an empty one is a shelf rather than a dead end: you drag an app onto it.
/// That is the whole product. The thirteen are not a filing system the launcher
/// applies to you, they are thirteen labelled places you put things.
///
/// ─── AND THE CRUD IS NOT NEW ────────────────────────────────────────────────
///
/// Filing writes a real drawer folder through [DrawerLayout.fileInto], so
/// everything that already works on a folder works here: rename, reorder
/// members, merge, ungroup, and the whole folder overlay. The rail is a second
/// view over `drawerFolders`, not a second store. The only rule that had to
/// bend is the two-or-more invariant, and [DrawerLayout.fileInto] says why: it
/// is a property of the folder GRID, where a tile of one costs a second tap and
/// shows a preview three quarters empty, and a rail slot has neither problem.
///
/// ─── SESSION STATE, LIKE KICKOFF'S ──────────────────────────────────────────
///
/// Which slot is open is not a preference. The menu opens on the fallback
/// bucket every time, because that is where the apps actually are, and a menu
/// that reopened on "07 Reverse Engineering" because you looked at it once is a
/// menu that hides your apps.
final _slotProvider = StateProvider<String?>((ref) => null);

class ToolDrawer extends ConsumerWidget {
  const ToolDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drawerItemsProvider(theme));
    final cats = CategorySet.forTheme(theme);

    // Apps, folders and the terminal go in the list; the two settings entries
    // go in the footer. Same division Kickoff makes and for the same reason:
    // the footer is chrome you configure, the list is things you open.
    final listable = [
      for (final i in items)
        if (switch (i) {
          AppDrawerItem() => true,
          // THE TERMINAL IS IN THE FOOTER HERE, and that departs from Kickoff.
          //
          // `KickoffDrawer` puts it in the list and its doc gives two reasons:
          // the footer holds SETTINGS, which are chrome you configure, while
          // the terminal is something you open; and a third footer button
          // would put three labels where two already fill the width.
          //
          // The first reason does not survive a rail. Kickoff's list is one
          // scrollable run of everything, so a launcher-owned row sits among
          // apps and reads as one. Here every row belongs to the slot the rail
          // has selected, and the terminal belongs to no category: filed under
          // the fallback it looks like an installed app, and filed nowhere it
          // is unreachable. The footer is the only place in this drawer that
          // means "the launcher's own", which is exactly what it is.
          //
          // The second reason is a layout problem and is solved as one: the
          // footer buttons stack their label under their glyph now, so three
          // fit where two did.
          TerminalDrawerItem() => false,
          // FOLDERS ARE NOT IN THE LIST HERE, unlike Kickoff.
          //
          // Every folder in this drawer IS a rail slot: `fileInto` names them
          // after categories, so a folder called "05 Password Attacks" is the
          // shelf, not an item on a shelf. Showing it as a row too would put
          // the same five apps behind two different taps and make the rail
          // look like a filter over a list that already contains everything.
          //
          // A folder whose name is NOT a category is the one exception, and it
          // is handled below rather than here: it gets its own rail slot
          // appended, so a user's own grouping is reachable without inventing
          // a second kind of row.
          FolderDrawerItem() => false,
          LauncherSettingsItem() || DeviceSettingsItem() => false,
        })
          i,
    ];

    // ─── THE RAIL ────────────────────────────────────────────────────────
    //
    // Favourites first, then every authored category in order, then any folder
    // the user made that is not one of them. Nothing is filtered for being
    // empty; see the class doc.
    final folders = <String, FolderDrawerItem>{
      for (final i in items)
        if (i is FolderDrawerItem) i.folder.name: i,
    };

    final buckets = _bucket(listable, cats);

    final slots = <String>[
      _favourites,
      ...cats.order,
      for (final name in folders.keys)
        if (!cats.order.contains(name)) name,
    ];

    // A slot can stop existing between builds: a user folder ungrouped, or a
    // distro republished with a shorter category list. Falling back to the
    // remainder rather than to index zero keeps the menu on the bucket that
    // actually holds apps instead of on Favourites.
    final wanted = ref.watch(_slotProvider);
    final active = (wanted != null && slots.contains(wanted))
        ? wanted
        : cats.fallback;

    final shown = _forSlot(ref, active, listable, buckets, folders);

    final searchAtBottom =
        (theme.prefs.drawerSearchPosition ?? 'bottom') != 'top';
    final showSearch = (theme.prefs.drawerSearchPosition ?? 'bottom') != 'off';
    final search = _Search(theme: theme);

    return ColoredBox(
      // The drawer's own wash, exactly as AppDrawer paints it: the desktop
      // stays legible behind the menu, which is what stops a full-screen menu
      // reading as a separate app.
      color: theme.palette.bgBottom
          .withValues(alpha: 0.94 * theme.drawerOpacity),
      child: SafeArea(
        child: Column(
          children: [
            if (showSearch && !searchAtBottom) search,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rail(
                    theme: theme,
                    slots: slots,
                    active: active,
                    counts: {
                      for (final s in slots)
                        s: _forSlot(ref, s, listable, buckets, folders).length,
                    },
                    onSelect: (s) =>
                        ref.read(_slotProvider.notifier).state = s,
                    onDropApp: (s, key) => _file(ref, s, key),
                  ),
                  Expanded(
                    child: _List(theme: theme, items: shown),
                  ),
                ],
              ),
            ),
            if (showSearch && searchAtBottom) search,
            _Footer(theme: theme),
          ],
        ),
      ),
    );
  }

  /// The pinned-apps slot. Not a category, so it carries a name no authored
  /// vocabulary can collide with by accident.
  static const _favourites = '\u2605 Favourites';

  /// Bucket the loose apps by category, the same rule everything else applies.
  ///
  /// Deliberately a third copy of this shape, like Kickoff's, and for the same
  /// reason its doc gives: the RULE is what must not diverge, and the rule is
  /// [CategorySet]. What differs is only what comes out, which here is entries
  /// rather than folders or rows.
  Map<String, List<DrawerItem>> _bucket(
    List<DrawerItem> all,
    CategorySet cats,
  ) {
    final buckets = <String, List<DrawerItem>>{};
    for (final item in all) {
      if (item is! AppDrawerItem) continue;
      final name = cats.nameFor(item.entry);
      if (name == null) continue;
      (buckets[name] ??= []).add(item);
    }
    // NO SWEEP. Kickoff sweeps sub-threshold buckets into the fallback so a
    // lone app is not stranded behind a rail slot the rail refuses to draw.
    // This rail draws every slot, so nothing can be stranded, and sweeping
    // would move an app the user can plainly see out from under its own
    // category.
    return buckets;
  }

  /// What a slot shows: a real folder's members if one bears its name, plus
  /// whatever the categoriser put there, plus the pinned apps for Favourites.
  ///
  /// The union is what makes filing feel like nothing happened. An app dragged
  /// into "11 Forensics" leaves the loose list (it is folded now) and arrives
  /// in that folder, so without adding the folder's members here the app would
  /// simply vanish from the slot it was just dropped on.
  /// ─── EACH ROW REMEMBERS WHETHER IT WAS FILED ────────────────────────
  ///
  /// The rows in a slot come from two places and only one of them can be
  /// removed: a FILED app is a member of a real folder and has an id to be
  /// pulled out of, while a CATEGORISED app is there because its manifest says
  /// so and has no folder to leave.
  ///
  /// This returned bare [DrawerItem]s, so the menu had to work out which kind
  /// it was holding by looking a folder up BY NAME and asking whether it
  /// contained the key. That is a second derivation of something this method
  /// already knew, and a second derivation is a second thing that can answer
  /// differently: any mismatch between the slot label and the folder name, of
  /// which there are several possible sources, and Remove silently vanished
  /// from the menu with nothing to say why.
  ///
  /// Carrying the id on the row removes the question. A row either has a
  /// folder id or it does not, and the menu reads it rather than deducing it.
  List<({DrawerItem item, String? folderId})> _forSlot(
    WidgetRef ref,
    String slot,
    List<DrawerItem> all,
    Map<String, List<DrawerItem>> buckets,
    Map<String, FolderDrawerItem> folders,
  ) {
    if (slot == _favourites) {
      final byKey = <String, DrawerItem>{
        for (final i in all)
          if (i is AppDrawerItem) i.entry.componentKey: i,
      };
      return [
        // Pinned, not filed. Unpinning is what the Pin glyph already does, so
        // Remove would be a second way to do the same thing.
        for (final k in theme.prefs.favourites)
          if (byKey[k] != null) (item: byKey[k]!, folderId: null),
      ];
    }

    final folder = folders[slot];
    return [
      if (folder != null)
        for (final e in folder.members)
          (item: AppDrawerItem(e), folderId: folder.folder.id),
      for (final i in buckets[slot] ?? const <DrawerItem>[])
        (item: i, folderId: null),
    ];
  }

  /// File an app onto a shelf.
  ///
  /// By NAME rather than by folder id, because most shelves have no folder yet:
  /// see [DrawerLayout.fileInto]. A refusal (the app is already in another
  /// folder) comes back as identical prefs, and the caller says so rather than
  /// letting the drag look like it worked.
  void _file(WidgetRef ref, String slot, String componentKey) {
    if (slot == _favourites) return;
    HapticFeedback.mediumImpact();
    ref
        .read(prefsProvider(theme.spec.id).notifier)
        .edit((p) => DrawerLayout.fileInto(
              p,
              slot,
              componentKey,
              newFolderId: newDrawerFolderId,
            ));
  }
}

/// The numbered column.
///
/// Fixed width and scrollable, because thirteen entries plus Favourites plus
/// the remainder will not fit any phone, and a rail that shrank its rows to fit
/// would put "09 Sniffing and Spoofing" on four lines.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.theme,
    required this.slots,
    required this.active,
    required this.counts,
    required this.onSelect,
    required this.onDropApp,
  });

  final EffectiveTheme theme;
  final List<String> slots;
  final String active;

  /// How many items each slot holds, so an empty shelf can say so rather than
  /// look identical to a full one until you tap it.
  final Map<String, int> counts;

  final ValueChanged<String> onSelect;
  final void Function(String slot, String componentKey) onDropApp;

  static const _width = 132.0;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return SizedBox(
      width: _width,
      child: ColoredBox(
        color: palette.bar.withValues(alpha: 0.55),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: slots.length,
          itemBuilder: (context, i) {
            final slot = slots[i];
            final on = slot == active;
            final count = counts[slot] ?? 0;

            return DragTarget<DrawerDrag>(
              // Only apps file. A folder dropped on a rail slot would be asking
              // to merge two shelves, which `mergeFolders` can do but which is
              // a different gesture with a different outcome, and guessing
              // between them from one drop is how apps get lost.
              onWillAcceptWithDetails: (d) => d.data is AppDrag,
              onAcceptWithDetails: (d) {
                final drag = d.data;
                if (drag is AppDrag) onDropApp(slot, drag.componentKey);
              },
              builder: (context, candidate, __) {
                final hovering = candidate.isNotEmpty;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(slot);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 110),
                    padding: const EdgeInsets.fromLTRB(9, 8, 7, 8),
                    decoration: BoxDecoration(
                      color: hovering
                          ? palette.accent.withValues(alpha: 0.28)
                          : on
                              ? palette.accent.withValues(alpha: 0.16)
                              : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          // The active marker is a bar down the leading edge,
                          // not a fill: at thirteen rows a filled row reads as
                          // a selected list item and the rail stops looking
                          // like a menu.
                          color: on ? palette.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            slot,
                            // THREE, not two. At 132dp in mono the longest
                            // authored label, "03 Web Application Analysis",
                            // wraps to three lines and was being truncated to
                            // "03 Web Application Anal" plus an ellipsis. A
                            // rail entry the user cannot read is a shelf they
                            // cannot tell apart from the one above it, and the
                            // ellipsis is a runtime backstop rather than a
                            // layout anyone should be seeing.
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: theme.typography.mono ?? 'UbuntuMono',
                              fontSize: 10.5 * theme.textScale,
                              height: 1.25,
                              color: on
                                  ? palette.onDark
                                  : palette.onDark.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 5),
                          Padding(
                            // Nudged down to sit on the first line's baseline
                            // rather than at the top of a two-line label.
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontFamily:
                                    theme.typography.mono ?? 'UbuntuMono',
                                fontSize: 9.5 * theme.textScale,
                                color: palette.onDark.withValues(alpha: 0.40),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The slot's contents, as rows.
///
/// A list rather than a grid, because the rail already spends 132dp and what is
/// left will not hold four readable columns on a 360dp phone. It is also what
/// the menu it imitates does.
class _List extends ConsumerWidget {
  const _List({required this.theme, required this.items});

  final EffectiveTheme theme;
  final List<({DrawerItem item, String? folderId})> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Text(
            // AN INSTRUCTION, NOT AN APOLOGY. An empty shelf is the normal
            // state of twelve of Kali's thirteen on a phone, so the empty view
            // has to read as "this is how you use it" rather than as an error.
            context.t('drawer.dragAppsHere'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: theme.typography.mono ?? 'UbuntuMono',
              fontSize: 11.5 * theme.textScale,
              height: 1.5,
              color: theme.palette.onDark.withValues(alpha: 0.38),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      itemBuilder: (context, i) => _Row(
        theme: theme,
        item: items[i].item,
        folderId: items[i].folderId,
      ),
    );
  }
}

class _Row extends ConsumerStatefulWidget {
  const _Row({
    required this.theme,
    required this.item,
    required this.folderId,
  });

  final EffectiveTheme theme;
  final DrawerItem item;

  /// The folder this row was FILED into, or null when it is here because its
  /// manifest category put it here. Non-null is exactly the condition under
  /// which Remove can do anything. See [ToolDrawer._forSlot].
  final String? folderId;

  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  /// See `_AppTileState._downAt`. Same release-intent split, because the same
  /// [LongPressDraggable] consumes the same long press.
  Offset? _downAt;
  static const _slop = 24.0;
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final item = widget.item;
    final size = theme.iconSizeDp * 0.55;

    final located = item is AppDrawerItem &&
        ref.watch(locateTargetProvider) == item.entry.componentKey;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Row(
        children: [
          PressPop(
            held: _held || located,
            radius: size * 0.24,
            ringColor: theme.palette.onDark,
            child: SizedBox(
              width: size,
              height: size,
              child: switch (item) {
                AppDrawerItem(:final entry) => AppIcon(entry: entry, size: size),
                // Unreachable: `listable` keeps only real apps, and the
                // terminal moved to the footer with the other two
                // launcher-owned entries. The switch stays exhaustive with no
                // default arm so a new [DrawerItem] variant has to decide
                // whether it belongs in a slot at all.
                TerminalDrawerItem() ||
                FolderDrawerItem() ||
                LauncherSettingsItem() ||
                DeviceSettingsItem() =>
                  const SizedBox.shrink(),
              },
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: theme.typography.display,
                fontSize: 13 * theme.textScale,
                color: theme.palette.onDark,
              ),
            ),
          ),
        ],
      ),
    );

    // A GUARD, not a branch anyone should hit. `listable` filters to real apps
    // and the footer took the terminal, so nothing else reaches a row. Kept
    // because the type still admits one and a crash on a drawer is worse than
    // a row that only launches.
    if (item is! AppDrawerItem) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => activateDrawerItem(context, ref, theme, item),
        child: content,
      );
    }

    final entry = item.entry;

    return LongPressDraggable<DrawerDrag>(
      data: AppDrag(entry.componentKey),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () {
        HapticFeedback.mediumImpact();
        if (mounted) setState(() => _held = true);
      },
      onDraggableCanceled: (_, offset) {
        final from = _downAt;
        if (from == null || (offset - from).distance < _slop) {
          _menu(entry).whenComplete(() {
            if (mounted) setState(() => _held = false);
          });
        } else if (mounted) {
          setState(() => _held = false);
        }
      },
      onDragEnd: (details) {
        if (details.wasAccepted && mounted) setState(() => _held = false);
      },
      feedback: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.1,
            child: AppIcon(entry: entry, size: theme.iconSizeDp),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: content),
      child: Listener(
        onPointerDown: (e) => _downAt = e.position,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => launchDrawerApp(ref, entry),
          child: content,
        ),
      ),
    );
  }

  /// The shared app menu, plus the one verb that only exists here.
  ///
  /// `onRemoveFromHome` is reused rather than a new parameter: the callback is
  /// documented as "the way OFF the surface this menu was opened from", and on
  /// a shelf that is taking the app back off the shelf. Adding a second
  /// callback meaning the same thing would put two ways to leave in the same
  /// three-glyph strip. It carries its own LABEL key, because the verb is the
  /// same and the noun is not.
  Future<void> _menu(AppEntry entry) {
    final theme = widget.theme;
    final folderId = widget.folderId;

    return showDrawerAppMenu(
      context,
      ref,
      theme,
      entry,
      anchor: AnchoredMenu.anchorOf(context),
      removeLabelKey: 'drawer.removeFromFolder',
      // Null for a categorised app: it has no folder to leave, so the glyph
      // would exist only to refuse. Read off the row rather than deduced from
      // the slot name; see [ToolDrawer._forSlot].
      onRemoveFromHome: folderId == null
          ? null
          : () => ref.read(prefsProvider(theme.spec.id).notifier).edit(
                (p) => DrawerLayout.removeFromFolder(
                  p,
                  folderId,
                  entry.componentKey,
                  // ONE, not the default two. See DrawerLayout.fileInto: a
                  // shelf holding one app is worth keeping, so pulling the
                  // second-to-last app out must not dissolve it.
                  dissolveBelow: 1,
                ),
              ),
    );
  }
}

/// The search pill, opening the shared search page.
class _Search extends StatelessWidget {
  const _Search({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SearchPage(theme: theme),
          ),
        ),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: palette.bar.withValues(alpha: 0.72),
            // Square, following the family. A pill here would be the one
            // rounded thing on a distro whose whole chrome is corners.
            borderRadius: BorderRadius.circular(theme.icons.cornerRadius * 10),
            border: Border.all(color: palette.onDark.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 17,
                color: palette.onDark.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 9),
              Text(
                context.t('drawer.searchApps'),
                style: TextStyle(
                  fontFamily: theme.typography.mono ?? 'UbuntuMono',
                  fontSize: 12.5 * theme.textScale,
                  color: palette.onDark.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The launcher's own entries: terminal, settings, device settings.
///
/// THREE, and stacked. Kickoff's footer is two side-by-side buttons with the
/// glyph beside the word, which fills the width at two and cannot take a third
/// without truncating. Stacking the label under the glyph gives each button the
/// full third of the row to wrap into, so "Device settings" reads on two lines
/// rather than being cut to "Device set" plus an ellipsis.
class _Footer extends ConsumerWidget {
  const _Footer({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final ink = palette.onDark.withValues(alpha: 0.72);

    Widget button(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: ink),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    // TWO lines, so the longest of the three wraps instead of
                    // truncating. The ellipsis stays as the runtime backstop
                    // for a translation longer than any of these.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 10.5 * theme.textScale,
                      height: 1.2,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.onDark.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIRST, because it is the one you open rather than the two you
          // configure, and on the distro this drawer was built for it is also
          // the one anyone reaches for.
          //
          // Labelled from the theme, not hardcoded: `terminalLabelFor` reads
          // the distro's own `terminal.appLabel` and falls back per shell, so
          // a distro that calls it something else says so here too.
          button(
            Icons.terminal,
            terminalLabelFor(theme),
            () => openTerminal(context, theme),
          ),
          button(
            Icons.tune,
            context.t('drawer.gLauncher'),
            () => openLauncherSettings(context, theme),
          ),
          button(
            Icons.settings,
            context.t('drawer.deviceSettings'),
            () => activateDrawerItem(
              context,
              ref,
              theme,
              const DeviceSettingsItem(),
            ),
          ),
        ],
      ),
    );
  }
}
