import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../design/device_preview.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart' show ChromeFamily;
import '../gestures/gesture_actions.dart';
import '../home/workspaces/workspace_controller.dart';
import '../themes/themes_screen.dart';
import 'folders_screen.dart';
import 'wallpaper_screen.dart';

/// Settings — Phase B, B1.
///
/// The look is no longer a fixed "One UI" skin. Every surface now derives from
/// the active theme via the chrome layer (see design/components): the accent is
/// the DISTRO's accent — Ubuntu orange, Fedora blue, KDE Breeze blue — not a
/// hardcoded Samsung blue, and the group framing forks on [ChromeFamily] so the
/// page reads as GNOME/Adwaita under Ubuntu and KDE/Breeze under Plasma. The old
/// `_Ou` palette (the one place that read Samsung-blue) is gone; its field names
/// survive on [_Skin], which resolves them from the chrome instead.
///
/// Every knob still writes to prefsProvider(themeId) and the shell repaints; the
/// screen re-reads the theme live (see build) so a change shows here at once.
///
/// ## Two rules that predate this screen and outlive it
///
///  - **OVERRIDES ARE STORED PER THEME.** `prefsProvider` is keyed on the theme
///    id, so choosing 5 columns under Ubuntu does not follow you into KDE. That
///    is the point: a distro's defaults are part of what makes it feel like
///    itself, and a global override would flatten every theme into the same
///    layout with different colours. See `engine/layout_resolver.dart` for the
///    merge order.
///  - **WE DO NOT REIMPLEMENT ANDROID SETTINGS.** Anything the OS owns is a
///    deep link out (`openAndroidSettings`), never a reimplementation. A
///    launcher that grows its own display or storage pages is wrong on the next
///    OEM skin and stale on the next Android release. Opinionated defaults still
///    need an escape hatch; the escape hatch is the real settings app.
///
/// (Absorbed from the retired `features/settings/README.md`, whose row list had
/// already gone stale — it still said "Home grid", renamed to "Desktop grid" in
/// Phase A.)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Live, not the push-time snapshot — every control reflects its edit at once.
    final theme =
        ref.watch(effectiveThemeProvider).asData?.value ?? widget.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final api = ref.read(launcherHostApiProvider);
    final workspaces = ref.watch(workspaceCountProvider);
    final q = _query.trim();

    // ThemedScaffold paints the background from the derived chrome and installs
    // the ChromeScope every widget below reads. No app bar: the large title
    // lives in the list, so we pass no title and keep the top status-bar inset.
    return ThemedScaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.viewPaddingOf(context).top,
          bottom: 28,
        ),
        children: [
          const _Title('Settings'),

          _SearchField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
          ),

          const _DefaultLauncherBanner(),

          // ── Personalize ────────────────────────────────────────────────
          _Group(
            label: 'Personalize',
            query: q,
            rows: [
              _FilterRow(
                const ['theme', 'distro', 'desktop look', 'appearance'],
                _Row(
                  icon: Icons.palette_outlined,
                  accent: true, // leads with the distro accent
                  title: 'Theme',
                  subtitle: 'The whole desktop look',
                  trailing: _Value(theme.spec.name),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ThemesScreen(),
                    ),
                  ),
                ),
              ),
              _FilterRow(
                const ['icon shape', 'circle', 'squircle', 'rounded'],
                _Row(
                  icon: Icons.category_outlined,
                  title: 'Icon shape',
                  subtitle: _shapeLong(theme.prefs.iconTreatment),
                  trailing: _Value(_shapeShort(theme.prefs.iconTreatment)),
                  onTap: () => _showShapeSheet(context, notifier, theme),
                ),
              ),
              _FilterRow(
                const ['icon pack', 'icons', 'adaptive', 'yaru'],
                _Row(
                  icon: Icons.grid_view_outlined,
                  title: 'Icon pack',
                  // Honest: the runtime engine already themes every app
                  // adaptively. Hand-authored hero packs are the not-yet part.
                  subtitle: 'Adaptive — every app covered',
                  trailing: const _Value('Adaptive'),
                  onTap: () =>
                      context.showMessage('Custom icon packs are coming'),
                ),
              ),
              _FilterRow(
                const ['wallpaper', 'background', 'photo', 'rotation'],
                _Row(
                  icon: Icons.image_outlined,
                  title: 'Wallpaper',
                  subtitle: 'Presets, your photos, rotation',
                  trailing: const _Chevron(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WallpaperScreen(theme: theme),
                    ),
                  ),
                ),
              ),
              _FilterRow(
                const [
                  'verbose boot',
                  'boot',
                  'boot log',
                  'startup',
                  'systemd',
                  'terminal',
                ],
                _ToggleRow(
                  icon: Icons.terminal,
                  title: 'Verbose boot',
                  // Off = the quick splash. On = the full [  OK  ] scroll every
                  // time the shell opens, themed to this distro.
                  subtitle: 'Play the full Linux boot log on every launch',
                  // null = off; the toggle reads and writes an explicit bool.
                  value: theme.prefs.verboseBoot ?? false,
                  onChanged: (v) =>
                      notifier.edit((p) => p.copyWith(verboseBoot: v)),
                ),
              ),
            ],
          ),

          // A LIVE PREVIEW, not another list row.
          //
          // Dock side, the app-grid button and the drawer width are spatial
          // settings, and a row that says "Dock position — Left" makes you
          // apply it and back out to find out what changed. Setup shows the
          // same picture from the same widget; Settings should not be the
          // poorer of the two just because it came first.
          //
          // Hidden while searching: a preview is not a search result, and it
          // would sit above a filtered list looking like one.
          if (q.isEmpty) _LayoutPreview(theme: theme),

          // ── Layout ─────────────────────────────────────────────────────
          _Group(
            label: 'Layout',
            query: q,
            rows: [
              _FilterRow(
                const ['dock', 'dock position', 'left', 'bottom'],
                _Row(
                  icon: Icons.dashboard_outlined,
                  accent: true,
                  title: 'Dock position',
                  trailing: _Seg(
                    // theme.dock is already the effective value (pref or default).
                    value: theme.dock.name,
                    options: const {
                      'left': 'Left',
                      'bottom': 'Bottom',
                      'off': 'Off',
                    },
                    onChanged: (v) =>
                        notifier.edit((p) => p.copyWith(dockSide: v)),
                  ),
                ),
              ),
              _FilterRow(
                const ['activities', 'grid button', 'app button', 'dock'],
                _Row(
                  icon: Icons.apps_outlined,
                  accent: true,
                  title: 'Activities button',
                  subtitle: 'Where the app-grid button sits in the dock',
                  trailing: _Seg(
                    value:
                        theme.prefs.dockGridButton ?? 'end', // Ubuntu default
                    options: const {
                      'start': 'Start',
                      'end': 'End',
                      'off': 'Off',
                    },
                    onChanged: (v) =>
                        notifier.edit((p) => p.copyWith(dockGridButton: v)),
                  ),
                ),
              ),
              _FilterRow(
                // Relabeled from "Home grid". The authentic-desktop decision
                // removed home-screen app icons, so "Home grid" implied an
                // icon grid that no longer exists. This rows × columns is the
                // desktop's placement grid — where widgets / conky tiles snap
                // once WidgetHost lands. The old "home grid" search term is kept
                // so anyone looking for the previous name still finds this.
                const [
                  'desktop grid',
                  'home grid',
                  'rows',
                  'columns',
                  'grid size',
                  'widgets',
                ],
                _Row(
                  icon: Icons.grid_view_outlined,
                  accent: true,
                  title: 'Desktop grid',
                  subtitle: 'Rows × columns',
                  trailing: _ChipValue(
                    label: '${theme.rows} × ${theme.cols}',
                    preview: DevicePreview(
                      palette: theme.palette,
                      mode: DevicePreviewMode.desktop,
                      dock: theme.dock,
                      gridButton: theme.prefs.dockGridButton ?? 'end',
                    ),
                  ),
                  onTap: () => _showGridSheet(context, notifier, theme),
                ),
              ),
              _FilterRow(
                const ['workspaces', 'pages', 'desktops', 'swipe'],
                _Row(
                  icon: Icons.dashboard_customize_outlined,
                  accent: true,
                  title: 'Workspaces',
                  subtitle: 'Vertical desktops you swipe between',
                  trailing: _Value('$workspaces'),
                  onTap: () => _showStepperSheet(
                    context,
                    title: 'Workspaces',
                    value: workspaces,
                    min: WorkspaceCount.min,
                    max: WorkspaceCount.max,
                    onChanged: (v) =>
                        ref.read(workspaceCountProvider.notifier).set(v),
                  ),
                ),
              ),
              _FilterRow(
                const ['drawer columns', 'app drawer', 'columns'],
                _Row(
                  icon: Icons.view_column_outlined,
                  accent: true,
                  title: 'Drawer columns',
                  trailing: _ChipValue(
                    label: '${theme.drawerCols}',
                    preview: DevicePreview(
                      palette: theme.palette,
                      mode: DevicePreviewMode.drawer,
                      cols: theme.drawerCols,
                    ),
                  ),
                  onTap: () => _showStepperSheet(
                    context,
                    title: 'Drawer columns',
                    value: theme.drawerCols,
                    min: 3,
                    max: 8,
                    onChanged: (v) =>
                        notifier.edit((p) => p.copyWith(drawerCols: v)),
                  ),
                ),
              ),
              _FilterRow(
                const [
                  'drawer scroll',
                  'scroll',
                  'pages',
                  'cube',
                  'swipe drawer',
                  'paged drawer',
                ],
                _Row(
                  icon: Icons.view_carousel_outlined,
                  accent: true,
                  title: 'Drawer scrolls',
                  subtitle: 'One long list, or paged',
                  // Inline segments, not a sheet: this is three options that
                  // change instantly and are worth trying against each other.
                  // Making someone open a sheet to compare them is the friction
                  // that stops anyone discovering the cube at all.
                  trailing: _Seg(
                    value: theme.prefs.drawerScrollStyle ?? 'vertical',
                    options: const {
                      'vertical': 'List',
                      'pages': 'Pages',
                      'cube': 'Cube',
                    },
                    onChanged: (v) => notifier.edit(
                      (p) => p.copyWith(drawerScrollStyle: v),
                    ),
                  ),
                ),
              ),
              _FilterRow(
                const [
                  'folders',
                  'folder',
                  'grouping',
                  'group apps',
                  'suggestions',
                  'games folder',
                ],
                _Row(
                  icon: Icons.folder_outlined,
                  accent: true,
                  title: 'Folders',
                  subtitle: 'Grid, shape, and suggested groups',
                  trailing: _ChipValue(
                    preview: DevicePreview(
                      palette: theme.palette,
                      mode: DevicePreviewMode.folder,
                      cols: theme.prefs.folderCols ?? 4,
                      rows: theme.prefs.folderRows ?? 3,
                    ),
                    chevron: true,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FoldersScreen(theme: theme),
                    ),
                  ),
                ),
              ),
              _FilterRow(
                const ['app drawer style', 'drawer style', 'activities grid'],
                _Row(
                  icon: Icons.view_agenda_outlined,
                  accent: true,
                  title: 'App drawer style',
                  trailing: const _Value('Activities grid'),
                  onTap: () =>
                      context.showMessage('More drawer styles are coming'),
                ),
              ),
              _FilterRow(
                const ['icon size', 'size', 'bigger', 'smaller'],
                _Row(
                  icon: Icons.photo_size_select_large_outlined,
                  accent: true,
                  title: 'Icon size',
                  trailing: _Value(_iconSizeLabel(theme.iconSizeDp)),
                  onTap: () => _showSliderSheet(
                    context,
                    title: 'Icon size',
                    value: theme.iconSizeDp,
                    min: 36,
                    max: 72,
                    format: (v) => '${v.round()} dp',
                    onCommit: (v) =>
                        notifier.edit((p) => p.copyWith(iconSizeDp: v)),
                  ),
                ),
              ),
              if (theme.icons.treatment.name == 'roundedSquare')
                _FilterRow(
                  const ['corner roundness', 'corners', 'rounded'],
                  _Row(
                    icon: Icons.rounded_corner_outlined,
                    accent: true,
                    title: 'Corner roundness',
                    trailing:
                        _Value('${(theme.icons.cornerRadius * 200).round()}%'),
                    onTap: () => _showSliderSheet(
                      context,
                      title: 'Corner roundness',
                      value: theme.icons.cornerRadius,
                      min: 0,
                      max: 0.5,
                      format: (v) => '${(v * 200).round()}%',
                      onCommit: (v) =>
                          notifier.edit((p) => p.copyWith(cornerRadius: v)),
                    ),
                  ),
                ),
              _FilterRow(
                const ['top bar', 'status bar', 'gnome bar'],
                _ToggleRow(
                  icon: Icons.web_asset_outlined,
                  accent: true,
                  title: 'Top bar',
                  value: theme.topBar,
                  onChanged: (v) => notifier.edit((p) => p.copyWith(topBar: v)),
                ),
              ),
            ],
          ),

          // ── Labels ─────────────────────────────────────────────────────
          _Group(
            label: 'Labels',
            query: q,
            rows: [
              _FilterRow(
                const ['wrap', 'app names', 'labels', 'truncate'],
                _ToggleRow(
                  icon: Icons.wrap_text,
                  title: 'Wrap long app names',
                  subtitle: 'Two lines instead of truncating',
                  value: theme.labelLines > 1,
                  onChanged: (v) =>
                      notifier.edit((p) => p.copyWith(labelLines: v ? 2 : 1)),
                ),
              ),
              _FilterRow(
                const ['text size', 'font size', 'labels'],
                _Row(
                  icon: Icons.format_size,
                  title: 'Text size',
                  trailing: _Value('${(theme.textScale * 100).round()}%'),
                  onTap: () => _showSliderSheet(
                    context,
                    title: 'Text size',
                    value: theme.textScale,
                    min: 0.8,
                    max: 1.4,
                    format: (v) => '${(v * 100).round()}%',
                    onCommit: (v) =>
                        notifier.edit((p) => p.copyWith(textScale: v)),
                  ),
                ),
              ),
            ],
          ),

          // ── Gestures ───────────────────────────────────────────────────
          const _GestureServiceCard(),
          _Group(
            label: 'Gestures',
            query: q,
            rows: [
              for (final g in Gesture.values)
                _FilterRow(
                  [g.label.toLowerCase(), 'gesture', 'swipe'],
                  _GestureRow(theme: theme, gesture: g),
                ),
            ],
          ),

          // ── System (hands off to Android) ──────────────────────────────
          _Group(
            label: 'System — opens Android settings',
            query: q,
            rows: [
              _FilterRow(
                const ['default launcher', 'home app', 'set default'],
                _Row(
                  icon: Icons.home_outlined,
                  title: 'Set as default launcher',
                  trailing: const _SysBadge(),
                  onTap: api.requestDefaultLauncher,
                ),
              ),
              _FilterRow(
                const ['notifications', 'access', 'permissions'],
                _Row(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications & access',
                  trailing: const _SysBadge(),
                  onTap: () => api.openAndroidSettings(
                    'android.settings.APP_NOTIFICATION_SETTINGS',
                  ),
                ),
              ),
            ],
          ),

          // ── Maintenance ────────────────────────────────────────────────
          _Group(
            label: 'Maintenance',
            query: q,
            rows: [
              _FilterRow(
                const ['rebuild icon cache', 'icons', 'stale', 'cache'],
                _Row(
                  icon: Icons.refresh,
                  title: 'Rebuild icon cache',
                  subtitle: 'If icons look wrong or stale',
                  trailing: const _Chevron(),
                  onTap: () async {
                    await api.clearIconCache();
                    if (context.mounted) {
                      context.showMessage('Icon cache cleared');
                    }
                  },
                ),
              ),
              _FilterRow(
                ['reset', 'defaults', theme.spec.name.toLowerCase()],
                _Row(
                  icon: Icons.settings_backup_restore,
                  title: 'Reset ${theme.spec.name} settings',
                  // Per-theme, per §5.3 — resetting Ubuntu must not touch KDE.
                  subtitle: 'Layout, icon shape and hidden apps',
                  trailing: const _Chevron(),
                  onTap: () => _confirmReset(context, notifier, theme),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The live desktop/drawer preview that heads the Layout group.
///
/// Two phones side by side rather than one: dock and drawer are different
/// surfaces, the settings below change both, and toggling between them would
/// hide whichever you were not looking at.
class _LayoutPreview extends StatelessWidget {
  const _LayoutPreview({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DevicePreview(
              palette: theme.palette,
              mode: DevicePreviewMode.desktop,
              dock: theme.dock,
              gridButton: theme.prefs.dockGridButton ?? 'end',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DevicePreview(
              palette: theme.palette,
              mode: DevicePreviewMode.drawer,
              cols: theme.drawerCols,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chrome resolver
// ─────────────────────────────────────────────────────────────────────────────

/// The framing that forks on [ChromeFamily] — the STRUCTURE of a group card, as
/// opposed to its colours. Adwaita is libadwaita's boxed-list look (rounded,
/// inset, plain header); Breeze is flatter and squarer with an upper-case
/// category header, like KDE System Settings; generic/aqua sit in between. This
/// is where the family split becomes visible on the settings page.
class _Framing {
  const _Framing({
    required this.cardRadius,
    required this.cardInset,
    required this.headerUpper,
  });

  /// Corner radius of the group card (and the search / banner cards).
  final double cardRadius;

  /// Horizontal margin around cards.
  final double cardInset;

  /// Upper-case the section label with tracking (Breeze category headers).
  final bool headerUpper;

  static _Framing forFamily(ChromeFamily f) => switch (f) {
        ChromeFamily.adwaita =>
          const _Framing(cardRadius: 16, cardInset: 16, headerUpper: false),
        ChromeFamily.breeze =>
          const _Framing(cardRadius: 6, cardInset: 12, headerUpper: true),
        ChromeFamily.aqua =>
          const _Framing(cardRadius: 12, cardInset: 16, headerUpper: false),
        ChromeFamily.generic =>
          const _Framing(cardRadius: 12, cardInset: 16, headerUpper: false),
      };
}

/// This screen's resolved skin: the colours it uses (mapped 1:1 from the derived
/// chrome) plus the family framing. Replaces the old fixed `_Ou` palette. Field
/// names are kept short and familiar so the widget bodies read the same; the
/// values now come from the active theme.
class _Skin {
  const _Skin({
    required this.bg,
    required this.card,
    required this.card2,
    required this.tx,
    required this.mut,
    required this.acc,
    required this.onAcc,
    required this.line,
    required this.warn,
    required this.framing,
  });

  final Color bg; // page background
  final Color card; // group / sheet surface
  final Color card2; // recessed chips (segment track, icon circle, step button)
  final Color tx; // primary text
  final Color mut; // muted text / icons
  final Color acc; // distro accent
  final Color onAcc; // ink on the accent (active segment text)
  final Color line; // hairline dividers
  final Color warn; // the vertical-swipe warning tint
  final _Framing framing;

  factory _Skin.fromData(ChromeData d) {
    final c = d.colors;
    return _Skin(
      bg: c.bg,
      card: c.surface,
      card2: c.surfaceAlt,
      tx: c.text,
      mut: c.textMuted,
      acc: c.accent,
      onAcc: c.onAccent,
      line: c.line,
      warn: c.warn,
      framing: _Framing.forFamily(d.family),
    );
  }

  /// Read the nearest chrome. Under a [ThemedScaffold] this is the live theme;
  /// outside one it is the bootstrap floor (never a crash).
  static _Skin of(BuildContext context) =>
      _Skin.fromData(ChromeScope.of(context));
}

// ─────────────────────────────────────────────────────────────────────────────
// Structure
// ─────────────────────────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Text(
        text,
        style: TextStyle(
          color: s.tx,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// A group label above a rounded card whose rows are divided by a hairline.
/// Empty groups render nothing — which is also how search hides a whole section.
/// The card is a [Material] so the rows' ink splashes have a surface to land on.
/// Radius, inset and header case fork on the theme's [ChromeFamily].
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows, this.query = ''});

  final String label;
  final List<_FilterRow> rows;

  /// Already trimmed; may be empty (no search active).
  final String query;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    final f = s.framing;
    final q = query.toLowerCase();
    // A matching group label reveals the whole section; otherwise filter row by
    // row. So "gestures" surfaces every gesture, and "wrap" surfaces one row.
    final labelHit = q.isEmpty || label.toLowerCase().contains(q);
    final visible = <Widget>[
      for (final r in rows)
        if (labelHit || r.matches(q)) r.child,
    ];
    if (visible.isEmpty) return const SizedBox.shrink();

    final divided = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      if (i > 0) {
        divided.add(Divider(height: 1, thickness: 1, color: s.line));
      }
      divided.add(visible[i]);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(f.cardInset, 0, f.cardInset, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(
              f.headerUpper ? label.toUpperCase() : label,
              style: TextStyle(
                color: s.mut,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: f.headerUpper ? 0.6 : 0,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(f.cardRadius),
            child: Material(
              color: s.card,
              child: Column(children: divided),
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings row plus the words that should surface it in search. [terms] must
/// be lowercase; [matches] receives an already-lowercased query.
class _FilterRow {
  const _FilterRow(this.terms, this.child);

  final List<String> terms;
  final Widget child;

  bool matches(String q) => q.isEmpty || terms.any((t) => t.contains(q));
}

/// The search field. Filters the settings live; the clear button appears only
/// once there's something to clear.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          s.framing.cardInset + 2, 0, s.framing.cardInset + 2, 18),
      child: Material(
        color: s.card,
        borderRadius: BorderRadius.circular(s.framing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: s.mut),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: TextStyle(color: s.tx, fontSize: 14),
                  cursorColor: s.acc,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: InputBorder.none,
                    hintText: 'Search settings',
                    hintStyle: TextStyle(color: s.mut, fontSize: 14),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: () {
                          controller.clear();
                          onChanged('');
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.close, size: 17, color: s.mut),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// icon circle · title (+ optional subtitle) · trailing control.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.subtitleTint,
    this.accent = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleTint;

  /// Tint the icon circle with the distro accent (was the `tint:` colour). A
  /// bool, not a Color, because the accent is resolved from the chrome inside
  /// [_IconCircle] — the row is built above the scope in the page build.
  final bool accent;

  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            _IconCircle(icon: icon, accent: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: s.tx,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          color: subtitleTint ?? s.mut,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// A row with a trailing toggle; the whole row flips it.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return _Row(
      icon: icon,
      accent: accent,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      // WidgetStateProperty, not the activeColor churn — the stable Material-3
      // surface. Track fills with the distro accent when on.
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStatePropertyAll(s.onAcc),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? s.acc : s.card2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, this.accent = false});

  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent ? s.acc.withValues(alpha: 0.16) : s.card2,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: accent ? s.acc : s.mut),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trailing controls
// ─────────────────────────────────────────────────────────────────────────────

class _Value extends StatelessWidget {
  const _Value(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: s.mut, fontSize: 12.5),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right, size: 18, color: s.mut),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return Icon(Icons.chevron_right, size: 18, color: s.mut);
  }
}

/// The `System` pill + external-link glyph for rows that leave the app.
class _SysBadge extends StatelessWidget {
  const _SysBadge();

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: s.acc.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            'System',
            style: TextStyle(
              color: s.acc,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.open_in_new, size: 15, color: s.mut),
      ],
    );
  }
}

/// A row's value as a PICTURE, with the text kept alongside it.
///
/// The chip is a real [DevicePreview] at 26x40 — the same renderer as the hero
/// previews and the setup backdrop, so a row can never disagree with the screen
/// it opens. Drawn from the live prefs, so it redraws the moment the setting
/// changes rather than the next time you visit.
///
/// The label stays. A picture at this size tells you the SHAPE of a setting
/// ("dock on the left", "a wide grid") and cannot tell you "5 x 4" — dropping
/// the number to make room for the graphic would trade precision for prettiness.
class _ChipValue extends StatelessWidget {
  const _ChipValue({
    required this.preview,
    this.label,
    this.chevron = false,
  });

  final Widget preview;
  final String? label;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(color: s.mut, fontSize: 12.5),
          ),
          const SizedBox(width: 10),
        ],
        SizedBox(width: 26, height: 40, child: preview),
        if (chevron) ...[
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 18, color: s.mut),
        ],
      ],
    );
  }
}

/// A pill track with one active segment (accent fill, ink text).
class _Seg extends StatelessWidget {
  const _Seg({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: s.card2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries)
            GestureDetector(
              onTap: () => onChanged(e.key),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: e.key == value
                    ? BoxDecoration(
                        color: s.acc,
                        borderRadius: BorderRadius.circular(7),
                      )
                    : null,
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        e.key == value ? FontWeight.w600 : FontWeight.w400,
                    color: e.key == value ? s.onAcc : s.mut,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gesture row (carries the vertical-swipe warning)
// ─────────────────────────────────────────────────────────────────────────────

class _GestureRow extends ConsumerWidget {
  const _GestureRow({required this.theme, required this.gesture});

  final EffectiveTheme theme;
  final Gesture gesture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _Skin.of(context);
    final binding = bindingFor(theme.prefs, gesture);
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    final label = binding.isApp ? 'Custom app' : binding.action.label;

    // Swipe up/down belong to the workspaces PageView. Binding them is allowed
    // (their phone, their fight) but must be flagged — the handoff calls for
    // exactly this one-line warning.
    final isVertical =
        gesture == Gesture.swipeUp || gesture == Gesture.swipeDown;
    final bound = binding.isApp || binding.action != GestureAction.none;
    final warn = isVertical && bound;

    return _Row(
      icon: Icons.gesture,
      title: gesture.label,
      subtitle: warn ? 'Overrides workspace scrolling' : null,
      subtitleTint: warn ? s.warn : null,
      trailing: _Value(label),
      onTap: () => _showGestureSheet(context, notifier, gesture),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets
// ─────────────────────────────────────────────────────────────────────────────

/// Show a themed modal sheet. A modal is pushed OUTSIDE this screen's
/// ChromeScope, so we capture the chrome here and re-provide it inside; without
/// that, the sheet would fall back to house chrome over a themed screen.
Future<T?> _sheet<T>(BuildContext context, Widget child) {
  final data = ChromeScope.of(context);
  final s = _Skin.fromData(data);
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: s.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ChromeScope(data: data, child: SafeArea(child: child)),
  );
}

Widget _sheetHead(BuildContext context, String title) {
  final s = _Skin.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: s.card2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: s.tx,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

void _showShapeSheet(
  BuildContext context,
  PrefsNotifier notifier,
  EffectiveTheme theme,
) {
  const shapes = <String, String>{
    '_theme': 'Theme default',
    'roundedSquare': 'Rounded square',
    'circle': 'Circle',
    'squircle': 'Squircle',
    'square': 'Square',
    'teardrop': 'Teardrop',
    'original': 'Original (unthemed)',
  };
  final current = theme.prefs.iconTreatment ?? '_theme';

  _sheet<void>(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, 'Icon shape'),
        for (final e in shapes.entries)
          _SheetOption(
            label: e.value,
            selected: e.key == current,
            onTap: () {
              notifier.edit(
                (p) => e.key == '_theme'
                    // copyWith can't null a field — that's what clearing is for.
                    ? p.clearing(iconTreatment: true, cornerRadius: true)
                    : p.copyWith(iconTreatment: e.key),
              );
              Navigator.pop(context);
            },
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

void _showGestureSheet(
  BuildContext context,
  PrefsNotifier notifier,
  Gesture gesture,
) {
  _sheet<void>(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetHead(context, gesture.label),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final a in GestureAction.values)
                _SheetOption(
                  label:
                      a.needsService ? '${a.label}  ·  needs access' : a.label,
                  onTap: () {
                    notifier.edit(
                      (p) => p.copyWith(
                        gestures: {...p.gestures, gesture.id: a.id},
                      ),
                    );
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

void _showGridSheet(
  BuildContext context,
  PrefsNotifier notifier,
  EffectiveTheme theme,
) {
  _sheet<void>(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHead(context, 'Desktop grid'),
            _StepRow(
              label: 'Rows',
              value: theme.rows,
              min: 3,
              max: 8,
              onChanged: (v) {
                notifier.edit((p) => p.copyWith(rows: v));
                setSheet(() {});
              },
            ),
            _StepRow(
              label: 'Columns',
              value: theme.cols,
              min: 3,
              max: 7,
              onChanged: (v) {
                notifier.edit((p) => p.copyWith(cols: v));
                setSheet(() {});
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    ),
  );
}

void _showStepperSheet(
  BuildContext context, {
  required String title,
  required int value,
  required int min,
  required int max,
  required ValueChanged<int> onChanged,
}) {
  _sheet<void>(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        var v = value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHead(context, title),
            _StepRow(
              label: title,
              value: v,
              min: min,
              max: max,
              onChanged: (next) {
                v = next;
                onChanged(next);
                setSheet(() {});
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    ),
  );
}

/// Slider sheet. Tracks the thumb at 60fps locally; commits ONLY on release —
/// every commit rewrites prefs and, for icons, invalidates the native cache, so
/// committing per drag-frame would re-render every icon dozens of times a second.
void _showSliderSheet(
  BuildContext context, {
  required String title,
  required double value,
  required double min,
  required double max,
  required String Function(double) format,
  required ValueChanged<double> onCommit,
}) {
  var live = value.clamp(min, max).toDouble();

  _sheet<void>(
    context,
    StatefulBuilder(
      builder: (context, setSheet) {
        final s = _Skin.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHead(context, title),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  format(live),
                  style: TextStyle(
                    color: s.acc,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: s.acc,
                  thumbColor: s.acc,
                  inactiveTrackColor: s.card2,
                  overlayColor: s.acc.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: live,
                  min: min,
                  max: max,
                  onChanged: (v) => setSheet(() => live = v),
                  onChangeEnd: onCommit,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? s.acc : s.tx,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: s.acc),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: s.tx, fontSize: 15),
            ),
          ),
          _StepButton(
            icon: Icons.remove,
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: s.tx,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    final enabled = onTap != null;
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: s.card2,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? s.tx : s.mut.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

Future<void> _confirmReset(
  BuildContext context,
  PrefsNotifier notifier,
  EffectiveTheme theme,
) async {
  // ThemedDialog captures + re-provides the chrome across the route boundary and
  // pops on the dialog's own context — the two things the old hand-rolled
  // AlertDialog got right only by luck of a single navigator.
  final ok = await ThemedDialog.confirm(
    context,
    title: 'Reset settings?',
    message:
        'Your ${theme.spec.name} layout, icon shape and hidden apps go back to '
        'the theme defaults. Other themes are untouched.',
    confirmLabel: 'Reset',
    cancelLabel: 'Cancel',
  );
  if (ok == true) notifier.resetAll();
}

// ─────────────────────────────────────────────────────────────────────────────
// The two stateful cards
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultLauncherBanner extends ConsumerWidget {
  const _DefaultLauncherBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(launcherHostApiProvider);
    final s = _Skin.of(context);

    return FutureBuilder<bool>(
      future: api.isDefaultLauncher(),
      builder: (context, snap) {
        // Absent while loading, and absent once we ARE the default — a banner
        // nagging about something already done teaches people to ignore banners.
        if (snap.data != false) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.fromLTRB(
              s.framing.cardInset, 0, s.framing.cardInset, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: s.acc.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(s.framing.cardRadius),
            border: Border.all(color: s.acc.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: s.acc),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'G Launcher is not your home app',
                      style: TextStyle(
                        color: s.tx,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gestures and the home button will not work',
                      style: TextStyle(color: s.mut, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ThemedButton(
                label: 'Set',
                onPressed: api.requestDefaultLauncher,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The accessibility opt-in. Blunt about what the permission does on purpose —
/// the system dialog is scary, and a vague explanation makes people refuse, or
/// worse, accept without understanding, which is not consent.
class _GestureServiceCard extends ConsumerWidget {
  const _GestureServiceCard();

  /// The full explanation, kept OUT of the card.
  ///
  /// It is genuinely worth reading — the accessibility prompt says G Launcher
  /// can "observe your actions", and someone who reads that without context is
  /// right to refuse. But a five-line disclaimer sitting permanently above the
  /// gesture list taxes everyone forever to reassure the few who ask. So the
  /// card states the offer in one line and the reasoning goes one tap away.
  static const _explainer =
      'Android only lets a launcher pull down the shade, open quick settings, '
      'show recents or lock the screen through an accessibility service.\n\n'
      'The next screen warns that G Launcher can "observe your actions". That '
      'is the standard wording for every app that uses this API.\n\n'
      'G Launcher does not read your screen and does not watch other apps. It '
      'asks only for the ability to perform the gestures you set here.\n\n'
      'Gestures that do not need it — Activities, launching an app, showing '
      'the dock — work either way.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(launcherHostApiProvider);
    final s = _Skin.of(context);

    return FutureBuilder<bool>(
      future: api.isGestureServiceEnabled(),
      builder: (context, snap) {
        if (snap.data == true) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.fromLTRB(
            s.framing.cardInset,
            0,
            s.framing.cardInset,
            16,
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: s.card,
            borderRadius: BorderRadius.circular(s.framing.cardRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shade, quick settings, recents and lock',
                      style: TextStyle(
                        color: s.tx,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Needs an accessibility service',
                      style: TextStyle(color: s.mut, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    ThemedButton(
                      label: 'Turn it on',
                      onPressed: api.openAccessibilitySettings,
                    ),
                  ],
                ),
              ),
              const _InfoButton(
                title: 'Why an accessibility service?',
                body: _explainer,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small (i) that opens its explanation in a themed sheet.
///
/// The pattern for anything needing more than a line of justification: the row
/// stays scannable, and the reasoning is there for whoever wants it instead of
/// being read past by everyone who does not.
class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);

    return IconButton(
      icon: Icon(Icons.info_outline, size: 20, color: s.mut),
      tooltip: title,
      onPressed: () => ThemedSheet.show<void>(
        context,
        title: title,
        isScrollControlled: true,
        builder: (sheet) {
          final d = ChromeScope.of(sheet);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Text(
              body,
              style: d.text.body.copyWith(
                color: d.colors.textMuted,
                height: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Label helpers
// ─────────────────────────────────────────────────────────────────────────────

String _shapeLong(String? raw) => switch (raw) {
      null => 'Following the theme',
      'roundedSquare' => 'Rounded square',
      'circle' => 'Circle',
      'squircle' => 'Squircle',
      'square' => 'Square',
      'teardrop' => 'Teardrop',
      'original' => 'Original, unthemed',
      _ => raw,
    };

String _shapeShort(String? raw) => switch (raw) {
      null => 'Theme',
      'roundedSquare' => 'Rounded',
      'circle' => 'Circle',
      'squircle' => 'Squircle',
      'square' => 'Square',
      'teardrop' => 'Teardrop',
      'original' => 'Original',
      _ => raw,
    };

String _iconSizeLabel(double dp) => switch (dp) {
      < 44 => 'Small',
      < 54 => 'Medium',
      < 64 => 'Large',
      _ => 'Huge',
    };
