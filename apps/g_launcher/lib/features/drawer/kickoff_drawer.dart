import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../design/branded_message.dart';
import '../../design/components/anchored_menu.dart';
import '../../data/usage/usage_repository.dart';
import '../../data/prefs/home_layout.dart';
import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../engine/effective_theme.dart';
import '../../features/dock/dock_metrics.dart';
import '../search/search_sheet.dart';
import 'app_icon.dart';
import 'drawer_actions.dart';
import 'drawer_drag.dart';
import 'drawer_items.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// Which rail tab Kickoff is showing. Session state, not a preference: Kickoff
/// opens on Favorites every time, exactly like the real thing.
enum KickoffTab { favorites, frequent, all }

/// One entry in the rail: either one of the three tabs, or a generated
/// category.
///
/// A sealed pair rather than a widened enum, because the categories are not
/// known at compile time. Which buckets exist depends on what is installed, so
/// a `KickoffTab.social` arm would be a promise the device cannot always keep.
class _Slot {
  const _Slot.tab(KickoffTab this.tab)
      : category = null,
        isAdd = false;
  const _Slot.category(String this.category)
      : tab = null,
        isAdd = false;

  /// The `+` at the end of the rail.
  ///
  /// A third kind rather than a widget appended beside the rail, so it scrolls
  /// with the categories and cannot end up off-screen on a distro with twelve
  /// of them. It is never selectable: tapping it opens a prompt and the rail
  /// stays where it was.
  const _Slot.add()
      : tab = null,
        category = null,
        isAdd = true;

  final KickoffTab? tab;
  final String? category;
  final bool isAdd;

  /// Stable across rebuilds, which is what the provider stores. Holding a
  /// [_Slot] directly would need value equality; holding the id needs nothing.
  String get id => isAdd
      ? 'add'
      : tab != null
          ? 'tab:${tab!.name}'
          : 'cat:$category';

  String get label => switch (tab) {
        KickoffTab.favorites => 'Favorites',
        KickoffTab.frequent => 'Frequent',
        KickoffTab.all => 'All',
        null => isAdd ? 'New category' : category!,
      };

  IconData get icon => switch (tab) {
        KickoffTab.favorites => Icons.star_outline,
        KickoffTab.frequent => Icons.history,
        KickoffTab.all => Icons.apps_outlined,
        null when isAdd => Icons.add,
        null => switch (category!) {
            'Social' => Icons.people_outline,
            'Media' => Icons.play_circle_outline,
            'Productivity' => Icons.work_outline,
            'Games' => Icons.sports_esports_outlined,
            'News' => Icons.article_outlined,
            'Travel' => Icons.flight_outlined,
            'Utilities' => Icons.build_outlined,
            // 'Other', and anything a newer build adds to kCategoryOrder that
            // this switch has not been taught yet. A glyph, never a crash.
            _ => Icons.more_horiz,
          },
      };
}

/// Session state, not a preference: Kickoff opens on Favorites every time,
/// exactly like the real thing. Stored as [_Slot.id] so a category that stops
/// existing (its last app uninstalled) simply fails to match and the rail falls
/// back to Favorites, rather than holding a dangling reference.
/// Is an app being dragged right now?
///
/// ─── THE RAIL GROWS WHILE YOU ARE CARRYING SOMETHING ────────────────────────
///
/// A categories rail is 56dp of icon with no label, which is a fine thing to
/// TAP and a poor thing to aim at with an app under your thumb: the icon you
/// are dropping onto is hidden by the hand doing the dropping, and twelve
/// stacked 44dp targets is a column of near-misses.
///
/// So while a drag is in flight the rail widens and labels itself. That is the
/// one moment the extra width costs nothing, because the list beside it is not
/// what you are looking at.
///
/// A provider rather than local state because the row that starts the drag and
/// the rail that grows are siblings, and the alternative is threading a
/// callback through both.
final _draggingProvider = StateProvider.autoDispose<bool>((ref) => false);

final _slotProvider =
    StateProvider.autoDispose<String>((ref) => 'tab:${KickoffTab.favorites.name}');

/// KDE Plasma's Kickoff menu.
///
/// The shape that says "KDE" is not a grid — it is a **category rail on the left
/// and a list of icon-and-name rows on the right**, with system actions along
/// the bottom. That list row is the signature: GNOME shows you a wall of icons,
/// Kickoff shows you a menu.
///
/// **Where the categories come from.** Android apps carry no freedesktop
/// categories, so "Games / Office / Development" would have to be invented — a
/// heuristic, or a Play Store lookup, both of which are wrong often enough to be
/// annoying. So the rail uses what the launcher already knows for certain:
///
///  - **Favorites** — the dock pins (`prefs.favourites`). Literally what KDE's
///    Favorites tab is: the apps you chose.
///  - **Frequent** — `frequentAppsProvider`, the same frecency ranking that
///    fills an unpinned dock.
///  - **All** — everything, A-to-Z, folders included.
///
/// Zero new data, zero guessing, and each tab means something the user can
/// predict. Folders appear in All (and in Favorites/Frequent they cannot, since
/// those are keyed by component key).
///
/// Everything comes off the shared [drawerItemsProvider], so hidden apps, drawer
/// folders and the launcher-owned entries all behave exactly as they do in the
/// GNOME drawer — only the presentation differs. The launcher entries are pulled
/// OUT of the list and rendered as the footer, which is where Kickoff puts its
/// system actions.
class KickoffDrawer extends ConsumerWidget {
  const KickoffDrawer({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(drawerItemsProvider(theme));
    final slotId = ref.watch(_slotProvider);

    // Apps and folders go in the list; the two launcher-owned entries go in the
    // footer. The switch is exhaustive so a new DrawerItem variant has to
    // declare which side of that line it falls on.
    final listable = [
      for (final i in items)
        if (switch (i) {
          AppDrawerItem() || FolderDrawerItem() => true,
          // THE TERMINAL GOES IN THE LIST, not the footer, and it is the one
          // launcher entry that does. The footer holds the two SETTINGS
          // entries, which are chrome you configure; the terminal is something
          // you open, which is what the list is for. A third footer button
          // would also put three labels where two already fill the width.
          TerminalDrawerItem() => true,
          LauncherSettingsItem() || DeviceSettingsItem() => false,
        })
          i,
    ];

    // Categories only in the categories rail, so a KDE-rail distro does no
    // bucketing work at all and its drawer is byte-identical to before.
    // THE DISTRO'S vocabulary. Identical to the built-in set for every theme
    // that authors no `categories`, so no plasma distro shipping today moves.
    final cats = CategorySet.forTheme(theme);

    final buckets = theme.kickoffRail == 'categories'
        ? _bucket(listable, cats)
        : const <String, List<DrawerItem>>{};

    // ─── THE DISTRO'S CATEGORIES, THEN THE USER'S ─────────────────────
    //
    // `cats.order` is computed: the built-in buckets, or whatever the distro
    // authored. It cannot be edited, and it should not be, because a user
    // renaming Social would be renaming a rule the manifest supplies.
    //
    // What the user owns is FOLDERS, which `DrawerLayout` has always stored and
    // which the tool menu already files into by name. Showing them in the rail
    // beside the computed ones makes the two the same thing to a thumb: drag an
    // app onto a name and it is filed there, whether that name came from the
    // distro or from you.
    //
    // Sorted by name and deduped against the computed set, so a folder called
    // Games does not appear twice.
    final computed = {
      for (final name in cats.order)
        if (buckets[name] != null) name,
    };
    final userFolders = [
      for (final f in DrawerLayout.orderedFolders(theme.prefs))
        if (!computed.contains(f.name)) f.name,
    ]..sort();

    final slots = <_Slot>[
      for (final t in KickoffTab.values) _Slot.tab(t),
      for (final name in cats.order)
        if (buckets[name] != null) _Slot.category(name),
      for (final name in userFolders) _Slot.category(name),
      // Only on the categories rail. A tabs rail is Favorites, Frequent and
      // All, and a `+` beside three fixed tabs would be offering to add a
      // fourth tab, which is not what it does.
      if (theme.kickoffRail == 'categories') const _Slot.add(),
    ];

    // A category can stop existing between builds (its last app uninstalled),
    // so a stored id that no longer matches falls back rather than showing an
    // empty rail with nothing selected.
    final active = slots.firstWhere(
      (s) => s.id == slotId && !s.isAdd,
      orElse: () => slots.first,
    );

    final shown = _forSlot(ref, active, listable, buckets);

    final searchAtBottom =
        (theme.prefs.drawerSearchPosition ?? 'bottom') != 'top';
    final search = _KickoffSearch(theme: theme);

    // Kickoff paints its OWN surface, and deliberately NOT the way GNOME does.
    // Activities is a translucent wash over the wallpaper; Kickoff is a solid
    // menu welded to the panel — you do not see your desktop through it. Same
    // palette, opposite treatment, which is a large part of why the two shells
    // read as different desktops rather than one drawer in two colours.
    //
    // The shell should mount this full-bleed and add nothing: no back arrow
    // (KDE closes Kickoff by pressing the launcher again or clicking away), no
    // second background.
    // Material, not ColoredBox: the rows and the footer buttons are InkWells,
    // and a shell overlay has no Scaffold above it to supply the Material
    // ancestor they require. Same crash the desktop bar hit; fixed here before
    // it can fire, since it only shows on a KDE theme.
    return Material(
      // Kickoff is the plasma shell's drawer, so it takes the DRAWER setting,
      // not the bar one, even though it is painted in the panel colour: what
      // the user is adjusting is the app list, and `palette.bar` is only where
      // the colour comes from. Breeze's Kickoff is near-solid by design, so
      // this scales an opaque base rather than an authored alpha.
      color: theme.palette.bar.withValues(alpha: theme.drawerOpacity),
      child: SafeArea(
        // The footer draws its own bottom inset, so the menu meets the panel.
        bottom: false,
        child: Column(
          children: [
            if (!searchAtBottom) search,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rail(theme: theme, slots: slots, active: active),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The categories rail is icon-only, so the label has to
                        // land somewhere or the user cannot tell Travel from
                        // Utilities. Heading the list is where Cinnamon puts it
                        // and it costs no rail width.
                        if (theme.kickoffRail == 'categories')
                          _ListHeading(theme: theme, slot: active),
                        Expanded(
                          child: shown.isEmpty
                        ? _Empty(theme: theme, slot: active)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: shown.length,
                            itemBuilder: (context, i) => _Row(
                              // Stable identity so switching tabs or creating a
                              // folder reuses rows instead of re-requesting
                              // every icon from native.
                              key: ValueKey(_idOf(shown[i])),
                              theme: theme,
                              item: shown[i],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (searchAtBottom) search,
            _Footer(theme: theme),
          ],
        ),
      ),
    );
  }

  /// A stable identity per row, for widget keys.
  static String _idOf(DrawerItem item) => switch (item) {
        AppDrawerItem(:final entry) => entry.componentKey,
        FolderDrawerItem(:final folder) => folder.id,
        LauncherSettingsItem() => 'launcher-settings',
        DeviceSettingsItem() => 'device-settings',
        TerminalDrawerItem() => 'terminal',
      };

  /// Category buckets, built the SAME way the library drawer builds them.
  ///
  /// Deliberately a copy of the shape in `drawer_items.dart` rather than a call
  /// into it: that function returns FOLDERS, and Kickoff wants flat lists of
  /// rows. What must not diverge is the RULE, and the rule is now a type:
  /// [CategorySet] owns the filing, the order and the sweep, so the two copies
  /// cannot disagree about any of the three the way they did while each held
  /// its own [kCategoryOrder] walk and its own literal `'Other'`.
  ///
  /// Sweeping matters more here than it looks. Without it a lone Social app
  /// would be reachable from no rail slot at all, because the rail only lists
  /// buckets that survived the threshold. It would be in the list, in the
  /// drawer, and findable only through All.
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

    // The fallback is never swept, and it is no longer the literal 'Other':
    // a distro that renamed it would have had its own remainder bucket swept
    // into a bucket called Other that nothing else would ever produce.
    cats.sweep(buckets);

    return buckets;
  }

  /// The rail's views over the one list.
  ///
  /// Favorites and Frequent are ORDERED by their source (pin order, frecency
  /// rank) rather than alphabetically, and that ordering is the whole point of
  /// those tabs. All and the categories keep the provider's A-to-Z.
  List<DrawerItem> _forSlot(
    WidgetRef ref,
    _Slot slot,
    List<DrawerItem> all,
    Map<String, List<DrawerItem>> buckets,
  ) {
    if (slot.category != null) {
      final computed = buckets[slot.category];
      if (computed != null) return computed;
      // A USER FOLDER. `buckets` holds only what `CategorySet` computed, so a
      // name the user made has nothing in there; its members live in
      // `DrawerLayout` and are already resolved to entries by
      // `drawerItemsProvider`.
      for (final i in all) {
        if (i is FolderDrawerItem && i.folder.name == slot.category) {
          return [for (final e in i.members) AppDrawerItem(e)];
        }
      }
      return const [];
    }

    final tab = slot.tab!;
    if (tab == KickoffTab.all) return all;

    final byKey = <String, DrawerItem>{
      for (final i in all)
        if (i is AppDrawerItem) i.entry.componentKey: i,
    };

    final keys = switch (tab) {
      KickoffTab.favorites => theme.prefs.favourites,
      KickoffTab.frequent => ref.watch(frequentAppsProvider),
      KickoffTab.all => const <String>[],
    };

    final picked = [
      for (final k in keys)
        if (byKey[k] != null) byKey[k]!,
    ];

    // Nothing used yet on a fresh install. Falling back to the alphabetical
    // head keeps the tab from reading as broken — the same fallback the Plasma
    // panel's task strip already uses. Favorites has no fallback on purpose:
    // an empty Favorites is TRUE (you have pinned nothing) and its empty state
    // says how to fill it.
    if (picked.isEmpty && tab == KickoffTab.frequent) {
      return all.take(12).toList();
    }
    return picked;
  }
}

/// The rail. Active slot takes the accent, KDE-style: a filled left border and
/// a tinted background.
///
/// ─── TWO WIDTHS, AND THAT IS THE WHOLE DIFFERENTIATION ──────────────────────
///
/// Tabs mode is 74dp with a label under every glyph, which is KDE's Kickoff and
/// what every plasma distro drew before this field existed.
///
/// Categories mode is 56dp and icon-only, because three labelled entries fit a
/// phone and eleven do not: "Productivity" does not render at 74dp, and a rail
/// wide enough for it eats the list. Icon-only also means the two rails read as
/// two menus at a glance rather than as one menu with more rows, which is the
/// point of the field. The active label heads the list instead.
///
/// Scrollable in both modes. Eleven slots at 40dp clears a phone, but a short
/// screen with a large text scale is exactly the device this launcher targets,
/// and a rail that clips its last category is a category the user cannot reach.
class _Rail extends ConsumerWidget {
  const _Rail({
    required this.theme,
    required this.slots,
    required this.active,
  });

  final EffectiveTheme theme;
  final List<_Slot> slots;
  final _Slot active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDark = theme.palette.onDark;
    // ─── COMPACT UNTIL SOMETHING IS BEING CARRIED ─────────────────────────
    //
    // A categories rail is icon-only at 56dp, which is right for tapping and
    // wrong for dropping: the icon you are aiming at is under the hand doing
    // the aiming, and a column of unlabelled 44dp targets is a column of
    // near-misses.
    //
    // While a drag is in flight it stops being compact, so every slot gets its
    // name back and the whole rail gets wider. That is the one moment the width
    // costs nothing, because the list beside it is not what you are looking at.
    final dragging = ref.watch(_draggingProvider);
    final compact = theme.kickoffRail == 'categories' && !dragging;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: compact ? 56 : 74,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: onDark.withValues(alpha: 0.10)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 6),
            for (final s in slots)
              _RailItem(
                theme: theme,
                slot: s,
                compact: compact,
                selected: s.id == active.id,
                // The `+` is a DROP TARGET, not a tab. Selecting it would
                // switch the list to a category that does not exist yet, and
                // the fallback above would bounce straight back to Favourites,
                // which reads as a tap that did nothing. It says what it wants
                // instead.
                onTap: s.isAdd
                    ? () => context.showMessage(
                          context.t('drawer.dragAppsHere'),
                        )
                    : () => ref.read(_slotProvider.notifier).state = s.id,
                // ─── DROP AN APP ON FAVOURITES TO PIN IT ──────────────
                //
                // Only the Favourites tab takes a drop. Frequent is computed
                // from usage and All is everything, so a drop on either would
                // be a gesture with nowhere to write; a category slot is a
                // filing rule, not a list you put things in.
                //
                // Returning null rather than an empty callback is what stops
                // the other slots from lighting up as targets. A slot that
                // highlights and then does nothing is worse than one that
                // never reacted.
                // ── EVERY NAMED SLOT TAKES A DROP NOW ─────────────────
                //
                // Favourites pins. A category FILES, into a folder of that
                // name, using the same `DrawerLayout.fileInto` the tool menu
                // has used since Kali's pass, so an app dropped on Games ends
                // up in the same place whichever drawer you did it from.
                //
                // Frequent and All still refuse. Frequent is computed from
                // usage and All is everything, so a drop on either has nowhere
                // to write, and a null callback is what stops them lighting up.
                onDropApp: s.isAdd
                    ? (key) => _newCategory(
                          ref,
                          theme,
                          key,
                          {
                            for (final x in slots)
                              if (x.category != null) x.category!,
                          },
                        )
                    : s.category != null
                        ? (key) => _file(ref, theme, s.category!, key)
                        : s.tab == KickoffTab.favorites
                    ? (key) {
                        // ── AGAINST THE CEILING, AND SAY SO WHEN FULL ──
                        //
                        // `capacity` is `DockMetrics.maxCapacity`, not what
                        // the current dock side holds: `drawer_actions` makes
                        // the same call and explains why. Pinning the
                        // eleventh on a bottom dock is not lost, it appears
                        // when the dock moves to the left edge.
                        //
                        // And the refusal is SPOKEN. `pinToDock` returns the
                        // prefs unchanged when it is full, and a drag that
                        // ends with the app back where it started and no
                        // explanation reads as a broken gesture rather than a
                        // full list.
                        final before = theme.prefs;
                        final after = HomeLayout.pinToDock(
                          before,
                          key,
                          capacity: DockMetrics.maxCapacity,
                        );
                        if (identical(before, after)) {
                          context.showMessage(
                            context.t('drawer.dockIsFull'),
                          );
                          return;
                        }
                        HapticFeedback.mediumImpact();
                        ref
                            .read(prefsProvider(theme.spec.id).notifier)
                            .edit((p) => HomeLayout.pinToDock(
                                  p,
                                  key,
                                  capacity: DockMetrics.maxCapacity,
                                ));
                      }
                    : null,
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ─── TOP LEVEL, BECAUSE THE CALLER IS THE RAIL ────────────────────────────
//
// These were methods on the drawer widget and every call site is inside
// `_Rail`, which is a sibling rather than a child. Passing `theme` explicitly
// is what that costs, and it is cheaper than threading two callbacks down.
/// File an app into a folder named after a rail slot.
///
/// `DrawerLayout.fileInto` creates the folder if it does not exist, which is
/// what makes a computed category and a user one behave alike: dropping on
/// Games when Games is a manifest bucket makes a real folder called Games,
/// and from then on the two are the same slot.
///
/// `dissolveBelow: 1` for the tool menu's reason: a shelf holding one app is
/// a legitimate thing to have made on purpose.
void _file(WidgetRef ref, EffectiveTheme theme, String category, String key) {
  HapticFeedback.mediumImpact();
  ref
      .read(prefsProvider(theme.spec.id).notifier)
      .edit((p) => DrawerLayout.fileInto(
            p,
            category,
            key,
            // A FACTORY, not an id. `fileInto` generates it inside the edit so
            // two drops landing in the same frame cannot both decide the folder
            // does not exist and write it twice; its own doc says so. Passing a
            // value computed out here would put the race back.
            newFolderId: newDrawerFolderId,
          ));
}

/// Make a category from the app dropped on the `+`.
///
/// ─── NO NAME PROMPT, AND THAT IS DELIBERATE ─────────────────────────────
///
/// The obvious version asks for a name first. There is no shared prompt in
/// this app to ask with: `folder_overlay` renames IN PLACE with its own
/// focus handling and its own save-on-dismiss rule, and building a second
/// dialog beside it would be a second answer to "what happens if you tap
/// away mid-edit".
///
/// So this does what a phone does. The folder is made with a working name,
/// the rail switches to it, and renaming is the thing the folder's own
/// screen already does properly. One naming surface, not two.
///
/// The name is numbered when taken, because a second `New category` beside
/// the first is two slots with one label and no way to tell them apart.
void _newCategory(
  WidgetRef ref,
  EffectiveTheme theme,
  String key,
  Set<String> taken,
) {
  const base = 'New category';
  var name = base;
  var n = 2;
  while (taken.contains(name)) {
    name = '$base $n';
    n++;
  }
  _file(ref, theme, name, key);
  ref.read(_slotProvider.notifier).state = _Slot.category(name).id;
}


/// The active category's name, above the list, in the categories rail only.
///
/// Not a section header inside the ListView: it must not scroll away, because
/// it is the only thing naming what an icon-only rail selected.
class _ListHeading extends StatelessWidget {
  const _ListHeading({required this.theme, required this.slot});

  final EffectiveTheme theme;
  final _Slot slot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Text(
        slot.label,
        style: TextStyle(
          fontSize: 11.5 * theme.textScale,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: theme.palette.accent,
          fontFamily: theme.typography.display,
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.theme,
    required this.slot,
    required this.compact,
    required this.selected,
    required this.onTap,
    this.onDropApp,
  });

  final EffectiveTheme theme;
  final _Slot slot;

  /// Icon-only, 56dp rail. See [_Rail]'s note.
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  /// Null on every slot that cannot take a drop. See [_Rail].
  final void Function(String componentKey)? onDropApp;

  @override
  Widget build(BuildContext context) {
    final accent = theme.palette.accent;
    final onDark = theme.palette.onDark;
    final ink = selected ? accent : onDark.withValues(alpha: 0.65);

    final tile = _tile(accent, ink, hovering: false);

    if (onDropApp == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      );
    }

    return DragTarget<DrawerDrag>(
      // Apps only. A folder dragged onto Favourites would be asking to pin a
      // folder, which the dock cannot hold, and guessing that they meant its
      // first member is how apps end up somewhere nobody chose.
      onWillAcceptWithDetails: (d) => d.data is AppDrag,
      onAcceptWithDetails: (d) {
        final drag = d.data;
        if (drag is AppDrag) onDropApp!(drag.componentKey);
      },
      builder: (context, candidate, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _tile(accent, ink, hovering: candidate.isNotEmpty),
      ),
    );
  }

  Widget _tile(
    Color accent,
    Color ink, {
    required bool hovering,
  }) {
    return Container(
        // Tighter when icon-only: the label is what needed the vertical room,
        // and eleven slots at the labelled spacing would not clear a phone.
        padding: EdgeInsets.symmetric(vertical: compact ? 11 : 10),
        decoration: BoxDecoration(
          // Hovering reads STRONGER than selected, deliberately: while a drag
          // is over it the question is no longer which tab you are on, it is
          // where this app is about to land.
          color: hovering
              ? accent.withValues(alpha: 0.30)
              : selected
                  ? accent.withValues(alpha: 0.14)
                  : null,
          border: Border(
            left: BorderSide(
              color: (selected || hovering) ? accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          children: [
            // Semantics, not decoration. An icon-only rail is unreadable to a
            // screen reader without it, and this is the one mode where the
            // visible label is gone.
            Semantics(
              label: compact ? slot.label : null,
              child: Icon(slot.icon, size: compact ? 20 : 19, color: ink),
            ),
            if (!compact) ...[
              const SizedBox(height: 3),
              Text(
                slot.label,
                style: TextStyle(
                  fontSize: 11 * theme.textScale,
                  color: ink,
                  fontFamily: theme.typography.display,
                ),
              ),
            ],
          ],
        ),
    );
  }
}

/// One Kickoff row: icon, then name. The list-not-grid shape is the signature.
///
/// ─── AND IT DRAGS, WHICH IS WHY THE HOLD GOT COMPLICATED ────────────────────
///
/// An app row is a [LongPressDraggable] now, so it can be dropped on the
/// Favourites tab. That takes the long press, which was already spoken for by
/// the menu, so intent is read on RELEASE the way `app_drawer` and `home_grid`
/// both do it: if nothing accepted the drop and the finger never travelled past
/// [_slop], it was a hold.
///
/// The two pieces that pattern needs, and that a naive version forgets:
/// [pointerDragAnchorStrategy], so the release offset is the FINGER rather than
/// the feedback's corner, and a [Listener] on pointer-down, because the
/// draggable reports no start position.
///
/// Non-app rows keep the plain `InkWell`. A folder cannot be pinned and the
/// launcher entries have no component key, so wrapping them would offer a
/// gesture that can only fail.
class _Row extends ConsumerStatefulWidget {
  const _Row({super.key, required this.theme, required this.item});

  final EffectiveTheme theme;
  final DrawerItem item;

  @override
  ConsumerState<_Row> createState() => _RowState();
}

class _RowState extends ConsumerState<_Row> {
  Offset? _downAt;

  /// The same 24dp `app_drawer` uses, so a hold on a Kickoff row and a hold on
  /// a drawer tile forgive the same amount of thumb wobble.
  static const _slop = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final item = widget.item;
    final onDark = theme.palette.onDark;
    // Rows are denser than grid tiles; a full-size drawer icon overwhelms them.
    final size = theme.iconSizeDp * 0.62;

    final row = InkWell(
      onTap: () => activateDrawerItem(context, ref, theme, item),
      onLongPress: switch (item) {
        AppDrawerItem(:final entry) => () =>
            showDrawerAppMenu(context, ref, theme, entry,
                anchor: AnchoredMenu.anchorOf(context)),
        final FolderDrawerItem f => () =>
            drawerFolderSettings(context, ref, theme, f,
                anchor: AnchoredMenu.anchorOf(context)),
        // Neither pin nor uninstall nor rename applies to a launcher entry, and
        // an empty sheet is worse than none. The terminal will eventually earn
        // a menu of its own (new session, snippets, hosts); until those exist,
        // showing an empty one would be the same mistake.
        LauncherSettingsItem() ||
        DeviceSettingsItem() ||
        TerminalDrawerItem() =>
          null,
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: switch (item) {
                AppDrawerItem(:final entry) =>
                  AppIcon(entry: entry, size: size),
                final FolderDrawerItem f => _FolderGlyph(theme: theme, item: f),
                LauncherSettingsItem() =>
                  LauncherBrandIcon(theme: theme, size: size),
                DeviceSettingsItem() => Icon(
                    Icons.settings,
                    size: size * 0.82,
                    color: onDark,
                  ),
                // A plain glyph rather than the brand mark. The brand mark says
                // "this launcher's own settings"; the terminal is a tool, and
                // it reads as one next to the app icons it sits among.
                TerminalDrawerItem() => Icon(
                    Icons.terminal,
                    size: size * 0.82,
                    color: onDark,
                  ),
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5 * theme.textScale,
                  color: onDark,
                  fontFamily: theme.typography.display,
                ),
              ),
            ),
            // Folders advertise that tapping opens rather than launches.
            if (item is FolderDrawerItem)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: onDark.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );

    // Only real apps drag: a folder cannot be pinned and the launcher entries
    // have no component key. Everything else keeps the plain row, which also
    // keeps its long press exactly as it was.
    if (item is! AppDrawerItem) return row;

    final entry = item.entry;

    return LongPressDraggable<DrawerDrag>(
      data: AppDrag(entry.componentKey),
      // See the class doc: under the default strategy the release offset is the
      // feedback's top-left, which on a full-width row is most of a screen from
      // the finger, and the slop test below could never pass.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () {
        HapticFeedback.selectionClick();
        ref.read(_draggingProvider.notifier).state = true;
      },
      // BOTH endings, not just the cancel. `onDraggableCanceled` fires when
      // nothing accepted; `onDragEnd` fires either way. Setting the flag false
      // only in the cancel path would leave the rail expanded forever after the
      // first successful drop.
      onDragEnd: (_) => ref.read(_draggingProvider.notifier).state = false,
      onDraggableCanceled: (_, offset) {
        final from = _downAt;
        // Nothing accepted it and it never moved, so it was a hold. The menu
        // opens here rather than from `onLongPress`, which the draggable has
        // taken.
        if (from == null || (offset - from).distance < _slop) {
          showDrawerAppMenu(
            context,
            ref,
            theme,
            entry,
            anchor: AnchoredMenu.anchorOf(context),
          );
        }
      },
      // The ICON, not the row. Dragging a full-width row across the screen
      // reads as moving the list; an icon under the thumb reads as carrying an
      // app, which is what is happening.
      feedback: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Material(
          color: Colors.transparent,
          child: AppIcon(entry: entry, size: theme.iconSizeDp),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: row),
      child: Listener(
        onPointerDown: (e) => _downAt = e.position,
        child: row,
      ),
    );
  }
}

/// A folder's 2x2 preview, sized for a list row.
class _FolderGlyph extends StatelessWidget {
  const _FolderGlyph({required this.theme, required this.item});

  final EffectiveTheme theme;
  final FolderDrawerItem item;

  @override
  Widget build(BuildContext context) {
    final size = theme.iconSizeDp * 0.62;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.palette.onDark.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(folderCornerRadius(theme, size)),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        children: [
          for (final m in item.members.take(4))
            AppIcon(entry: m, size: size / 2 - 4),
        ],
      ),
    );
  }
}

/// Kickoff's search field. Tapping opens the shared search page, same as the
/// GNOME drawer — one search experience, whichever desktop you are wearing.
class _KickoffSearch extends StatelessWidget {
  const _KickoffSearch({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final onDark = theme.palette.onDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showSearchSheet(context, theme),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: onDark.withValues(alpha: 0.08),
            // Breeze corners are tighter than Adwaita's pills.
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: onDark.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: onDark.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                'Search apps',
                style: TextStyle(
                  color: onDark.withValues(alpha: 0.6),
                  fontFamily: theme.typography.display,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The system row along the bottom — where Kickoff keeps leave/settings actions.
/// These are the launcher-owned [DrawerItem]s, pulled out of the list so they
/// sit where a KDE user expects them instead of alphabetically among the apps.
class _Footer extends ConsumerWidget {
  const _Footer({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDark = theme.palette.onDark;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: onDark.withValues(alpha: 0.10))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _FooterButton(
                theme: theme,
                icon: Icons.settings_outlined,
                label: 'G Launcher',
                onTap: () => activateDrawerItem(
                  context,
                  ref,
                  theme,
                  const LauncherSettingsItem(),
                ),
              ),
            ),
            Container(width: 1, height: 26, color: onDark.withValues(alpha: 0.10)),
            Expanded(
              child: _FooterButton(
                theme: theme,
                icon: Icons.tune,
                label: 'Device settings',
                onTap: () => activateDrawerItem(
                  context,
                  ref,
                  theme,
                  const DeviceSettingsItem(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = theme.palette.onDark.withValues(alpha: 0.7);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12 * theme.textScale,
                  color: ink,
                  fontFamily: theme.typography.display,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An honest empty tab. Favorites starts empty for everyone, and saying how to
/// fill it beats an unexplained blank panel.
class _Empty extends StatelessWidget {
  const _Empty({required this.theme, required this.slot});

  final EffectiveTheme theme;
  final _Slot slot;

  @override
  Widget build(BuildContext context) {
    final text = switch (slot.tab) {
      KickoffTab.favorites =>
        'Pin an app to the dock and it shows up here.\nHold any app, then Pin to dock.',
      KickoffTab.frequent => 'The apps you use most will collect here.',
      KickoffTab.all => 'No apps.',
      // A category slot only exists because it had members when the rail was
      // built, so this is the frame between an uninstall and the rebuild. It
      // needs words rather than a blank panel, but it never sits there.
      null => 'Nothing in this category.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5 * theme.textScale,
            height: 1.5,
            color: theme.palette.onDark.withValues(alpha: 0.5),
            fontFamily: theme.typography.display,
          ),
        ),
      ),
    );
  }
}
