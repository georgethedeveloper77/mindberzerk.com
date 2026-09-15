/// The panel editor: a sheet, because a 44dp strip is a desktop control.
///
/// ─── WHY THE EDITING LEFT THE PANEL ────────────────────────────────────────
///
/// Editing used to happen ON the panel. Each module dimmed, took a badge and
/// answered a tap, and a toolbar sat against the edge with Add, Edge, a height
/// stepper, Reset and Done.
///
/// It did not work on a phone. The badges landed 30dp apart and overlapped the
/// modules beside them, the window list was crushed to nothing to make room,
/// and two identical minus circles gave no way to tell Network from Volume
/// before tapping one of them. Reordering meant dragging a 17dp icon sideways
/// along a strip past neighbours that also accepted the drop, which is the
/// hardest gesture in the app.
///
/// So the panel goes back to being a panel, and the editing happens where there
/// is room: 56dp rows carrying a glyph, a name and what the module does, with
/// 48dp controls and a vertical drag to reorder. The panel stays legible behind
/// the sheet and updates live as the list changes, which is the one thing the
/// inline version had going for it and the only part worth keeping.
///
/// ─── IT WEARS THE DISTRO, NOT THE HOUSE ────────────────────────────────────
///
/// Every colour and both typefaces come off `EffectiveTheme`, so the editor for
/// Garuda is Garuda pink on Garuda's bar colour and the editor for Mint is Mint
/// green. It is a piece of the desktop being edited rather than a settings
/// screen that happens to be about it, and a house-chrome sheet sliding up over
/// a distro panel would say the opposite.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart'
    show PanelItem, PanelModule, TopBarSide, ThemePalette;
import '../drawer/app_icon.dart';
import 'panel_edit.dart';
import 'panel_module_names.dart';
import 'panel_skin.dart';

/// Every module the editor can offer, in the order it lists them.
///
/// Ordered by what people reach for: the two that define a panel, then the
/// readouts, then the shaping. NOT the enum's order, which is the order the
/// modules happened to be written in.
const List<PanelModule> editableModules = [
  PanelModule.kickoff,
  PanelModule.tasks,
  PanelModule.app,
  PanelModule.pager,
  PanelModule.wifi,
  PanelModule.volume,
  PanelModule.battery,
  PanelModule.network,
  PanelModule.memory,
  PanelModule.storage,
  PanelModule.clock,
  PanelModule.spacer,
];

/// Modules a panel may legitimately hold more than one of.
///
/// A spacer, because two spacers is how a panel centres what sits between them.
/// An app, because a panel with one app button is not what anybody wants a
/// panel for. Everything else is one of a kind: a second clock shows the same
/// time.
bool repeatableModule(PanelModule m) =>
    m == PanelModule.spacer || m == PanelModule.app;

/// Open the editor beside the panel it edits.
///
/// ─── IT OPENS ON THE OPPOSITE EDGE ─────────────────────────────────────────
///
/// A bottom sheet is the right shape and the wrong place. With the panel at the
/// bottom, the sheet covers it, and every row is then talking about something
/// the user cannot see: remove the clock and there is no clock leaving, just a
/// row moving between two groups.
///
/// So the editor opens AWAY from the panel. Panel at the bottom, sheet from the
/// top. Panel at the top, sheet from the bottom. A left or right panel is a
/// vertical strip down one side and a bottom sheet never covers it, so that
/// keeps the shape a phone expects.
///
/// This is why it is a `showGeneralDialog` and not `showModalBottomSheet`: that
/// helper can only come from the bottom, and the placement is the point.
///
/// Returns when the editor closes, so the caller can leave edit mode without
/// tracking the route's own lifetime.
Future<void> showPanelEditor(BuildContext context, EffectiveTheme theme) {
  // The panel's edge decides where the editor is NOT.
  final fromTop = theme.panelSide == TopBarSide.bottom;

  return showGeneralDialog<void>(
    context: context,
    // ─── THE ROOT NAVIGATOR, NOT THE SHELL'S ────────────────────────────
    //
    // The Edge control rebuilds the shell subtree under the editor, and a route
    // living in a navigator inside that subtree is at the mercy of it.
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => Align(
      alignment: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
      child: _PanelEditor(theme: theme, fromTop: fromTop),
    ),
    transitionBuilder: (_, anim, __, child) => SlideTransition(
      // In from the edge it lives on, so the editor reads as arriving from the
      // side of the screen the panel is not on.
      position: Tween<Offset>(
        begin: Offset(0, fromTop ? -1 : 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _PanelEditor extends ConsumerWidget {
  const _PanelEditor({required this.theme, required this.fromTop});

  /// True when the editor is anchored to the top of the screen, which rounds
  /// its BOTTOM corners and puts the grab handle at the foot. A sheet with its
  /// handle on the far side from the edge it hangs off looks upside down.
  final bool fromTop;

  /// The theme at open time, kept only for the ID. Everything read below comes
  /// off the LIVE theme, so the sheet redraws as its own edits land rather than
  /// showing the panel as it was when the sheet opened.
  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(effectiveThemeProvider).value ?? theme;
    final p = live.palette;
    final items = currentPanelItems(live);
    final height = live.panelHeight ?? defaultPanelHeight;

    final onPanel = items.map((e) => e.kind).toList();
    final off = [
      for (final m in editableModules)
        if (repeatableModule(m) || !onPanel.contains(m)) m,
    ];

    return Container(
      // 70% of the screen, which leaves the panel and a strip of desktop above
      // it. Enough for five rows and the controls without hiding the subject.
      height: MediaQuery.of(context).size.height * 0.70,
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.bar,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(fromTop ? 0 : 16),
          bottom: Radius.circular(fromTop ? 16 : 0),
        ),
        border: Border.all(color: p.onDark.withValues(alpha: 0.10)),
      ),
      // ─── A Material, BECAUSE showGeneralDialog DOES NOT ADD ONE ─────────
      //
      // `showModalBottomSheet` wraps its content in one; a raw dialog route
      // does not. Every ink-based control inside asserts without an ancestor,
      // which is what `InkResponse` in the add and remove buttons did, and it
      // is also what `ReorderableListView` needs for the lifted drag proxy.
      //
      // Transparency, not a colour: the Container above already paints the
      // surface, and a second opaque layer would square off the corners it
      // just rounded.
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: live.typography.display,
            color: p.onDark,
          ),
          child: Column(
            children: [
              // The status bar sits above a top-anchored editor, the gesture bar
              // below a bottom-anchored one. Padding only the edge it touches.
              SizedBox(
                height: fromTop ? MediaQuery.of(context).padding.top : 0,
              ),
              if (!fromTop) _grab(p),
              _header(context, ref, p),
              // ─── SLIVERS, NOT A LIST INSIDE A LIST ────────────────────
              //
              // This was a `ListView` holding a shrink-wrapped
              // `ReorderableListView`, which is two viewports stacked, and the
              // inner one handed its rows unbounded width. A `Row` with an
              // `Expanded` in it then overflowed by ninety-nine THOUSAND pixels,
              // which is the shape of a constraint that was never finite rather
              // than a layout that was slightly too wide.
              //
              // `SliverReorderableList` is the supported way to put a reorderable
              // run inside a scroll view that also holds other things. One
              // viewport, one set of constraints, and the drag still works.
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _group(context, p, 'shell.onThePanel'),
                    ),
                    SliverReorderableList(
                      itemCount: items.length,
                      onReorderItem: (from, to) =>
                          reorderPanelModule(ref, live, items, from, to),
                      proxyDecorator: (child, _, __) => Material(
                        color: p.onDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        child: child,
                      ),
                      itemBuilder: (context, i) => _PanelRow(
                        key: ValueKey('${items[i].toStorage()}.$i'),
                        theme: live,
                        item: items[i],
                        index: i,
                        onRemove: () => removePanelModule(ref, live, items, i),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _group(context, p, 'shell.notOnThePanel'),
                    ),
                    SliverList.list(
                      children: [
                        if (off.isEmpty)
                          _empty(context, p, 'shell.everythingOnPanel')
                        else
                          for (final m in off)
                            _AddRow(theme: live, module: m, items: items),
                        _EdgeField(theme: live),
                        _HeightField(theme: live, height: height),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ],
                ),
              ),
              _footer(context, ref, live),
              if (fromTop) _grab(p),
              SizedBox(
                height: fromTop ? 0 : MediaQuery.of(context).padding.bottom,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grab(ThemePalette p) => Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 2),
        decoration: BoxDecoration(
          color: p.onDark.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header(BuildContext context, WidgetRef ref, ThemePalette p) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.t('shell.editPanel'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.t('shell.done'),
                style: TextStyle(color: p.accent, fontSize: 14),
              ),
            ),
          ],
        ),
      );

  Widget _group(BuildContext context, ThemePalette p, String key) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Text(
          context.t(key).toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.4,
            color: p.onDark.withValues(alpha: 0.55),
          ),
        ),
      );

  Widget _empty(BuildContext context, ThemePalette p, String key) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Text(
          context.t(key),
          style: TextStyle(
            fontSize: 13,
            color: p.onDark.withValues(alpha: 0.45),
          ),
        ),
      );

  Widget _footer(BuildContext context, WidgetRef ref, EffectiveTheme live) {
    final p = live.palette;
    // EITHER pref. Someone who only thickened the panel has something to reset,
    // and a Reset that ignored height would leave them with no way back to the
    // distro's own.
    final edited = live.prefs.panelModules != null ||
        live.prefs.panelHeight != null ||
        live.prefs.panelSide != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: p.onDark.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          // Absent until there is something to reset. A Reset that resets
          // nothing teaches the user that it does nothing.
          if (edited)
            OutlinedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(prefsProvider(live.spec.id).notifier).edit(
                      (x) => x.clearing(
                        panelModules: true,
                        panelHeight: true,
                        panelSide: true,
                      ),
                    );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: BorderSide(color: p.onDark.withValues(alpha: 0.20)),
              ),
              child: Text(
                context.t('shell.resetPanel'),
                style: TextStyle(color: p.onDark.withValues(alpha: 0.75)),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.bar,
                minimumSize: const Size(0, 48),
              ),
              child: Text(context.t('shell.done')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    super.key,
    required this.theme,
    required this.item,
    required this.index,
    required this.onRemove,
  });

  final EffectiveTheme theme;
  final PanelItem item;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final label = panelModuleLabel(context, item.kind);

    return Container(
      color: p.bar,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: 6, right: 8),
      child: Row(
        children: [
          // 48dp of grip. The whole point of moving here is that the thing you
          // grab is bigger than the thing you were grabbing before.
          //
          // DELAYED, so a stray horizontal finger on the grip does not start a
          // drag the user did not mean. The list scrolls vertically and so does
          // the drag, and the two are told apart by the hold.
          ReorderableDelayedDragStartListener(
            index: index,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: p.onDark.withValues(alpha: 0.35),
              ),
            ),
          ),
          _glyph(theme, panelModuleIcon(item.kind)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                Text(
                  // The package for an app module, the description for the
                  // rest. Two app buttons are the ordinary case, so the name
                  // alone would not say which one this row is.
                  item.kind == PanelModule.app
                      ? (item.package ?? '')
                      : context.t(panelModuleNote(item.kind)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.onDark.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          _RoundAction(
            icon: Icons.remove,
            colour: p.accent,
            semantic: label,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

/// A module not currently on the panel.
class _AddRow extends ConsumerWidget {
  const _AddRow({
    required this.theme,
    required this.module,
    required this.items,
  });

  final EffectiveTheme theme;
  final PanelModule module;
  final List<PanelItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = theme.palette;
    final label = panelModuleLabel(context, module);

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: 54, right: 8),
      child: Row(
        children: [
          _glyph(theme, panelModuleIcon(module), muted: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                Text(
                  context.t(panelModuleNote(module)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.onDark.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          _RoundAction(
            icon: Icons.add,
            colour: p.accent,
            semantic: label,
            onTap: () {
              if (module == PanelModule.app) {
                // A kind is not enough for this one: it needs to know WHICH
                // app, so the choice is a second sheet rather than a write.
                _pickPanelApp(context, ref, theme, items);
                return;
              }
              addPanelModule(ref, theme, items, PanelItem(module));
            },
          ),
        ],
      ),
    );
  }
}

Widget _glyph(EffectiveTheme theme, IconData icon, {bool muted = false}) {
  final p = theme.palette;
  return Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: p.onDark.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      icon,
      size: 17,
      color: muted ? p.onDark.withValues(alpha: 0.60) : p.accent,
    ),
  );
}

/// The 48dp circle that adds or removes. One widget, because a plus and a minus
/// that behave differently under the thumb is the bug this whole sheet exists
/// to fix.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.colour,
    required this.semantic,
    required this.onTap,
  });

  final IconData icon;
  final Color colour;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: 26,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 22, color: colour),
        ),
      ),
    );
  }
}

/// The four edges, as a segmented control.
class _EdgeField extends ConsumerWidget {
  const _EdgeField({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const sides = [
      (TopBarSide.top, 'shell.edgeTop'),
      (TopBarSide.bottom, 'shell.edgeBottom'),
      (TopBarSide.left, 'shell.edgeLeft'),
      (TopBarSide.right, 'shell.edgeRight'),
    ];
    final p = theme.palette;

    return _Field(
      theme: theme,
      label: context.t('shell.panelEdge'),
      child: Row(
        children: [
          for (final (side, key) in sides) ...[
            if (side != sides.first.$1) const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(prefsProvider(theme.spec.id).notifier)
                      .edit((x) => x.copyWith(panelSide: side.name));
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: EdgeInsets.zero,
                  backgroundColor:
                      side == theme.panelSide ? p.accent : Colors.transparent,
                  side: BorderSide(
                    color: side == theme.panelSide
                        ? p.accent
                        : p.onDark.withValues(alpha: 0.20),
                  ),
                ),
                child: Text(
                  context.t(key),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: side == theme.panelSide
                        ? p.bar
                        : p.onDark.withValues(alpha: 0.80),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thickness, as a stepper with a track showing where it sits in the range.
class _HeightField extends ConsumerWidget {
  const _HeightField({required this.theme, required this.height});

  final EffectiveTheme theme;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = theme.palette;
    final span = (height - minPanelHeight) / (maxPanelHeight - minPanelHeight);

    Widget step(IconData icon, bool enabled, double to) => OutlinedButton(
          onPressed: enabled ? () => setPanelHeight(ref, theme, to) : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            side: BorderSide(color: p.onDark.withValues(alpha: 0.20)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: p.onDark.withValues(alpha: enabled ? 0.85 : 0.30),
          ),
        );

    return _Field(
      theme: theme,
      label: context.t('shell.panelThickness'),
      child: Row(
        children: [
          // A STEPPER, NOT A SLIDER. Panel thickness has about ten useful
          // values and a wrong one is instantly visible, so the control that
          // matters is the one you can nudge and read.
          step(Icons.remove, height > minPanelHeight, height - panelHeightStep),
          SizedBox(
            width: 64,
            child: Text(
              '${height.round()} dp',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontFamily: theme.typography.mono,
              ),
            ),
          ),
          step(Icons.add, height < maxPanelHeight, height + panelHeightStep),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: p.onDark.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: span.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.theme,
    required this.label,
    required this.child,
  });

  final EffectiveTheme theme;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.4,
              color: theme.palette.onDark.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Choose which app goes on the panel.
///
/// Reads `shellAppsProvider`, the same list the dock and drawer use, so an app
/// the user hid stays hidden here. The panel must not become a way around the
/// drawer's own filtering.
void _pickPanelApp(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  List<PanelItem> items,
) {
  final apps = ref.read(shellAppsProvider(theme));
  final already = {
    for (final e in items)
      if (e.kind == PanelModule.app) e.package,
  };
  final p = theme.palette;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.bar,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheet).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('shell.whichApp'),
                      style: TextStyle(
                        fontSize: 16,
                        color: p.onDark,
                        fontFamily: theme.typography.display,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.78,
                ),
                itemCount: apps.length,
                itemBuilder: (context, i) {
                  final entry = apps[i];
                  // Dimmed rather than absent. A panel CAN hold the same app
                  // twice, but somebody scanning for one they already added
                  // should be able to see that they did.
                  final on = already.contains(entry.packageName);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pop(sheet);
                      addPanelModule(
                        ref,
                        theme,
                        items,
                        PanelItem(PanelModule.app, entry.packageName),
                      );
                    },
                    child: Opacity(
                      opacity: on ? 0.4 : 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(entry: entry, size: 40),
                          const SizedBox(height: 4),
                          Text(
                            entry.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: p.onDark.withValues(alpha: 0.80),
                              fontFamily: theme.typography.display,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
