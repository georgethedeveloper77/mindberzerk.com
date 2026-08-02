import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../design/components/components.dart';
import 'package:g_launcher/i18n/i18n.dart';
import '../../engine/desklet_spec.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart' as api;
import 'desklet_edit.dart';
import 'desklet_picker.dart';
import 'desklet_settings.dart';

/// What a held desklet offers.
///
/// ─── WHY A SHEET AND NOT STRAIGHT INTO EDIT MODE ────────────────────────────
///
/// Holding a tile used to call `edit.enter()` and `edit.select(id)` directly,
/// which put the desktop into edit mode instantly. That had two costs.
///
/// It made the desktop LIVE at the exact moment the user was deciding what to
/// do: everything on screen became draggable, so a thumb that drifted while
/// reading moved a widget. A menu should freeze the thing it is a menu about,
/// which is what a modal barrier does for free.
///
/// ─── ANCHORED, NOT A BOTTOM SHEET ───────────────────────────────────────────
///
/// This started as a `ThemedSheet`, which is what every other menu in the app
/// is, and it was the wrong primitive. A bottom sheet is for something about
/// the SCREEN. This is about one tile, most desklets sit in the upper half, and
/// a bottom sheet therefore opened as far from its subject as the display
/// allows with the tile itself behind the scrim.
///
/// So it is a panel beside the tile, on the same glass every other floating
/// surface uses, positioned below when there is room and above when there is
/// not.
///
/// And it made resize the ONLY discoverable action, because handles on the
/// selected tile were the whole vocabulary. Remove was a small badge in a
/// corner; per-widget settings and stacks had nowhere to live at all.
///
/// So the hold opens this, and only Resize enters edit mode. Everything else
/// happens without the desktop ever becoming draggable.
///
/// ─── THE ROWS DIFFER FOR A STACK ────────────────────────────────────────────
///
/// A stack offers Unstack where a plain tile offers Make a stack, because those
/// are the same action in opposite directions and showing both would leave one
/// of them inert. Everything else is shared: a stack resizes, takes settings
/// and is removed exactly like any other tile.
Future<void> showDeskletMenu(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  Desklet desklet, {
  /// The tile's rectangle in global coordinates, so the panel opens beside the
  /// thing it is about. Null falls back to the centre of the screen, which is
  /// only reachable if a caller could not measure itself.
  Rect? anchor,
}) {
  HapticFeedback.mediumImpact();

  final kind = DeskletKinds.byId(desklet.kind);
  final isStack = desklet.kind == 'stack';

  // A stack's header counts its members, because "Stack" alone says nothing
  // about which one you are holding when there are two on a page.
  final memberCount =
      isStack ? DeskletLayout.membersOf(theme.prefs, desklet.id).length : 0;

  // A hosted widget's own label, which the picker stored when it placed it.
  // Falls back to the kind's label, then to something honest rather than to a
  // blank header: an unknown kind is a CDN pack this build has never heard of,
  // and it can still be moved and removed.
  final label = switch (desklet.config['label']) {
    final String s when s.isNotEmpty => s,
    _ when isStack => memberCount == 1
        ? context.t('desklets.stackOne')
        : context.t('desklets.stackMany', {'n': '$memberCount'}),
    // The kind's own label is authored English in desklet_spec and stays that
    // way for now: those are a separate table with their own keys to mint.
    _ => kind?.label ?? context.t('desklets.widget'),
  };

  // Built from the theme rather than looked up: the desktop is not guaranteed
  // to sit under a ChromeScope, and this route is not a descendant of it.
  final chrome = ChromeData.fromPalette(
    theme.palette,
    typography: theme.typography,
    textScale: theme.textScale,
    family: theme.chromeFamily,
    opacity: theme.surfaceOpacity,
    // The panel material, so this menu is cut and blurred like every other
    // floating surface. Built here rather than read from a scope because the
    // desktop is not guaranteed to sit under one and this route is not a
    // descendant of it, which is also why it is the one place that can forget.
    panelBlur: theme.panelBlur,
    panelTint: theme.panelTint,
    panelRadius: theme.panelRadius,
  );

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (sheet, _, __) {
      // `context`, the CALLER's, is passed alongside the route's own. Anything
      // that opens a second surface must push from a context that OUTLIVES this
      // panel: `sheet` is dead the instant the row pops it, and pushing onto a
      // dead route silently does nothing. Same trap desktop_menu documents.
      final rows =
          _rows(context, sheet, ref, theme, desklet, label, isStack);
      final size = MediaQuery.sizeOf(sheet);
      final pad = MediaQuery.viewPaddingOf(sheet);

      const width = 244.0;
      // Header plus rows, close enough to place it without measuring.
      final height = 44.0 + rows.length * 56.0;

      final a = anchor ??
          Rect.fromCenter(
            center: size.center(Offset.zero),
            width: 1,
            height: 1,
          );

      // ── BESIDE THE TILE, NOT AT THE BOTTOM OF THE SCREEN ──────────────
      //
      // This was a bottom sheet, which is what every other menu in the app is
      // and which is wrong here: a bottom sheet is for something about the
      // SCREEN, and this is about one tile. Most desklets sit in the upper
      // half, so the menu opened as far from its subject as the display allows
      // and the tile it referred to was behind the scrim.
      //
      // Below the tile when there is room, above it otherwise, clamped to the
      // safe area either way.
      final below = a.bottom + 8;
      final top = below + height <= size.height - pad.bottom - 8
          ? below
          : (a.top - height - 8)
              .clamp(pad.top + 8, size.height - height - pad.bottom - 8);

      final left = (a.center.dx - width / 2)
          .clamp(8.0, size.width - width - 8);

      return ChromeScope(
        data: chrome,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              child: GlassPanel(
                child: Material(
                  // Transparent: the glass paints. Material is here because a
                  // ThemedListRow's ink needs an ancestor and showGeneralDialog
                  // builds outside the app's Scaffold.
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: chrome.text.title,
                        ),
                      ),
                      ...rows,
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

List<Widget> _rows(
  /// The context that opened the panel. Survives the pop, so it is what any
  /// row pushing a further screen or sheet must use.
  BuildContext host,
  /// The panel's own route context. Only ever used to pop it.
  BuildContext sheet,
  WidgetRef ref,
  EffectiveTheme theme,
  Desklet desklet,
  String label,
  bool isStack,
) {
  return [
        ThemedListRow(
          icon: Icons.open_with,
          // ─── IT WAS NEVER ONLY RESIZE ──────────────────────────────
          //
          // Edit mode has driven both since it existed: `EditableDesklet`
          // pans to move and drags the corner handle to resize. The row said
          // "Resize", so the move half was undiscoverable, and moving a widget
          // read as a missing feature when it was a missing word.
          title: host.t('desklets.moveOrResize'),
          subtitle: host.t('desklets.moveOrResizeSub'),
          onTap: () {
            Navigator.pop(sheet);
            // The ONLY path that makes the desktop draggable, and it is now
            // deliberate rather than a side effect of holding something.
            final edit = ref.read(deskletEditProvider.notifier);
            edit.enter();
            edit.select(desklet.id);
          },
        ),
        if (isStack)
          ThemedListRow(
            icon: Icons.add,
            title: host.t('desklets.addWidget'),
            subtitle: host.t('desklets.addWidgetSub'),
            onTap: () {
              Navigator.pop(sheet);
              // `host`, not `sheet`: the panel's route is dead by the time the
              // picker pushes. Same reason the settings row uses it.
              showDeskletPicker(
                host,
                ref,
                theme,
                page: desklet.page,
                intoStack: desklet.id,
              );
            },
          ),
        if (isStack)
          ThemedListRow(
            icon: Icons.layers_clear_outlined,
            title: host.t('desklets.unstack'),
            subtitle: host.t('desklets.unstackSub'),
            onTap: () {
              Navigator.pop(sheet);
              ref.read(prefsProvider(theme.spec.id).notifier).edit(
                    (p) => DeskletLayout.unstack(
                      p,
                      desklet.id,
                      cols: theme.deskletCols,
                      rows: theme.deskletRows,
                    ),
                  );
            },
          )
        else
          ThemedListRow(
            icon: Icons.layers_outlined,
            title: host.t('desklets.makeStack'),
            subtitle: host.t('desklets.makeStackSub'),
            onTap: () {
              Navigator.pop(sheet);
              // The tile keeps its config and its native allocation; only its
              // position changes. See DeskletLayout.makeStack.
              ref.read(prefsProvider(theme.spec.id).notifier).edit(
                    (p) => DeskletLayout.makeStack(
                      p,
                      desklet.id,
                      newId: () =>
                          'st${DateTime.now().microsecondsSinceEpoch}',
                    ),
                  );
            },
          ),
        ThemedListRow(
          icon: Icons.tune,
          title: host.t('desklets.widgetSettings'),
          subtitle: host.t('desklets.widgetSettingsSub'),
          onTap: () {
            Navigator.pop(sheet);
            showDeskletSettings(host, ref, theme, desklet);
          },
        ),
        ThemedListRow(
          icon: Icons.delete_outline,
          title: host.t('desklets.remove'),
          subtitle: host.t('desklets.removeSub'),
          danger: true,
          onTap: () {
            Navigator.pop(sheet);
            removeDesklet(ref, theme, desklet);
          },
        ),
  ];
}

/// Take a desklet off the desktop, releasing anything native it owns.
///
/// ─── WHY THIS IS A FUNCTION AND NOT TWO COPIES ──────────────────────────────
///
/// A hosted AppWidget holds a device-local id allocated by `AppWidgetHost`. Drop
/// the placement without releasing it and the allocation leaks for the life of
/// the install: the host keeps listening for a widget nothing draws, and the id
/// is never reused.
///
/// That knowledge lived inside the editor's close badge, which was the only way
/// to remove a desklet at the time. It is now reachable from two places, and
/// two copies of "remember to free the native thing" is how one of them ends up
/// forgetting.
void removeDesklet(
  WidgetRef ref,
  EffectiveTheme theme,
  Desklet desklet,
) {
  HapticFeedback.mediumImpact();

  // Nothing selected any more; leaving a stale id selected would draw handles
  // around a tile that no longer exists.
  ref.read(deskletEditProvider.notifier).select(null);

  // ── A STACK TAKES ITS MEMBERS WITH IT ────────────────────────────────
  //
  // Members are parked on a page nothing renders, so deleting the stack alone
  // would leave them stored, invisible and unreachable forever, each hosted one
  // still holding a native allocation. Collected BEFORE the edit, while the
  // stack still exists to be read.
  final doomed = <Desklet>[
    desklet,
    if (desklet.kind == 'stack')
      ...DeskletLayout.stackContents(theme.prefs, desklet.id),
  ];

  for (final d in doomed) {
    if (d.kind != 'appwidget') continue;
    final id = d.config['widgetId'];
    if (id is int) {
      api.LauncherHostApi().removeWidget(id);
    }
  }

  ref.read(prefsProvider(theme.spec.id).notifier).edit((p) {
    var out = p;
    for (final d in doomed) {
      out = DeskletLayout.remove(out, d.id);
    }
    return out;
  });
}
