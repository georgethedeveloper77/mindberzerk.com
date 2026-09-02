import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/home_layout.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../design/components/press_pop.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../dock/dock_metrics.dart';
import 'app_icon.dart';
import 'app_menu_words.dart';
import 'drawer_actions.dart';
import 'drawer_items.dart';
import 'drawer_state.dart';
import 'folder_glyph_picker.dart';
import 'folder_glyphs.dart';
import 'folder_store.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// An open drawer folder, full screen, over a blurred desktop.
///
/// ─── WHY THIS REPLACED THE BOTTOM SHEET ─────────────────────────────────────
///
/// A folder used to open as a [ThemedSheet] docked to the bottom of the screen.
/// The folder's name sat in a small header row competing with an Ungroup
/// button, the grid was pinned to the bottom edge under your thumb, and the
/// thing you had just opened looked like a settings panel rather than like the
/// folder you tapped.
///
/// ─── AND WHY THERE ARE NO SHEETS *INSIDE* IT EITHER ─────────────────────────
///
/// The first version of this screen kept reaching for [ThemedSheet] whenever it
/// needed a second surface: rename, add apps, the member long-press menu. Three
/// Android modal bottom sheets sliding up over a desktop metaphor. That is the
/// same category error the bottom-sheet folder was, one level down — the sheet
/// is the nearest primitive to hand on Android, so every secondary surface
/// becomes one, and the launcher stops looking like the desktop it imitates.
///
/// A real desktop has three answers here and none of them is a bottom sheet:
///
///   1. **Rename happens IN PLACE.** Click the name, it becomes an editable
///      field, press Enter. GNOME Files, Finder and Explorer all do this. It
///      also removes an entire modal route from the path, which is strictly
///      less that can go wrong.
///   2. **Adding apps is a centred DIALOG** ([ThemedDialog], a centred card),
///      not a panel climbing up from the bottom edge.
///   3. **Long-press is a CONTEXT MENU at the pointer**, the way a right-click
///      menu appears where you clicked, rather than 400px away at the bottom of
///      the screen.
///
/// ─── CHROME ─────────────────────────────────────────────────────────────────
///
/// This screen INSTALLS its own [ChromeScope], the way [ThemedScaffold] does
/// for every settings page. It is a bare route, so without one everything
/// inside it — and every dialog and menu opened from it, since those capture
/// the chrome before pushing — falls back to [ChromeData.bootstrap] and renders
/// in house colours over a themed desktop. `ChromeScope.of` degrades rather
/// than throwing, which is the right call and also why this class of mistake is
/// invisible until someone looks at it on a non-default theme.
///
/// The folder's own furniture (the blur tint, the panel, the big name) still
/// reads [EffectiveTheme.palette] directly, because that furniture belongs to
/// the DESKTOP layer, not the chrome layer: it sits on the wallpaper, not on a
/// settings page. The chrome is installed for the dialogs and menus.
///
/// ─── THE MATERIAL ───────────────────────────────────────────────────────────
///
/// This is a ROUTE, and a route has no Scaffold. [ThemedListRow] draws ink, so
/// the context menu needs a Material ancestor — the same trap the desktop
/// long-press bar and KickoffDrawer both hit.
Future<void> showFolderOverlay(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  FolderDrawerItem item,
) =>
    _showFolder(context, theme, item.folder.id, const DrawerFolderStore());

/// The same screen, over a HOME folder.
///
/// ─── IT REPLACED A BARE Dialog, AND THAT IS THE WHOLE POINT OF THE SEAM ─────
///
/// The desktop's folders opened into a `Dialog` holding a `TextField` and a
/// `GridView.count(crossAxisCount: 4)`, with raw `TextStyle`, raw palette
/// colours, no [ChromeScope], and a long press that removed a member outright
/// with no menu and no undo. It could not rename properly, could not add,
/// could not reorder, could not pin, could not uninstall, and did not page.
///
/// None of that was a decision about desktop folders. It is simply where the
/// code stopped when `folder_overlay.dart` was written for the drawer and
/// nobody went back. [FolderStore] is what lets one screen answer both without
/// merging two storage models that are correctly separate.
Future<void> showHomeFolderOverlay(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  String folderId,
) =>
    _showFolder(context, theme, folderId, const HomeFolderStore());

Future<void> _showFolder(
  BuildContext context,
  EffectiveTheme theme,
  String folderId,
  FolderStore store,
) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      // Non-opaque: the drawer stays mounted and visible behind the blur, which
      // is what makes this read as the folder opening ON the drawer rather than
      // as a new screen replacing it.
      opaque: false,
      barrierColor: null,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => _FolderOverlay(
        theme: theme,
        folderId: folderId,
        store: store,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        // Fade plus a small scale-up. Scaling from 0.92 rather than from
        // nothing keeps it feeling like the tile expanding; a full zoom from
        // zero reads as a popup and costs more frames on the budget phones this
        // ships to.
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _FolderOverlay extends ConsumerStatefulWidget {
  const _FolderOverlay({
    required this.theme,
    required this.folderId,
    required this.store,
  });

  final EffectiveTheme theme;
  final String folderId;

  /// Where this folder lives. See [FolderStore]: the screen is one, the models
  /// are two, and everything below goes through here rather than naming
  /// `DrawerLayout` directly.
  final FolderStore store;

  @override
  ConsumerState<_FolderOverlay> createState() => _FolderOverlayState();
}

class _FolderOverlayState extends ConsumerState<_FolderOverlay> {
  final _pages = PageController();
  int _page = 0;

  /// In-place rename state. Null means "not editing"; non-null means the title
  /// IS a text field. Held here rather than inside the title widget so that
  /// committing can be triggered from anywhere on the screen — tapping the
  /// backdrop mid-rename should SAVE, not discard.
  TextEditingController? _renaming;
  final _renameFocus = FocusNode();

  /// The auto-close below fires from `build`, and `build` can run more than
  /// once before the scheduled callback lands. Without this the pop is queued
  /// twice and the second one takes the DRAWER's route down with it — a folder
  /// dissolving would close the app drawer, which reads as the launcher
  /// crashing back to the desktop.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() {
      final p = (_pages.page ?? 0).round();
      if (p != _page && mounted) setState(() => _page = p);
    });
    // Losing focus commits, so tapping elsewhere behaves like every
    // rename-in-place field on a desktop: the edit is kept, not thrown away.
    _renameFocus.addListener(() {
      if (!_renameFocus.hasFocus && _renaming != null) _commitRename();
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _renameFocus.dispose();
    _renaming?.dispose();
    super.dispose();
  }

  void _startRename(String current) {
    setState(() {
      _renaming = TextEditingController(text: current)
        ..selection =
            TextSelection(baseOffset: 0, extentOffset: current.length);
    });
    // Focus AFTER the field exists, or the request lands on nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _renameFocus.requestFocus();
    });
  }

  /// ─── THE ID THIS OVERLAY IS SHOWING, WHICH CAN CHANGE UNDER IT ──────────
  ///
  /// `widget.folderId` is the id the overlay was OPENED with, and for a
  /// generated folder that id stops existing the moment `_editable` converts
  /// it: the members move into a real folder and the category is no longer
  /// rebuilt for them.
  ///
  /// Every lookup below was keyed on `widget.folderId`, so the first edit made
  /// the folder vanish from under itself and the "dissolved while open" branch
  /// popped the overlay. From the outside that looked exactly like a gesture
  /// doing nothing: press, and the folder closes.
  ///
  /// So the id lives in state and follows the conversion. `widget.folderId` is
  /// now only the STARTING value and must not be read anywhere else.
  late String _id = widget.folderId;

  /// ─── MATERIALISE ON FIRST EDIT ──────────────────────────────────────────
  ///
  /// This was `_readOnly`, and every gesture here was gated on it: rename
  /// passed a null callback, the member menu returned early, drops were
  /// refused, Add and Ungroup were not rendered. Defensible while the
  /// alternative was writes that silently did nothing, and still wrong: it made
  /// an opened category folder completely inert.
  ///
  /// The problem was never that the writes failed. It was that they could not
  /// STICK. The folder is rebuilt from each app's declared category on the next
  /// launch, so removing an app from Social put it straight back.
  ///
  /// Converting solves both. The first edit writes the folder into
  /// `drawerFolders` under a real id with the members it holds right now, and
  /// from then on it is an ordinary folder: every gesture works, and it stays
  /// as the user left it because `drawerItemsProvider` skips apps that are
  /// already in a folder when it builds the categories.
  ///
  /// Returns the id to edit AGAINST. Callers must use the return value rather
  /// than `widget.folderId`, which after a conversion still names a generated
  /// folder that no longer describes anything.
  /// True while a conversion is in flight. See [_editable].
  bool _converting = false;

  Future<String> _editable(FolderSnapshot live) async {
    // ─── THE FLAG, BECAUSE THE COMMENT BELOW WAS NOT ACHIEVABLE ──────────
    //
    // This used to say the id is swapped BEFORE returning, so the rebuild the
    // write triggers already looks the folder up under its new id. It cannot
    // be: the write happens INSIDE the await, Riverpod notifies while that
    // future is still pending, and the `setState` only runs after it resolves.
    //
    // So exactly one frame rebuilt with the old `cat:` id, `watch` returned
    // null, and the dissolved-while-open branch popped the folder. On screen
    // that is: hold an app inside a derived folder, the folder shuts, and the
    // folder reappears first in the Library because converting made it a user
    // folder and those sort ahead of the categories. One cause, both symptoms,
    // and it is the elementary long-press report from six passes back.
    //
    // The flag closes the window rather than trying to win a race with the
    // notifier. The null branch checks it and waits instead of popping.
    if (mounted) setState(() => _converting = true);
    try {
      final id = await widget.store.editable(ref, widget.theme, _id, live);
      if (mounted && id != _id) setState(() => _id = id);
      return id;
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _commitRename() {
    final controller = _renaming;
    if (controller == null) return;

    final name = controller.text;
    setState(() => _renaming = null);
    controller.dispose();

    // ─── CONVERT, THEN RENAME ────────────────────────────────────────────
    //
    // Renaming a generated folder is the clearest case for materialising:
    // calling it "Chat" only means anything if it then STAYS Chat, and a
    // derived Social folder is rebuilt under its own name every launch.
    //
    // Fire and forget rather than awaited, matching every other write on this
    // screen: the overlay reads its folder live from the provider, so the
    // rename lands on the next build either way.
    //
    // A blank name is refused by DrawerLayout.rename rather than stored, so
    // clearing the field and pressing Enter simply keeps the old name.
    final live = _live();
    if (live == null) return;

    () async {
      final id = await _editable(live);
      await widget.store.rename(ref, widget.theme, id, name);
    }();
  }

  /// Open the icon picker and write the answer.
  ///
  /// ─── CONVERT FIRST, LIKE RENAME ─────────────────────────────────────────
  ///
  /// A generated `cat:` folder owns nothing, so `setGlyph` against its id is a
  /// no-op that LOOKS like it worked: the sheet closes, and the icon comes back
  /// on the next launch because the category is rebuilt from scratch. Going
  /// through [_editable] first is the same dance `_commitRename` does and for
  /// the same reason.
  ///
  /// The distro's authored glyph survives the conversion, because
  /// [DrawerFolderStore.editable] copies it onto the materialised folder. So a
  /// user who opens the picker on Internet, changes nothing and backs out is
  /// left exactly where they started rather than with a plain folder.
  Future<void> _chooseGlyph(
    BuildContext scoped,
    EffectiveTheme theme,
    FolderSnapshot live,
  ) async {
    // [scoped], never `context`. See [_Actions.onIcon].
    final picked = await showFolderGlyphPicker(
      scoped,
      current: live.glyph,
    );
    // Null is CANCELLED, not cleared. Clearing comes back as the sentinel
    // below, because a nullable return cannot say both things and silently
    // wiping someone's icon when they dismissed a sheet is the worse failure.
    if (picked == null) return;
    if (!mounted) return;

    final id = await _editable(live);
    await widget.store.setGlyph(
      ref,
      theme,
      id,
      picked == kFolderGlyphCleared ? null : picked,
    );
  }

  /// The folder as it stands right now, or null if it has just been dissolved.
  ///
  /// Read from the provider rather than captured, because `_commitRename` runs
  /// from a focus listener that can fire after the members have changed.
  FolderSnapshot? _live() => widget.store.read(ref, widget.theme, _id);

  @override
  Widget build(BuildContext context) {
    // Live theme, not the push-time snapshot: renaming, adding an app or
    // changing the folder grid must all land under your finger rather than on
    // the next open.
    //
    // hasValue, not asData, and that is what makes the above actually true.
    // asData is null through a RELOAD, not only a first load, and every prefs
    // write reloads effectiveThemeProvider, so each of those three actions fell
    // back to the very snapshot this line exists to avoid. See home_screen.dart.
    final themeAsync = ref.watch(effectiveThemeProvider);
    final theme =
        themeAsync.hasValue ? themeAsync.requireValue : widget.theme;

    // WATCH, not read: this is build, and the panel has to repaint when a
    // member is added, removed or reordered. See [FolderStore] for why the two
    // are named apart.
    final live = widget.store.watch(ref, theme, _id);

    // Dissolved while open — the last-but-one member was pulled out, or the
    // Ungroup button was hit. Close rather than sit here rendering a folder
    // that no longer exists.
    if (live == null) {
      // MID-CONVERSION, not dissolved. The folder is being rewritten under a
      // new id and this frame is looking under the old one; the next frame has
      // the right id and finds it. Popping here is what shut the folder every
      // time someone held an app inside a category.
      if (_converting) return const SizedBox.shrink();
      if (!_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        });
      }
      return const SizedBox.shrink();
    }

    final palette = theme.palette;
    final cols = theme.prefs.folderCols ?? 4;

    // FOUR, not three. Three rows against four columns is a landscape block in
    // a portrait panel, and at 16 per page a folder holding a dozen apps stops
    // paging at all, which is where paging is least welcome: a folder is a
    // place you opened to find ONE thing.
    //
    // The panel grows to `rows * tileH`, about 416dp at the default icon size
    // and two label lines, which clears the 890dp screen with the header and
    // the search field still on it.
    final rows = theme.prefs.folderRows ?? 4;
    final perPage = math.max(1, cols * rows);
    final pageCount = math.max(1, (live.members.length / perPage).ceil());

    // The unnamed folder reads as a placeholder, exactly like an empty text
    // field: the name is still "Folder" in storage, but showing it in full ink
    // implies someone chose it. Muted ink says "this is waiting for you".
    final unnamed = live.name.trim() == defaultFolderName;

    // Derived exactly as ThemedScaffold derives it, so a dialog opened from
    // here is indistinguishable from one opened out of Settings.
    final chrome = ChromeData.fromPalette(
      theme.palette,
      typography: theme.typography,
      textScale: theme.textScale,
      family: theme.chromeFamily,
      // The drawer's own knob, falling back to the single slider when unset.
    opacity: theme.drawerOpacity,
    );

    return ChromeScope(
      data: chrome,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // ── The backdrop ────────────────────────────────────────────────
            // Tapping anywhere off the panel closes, which is the gesture
            // people try first and the reason the panel needs no close button.
            // Mid-rename it COMMITS instead, because a field losing focus is a
            // save everywhere else on a desktop.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_renaming != null) {
                    _commitRename();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: ColoredBox(
                    // Not opaque: the wallpaper and the drawer stay legible
                    // through it, which is the whole effect. Tinted with the
                    // distro's own deep background so a light theme dims toward
                    // its own colour rather than toward black.
                    color: palette.bgBottom.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  _Title(
                    theme: theme,
                    name: live.name,
                    unnamed: unnamed,
                    controller: _renaming,
                    focus: _renameFocus,
                    onStartRename: () => _startRename(live.name),
                    onCommit: _commitRename,
                  ),

                  const Spacer(),

                  // RENDERED FOR EVERY FOLDER, generated ones included. They
                  // were hidden on a category folder because its writes could
                  // not stick; `_editable` converts it first, so they can.
                  _Actions(
                    theme: theme,
                    glyph: live.glyph,
                    onIcon: (inner) => _chooseGlyph(inner, theme, live),
                    onAdd: () => _addApps(theme, live),
                    onUngroup: () {
                      // ─── ASK BEFORE PROMISING ──────────────────────────
                      //
                      // Pop FIRST is what gives this the exit animation rather
                      // than the panel blinking out a frame early, and it is
                      // only safe while the write cannot refuse. On the desktop
                      // it can: `HomeLayout.dissolve` turns down a folder of
                      // six with four free slots, whole, rather than dropping
                      // two apps. So the store is asked first and the refusal
                      // is spoken instead.
                      //
                      // The drawer has no such limit and always answers true,
                      // so nothing about its behaviour moves.
                      if (!widget.store.canDissolve(ref, theme, _id)) {
                        context.showMessage(
                          context.t(widget.store.dissolveRefusalKey),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      // No conversion first. `dissolve` against a generated id
                      // is a no-op, and a no-op is the CORRECT result: an
                      // ungrouped category folder is simply rebuilt by the
                      // categories. See [DrawerFolderStore.dissolve].
                      widget.store.dissolve(ref, theme, _id);
                    },
                  ),

                  const SizedBox(height: 14),

                  _Panel(
                    theme: theme,
                    store: widget.store,
                    members: live.members,
                    folderId: _id,
                    // Closed over `live` HERE, where it is in scope. The panel
                    // and the tiles hold plain data and no ref, so the
                    // conversion decision is made by the only widget that can
                    // make it and handed down as a callback.
                    editable: () => _editable(live),
                    cols: cols,
                    rows: rows,
                    perPage: perPage,
                    pageCount: pageCount,
                    controller: _pages,
                    // Which member Locate is pointing at, as an index into the
                    // list the panel is about to page. Resolved HERE because
                    // this is the widget with a `ref`; the panel only needs the
                    // number. Negative when nothing is aimed or the target is
                    // not in this folder.
                    locateIndex: () {
                      final target = ref.watch(locateTargetProvider);
                      if (target == null) return -1;
                      return live.members
                          .indexWhere((m) => m.componentKey == target);
                    }(),
                  ),

                  const SizedBox(height: 16),

                  if (pageCount > 1)
                    _Dots(count: pageCount, page: _page, color: palette.onDark),

                  const Spacer(flex: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Add loose apps to this folder, several at a time, in a CENTRED DIALOG.
  ///
  /// A dialog rather than a sheet because this is a desktop metaphor and a
  /// desktop puts a chooser in the middle of the screen. [ThemedDialog] already
  /// captures and re-provides the chrome across the route boundary, so it
  /// inherits the scope installed above.
  ///
  /// Multi-select rather than one at a time, because the reason anyone opens
  /// this is that they have four apps to file, and a chooser that closes after
  /// each one turns that into four round trips.
  ///
  /// Only LOOSE apps are offered. An app already in another folder is not shown
  /// at all rather than shown and refused: [DrawerLayout.addToFolder] declines
  /// to move an app between folders on purpose, and offering a choice that will
  /// be rejected is worse than not offering it.
  void _addApps(EffectiveTheme theme, FolderSnapshot folder) {
    // Asked of the store. Both answer "everything not already in a folder",
    // but they read different sets, and the desktop's includes apps that are
    // merely sitting in a slot, since filing one frees it.
    final loose = widget.store.candidates(ref, theme);

    final chosen = <String>{};

    ThemedDialog.show<void>(
      context,
      title: loose.isEmpty ? 'Nothing to add' : 'Add to ${folder.name}',
      content: loose.isEmpty
          ? const Text('Every app is already in a folder.')
          : SizedBox(
              // A dialog child is UNBOUNDED vertically, so the list must be
              // given a height or the ListView inside has nothing to lay out
              // against. This is the shape of mistake that produces a
              // five-figure overflow rather than a slightly wrong box.
              width: double.maxFinite,
              height: math.min(MediaQuery.sizeOf(context).height * 0.45, 420),
              child: StatefulBuilder(
                builder: (ctx, setDialogState) => ListView.builder(
                  itemCount: loose.length,
                  itemBuilder: (_, i) {
                    final a = loose[i];
                    final on = chosen.contains(a.componentKey);
                    final d = ChromeScope.of(ctx);

                    // Hand-built rather than a ThemedListRow, because the row
                    // needs the app's REAL icon on the left and
                    // ThemedListRow's only leading slot is an IconData.
                    // Colours and type still come from the chrome, so it reads
                    // as a peer of every other row.
                    return InkWell(
                      onTap: () => setDialogState(() {
                        if (on) {
                          chosen.remove(a.componentKey);
                        } else {
                          chosen.add(a.componentKey);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            AppIcon(entry: a, size: 30),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                a.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: d.text.body,
                              ),
                            ),
                            Icon(
                              on
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: on ? d.colors.accent : d.colors.textFaint,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
      actionsBuilder: (dialogCtx) => [
        ThemedButton(
          label: loose.isEmpty ? 'Close' : context.t('common.cancel'),
          kind: ThemedButtonKind.text,
          onPressed: () => Navigator.of(dialogCtx).pop(),
        ),
        if (loose.isNotEmpty)
          ThemedButton(
            label: 'Add',
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              if (chosen.isEmpty) return;
              // Converts a generated folder first: `addToFolder` against a
              // `cat:` id finds nothing and returns prefs unchanged, so the
              // sheet would close having added nothing.
              () async {
                final id = await _editable(folder);
                // ONE edit for the whole selection, not one per app. Both
                // stores fold it into a single transform; see
                // [FolderStore.addMembers].
                await widget.store.addMembers(ref, theme, id, chosen);
              }();
            },
          ),
      ],
    );
  }
}

/// The folder's name, large and centred — and, while editing, the field itself.
///
/// The two states are the same size and the same position on purpose. A rename
/// control that jumps somewhere else when you activate it makes you find your
/// place again; leaving the text exactly where it was is what makes this read
/// as editing the thing rather than filling in a form about it.
class _Title extends StatelessWidget {
  const _Title({
    required this.theme,
    required this.name,
    required this.unnamed,
    required this.controller,
    required this.focus,
    required this.onStartRename,
    required this.onCommit,
  });

  final EffectiveTheme theme;
  final String name;
  final bool unnamed;
  final TextEditingController? controller;
  final FocusNode focus;
  /// NULLABLE, and null means this folder cannot be renamed.
  ///
  /// Passed straight to the title's `onTap`, so a null also removes the ripple
  /// and the pointer cursor: the title stops advertising a tap that would do
  /// nothing rather than merely ignoring it.
  final VoidCallback? onStartRename;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    final style = TextStyle(
      fontFamily: theme.typography.display,
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.1,
      color: palette.onDark,
    );

    if (controller != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: TextField(
          controller: controller,
          focusNode: focus,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onCommit(),
          style: style,
          cursorColor: palette.accent,
          // Single line, always. An unbounded field in a Column with a Spacer
          // either side is exactly how a text field grows without limit.
          maxLines: 1,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: palette.accent, width: 2),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: palette.onDark.withValues(alpha: 0.30),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onStartRename,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          unnamed ? 'Folder name' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: unnamed
              ? style.copyWith(color: palette.onDark.withValues(alpha: 0.45))
              : style,
        ),
      ),
    );
  }
}

/// The two verbs a folder owns, as glyph buttons above the panel.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.theme,
    required this.onAdd,
    required this.onUngroup,
    required this.onIcon,
    required this.glyph,
  });

  final EffectiveTheme theme;
  final VoidCallback onAdd;
  final VoidCallback onUngroup;

  /// Takes a [BuildContext] rather than being a [VoidCallback], and that is
  /// load-bearing.
  ///
  /// The picker is a [ThemedSheet], which reads [ChromeScope] BEFORE pushing
  /// its route. The overlay's State builds the scope, so the State's own
  /// `context` is ABOVE it and would resolve to [ChromeData.bootstrap]: house
  /// colours on a sheet opened over a Zorin panel. This widget is built INSIDE
  /// the scope, so its context resolves correctly, and passing it down is the
  /// smallest way to say so.
  final void Function(BuildContext) onIcon;

  /// Drawn INSIDE its own button, so the control shows the current answer
  /// rather than a generic paintbrush. A settings row that displays its value
  /// is the difference between "you may change this" and "this is what it is".
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Right-aligned and inset to the panel's own margin, so the buttons sit
      // over the panel's top-right corner rather than floating loose.
      padding: const EdgeInsets.only(right: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _GlyphButton(
            theme: theme,
            icon: Icons.folder_off_outlined,
            semantic: 'Ungroup this folder',
            onTap: onUngroup,
          ),
          const SizedBox(width: 18),
          Builder(
            // The context this needs is one below [ChromeScope], and the
            // closure above was created in the State's build, which is one
            // above. A Builder is the cheapest way to get a context from the
            // right side of that boundary.
            builder: (inner) => _GlyphButton(
              theme: theme,
              icon: resolveFolderGlyph(folderGlyph: glyph),
              semantic: context.t('drawer.chooseAnIconForThisFolder'),
              onTap: () => onIcon(inner),
            ),
          ),
          const SizedBox(width: 18),
          _GlyphButton(
            theme: theme,
            icon: Icons.add,
            semantic: 'Add apps to this folder',
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _GlyphButton extends StatelessWidget {
  const _GlyphButton({
    required this.theme,
    required this.icon,
    required this.semantic,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final IconData icon;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onDark = theme.palette.onDark;

    return Semantics(
      button: true,
      label: semantic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: onDark.withValues(alpha: 0.55)),
          ),
          child: Icon(icon, size: 20, color: onDark),
        ),
      ),
    );
  }
}

/// Move a member into another folder, or into one that does not exist yet.
///
/// ─── ONE EDIT, NOT TWO ──────────────────────────────────────────────────────
///
/// The remove and the file happen in a single `edit`, so a move is atomic. Done
/// as two writes, a folder that emptied to below its dissolve floor would
/// vanish between them and the second write would land in a folder the first
/// one deleted, which is exactly the shape of bug that leaves an app filed
/// nowhere.
///
/// ─── AND NEW FOLDER IS AN OPTION IN THE SAME LIST ───────────────────────────
///
/// Not a separate verb on the sheet above. "Move to a new folder" and "move to
/// an existing one" are the same intent with a different destination, and
/// splitting them would put two rows on a menu for one decision. It sits at the
/// top because on a fresh install it is the only destination there is.
Future<void> _moveTo(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  String fromId,
  AppEntry entry,
) async {
  final prefs = ref.read(prefsProvider(theme.spec.id)).value;
  if (prefs == null) return;

  final targets = [
    for (final f in DrawerLayout.orderedFolders(prefs))
      if (f.id != fromId) f,
  ];

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final d = ChromeScope.of(ctx);
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: d.colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThemedListRow(
                icon: Icons.create_new_folder_outlined,
                title: ctx.t('drawer.newFolder'),
                onTap: () {
                  Navigator.pop(ctx);
                  _commitMove(ref, theme, fromId, entry, null);
                },
              ),
              // Capped and scrollable. Someone with twenty folders should not
              // get a sheet taller than the screen with the first ones off the
              // top edge.
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in targets)
                      ThemedListRow(
                        icon: Icons.folder_outlined,
                        title: f.name,
                        onTap: () {
                          Navigator.pop(ctx);
                          _commitMove(ref, theme, fromId, entry, f.name);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// [toName] null means a new folder, numbered so two of them are tellable apart.
void _commitMove(
  WidgetRef ref,
  EffectiveTheme theme,
  String fromId,
  AppEntry entry,
  String? toName,
) {
  final prefs = ref.read(prefsProvider(theme.spec.id)).value;
  if (prefs == null) return;

  var name = toName;
  if (name == null) {
    final taken = {
      for (final f in DrawerLayout.orderedFolders(prefs)) f.name,
    };
    name = 'New folder';
    var n = 2;
    while (taken.contains(name)) {
      name = 'New folder $n';
      n++;
    }
  }

  HapticFeedback.mediumImpact();
  ref.read(prefsProvider(theme.spec.id).notifier).edit((p) {
    // Remove FIRST, so the source's dissolve check runs against the state
    // after this app has left. `dissolveBelow: 1` for the tool menu's reason:
    // a folder holding one app is a legitimate thing to have made.
    final without = DrawerLayout.removeFromFolder(
      p,
      fromId,
      entry.componentKey,
      dissolveBelow: 1,
    );
    return DrawerLayout.fileInto(
      without,
      name!,
      entry.componentKey,
      newFolderId: newDrawerFolderId,
    );
  });
}

/// The rounded panel holding the grid, paged when the members do not fit.
///
/// ─── STATEFUL ONLY BECAUSE OF THE EDGE FLIP ─────────────────────────────────
///
/// A drag that has to cross a page boundary is the reason. Holding a member
/// against the left or right edge of the panel turns the page under it, which
/// needs a timer, which needs somewhere to live and something to cancel it.
///
/// It matters less than it did now that folders default to 4x4: sixteen members
/// fit on one page and most folders never reach a second. But "I cannot move
/// this app back to page one" is unrecoverable from inside the UI when it does
/// happen, and the only alternative is telling the user to take the app out of
/// the folder and put it back.
class _Panel extends StatefulWidget {
  const _Panel({
    required this.theme,
    required this.store,
    required this.members,
    required this.folderId,
    required this.editable,
    required this.cols,
    required this.rows,
    required this.perPage,
    required this.pageCount,
    required this.controller,
    this.locateIndex = -1,
  });

  final EffectiveTheme theme;

  /// Where this folder lives. Passed through to the member tiles, which are
  /// what actually write; see [FolderStore].
  final FolderStore store;

  final List<AppEntry> members;
  final String folderId;

  /// Converts a generated folder into a real one and answers with the id to
  /// write against. Threaded down from `_FolderOverlayState`, which is the only
  /// thing here holding a `ref` and the live folder.
  ///
  /// The panel and its tiles are deliberately plain widgets over plain data, so
  /// neither can look the folder up for itself. Passing the decision down is
  /// what keeps that true.
  final Future<String> Function() editable;

  final int cols;
  final int rows;
  final int perPage;
  final int pageCount;
  final PageController controller;

  /// Index of the member Locate is pointing at, or negative for none.
  ///
  /// A folder holding more than [perPage] members pages, and opening it on page
  /// one to answer "where is WhatsApp" when WhatsApp is on page two is the same
  /// non-answer the drawer's own page jump exists to avoid.
  final int locateIndex;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  /// Running while a drag sits against an edge. Cancelled the moment it leaves,
  /// so a drag that pauses mid-panel never turns a page.
  Timer? _flip;

  /// How long a drag has to rest against an edge before the page turns.
  ///
  /// Long enough that crossing the edge on the way to a tile near it does not
  /// flip, short enough that a deliberate hold does not feel ignored. Repeats
  /// at the same interval, so holding keeps paging.
  static const _dwell = Duration(milliseconds: 600);

  /// How much of the panel's width counts as an edge.
  static const _edge = 44.0;

  @override
  void initState() {
    super.initState();
    // The overlay is usually MOUNTED by Locate, so the target is already set
    // before the first frame and there is no change for `didUpdateWidget` to
    // catch. Jumping here covers that; jumping there covers an aim that lands
    // while the folder is already open.
    _jumpToLocated();
  }

  @override
  void didUpdateWidget(_Panel old) {
    super.didUpdateWidget(old);
    if (widget.locateIndex != old.locateIndex) _jumpToLocated();
  }

  /// Page to the located member, if there is one and it is not already shown.
  ///
  /// Post-frame because this runs from `initState`, where the controller has no
  /// clients yet: a PageController is only usable once its PageView has been
  /// laid out, and calling it earlier throws.
  void _jumpToLocated() {
    final i = widget.locateIndex;
    if (i < 0 || widget.perPage < 1) return;

    final page = i ~/ widget.perPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.controller.hasClients) return;
      if ((widget.controller.page ?? 0).round() == page) return;
      widget.controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _flip?.cancel();
    super.dispose();
  }

  void _stopFlip() {
    _flip?.cancel();
    _flip = null;
  }

  void _armFlip(bool forward) {
    if (_flip != null) return;
    _flip = Timer.periodic(_dwell, (_) {
      if (!mounted) return _stopFlip();

      final page = (widget.controller.page ?? 0).round();
      final next = forward ? page + 1 : page - 1;
      if (next < 0 || next >= widget.pageCount) return _stopFlip();

      widget.controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Which edge, if any, a hovering drag is over.
  void _onDragMove(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return _stopFlip();

    final local = box.globalToLocal(global);
    if (local.dy < 0 || local.dy > box.size.height) return _stopFlip();

    if (local.dx < _edge) {
      _armFlip(false);
    } else if (local.dx > box.size.width - _edge) {
      _armFlip(true);
    } else {
      _stopFlip();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final members = widget.members;
    final folderId = widget.folderId;
    final cols = widget.cols;
    final rows = widget.rows;
    final perPage = widget.perPage;
    final pageCount = widget.pageCount;
    final controller = widget.controller;

    final palette = theme.palette;

    // The tile is icon + gap + the LABEL BLOCK. Derived from the live icon
    // size rather than fixed, so the folder still fits itself when the icon
    // size setting changes, and now from the resolved labelLines too: the
    // member tile wraps long names (two lines by default, matching the
    // drawer), and a cell whose extent still budgeted one line would clip the
    // second into an overflow stripe. 16 logical pixels per extra line covers
    // the 12sp label with its line height.
    final tileH =
        theme.iconSizeDp + 34 + (theme.labelLines - 1) * 16.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          // Lifted off the blurred backdrop rather than transparent, or the
          // grid reads as floating loose on the wallpaper and the label text
          // fights whatever photo is behind it.
          color: palette.bgBottom.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: palette.onDark.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: SizedBox(
          height: rows * tileH,
          // A panel-wide target that catches the drag in the GAPS.
          //
          // ─── WHY IT ACCEPTS, WHEN IT DOES NOTHING WITH A DROP ───────────
          //
          // It returned false here, which looked right (the member tiles are
          // the real targets) and silently broke the edge flip. Flutter's
          // `_DragAvatar.updateDrag` calls `didMove` on the ACTIVE target only,
          // and the active target is the first one whose `onWillAccept`
          // returned true. A target that refuses never becomes active, so its
          // `onMove` is never called and this whole timer was unreachable.
          //
          // Accepting costs nothing. The hit-test path runs innermost first, so
          // whenever the pointer is over a member tile that tile is active and
          // this one is not consulted; it only becomes active in the padding
          // and the gaps, which is the one case the tiles cannot report.
          // `onAcceptWithDetails` deliberately does nothing: a drop in the gap
          // means "not on anything", and the member returns to where it was.
          child: DragTarget<String>(
            // ─── BACK TO false, AND ACCEPTING HERE WAS A REGRESSION ─────
            //
            // This was flipped to `true` so the panel would become the active
            // drag target and receive `onMove`, because Flutter only calls
            // `didMove` on the target that accepted. That worked for the edge
            // flip and silently broke the LONG-PRESS MENU inside every folder.
            //
            // Hold a member and release without moving. The source tile refuses
            // its own drop (`!_isSource`), so with this accepting, THIS target
            // took it. An accepted drop means `onDraggableCanceled` never
            // fires, and that callback is the entire mechanism by which a hold
            // becomes a menu. So Uninstall, Pin to dock and Remove from folder
            // all became unreachable from inside a folder, with the tile simply
            // springing back.
            //
            // The flip does not need this. Member tiles forward their hover
            // position through `onDragOver`, and a finger near the panel's edge
            // is over the leftmost or rightmost TILE, not over the 8dp of
            // padding beyond it. So the tiles cover the zone anyone can
            // actually aim at, and this target goes back to watching without
            // claiming anything.
            onWillAcceptWithDetails: (_) => false,
            onLeave: (_) => _stopFlip(),

            builder: (context, _, __) => PageView.builder(
            controller: controller,
            // One page of members always fits by construction, so the page
            // itself never scrolls — which is what keeps the horizontal swipe
            // unambiguous.
            itemCount: pageCount,
            itemBuilder: (_, page) {
              final start = page * perPage;
              final count = math.min(perPage, members.length - start);

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: tileH,
                  crossAxisSpacing: 4,
                ),
                itemCount: count,
                itemBuilder: (_, i) => _MemberTile(
                  editable: widget.editable,
                  store: widget.store,
                  theme: theme,
                  entry: members[start + i],
                  folderId: folderId,
                  // The tiles are the active drag target for most of the
                  // panel's area, so they are the only thing that sees the
                  // pointer there. Without this the flip would arm only in the
                  // few dp of padding at the very edge, which is not a zone
                  // anyone can aim at.
                  onDragOver: _onDragMove,
                  onDragDone: _stopFlip,
                ),
              );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerStatefulWidget {
  const _MemberTile({
    required this.theme,
    required this.store,
    required this.entry,
    required this.folderId,
    required this.editable,
    this.onDragOver,
    this.onDragDone,
  });

  final EffectiveTheme theme;

  /// Where this folder lives. The tile is what writes a reorder and what opens
  /// the member menu, so it is the leaf the seam has to reach.
  final FolderStore store;

  final AppEntry entry;
  final String folderId;

  /// Converts a generated folder into a real one and answers with the id to
  /// write against.
  ///
  /// A hook back to the panel rather than logic here, because materialising is
  /// a decision about the FOLDER and this widget is one member of it. Six tiles
  /// each converting independently would race and write six folders.
  final Future<String> Function() editable;

  /// Where a hovering drag is, in GLOBAL coordinates, reported to the panel.
  ///
  /// The panel owns the edge-flip decision because it is the thing with edges,
  /// but it is not the active drag target while the pointer is over a tile, so
  /// it cannot see the pointer there. The tile forwards what it sees.
  final void Function(Offset globalPosition)? onDragOver;

  /// The drag is over, by drop or by cancel. Stops the flip timer, which would
  /// otherwise keep paging after the finger is gone.
  final VoidCallback? onDragDone;

  @override
  ConsumerState<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends ConsumerState<_MemberTile> {
  /// Where the finger went down, so the context menu can open THERE.
  Offset _down = Offset.zero;

  /// Is this member's menu open? Same contract as `_AppTile._held`.
  bool _held = false;

  /// Where the POINTER went down, for the hold-versus-drag test on release.
  ///
  /// Separate from [_down], which is a global position captured for the menu's
  /// anchor. This one is compared against the draggable's release offset, and
  /// under `pointerDragAnchorStrategy` that offset is the finger, so the two
  /// have to be measured the same way. See `_AppTileState._downAt`.
  Offset? _downAt;

  /// Which half of this tile a hovering drag is over, or null when nothing is
  /// hovering. Tracked in `onMove` rather than read at accept time, because
  /// `onAcceptWithDetails` reports where the drag was RELEASED relative to the
  /// FEEDBACK widget, which is not where the finger is.
  bool? _dropAfter;

  /// Same 24dp as the drawer's tiles. Named separately for the reason
  /// `_FolderTileState._slop` gives: it is the same number, not the same
  /// decision.
  static const _slop = 24.0;

  /// Is this the tile currently being dragged? Used only to skip its own drop
  /// zone, so a member cannot be dropped onto itself.
  bool _isSource(String key) => key == widget.entry.componentKey;

  void _openMenu() {
    // No `_held = true` here. `onDragStarted` already set it when the timer
    // completed; this only holds it until the panel closes.
    // ─── CONVERT BEFORE OPENING, NOT AFTER CHOOSING ──────────────────────
    //
    // Every verb on this menu writes through `DrawerLayout` keyed by the folder
    // id, and a `cat:` id matches nothing, so on a generated folder the sheet
    // used to be refused outright.
    //
    // Converting when the menu OPENS rather than when an item is tapped costs a
    // write the user might not have needed, and it is worth it: the menu is
    // built with an id, so deferring means every item would have to convert
    // itself and re-derive its own id afterwards.
    //
    // The cost is bounded and honest: a generated folder whose menu was opened
    // and dismissed becomes a real folder holding exactly what it held. Nothing
    // about it looks different, and the user can Ungroup it.
    () async {
      final id = await widget.editable();
      if (!mounted) return;

      await showFolderMemberMenu(
        context,
        ref,
        widget.theme,
        at: _down,
        folderId: id,
        entry: widget.entry,
        store: widget.store,
      );
      if (mounted) setState(() => _held = false);
    }();
  }

  Future<void> _accept(String sourceKey) async {
    final after = _dropAfter ?? false;
    setState(() => _dropAfter = null);
    widget.onDragDone?.call();

    HapticFeedback.selectionClick();

    // Converts a generated folder before reordering inside it, for the reason
    // `_editable` gives: an order written against a derived folder is rebuilt
    // away on the next launch.
    final id = await widget.editable();
    if (!mounted) return;

    // `id`, NOT `widget.folderId`. After a conversion the widget still names
    // the generated folder, which no longer exists, and the reorder would find
    // nothing and return prefs unchanged: exactly the silent no-op this was
    // written to undo.
    await widget.store.reorder(
      ref,
      widget.theme,
      id,
      sourceKey,
      widget.entry.componentKey,
      after: after,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final entry = widget.entry;

    // Held, or being pointed at by Locate. One ring for both; see the note on
    // `_AppTile`.
    final located = ref.watch(locateTargetProvider) == entry.componentKey;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressPop(
          held: _held || located,
          radius: theme.iconSizeDp * 0.24,
          ringColor: theme.palette.onDark,
          child: AppIcon(entry: entry, size: theme.iconSizeDp),
        ),
        const SizedBox(height: 6),
        Text(
          entry.label,
          // The RESOLVED line count, two by default, so "Culimix Delivery"
          // wraps whole instead of truncating. The ellipsis stays as the
          // runtime backstop for names longer than even two lines.
          maxLines: theme.labelLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: theme.typography.display,
            fontSize: 12,
            color: theme.palette.onDark,
          ),
        ),
      ],
    );

    // ─── THE DROP IS ALWAYS AN INSERT, NEVER A MERGE ────────────────────────
    //
    // The drawer's tile has three zones, because out there a drop on the middle
    // of an app means "fold these two together". Inside a folder that meaning
    // does not exist: the drawer has no nested folders and is not getting any.
    // So a member tile has two zones and no middle, and the whole tile is live
    // rather than only its edges, which is what makes a short drag land where
    // it looks like it will.
    return DragTarget<String>(
      // Accepted on every folder now. It was refused at the door on a
      // generated one, because `reorderMembers` against a `cat:` id returns
      // unchanged prefs, which would have shown the insert marker, played the
      // haptic and then put the icon back. `_accept` converts first.
      onWillAcceptWithDetails: (d) => !_isSource(d.data),
      onLeave: (_) {
        if (_dropAfter != null) setState(() => _dropAfter = null);
      },
      onMove: (d) {
        widget.onDragOver?.call(d.offset);

        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final local = box.globalToLocal(d.offset);
        final after = local.dx > box.size.width / 2;
        if (after != _dropAfter) setState(() => _dropAfter = after);
      },
      onAcceptWithDetails: (d) => _accept(d.data),
      builder: (context, candidate, __) {
        final marker = _dropAfter;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            LongPressDraggable<String>(
              data: entry.componentKey,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              // ─── THE DIP LANDS HERE, NOT ON RELEASE ─────────────────────
              //
              // `_held` was set in `onDraggableCanceled`, which fires when the
              // finger LIFTS. So nothing happened under the thumb while the
              // long-press timer ran, and the tile then squashed at the same
              // instant the menu appeared, which reads as decoration on the menu
              // rather than as a response to the press. The whole argument for
              // squash-and-pop over a plain scale was that the motion is a
              // CONSEQUENCE of pressing, and setting it on release threw that away.
              //
              // `onDragStarted` IS the timer completing: it is the moment the
              // draggable takes the long press, and it is where the haptic already
              // fires. Same frame, same event, so the dip and the buzz are one
              // thing rather than two near each other.
              //
              // It stays true through a real drag as well, which costs nothing:
              // `childWhenDragging` replaces this tile for the whole drag, so
              // nothing popped is on screen to see.
              onDragStarted: () {
                HapticFeedback.mediumImpact();
                if (mounted) setState(() => _held = true);
              },

              // Whatever ended it. `onDragEnd` covers an accepted drop and
              // `onDraggableCanceled` covers a refused one, but a timer that
              // outlives the finger keeps turning pages at an empty panel, so
              // both paths stop it.
              onDragEnd: (_) => widget.onDragDone?.call(),

              // ─── SPLIT ON RELEASE, EXACTLY AS THE DRAWER DOES ─────────
              //
              // `LongPressDraggable` consumes the long press, so the
              // `onLongPress` this tile used to carry would never fire again
              // now that a member can be dragged. Rather than demote the menu
              // to a worse trigger, intent is read on release: nothing
              // accepted the drop AND the finger never really travelled means
              // it was a hold, so the menu opens. This is the same trade
              // `_AppTile` documents, and doing it differently here would
              // make the same gesture mean two things in two grids.
              onDraggableCanceled: (_, offset) {
                widget.onDragDone?.call();
                final from = _downAt;
                if (from == null || (offset - from).distance < _slop) {
                  _openMenu();
                } else if (mounted) {
                  // Travelled, so it was a drag nothing accepted. No menu is
                  // coming, so nothing else would clear the pop.
                  setState(() => _held = false);
                }
              },
              feedback: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Opacity(
                  opacity: 0.9,
                  child: AppIcon(entry: entry, size: theme.iconSizeDp * 1.1),
                ),
              ),
              // The gap the tile leaves behind, so the row does not close up
              // and re-open under the finger while a drag is in flight.
              childWhenDragging: Opacity(opacity: 0.25, child: content),
              // Listener INSIDE, as the draggable's child, which is where
              // `_AppTile` puts its own. An ancestor Listener does still see
              // the pointer, but matching the tile that is known to work is
              // worth more here than the equivalence argument.
              child: Listener(
                // The Listener already here for the hold-versus-drag test does
                // double duty: the next deliberate touch also clears the Locate
                // ring, matching the drawer underneath. It competes for nothing,
                // which matters in a panel where every tile is already a drag
                // source and a drop target.
                onPointerDown: (e) {
                  _downAt = e.position;
                  ref.read(locateTargetProvider.notifier).clear();
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _down = d.globalPosition,
                  onTap: () {
                    // Close first: coming back from an app to a folder still
                    // hanging open over the drawer is not where anyone
                    // expects to land.
                    Navigator.pop(context);
                    launchDrawerApp(ref, entry);
                  },
                  child: content,
                ),
              ),
            ),

          // The insertion caret. A LINE on the side the drop will land, not a
          // highlight over the tile: a highlight says "into this one", which
          // is what merging looks like everywhere else in this launcher, and
          // that is the one thing this drop cannot do.
          if (marker != null)
            Positioned(
              top: 0,
              bottom: 0,
              left: marker ? null : -3,
              right: marker ? -3 : null,
              child: Center(
                child: Container(
                  width: 3,
                  height: theme.iconSizeDp,
                  decoration: BoxDecoration(
                    color: theme.palette.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
}

/// A context menu anchored where the finger went down.
///
/// ─── THIS IS THE POINT OF "NOT ANDROID SHEETS" ──────────────────────────────
///
/// These three actions used to arrive as a bottom sheet: you hold an icon in
/// the middle of the screen and a panel climbs up from the bottom edge, 400px
/// away from the thing you are acting on. That is an Android convention and it
/// is the wrong one for a desktop metaphor — a right-click menu appears AT the
/// pointer, which is why you can hit it without moving your hand and why it is
/// never ambiguous which item it belongs to.
///
/// Positioned by hand rather than with `showMenu`, because Material's popup
/// menu brings its own theme, its own item widgets and its own elevation model,
/// and each of those would have to be overridden back to the chrome. A
/// [Positioned] card built from [ThemedListRow]s is less code and is themed by
/// construction.
///
/// The card is CLAMPED to the screen and flips above the finger when there is
/// no room below. A menu opened near the bottom of a folder grid would
/// otherwise hang off the edge, and the item you wanted is the one that fell
/// off.
/// Returns when the menu closes, however it closed.
///
/// It used to be `void` and simply dropped the future `AnchoredMenu.show`
/// hands back. The caller now needs it: the member tile holds its pressed state
/// for exactly as long as the panel is up, and without a future to wait on
/// there is nothing to tell it when that is.
Future<void> showFolderMemberMenu(
BuildContext context,
WidgetRef ref,
EffectiveTheme theme, {
required Offset at,
required String folderId,
required AppEntry entry,

/// Where this folder lives.
///
/// Only ONE row here needs it: Remove from folder. Pin, App info and Uninstall
/// are about the APP and are identical whichever surface holds the folder,
/// which is why this menu was already almost store-agnostic and why the seam
/// costs one parameter rather than a rewrite. See [FolderStore].
required FolderStore store,
}) {
HapticFeedback.mediumImpact();

// Captured before pushing, exactly as ThemedSheet and ThemedDialog do: the
// menu's route is not a descendant of this screen's scope.
final chrome = ChromeScope.of(context);
final notifier = ref.read(appListProvider.notifier);
final prefs = ref.read(prefsProvider(theme.spec.id).notifier);

// ─── POSITIONING MOVED TO AnchoredMenu ────────────────────────────────
//
// This file wrote the clamp-and-flip first and two other menus copied it with
// different constants. It is one primitive now, so the disagreements (14
// versus 16 radius, three different widths) are gone and the two menus that
// were still bottom sheets could be converted without writing it a fifth
// time.
//
// The height arithmetic is gone with it. `rowCount * rowH + pad` was a guess
// about a panel that had not been built, and it was wrong for any row that
// wrapped, any longer translation and any larger system font. AnchoredMenu
// measures the child instead.
//
// Anchored at the FINGER here, deliberately, unlike the drawer's grid where
// the tile's own rectangle is the better anchor. A folder's contents are laid
// out tightly and the member you held is small, so the pointer is the more
// precise statement of which one you meant.
return AnchoredMenu.show(
  context: context,
  chrome: chrome,
  anchor: Rect.fromCenter(center: at, width: 1, height: 1),
  width: 236,
  // A HEADER, which this menu never had.
  //
  // It opened straight onto its rows, which was defensible while it was
  // anchored at the finger inside a folder you had just opened. It is not
  // defensible now that the drawer's menu names and pictures its subject:
  // two panels with the same rows, one of which tells you what it is about,
  // teaches that the header means something is different. It does not.
  title: entry.label,
  leading: AppIcon(entry: entry, size: 30),
  onInfo: () => notifier.openInfo(entry),
  rows: (ctx) {
    // ONLY the work-profile case is decided here now.
    //
    // This used to also exclude `entry.isSystem`, which reads as "system apps
    // cannot be uninstalled" but actually means "apps that shipped with the
    // phone", and on a Samsung device that includes every preinstalled app
    // the user has since updated through Play. Those ARE removable: the
    // system offers to drop the update. Native makes the finer distinction
    // and returns a status; a refusal gets a sentence rather than silence,
    // which is the same reason showDrawerAppMenu stopped filtering here.
    final canUninstall = !entry.isWorkProfile;

    // Being in a folder does not bar an app from the dock: pinToDock takes
    // any componentKey and has no idea where the drawer files it. Pinned
    // members get Unpin; unpinned ones get Pin only while the dock has room,
    // because offering a pin that can only be refused is a button that exists
    // to say no.
    //
    // Read off the snapshot the menu opened with, same as everything else
    // here and the same pattern showDrawerAppMenu uses. A pin landing from
    // another surface while this menu is up can slip past the on-tap check
    // below, in which case pinToDock inside the edit refuses against the LIVE
    // prefs and nothing is lost; the window is a tap wide.
    final isPinned = HomeLayout.isPinned(theme.prefs, entry.componentKey);
    final dockHasSpace =
        theme.prefs.favourites.length < DockMetrics.maxCapacity;
    final showPinRow = isPinned || dockHasSpace;

    return [
      // Pin first, matching showDrawerAppMenu's ordering so the
      // same action sits in the same place whichever surface the
      // long-press came from.
      if (showPinRow)
        ThemedListRow(
          icon: isPinned
              ? Icons.push_pin_outlined
              : Icons.push_pin,
          // The FAMILY's word, matching showDrawerAppMenu. Two menus that
          // perform the same write on the same app must not call it two
          // different things depending on which surface opened them.
          title: ctx.t(
            isPinned
                ? AppMenuWords.forTheme(theme).unpin
                : AppMenuWords.forTheme(theme).pin,
            ),
            onTap: () {
              Navigator.pop(ctx);
              if (isPinned) {
                prefs.edit(
                  (p) => HomeLayout.unpinFromDock(
                    p,
                    entry.componentKey,
                  ),
                );
                return;
              }
              // The space check above ran when the menu OPENED; a
              // pin from another surface can fill the dock before
              // this tap lands. Same refusal contract as the
              // drawer menu: compare identity, say so, drop it.
              final before = theme.prefs;
              final after = HomeLayout.pinToDock(
                before,
                entry.componentKey,
                capacity: DockMetrics.maxCapacity,
              );
              if (identical(before, after)) {
                if (context.mounted) {
                  context.showMessage(
                    context.t('drawer.dockIsFull'),
                  );
                }
                return;
              }
              prefs.edit(
                (p) => HomeLayout.pinToDock(
                  p,
                  entry.componentKey,
                  capacity: DockMetrics.maxCapacity,
                ),
              );
            },
          ),
        ThemedListRow(
          icon: Icons.folder_off_outlined,
          title: ctx.t('drawer.removeFromFolder'),
          onTap: () {
            Navigator.pop(ctx);
            store.removeMember(ref, theme, folderId, entry.componentKey);
          },
        ),
        // ─── MOVE, WHICH IS THE ONE VERB THE SHEET WAS MISSING ────────
        //
        // Remove takes an app OUT and leaves it loose. There was no way to say
        // "this belongs in the other one", so moving meant remove, close the
        // folder, find the app, open the target, add it. Five steps to express
        // one intent.
        //
        // Placed after Remove because they are the same family of action and
        // this is the gentler of the two: Move keeps the app filed somewhere,
        // Remove does not.
        ThemedListRow(
          icon: Icons.drive_file_move_outline,
          title: ctx.t('drawer.moveTo'),
          onTap: () async {
            Navigator.pop(ctx);
            await _moveTo(context, ref, theme, folderId, entry);
          },
        ),
        ThemedListRow(
          icon: Icons.info_outline,
          title: ctx.t('shell.appInfo'),
          onTap: () {
            Navigator.pop(ctx);
            notifier.openInfo(entry);
          },
        ),
        // A refusal is now spoken rather than swallowed. The message goes to
        // `context`, the caller's, NOT to `ctx`: this pops the menu first, and
        // `ctx` is dead the moment it does, so a message posted to it would
        // land on a route that no longer exists and simply never appear.
        if (canUninstall)
          ThemedListRow(
            icon: Icons.delete_outline,
            title: ctx.t('drawer.uninstall'),
            danger: true,
            onTap: () async {
              Navigator.pop(ctx);
              final status = await notifier.uninstall(entry);
              if (UninstallStatus.succeeded(status)) return;
              if (!context.mounted) return;
              context.showMessage(context.t(uninstallRefusalKey(status)));
            },
          ),
      ];
    },
  );
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.page,
    required this.color,
  });

  final int count;
  final int page;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: i == page ? 0.90 : 0.30),
            ),
          ),
      ],
    );
  }
}
