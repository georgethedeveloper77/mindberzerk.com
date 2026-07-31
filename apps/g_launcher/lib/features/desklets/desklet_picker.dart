import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/desklet_layout.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import 'package:g_launcher/i18n/i18n.dart';
import '../../engine/desklet_spec.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart' as api;
import '../drawer/app_icon.dart';
import 'desklet_edit.dart';
// DeskletSurfaceView for its cell-size estimate: the picker must size a
// hosted widget in the same cells the surface will draw it in.
import 'desklet_surface.dart' show buildDesklet, DeskletSurfaceView;
import 'widget_catalog.dart';

/// Add something to the desktop. PHASE D4 → the image-2 restructure.
///
/// ─── TWO THINGS SHARE ONE WORD, SO THIS SURFACE HAS TWO SECTIONS ────────────
///
/// "Widgets" means two different objects on this launcher, and pretending they
/// are one is what made the old picker misleading:
///
///   OURS   desklets — a clock, a glance, a monitor, a note. Pure Flutter,
///          drawn on the grid the desktop already had, themed per distro. These
///          need no host and work today, so they come FIRST and show a LIVE
///          preview: you see the actual themed thing before you place it, the
///          way image 2 previews a widget rather than naming it.
///
///   THEIRS third-party Android app widgets — RemoteViews from other apps.
///          Enumerating them is `AppWidgetManager.getInstalledProviders()` and
///          placing one live needs an `AppWidgetHost`, neither of which is a
///          Dart concern. That section is scaffolded here and fed real data in
///          the next slice; until then it says so plainly rather than showing an
///          empty list that reads as broken.
///
/// ─── WHY A FULL-SCREEN ROUTE AND NOT A SHEET ────────────────────────────────
///
/// The old picker was a bottom sheet of text rows. A search field pinned on top,
/// a grid of live previews, and a scrolling app list below is more surface than
/// a sheet wants to be, and it is exactly the shape image 2 is. The call
/// signature is unchanged, so the edit bar's Add button and the empty-cell tap
/// keep working without an edit.
///
/// ChromeScope does not cross a route boundary on its own, so it is captured
/// here and re-provided inside the route — the same trick ThemedSheet and the
/// desktop menu use — which keeps `showMessage` and any themed rows dressed in
/// the distro's palette on the far side of the push.
Future<void> showDeskletPicker(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme, {
  required int page,
  int? col,
  int? row,
  /// When set, whatever is picked joins THIS stack instead of landing on the
  /// desktop. See the note on `_absorb`.
  String? intoStack,
}) async {
  const fallback = [
    'glance',
    'clock',
    'monitor',
    'fastfetch',
    'network',
    'storage',
    'battery',
    'notes',
    'search',
  ];

  final offers = DeskletKinds.resolveOffers(
    theme.spec.desklets.offersOr(fallback),
  );

  // Pane-only kinds never appear in a graphical picker: `df -h` on a GNOME
  // desktop would be a file manager, not a desklet. On the terminal shell they
  // are added by TYPING the command, which needs no sheet at all.
  final shown = offers.where((k) => !k.paneOnly).toList();

  if (shown.isEmpty) {
    context.showMessage(context.t('desklets.thisThemeOffersNo'));
    return;
  }

  final chrome = ChromeScope.of(context);

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChromeScope(
        data: chrome,
        child: _WidgetPickerScreen(
          theme: theme,
          kinds: shown,
          page: page,
          col: col,
          row: row,
          intoStack: intoStack,
        ),
      ),
    ),
  );
}

class _WidgetPickerScreen extends ConsumerStatefulWidget {
  const _WidgetPickerScreen({
    required this.theme,
    required this.kinds,
    required this.page,
    required this.col,
    required this.row,
    required this.intoStack,
  });

  final EffectiveTheme theme;
  final List<DeskletKind> kinds;
  final int page;

  /// The stack a pick should join, or null for the desktop. See `_commit`.
  final String? intoStack;

  final int? col;
  final int? row;

  @override
  ConsumerState<_WidgetPickerScreen> createState() =>
      _WidgetPickerScreenState();
}

class _WidgetPickerScreenState extends ConsumerState<_WidgetPickerScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  EffectiveTheme get theme => widget.theme;

  /// Add the kind and leave. An exact cell when the user tapped an empty one,
  /// otherwise wherever it fits. Refusal keeps the picker OPEN — you came here
  /// to place something, and closing on failure would make you reopen it — while
  /// success pops back to the desktop with the new tile already selected so its
  /// resize handle is showing.
  void _pick(DeskletKind kind) {
    final before = ref.read(prefsProvider(theme.spec.id)).value;
    if (before == null) return;

    String newId() => 'dk${DateTime.now().microsecondsSinceEpoch}';

    final after = (widget.col != null && widget.row != null)
        ? DeskletLayout.placeAt(
            before,
            kindId: kind.id,
            page: widget.page,
            col: widget.col!,
            row: widget.row!,
            cols: theme.deskletCols,
            rows: theme.deskletRows,
            newId: newId,
          )
        : DeskletLayout.place(
            before,
            kindId: kind.id,
            page: widget.page,
            cols: theme.deskletCols,
            rows: theme.deskletRows,
            newId: newId,
          );

    if (identical(after, before)) {
      context.showMessage(context.t('desklets.noRoomOnThis'));
      return;
    }

    HapticFeedback.selectionClick();
    _commit(after);
  }

  /// ─── WHERE A NEWLY PLACED DESKLET ACTUALLY GOES ─────────────────────────
  ///
  /// Both placement paths put the new tile on the DESKTOP, because that was the
  /// only destination there was. Adding to a stack could not reuse them by
  /// passing a different cell: a stack's members do not occupy cells at all,
  /// they are parked off-desktop and drawn into the stack's own rectangle.
  ///
  /// So placement runs unchanged and the result is ABSORBED afterwards. The
  /// tile is minted with a real position and immediately moved into the stack,
  /// which wastes a cell for the length of one function call and costs nothing.
  /// The alternative was a second pair of place / placeAt overloads that agree
  /// with the first pair until they do not.
  ///
  /// One consequence worth knowing: adding to a stack still needs a free cell
  /// to mint into, so a completely full page refuses. That is honest rather
  /// than ideal, and it is the same message the desktop already gives.
  void _commit(LauncherPrefs after) {
    final id = after.desklets.last.id;
    final stack = widget.intoStack;

    final out =
        stack == null ? after : DeskletLayout.addToStack(after, stack, id);

    ref.read(prefsProvider(theme.spec.id).notifier).edit((_) => out);

    // The STACK is what gets selected when we joined one: the new member has no
    // footprint of its own, so selecting it would draw handles around nothing.
    ref.read(deskletEditProvider.notifier).select(stack ?? id);
    Navigator.of(context).pop();
  }

  /// Place a hosted third-party AppWidget. Binds it natively (which can pop the
  /// system consent dialog and the provider's config screen), then drops an
  /// `appwidget` desklet carrying the returned host id.
  ///
  /// The native bind allocates a widget id even before the desklet is stored, so
  /// if there turns out to be no room the id is RELEASED rather than leaked —
  /// the opposite order from a Dart-only desklet, and the reason the refusal
  /// path here calls removeWidget.
  Future<void> _pickWidget(api.WidgetProviderInfo provider) async {
    final widgetId =
        await api.LauncherHostApi().addWidget(provider.providerKey);
    if (!mounted) return;
    // Null = the user cancelled the bind dialog or the config screen. Leave the
    // picker open, say nothing: a cancel is a choice, not an error.
    if (widgetId == null) return;

    final host = api.LauncherHostApi();
    final before = ref.read(prefsProvider(theme.spec.id)).value;
    if (before == null) {
      await host.removeWidget(widgetId);
      return;
    }

    String newId() => 'wk${DateTime.now().microsecondsSinceEpoch}';

    // ─── INITIAL SPAN, IN dp, AGAINST THE REAL CELL ───────────────────────
    //
    // This used to divide by a hardcoded 70, and to use `targetCellWidth` and
    // `targetCellHeight` as spans directly. Both were wrong in the same
    // direction and they compounded.
    //
    // A row on a 4 by 5 grid is about 140dp tall on a 1080 by 2340 phone, not
    // 70. So a Google Weather strip asking for 74dp was seeded at two rows and
    // handed 280dp: nearly four times its own height, which is exactly the
    // "third-party widgets look terrible" report. Spotify's media widget got
    // two and a half times.
    //
    // And `targetCell*` is expressed in a STANDARD launcher's cells, which are
    // roughly square and roughly 70dp. Treating those numbers as spans on a
    // grid whose rows are twice as tall doubles the error again.
    //
    // So: convert everything to dp first, then divide by what a cell on THIS
    // phone and THIS distro's grid actually measures.
    const nominalCellDp = 70.0;
    final cell = DeskletSurfaceView.estimateCell(context, theme);

    final tw = provider.targetCellWidth;
    final th = provider.targetCellHeight;

    final wantWidthDp =
        tw > 0 ? tw * nominalCellDp : provider.minWidthDp.toDouble();
    final wantHeightDp =
        th > 0 ? th * nominalCellDp : provider.minHeightDp.toDouble();

    // Ceil, because a widget given LESS than it asked for clips its own
    // layout, which is worse than a little slack around it.
    final sx = (wantWidthDp / cell.w).ceil().clamp(1, theme.deskletCols);
    final sy = (wantHeightDp / cell.h).ceil().clamp(1, theme.deskletRows);

    final config = <String, Object?>{
      'widgetId': widgetId,
      'providerKey': provider.providerKey,
      'label': provider.label,
      'minWidthDp': provider.minWidthDp,
      'minHeightDp': provider.minHeightDp,
    };

    var after = (widget.col != null && widget.row != null)
        ? DeskletLayout.placeAt(
            before,
            kindId: 'appwidget',
            page: widget.page,
            col: widget.col!,
            row: widget.row!,
            cols: theme.deskletCols,
            rows: theme.deskletRows,
            newId: newId,
            spanX: sx,
            spanY: sy,
            config: config,
          )
        : before;

    // An exact-cell refusal (occupied) or no cell given → let the packer choose.
    if (identical(after, before)) {
      after = DeskletLayout.place(
        before,
        kindId: 'appwidget',
        page: widget.page,
        cols: theme.deskletCols,
        rows: theme.deskletRows,
        newId: newId,
        spanX: sx,
        spanY: sy,
        config: config,
      );
    }

    if (identical(after, before)) {
      // Genuinely no room. Release the id we just bound rather than leak it.
      await host.removeWidget(widgetId);
      if (!mounted) return;
      context.showMessage(context.t('desklets.noRoomOnThis'));
      return;
    }

    HapticFeedback.selectionClick();
    _commit(after);
  }

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;

    final q = _query.trim().toLowerCase();
    final ours = q.isEmpty
        ? widget.kinds
        : widget.kinds.where((k) => k.label.toLowerCase().contains(q)).toList();

    // Two cards per row on a phone. Computed from the real width so the grid
    // stays even on a fold or a tablet without a breakpoint table.
    final screenW = MediaQuery.sizeOf(context).width;
    const pad = 16.0;
    const gap = 12.0;
    final cardW = (screenW - pad * 2 - gap) / 2;

    return Scaffold(
      backgroundColor: p.bgBottom,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(theme: theme),
            _SearchField(
              theme: theme,
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(pad, 8, pad, 24),
                children: [
                  _SectionHeader(theme: theme, label: context.t('drawer.gLauncher')),
                  const SizedBox(height: 12),
                  if (ours.isEmpty)
                    _EmptyLine(theme: theme, text: 'No widgets match')
                  else
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final kind in ours)
                          SizedBox(
                            width: cardW,
                            child: _DeskletPreviewCard(
                              theme: theme,
                              kind: kind,
                              onTap: () => _pick(kind),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 28),
                  _SectionHeader(theme: theme, label: context.t('desklets.appWidgets')),
                  const SizedBox(height: 12),
                  _AppWidgetSection(
                    theme: theme,
                    query: q,
                    onPlace: _pickWidget,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Just the title. No back button — the picker is dismissed with the system
/// back gesture, and it pops itself the moment you place something. A plain row
/// rather than an AppBar so it reads from the theme palette rather than the
/// Material default, the same as every other chrome surface in the app.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
      child: Text(
        'Add to desktop',
        style: TextStyle(
          fontFamily: theme.typography.display,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: p.onDark,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.theme,
    required this.controller,
    required this.onChanged,
  });

  final EffectiveTheme theme;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.onDark.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: p.onDark.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.search,
                size: 18, color: p.onDark.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: p.accent,
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 15,
                  color: p.onDark,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search widgets',
                  hintStyle: TextStyle(
                    fontFamily: theme.typography.display,
                    color: p.onDark.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.theme, required this.label});

  final EffectiveTheme theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: theme.typography.display,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: theme.palette.onDark.withValues(alpha: 0.6),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.theme, required this.text});

  final EffectiveTheme theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: theme.typography.display,
        fontSize: 13,
        color: theme.palette.onDark.withValues(alpha: 0.45),
      ),
    );
  }
}

/// A live desklet, shown at rest inside a mini desktop swatch. The whole point
/// of the restructure: you see the actual themed thing, not its name.
///
/// The preview renders through the SAME [buildDesklet] the desktop uses, so a
/// preview can never drift from what actually lands — and it sits on the
/// distro's own dark base so a bare (text-on-wallpaper) desklet stays readable
/// with no wallpaper behind it. [IgnorePointer] keeps the note and search tiles
/// from swallowing the tap that is meant to ADD them.
class _DeskletPreviewCard extends StatelessWidget {
  const _DeskletPreviewCard({
    required this.theme,
    required this.kind,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final DeskletKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    final skin = theme.spec.desklets.skinFor(theme.shell, kind.id);

    final preview = buildDesklet(
      theme,
      Desklet(
        id: 'preview_${kind.id}',
        kind: kind.id,
        page: 0,
        col: 0,
        row: 0,
        spanX: kind.defaultSpanX,
        spanY: kind.defaultSpanY,
      ),
      skin,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 104,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.bgBottom,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.onDark.withValues(alpha: 0.12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: preview ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            kind.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: theme.typography.display,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.onDark,
            ),
          ),
          Text(
            '${kind.defaultSpanX} x ${kind.defaultSpanY}',
            style: TextStyle(
              fontFamily: theme.typography.mono,
              fontSize: 11,
              color: p.onDark.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Third-party app widgets, grouped by app — the image-2 list.
///
/// One row per app with a provider count; tapping expands to that app's widgets
/// with live preview thumbnails. Enumeration is real and previewable now;
/// PLACEMENT is not, because a widget only becomes placeable once the host is
/// running, and that is the next slice. So a provider tap says so plainly rather
/// than doing nothing — the same honesty rule the nullable stat rows follow.
class _AppWidgetSection extends ConsumerWidget {
  const _AppWidgetSection({
    required this.theme,
    required this.query,
    required this.onPlace,
  });

  final EffectiveTheme theme;
  final String query;
  final void Function(api.WidgetProviderInfo) onPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(installedWidgetProvidersProvider);

    return async.when(
      loading: () => _Note(theme: theme, text: 'Looking for app widgets'),
      error: (_, __) => _Note(theme: theme, text: 'Could not read app widgets'),
      data: (groups) {
        // Filter by app label or any of the app's widget labels, so typing
        // "clock" surfaces the app whose widget is a clock even if the app is
        // not called that.
        final shown = query.isEmpty
            ? groups
            : groups.where((g) {
                if (g.appLabel.toLowerCase().contains(query)) return true;
                return g.providers
                    .any((p) => p.label.toLowerCase().contains(query));
              }).toList();

        if (shown.isEmpty) {
          return _Note(
            theme: theme,
            text: groups.isEmpty
                ? 'No app widgets installed'
                : 'No app widgets match',
          );
        }

        // Look up each app's launcher icon once for the group header. Apps
        // without a launcher activity fall back to a glyph.
        final apps =
            ref.watch(appListProvider).asData?.value ?? const <api.AppEntry>[];
        final iconByPkg = <String, api.AppEntry>{};
        for (final a in apps) {
          final pkg = a.componentKey.split('/').first;
          iconByPkg.putIfAbsent(pkg, () => a);
        }

        return Column(
          children: [
            for (final g in shown)
              _AppGroupTile(
                // Key on the query too, so switching from "no filter" to a
                // filtered view resets each tile's expansion to the sensible
                // default rather than keeping a stale open/closed state.
                key: ValueKey('${g.packageName}:${query.isEmpty}'),
                theme: theme,
                group: g,
                icon: iconByPkg[g.packageName],
                startExpanded: query.isNotEmpty,
                onPlace: onPlace,
              ),
          ],
        );
      },
    );
  }
}

/// One app row that expands to its widgets. Custom rather than [ExpansionTile]
/// so the chrome reads from the theme palette rather than Material defaults.
class _AppGroupTile extends StatefulWidget {
  const _AppGroupTile({
    super.key,
    required this.theme,
    required this.group,
    required this.icon,
    required this.startExpanded,
    required this.onPlace,
  });

  final EffectiveTheme theme;
  final WidgetAppGroup group;
  final api.AppEntry? icon;
  final bool startExpanded;
  final void Function(api.WidgetProviderInfo) onPlace;

  @override
  State<_AppGroupTile> createState() => _AppGroupTileState();
}

class _AppGroupTileState extends State<_AppGroupTile> {
  late bool _open = widget.startExpanded;

  @override
  Widget build(BuildContext context) {
    final p = widget.theme.palette;
    final g = widget.group;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: widget.icon != null
                      ? AppIcon(entry: widget.icon!, size: 40)
                      : Icon(Icons.widgets_outlined,
                          color: p.onDark.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    g.appLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: widget.theme.typography.display,
                      fontSize: 16,
                      color: p.onDark,
                    ),
                  ),
                ),
                Text(
                  '${g.providers.length}',
                  style: TextStyle(
                    fontFamily: widget.theme.typography.mono,
                    fontSize: 14,
                    color: p.onDark.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  color: p.onDark.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Column(
              children: [
                for (final provider in g.providers)
                  _ProviderRow(
                    theme: widget.theme,
                    provider: provider,
                    onPlace: widget.onPlace,
                  ),
              ],
            ),
          ),
        Divider(height: 1, color: p.onDark.withValues(alpha: 0.08)),
      ],
    );
  }
}

/// One widget provider: a preview thumbnail + its label. Tapping explains that
/// placement waits on the host slice, rather than silently doing nothing.
class _ProviderRow extends ConsumerWidget {
  const _ProviderRow({
    required this.theme,
    required this.provider,
    required this.onPlace,
  });

  final EffectiveTheme theme;
  final api.WidgetProviderInfo provider;
  final void Function(api.WidgetProviderInfo) onPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = theme.palette;

    // Ask for the preview at the thumbnail's real pixel size, so the native
    // render matches what is shown rather than being up- or downscaled.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final req = (
      providerKey: provider.providerKey,
      width: (96 * dpr).round(),
      height: (64 * dpr).round(),
    );
    final preview = ref.watch(widgetPreviewProvider(req));

    return InkWell(
      onTap: () => onPlace(provider),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Row(
          children: [
            Container(
              width: 96,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.onDark.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.onDark.withValues(alpha: 0.10)),
              ),
              child: preview.maybeWhen(
                data: (bytes) => bytes == null
                    ? _previewFallback(p.onDark)
                    : Image.memory(bytes, fit: BoxFit.contain),
                orElse: () => _previewFallback(p.onDark),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 14,
                      color: p.onDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _resizeLabel(provider),
                    style: TextStyle(
                      fontFamily: theme.typography.mono,
                      fontSize: 11,
                      color: p.onDark.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewFallback(Color onDark) => Center(
        child: Icon(
          Icons.widgets_outlined,
          size: 22,
          color: onDark.withValues(alpha: 0.35),
        ),
      );

  /// A short human hint about size, from the provider's min footprint. Kept
  /// approximate on purpose — exact cell mapping is the host slice's job.
  static String _resizeLabel(api.WidgetProviderInfo p) {
    final resizable = p.resizeMode != 0;
    final size = '${p.minWidthDp}×${p.minHeightDp}dp';
    return resizable ? '$size · resizable' : size;
  }
}

/// A quiet single-line status inside the App widgets section.
class _Note extends StatelessWidget {
  const _Note({required this.theme, required this.text});

  final EffectiveTheme theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: p.onDark.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.onDark.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(Icons.widgets_outlined,
              size: 20, color: p.onDark.withValues(alpha: 0.55)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: theme.typography.display,
                fontSize: 13,
                height: 1.35,
                color: p.onDark.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
