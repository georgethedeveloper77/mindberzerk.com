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
import '../../engine/widget_span.dart';
import '../../platform/launcher_api.g.dart' as api;
import '../drawer/app_icon.dart';
import 'desklet_cell.dart';
import 'desklet_edit.dart';
// DeskletSurfaceView for `gutter` only. The cell itself now arrives through
// `deskletCellProvider`, measured, rather than being estimated from the window.
import 'desklet_surface.dart' show buildDesklet, DeskletSurfaceView;
import 'widget_catalog.dart';
import 'widget_provider_card.dart';

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

    // ─── INITIAL SPAN ─────────────────────────────────────────────────────
    //
    // One line now, because the rule lives in `WidgetSpanResolver` where it can
    // be unit-tested. The whole story of what was wrong with the arithmetic
    // that used to sit here is written up in `widget_span.dart`; the short
    // version is that it multiplied `targetCellWidth` by a nominal 70dp, and 70
    // has never been the size of a launcher cell.
    //
    // The cell is the SURFACE'S OWN measurement, not an estimate of it. Null
    // only before any desktop has laid out, which the picker is not reachable
    // without; the fallback exists so a first-run edge case seeds something
    // sane rather than throwing.
    final cell = ref.read(deskletCellProvider) ??
        (
          w: 48.0,
          h: 48.0,
          cols: theme.deskletCols,
          rows: theme.deskletRows,
          gutter: DeskletSurfaceView.gutter,
        );

    final span = WidgetSpanResolver.resolve(
      widgetFootprint(provider),
      cell: cell,
      colFactor: DeskletLayout.colFactor,
      rowFactor: DeskletLayout.rowFactor,
    );
    final sx = span.spanX;
    final sy = span.spanY;

    // EVERY field the resolver reads is stored, not just the two that used to
    // be. Without `minResize*` the resize handles have no floor to clamp
    // against; without `targetCell*` a re-derive after a grid change falls back
    // to the dp path and quietly gives a different answer from the one the
    // widget was placed at.
    final config = <String, Object?>{
      WidgetConfigKeys.widgetId: widgetId,
      WidgetConfigKeys.providerKey: provider.providerKey,
      WidgetConfigKeys.label: provider.label,
      WidgetConfigKeys.minWidthDp: provider.minWidthDp,
      WidgetConfigKeys.minHeightDp: provider.minHeightDp,
      WidgetConfigKeys.minResizeWidthDp: provider.minResizeWidthDp,
      WidgetConfigKeys.minResizeHeightDp: provider.minResizeHeightDp,
      WidgetConfigKeys.targetCellWidth: provider.targetCellWidth,
      WidgetConfigKeys.targetCellHeight: provider.targetCellHeight,
      WidgetConfigKeys.resizeMode: provider.resizeMode,
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
                // ─── CARDS, NOT ROWS ────────────────────────────────────
                //
                // `_ProviderRow` put every preview in a 96dp thumbnail beside a
                // line of text. That reads as a list of names with pictures
                // attached; the stock picker reads as a set of offers, and the
                // whole difference is that its preview spans the card and its
                // height comes from the widget's own footprint.
                //
                // `WidgetProviderCard` was written for exactly this and then
                // never instantiated, so the better design has been sitting in
                // the tree unused. It carries the description line too, which
                // is the other half of why the stock sheet looks considered.
                for (final provider in g.providers)
                  WidgetProviderCard(
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
