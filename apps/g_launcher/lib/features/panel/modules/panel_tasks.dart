/// The task strip: what a taskbar puts between the menu button and the tray.
///
/// ─── ON A DOCKLESS DISTRO THIS IS THE DOCK ─────────────────────────────────
///
/// Mint authors `dock: "off"` and puts a panel at the bottom instead, and this
/// strip reads `HomeLayout.dockKeys`: the same pins, the same frecency
/// fallback, the same capacity rule. It is not dock-like, it is the dock in
/// panel form, which is why it drags by the same rules and reports
/// [DragOrigin.dock] rather than a fifth origin nobody would have a rule for.
///
/// It also means drag was missing from the one surface Mint has. The dock got
/// it and Mint has no dock, so on the distro that started this work nothing
/// could be dragged anywhere.
///
/// ─── IT READS ITS OWN APPS NOW ─────────────────────────────────────────────
///
/// The list used to be computed in the KDE shell's `build` and passed down,
/// which meant the panel's widest module could only be drawn by the one shell
/// that did that computation. It is the same lookup the GNOME dock does, on the
/// same providers, so it moves in with the widget that needs it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/platform/launcher_api.g.dart';

import '../../../data/prefs/home_layout.dart';
import '../../../data/prefs/prefs_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/shell_apps.dart';
import '../../../data/usage/usage_repository.dart';
import '../../../engine/effective_theme.dart';
import '../../dock/dock_metrics.dart';
import '../../dock/dock_motion.dart';
import '../../drawer/app_icon.dart';
import '../../drawer/drawer_drag.dart';
import '../panel_skin.dart';

class PanelTaskStrip extends ConsumerWidget {
  const PanelTaskStrip({
    super.key,
    required this.theme,
    required this.vertical,
  });

  final EffectiveTheme theme;
  final bool vertical;

  /// The panel's own ceiling, above the dock's. A strip is scrollable, so this
  /// is about how many are worth ranking rather than how many fit.
  static const int capacity = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(shellAppsProvider(theme));
    final frequent = ref.watch(frequentAppsProvider);
    final byKey = {for (final a in apps) a.componentKey: a};

    // Same source of truth as the GNOME dock: pins, else most-used, else the
    // alphabetical head so the task strip is never empty on first run.
    var keys = HomeLayout.dockKeys(
      theme.prefs,
      frequent: frequent,
      capacity: capacity,
      defaultLimit: DockMetrics.defaultCount,
    );
    if (keys.isEmpty) {
      keys = [
        for (final a in apps.take(DockMetrics.defaultCount)) a.componentKey,
      ];
    }
    final taskKeys = [
      for (final k in keys)
        if (byKey[k] != null) k,
    ];

    // ─── ONE TARGET FOR THE WHOLE STRIP ─────────────────────────────────
    //
    // Same shape the dock uses and for the same reason: an app arriving from
    // the desktop has no opinion about which gap in the strip it lands in, and
    // asking somebody to hit a 4dp gap to express something they were not
    // thinking about turns a drop into a game.
    return DragTarget<DrawerDrag>(
      onWillAcceptWithDetails: (d) =>
          d.data is AppDrag && d.data.from != DragOrigin.dock,
      onAcceptWithDetails: (d) {
        HapticFeedback.mediumImpact();
        final key = (d.data as AppDrag).componentKey;
        ref.read(prefsProvider(theme.spec.id).notifier).edit((p) {
          final pinned =
              HomeLayout.pinToDock(p, key, capacity: PanelTaskStrip.capacity);
          final at = HomeLayout.slotOf(pinned, key);
          // One arrangement across both surfaces: an app that arrives here
          // leaves the desktop, or the drag reads as having failed.
          return at == null
              ? pinned
              : HomeLayout.removeFromHome(pinned, at.page, at.index);
        });
      },
      builder: (context, candidate, __) => DecoratedBox(
        decoration: BoxDecoration(
          color: candidate.isEmpty
              ? null
              : theme.palette.accent.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(4),
        ),
        // The panel's thickness decides the icon, so it is read here rather
        // than assumed: a horizontal strip's height and a vertical one's width.
        child: LayoutBuilder(
          builder: (context, box) => _strip(
            ref,
            taskKeys,
            byKey,
            panelIconSize(vertical ? box.maxWidth : box.maxHeight),
          ),
        ),
      ),
    );
  }

  /// Scrolls ALONG the panel. Left horizontal, a vertical strip would have
  /// tried to scroll its 40dp width and the task list would have been
  /// unreachable past the first icon.
  Widget _strip(
    WidgetRef ref,
    List<String> taskKeys,
    Map<String, AppEntry> byKey,
    double icon,
  ) {
    Widget button(String k) => _TaskButton(
          vertical: vertical,
          icon: icon,
          entry: byKey[k]!,
          onTap: () {
            ref.read(appListProvider.notifier).launch(byKey[k]!);
            ref.read(usageProvider.notifier).record(k);
          },
        );

    ListView list(Widget Function(int i, String k) wrap) => ListView(
          scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
          children: [
            for (var i = 0; i < taskKeys.length; i++) wrap(i, taskKeys[i]),
          ],
        );

    // ─── THE SAME MOTION EVERY DOCK GETS ──────────────────────────────
    //
    // Mint has no dock and this strip IS its dock, reading the same
    // `HomeLayout.dockKeys`. A hover setting that worked on Ubuntu's dock and
    // not on this one would be exactly the distro-specific behaviour the panel
    // refactor existed to remove.
    final hover = theme.dockHover;
    final press = theme.dockPress;
    // Either axis keeps the tracker alive. Gating on hover alone left press
    // dead on Mint, whose panel is the one surface it has.
    if (hover == 'none' && press == 'none') return list((i, k) => button(k));

    return DockFocusTracker(
      enabled: true,
      vertical: vertical,
      // Measured from this strip's own icon, not the dock's. A panel task icon
      // is well under a dock slot, and borrowing the dock's spread would make
      // the motion reach half the panel.
      spread: (icon + panelIconGap) * 2,
      builder: (context, focus) => list(
        (i, k) {
          // The strip scrolls, so this is a position in the LIST's space and
          // the tracker sits inside the viewport with it. A tracker outside
          // would report viewport coordinates while the slots had moved.
          final centre = (icon + panelIconGap) / 2 + i * (icon + panelIconGap);

          // Hover outside, press inside, the same nesting the docks use: press
          // moves a slot relative to wherever hover has put it.
          return DockSlotMotion(
            mode: hover,
            focus: focus,
            centre: centre,
            slotSize: icon,
            vertical: vertical,
            child: DockPressMotion(
              mode: press,
              focus: focus,
              centre: centre,
              vertical: vertical,
              child: button(k),
            ),
          );
        },
      ),
    );
  }
}

class _TaskButton extends ConsumerWidget {
  const _TaskButton({
    required this.entry,
    required this.onTap,
    required this.vertical,
    required this.icon,
  });

  /// Icon size from [panelIconSize]. The tap target is this plus the gap along
  /// the panel, and the panel's whole thickness across it.
  final double icon;

  final AppEntry entry;
  final VoidCallback onTap;

  /// Which way the padding runs. The icon itself needs no change, because this
  /// button never carried a label: a Plasma task strip on a phone is icons, and
  /// that is the one thing about it that was already orientation-neutral.
  final bool vertical;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: panelIconGap / 2)
          : const EdgeInsets.symmetric(horizontal: panelIconGap / 2),
      child: Center(child: AppIcon(entry: entry, size: icon)),
    );

    // ─── DOCK ORIGIN, NOT A PANEL ONE ────────────────────────────────────
    //
    // What this strip holds IS the dock's list, so a target reading the origin
    // gets the right answer without knowing this surface exists. The desktop
    // already unpins anything arriving `from: dock`, which is what makes
    // dragging an app off Mint's panel take it off the panel.
    return LongPressDraggable<DrawerDrag>(
      data: AppDrag(entry.componentKey, from: DragOrigin.dock),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // The motion carries each icon's drop target with it, so it stands down
      // for the drag. See `dockDragActiveProvider`.
      onDragStarted: () {
        HapticFeedback.mediumImpact();
        ref.read(dockDragActiveProvider.notifier).set(true);
      },
      onDragEnd: (_) => ref.read(dockDragActiveProvider.notifier).set(false),
      onDraggableCanceled: (_, __) =>
          ref.read(dockDragActiveProvider.notifier).set(false),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: AppIcon(entry: entry, size: icon + 8),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: core),
      child: InkWell(onTap: onTap, child: core),
    );
  }
}
