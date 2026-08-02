import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../design/device_preview.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart' show ChromeFamily;
import '../../system/notification_badges.dart';
import '../../system/system_stats.dart';
import '../gestures/gesture_actions.dart';
import 'backup_screen.dart';
import 'restore_screen.dart';
import '../home/workspaces/workspace_controller.dart';
import '../icons/icon_theme_screen.dart';
import '../themes/themes_screen.dart';
import 'device_pages.dart';
import 'folders_screen.dart';
import 'language_settings.dart';
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
        // hasValue, not asData: asData is null while a provider RELOADS, not
        // only while it first loads, and effectiveThemeProvider reloads on
        // every prefs write because it awaits prefsProvider(id).future. With
        // asData, every toggle on this page dropped back to the push-time
        // snapshot for a frame and then forward again. See home_screen.dart.
        ref.watch(effectiveThemeProvider).hasValue
            ? ref.watch(effectiveThemeProvider).requireValue
            : widget.theme;
    ref.read(prefsProvider(theme.spec.id).notifier);
    ref.read(launcherHostApiProvider);
    final workspaces = ref.watch(workspaceCountProvider);
    final q = _query.trim();

    // Read once, here, and handed down. Watching the stream inside each row
    // would give one ticker four subscribers for one value each.
    final devices = ref.watch(deviceCategoriesProvider);
    final stats = ref.watch(systemStatsProvider).asData?.value;

    // ThemedScaffold paints the background from the derived chrome and installs
    // the ChromeScope every widget below reads. No app bar: the large title
    // lives in the list, so we pass no title and keep the top status-bar inset.
    // ── WHY THIS NOW PASSES A TITLE ─────────────────────────────────────
    //
    // It passed `body:` only, so ThemedScaffold built NO app bar and the page
    // wore a large left-aligned `_Title` inside the list instead. That is an
    // iOS large-title pattern, and it is why the centred Adwaita header bar
    // added to ThemedScaffold changed the section pages and left this one
    // looking exactly as before: there was no bar here to restyle.
    //
    // The scaffold's own inset handling comes with the bar, so the manual
    // viewPadding on the list goes with the title.
    return ThemedScaffold(
      title: context.t('settings.settings'),
      // ─── NO BACK ARROW: THIS IS A ROOT, NOT A STEP ──────────────────────
      //
      // Settings is reached from the drawer and from the desktop menu, both of
      // which are dismissed rather than navigated away from, so there is
      // nothing behind it to go back TO. Flutter offers the arrow because a
      // route exists underneath; that route is the home screen, which the
      // system back gesture already returns to.
      //
      // The section pages keep theirs: those genuinely are a step deeper and
      // the arrow means what it says.
      automaticallyImplyLeading: false,
      // ─── NO BACK ARROW: THIS IS A ROOT, NOT A STEP ──────────────────────
      //
      // Settings is reached from the drawer and from the desktop menu, both of
      // which are dismissed rather than navigated away from, so there is
      // nothing behind it to go back TO. Flutter offers the arrow because a
      // route exists underneath; that route is the home screen, which the
      // system back gesture already returns to.
      //
      // The section pages below keep theirs: those genuinely are a step deeper
      // and the arrow means what it says.
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        children: [
          _SearchField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
          ),

          const _DefaultLauncherBanner(),

          // ── LANDING, OR A FLAT FILTERED LIST ──────────────────────────
          //
          // The screen was one list of about twenty rows across six groups.
          // Long enough that nobody scrolled it, and with no room for the
          // per-setting previews.
          //
          // SEARCH IS WHY THIS IS A BRANCH AND NOT A ROUTER. With a query
          // typed, every section is mounted flat and `_Group` filters them
          // exactly as before, so a search still reaches a row three taps
          // deep. Hiding rows behind sub-pages WITHOUT this would have made
          // the search box quietly less useful, which is the usual price of
          // splitting a settings screen and the one worth not paying.
          if (q.isNotEmpty) ...[
            ..._appearanceSection(context, ref, theme, workspaces, q),
            ..._desktopSection(context, ref, theme, workspaces, q),
            ..._applicationsSection(context, ref, theme, workspaces, q),
            ..._gesturesSection(context, ref, theme, workspaces, q),
            ..._systemSection(context, ref, theme, workspaces, q),
          ] else ...[
            // ── THE DISTRO ────────────────────────────────────────────────
            //
            // Its own group, above everything. It is the setting that changes
            // every other setting on this screen, and grouping it with
            // wallpaper and icons undersells it. The label carries the version,
            // so the header doubles as the answer to "which Ubuntu is this".
            _Group(
              label: theme.spec.version.isEmpty
                  ? theme.spec.name
                  : '${theme.spec.name} ${theme.spec.version}',
              rows: [
                _FilterRow(
                  const ['distro', 'theme', 'desktop', 'switch'],
                  _Row(
                    icon: Icons.desktop_windows_outlined,
                    accent: true,
                    title: context.t('settings.changeDesktop'),
                    subtitle: context.t('settings.settingsBelowAreStored'),
                    trailing: const _Chevron(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ThemesScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── DEVICE ────────────────────────────────────────────────────
            //
            // Built from `deviceCategoriesProvider`, so a phone that will not
            // report a figure has no row for it. Bluetooth, Notifications,
            // Sound and Privacy are absent entirely: there is nothing
            // permission-free to read for any of them, and a category that can
            // only link out is a link, not a settings page.
            //
            // Each row carries its own VALUE, and that is what stops this
            // reading as a menu. "Wi-Fi", "72%", "42G free" are readable
            // without tapping anything, the way a desktop settings sidebar is.
            if (devices.isNotEmpty)
              _Group(
                label: context.t('settings.device'),
                rows: [
                  for (final d in devices)
                    _FilterRow(
                      [d.label.toLowerCase(), ...d.keywords],
                      _Row(
                        icon: d.icon,
                        accent: true,
                        title: d.label,
                        trailing: _ValueChevron(text: d.valueFor(stats)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => d.page),
                        ),
                      ),
                    ),
                ],
              ),

            _Group(
              label: context.t('setup.step.distro'),
              rows: [
                _FilterRow(
                  const ['appearance', 'wallpaper', 'icons', 'boot', 'labels'],
                  _Row(
                    icon: Icons.palette_outlined,
                    accent: true,
                    title: context.t('settings.appearance'),
                    trailing: const _Chevron(),
                    onTap: () => _openSection(
                      context,
                      'Appearance',
                      _appearanceSection,
                    ),
                  ),
                ),
                _FilterRow(
                  const ['dock', 'grid', 'workspaces', 'widgets', 'desktop'],
                  _Row(
                    icon: Icons.layers_outlined,
                    accent: true,
                    title: context.t('settings.desktopAndDock'),
                    trailing: const _Chevron(),
                    onTap: () => _openSection(
                      context,
                      'Desktop and dock',
                      _desktopSection,
                    ),
                  ),
                ),
                _FilterRow(
                  const ['apps', 'drawer', 'folders', 'search', 'columns'],
                  _Row(
                    icon: Icons.apps_outlined,
                    accent: true,
                    title: context.t('settings.applications'),
                    trailing: const _Chevron(),
                    onTap: () => _openSection(
                      context,
                      'Applications',
                      _applicationsSection,
                    ),
                  ),
                ),
                _FilterRow(
                  const ['gestures', 'swipe', 'accessibility'],
                  _Row(
                    icon: Icons.gesture_outlined,
                    accent: true,
                    title: context.t('settings.gestures'),
                    trailing: const _Chevron(),
                    onTap: () =>
                        _openSection(context, 'Gestures', _gesturesSection),
                  ),
                ),
              ],
            ),

            // ── LANGUAGE ──────────────────────────────────────────────────
            // Global, not per-distro: language is a property of the user, not
            // the skin. Its own group rather than a row under System, because
            // "System" here means Android settings and reset.
            _Group(
              label: ref.t('settings.language.title'),
              rows: [
                _FilterRow(
                  const ['language', 'idioma', 'locale', 'translate', 'lugha'],
                  _Row(
                    icon: Icons.language_outlined,
                    accent: true,
                    title: ref.t('settings.language.title'),
                    subtitle:
                        ref.watch(i18nProvider).selectedLocale?.nativeName ??
                            ref.t('settings.language.system'),
                    trailing: const _Chevron(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LanguageSettingsPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            _Group(
              label: context.t('settings.system'),
              rows: [
                _FilterRow(
                  const ['system', 'android', 'reset', 'about', 'default'],
                  _Row(
                    icon: Icons.info_outline,
                    accent: true,
                    title: context.t('settings.system'),
                    subtitle: context.t('settings.androidSettingsMaintenanceReset'),
                    trailing: const _Chevron(),
                    onTap: () =>
                        _openSection(context, 'System', _systemSection),
                  ),
                ),
              ],
            ),
          ],
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

// `_Title` LIVED HERE and is gone. It was a 28px, w700, left-aligned page
// heading rendered as the first item of the list: the iOS large-title pattern,
// and the loudest of the three things making this screen read as a phone app
// wearing Ubuntu's orange. The landing page now passes a title to
// ThemedScaffold and gets the same flat centred header bar every other chrome
// screen already had.

/// A group label above a rounded card whose rows are divided by a hairline.
/// Empty groups render nothing — which is also how search hides a whole section.
/// The card is a [Material] so the rows' ink splashes have a surface to land on.
/// Radius, inset and header case fork on the theme's [ChromeFamily].
class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.rows,
    this.query = '',
    this.onReset,
  });

  final String label;
  final List<_FilterRow> rows;

  /// Restore this group's settings, or null for no affordance.
  ///
  /// ─── CURRENTLY ALWAYS NULL, AND KEPT ON PURPOSE ─────────────────────────
  ///
  /// Six groups passed this until `RestoreScreen` arrived. Two surfaces for
  /// one feature is worse than either alone, especially with DIFFERENT section
  /// boundaries: this screen groups the bar with the icons, that one groups it
  /// with the desktop, and a user who reset "Icons and bar" here and "Icons"
  /// there would get two different results from the same word. The dedicated
  /// page won because it can say "settings only, nothing you made is removed"
  /// once, at the top, where it is read.
  ///
  /// The parameter stays because the header slot is the right home if a group
  /// ever wants a local action, and because deleting it would take the layout
  /// with it for no gain. It renders nothing while null.
  final VoidCallback? onReset;

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
            child: Row(
              children: [
                Expanded(
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
                if (onReset != null)
                  GestureDetector(
                    onTap: onReset,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      // Padding rather than a bare Text: the tap target has to
                      // be reachable with a thumb, and the glyph is small.
                      padding: const EdgeInsets.fromLTRB(10, 2, 2, 4),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: ChromeScope.of(context).colors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
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
            // ── ICONS ON THE LANDING PAGE, NONE INSIDE A SECTION ──────
            //
            // GNOME puts icons in the settings SIDEBAR and almost never on the
            // rows within a page. An accent circle on every row is an iOS and
            // One UI convention, and together with the large title it was the
            // main reason this chrome read as a phone app wearing Ubuntu's
            // orange rather than as a desktop settings app.
            //
            // A scope rather than a parameter, deliberately: the rows were
            // sliced verbatim out of the old build method and all 30 of them
            // pass `icon:`. Threading a flag through every one would have meant
            // editing all 30, which is exactly the retyping this refactor kept
            // avoiding. `_SectionPage` sets it false for its whole subtree and
            // nothing else has to know.
            if (_RowIcons.of(context)) ...[
              _IconCircle(icon: icon, accent: accent),
              const SizedBox(width: 14),
            ],
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
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// DIMMED AND INERT, NOT ABSENT.
  ///
  /// A setting that only applies in some other mode ("Group A to Z" needs the
  /// list layout) is shown greyed with the reason in its own subtitle rather
  /// than hidden. Hiding it means someone who has read about the feature
  /// concludes it does not exist in this build; greying it teaches the rule at
  /// a glance and says where to go for it.
  ///
  /// Both the row tap AND the switch have to go inert. Killing only one leaves
  /// a control that half-works, which is worse than either.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    final row = _Row(
      icon: icon,
      accent: accent,
      title: title,
      subtitle: subtitle,
      onTap: enabled ? () => onChanged(!value) : null,
      // WidgetStateProperty, not the activeColor churn — the stable Material-3
      // surface. Track fills with the distro accent when on.
      trailing: Switch(
        value: value,
        // Null disables it. Material greys the thumb and track itself, so the
        // colours below still apply in the enabled case only.
        onChanged: enabled ? onChanged : null,
        thumbColor: WidgetStatePropertyAll(s.onAcc),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? s.acc : s.card2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );

    // One Opacity over the whole row, so the label, the subtitle, the icon
    // circle and the switch all fade together. Dimming only the switch would
    // read as a rendering glitch rather than as a disabled setting.
    return enabled ? row : Opacity(opacity: 0.45, child: row);
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
    final binding = bindingFor(theme, gesture);
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
    '_theme': 'Distro default',
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
              label: context.t('settings.rows'),
              value: theme.rows,
              min: 3,
              max: 8,
              onChanged: (v) {
                notifier.edit((p) => p.copyWith(rows: v));
                setSheet(() {});
              },
            ),
            _StepRow(
              label: context.t('settings.columns'),
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
  // ─── THE COPY USED TO OVERSTATE WHAT THIS DID ─────────────────────────
  //
  // It promised icon shape would go back to the distro default and called
  // `resetAll`, which clears one theme's file. Icon shape is a PROMOTED
  // field, so it lived in the global bucket and was re-applied the instant
  // the provider rebuilt. `resetEverything` clears both, which is what this
  // message has always described.
  //
  // And it said "hidden apps", which is content. A reset does not un-hide
  // apps; the drawer's own screen does that.
  final ok = await ThemedDialog.confirm(
    context,
    title: context.t('settings.resetSettings'),
    message:
        'Every setting for ${theme.spec.name}, and the settings shared by all '
        'distros, go back to their defaults. Other distros keep their own '
        'layouts. Nothing you made is removed: your folders, pinned apps, '
        'hidden apps, widgets and photos are untouched.',
    confirmLabel: context.t('settings.reset'),
    cancelLabel: context.t('common.cancel'),
  );
  if (ok == true) notifier.resetEverything();
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
                label: context.t('settings.set'),
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
      'Android only lets a launcher pull down the shade, open quick settings, show recents or lock the screen through an accessibility service.\n\nThe next screen warns that G Launcher can "observe your actions". That is the standard wording for every app that uses this API.\n\nG Launcher does not read your screen and does not watch other apps. It asks only for the ability to perform the gestures you set here.\n\nGestures that do not need it, such as Activities, launching an app or showing the dock, work either way.';

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
                      label: context.t('settings.turnItOn'),
                      onPressed: api.openAccessibilitySettings,
                    ),
                  ],
                ),
              ),
              _InfoButton(
                title: context.t('settings.whyAnAccessibilityService'),
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

/// The Icons row's subtitle: which SOURCE is on top right now.
///
/// Reads the two prefs and nothing async, because a settings row that waits on
/// a package-manager call renders blank on first paint and then pops. The
/// screen behind it does the resolving.
///
/// ORDER MATTERS AND MIRRORS THE RENDERER. A third-party pack layers ABOVE the
/// icon theme, so when both are set the installed pack is what the user is
/// mostly looking at, and that is what this names.
String _iconsLong(EffectiveTheme theme) {
  if (theme.prefs.systemIconPack != null) {
    return 'An installed pack, over the distro icons';
  }
  final hero = theme.prefs.iconPackId;
  if (hero != null) return 'The $hero icon theme';
  return "The distro's own icons";
}

String _iconsShort(EffectiveTheme theme) {
  if (theme.prefs.systemIconPack != null) return 'Custom';
  return theme.prefs.iconPackId ?? 'Distro';
}

String _shapeLong(String? raw) => switch (raw) {
      null => 'Following the distro',
      'roundedSquare' => 'Rounded square',
      'circle' => 'Circle',
      'squircle' => 'Squircle',
      'square' => 'Square',
      'teardrop' => 'Teardrop',
      'original' => 'Original, unthemed',
      _ => raw,
    };

String _shapeShort(String? raw) => switch (raw) {
      null => 'Distro',
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

/// Appearance: the distro, its artwork, and how text reads.
///
/// Sliced VERBATIM out of the old single build method. The rows, their
/// `_FilterRow` keywords and their order are byte-identical to what shipped;
/// only where they are mounted changed. That was the whole risk in this
/// refactor: a row that loses its keywords stops being findable by search and
/// nothing fails, so nothing here was retyped.
List<Widget> _appearanceSection(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  int workspaces,
  String q,
) {
  // Derived here rather than passed, so the signature never has to name the
  // Pigeon host API type, which this file does not import.
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  ref.read(launcherHostApiProvider);

  final mode = theme.prefs.themeMode ?? 'system';
  final hasLight = theme.spec.paletteLight != null;

  return [
    // ── Light and dark ─────────────────────────────────────────────
    //
    // First in the section because it is the coarsest appearance decision
    // there is, and because it is the one setting here that applies to EVERY
    // distro rather than the one on screen. It writes the same global value
    // the setup wizard's Appearance step does; see GlobalPrefs.themeMode.
    // ─── SURFACES ──────────────────────────────────────────────────
    //
    // The main slider governs EVERYTHING, and the three below it split out one
    // section each from that number.
    //
    // The old reasoning here was that a per-page version would mean a settings
    // page and a sheet over it disagreeing about how solid they are, which
    // reads as a rendering fault. That still holds, and it is why the split
    // stops where it does: only the three PERMANENT chrome surfaces get their
    // own control. Sheets, dialogs and menus are transient and stay on this
    // slider, so nothing that stacks over something else can disagree with it.
    //
    // ─── AND THE THREE LIVE WITH THEIR SECTIONS, NOT HERE ──────────────
    //
    // Dock opacity sits under Layout beside the dock's position, drawer
    // opacity under App drawer, bar opacity under Icons and bar beside the
    // top-bar switch. Someone adjusting the dock is already on the dock's
    // rows; making them come here instead means the one screen that knows
    // what a dock is has nothing to say about how solid it looks. This slider
    // remains the one that governs everything, and each section follows it
    // until moved.
    _Group(
      label: context.t('settings.surfaces'),
      query: q,
      rows: [
        _FilterRow(
          const ['opacity', 'transparency', 'surface', 'glass', 'wallpaper'],
          _OpacityRow(
            value: theme.surfaceOpacity,
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(surfaceOpacity: v)),
          ),
        ),
      ],
    ),

    // ─── PANELS ────────────────────────────────────────────────────────
    //
    // Directly under the main opacity slider, because the first row here is
    // the same material question one level down: that slider governs pages,
    // these govern the things that float over them.
    //
    // The PREVIEW is the reason this group is worth having rather than four
    // loose rows. Blur, tint and corner radius are the three settings in the
    // app whose effect is impossible to describe in a subtitle and obvious the
    // instant you see it, and the surface they change is one that only appears
    // when you are no longer looking at this screen.
    _Group(
      label: 'Panels',
      query: q,
      rows: [
        _FilterRow(
          const ['panel', 'sheet', 'dialog', 'menu', 'preview', 'glass'],
          _PanelPreview(theme: theme),
        ),
        _FilterRow(
          const ['panel', 'sheet', 'opacity', 'transparency', 'glass'],
          _OpacityRow(
            label: 'Panel opacity',
            sub: 'Sheets, dialogs and menus',
            value: theme.panelOpacity,
            following: theme.prefs.panelOpacity == null,
            onChanged: (v) => notifier.edit((p) => p.copyWith(panelOpacity: v)),
            onFollow: () =>
                notifier.edit((p) => p.clearing(panelOpacity: true)),
          ),
        ),
        _FilterRow(
          const ['blur', 'panel', 'glass', 'frosted', 'performance', 'lag'],
          _PanelSlider(
            icon: Icons.blur_on,
            label: 'Blur',
            // The honest reason this is exposed, said plainly. Someone whose
            // launcher stutters is not going to guess that the frosted glass
            // is what costs them the frames.
            sub: 'Turn it down if the launcher feels slow',
            value: theme.panelBlur,
            min: 0,
            max: 24,
            divisions: 12,
            format: (v) => v <= 0 ? 'Off' : v.round().toString(),
            onChanged: (v) => notifier.edit((p) => p.copyWith(panelBlur: v)),
          ),
        ),
        _FilterRow(
          const ['tint', 'colour', 'color', 'panel', 'distro'],
          _PanelSlider(
            icon: Icons.palette_outlined,
            label: 'Tint',
            sub: 'How much distro colour the glass carries',
            value: theme.panelTint,
            min: 0,
            max: 1,
            divisions: 10,
            format: (v) => '${(v * 100).round()}%',
            onChanged: (v) => notifier.edit((p) => p.copyWith(panelTint: v)),
          ),
        ),
        _FilterRow(
          const ['corner', 'radius', 'rounded', 'panel', 'shape'],
          _PanelSlider(
            icon: Icons.rounded_corner_outlined,
            label: 'Corners',
            sub: 'Shared by every panel, so none of them disagree',
            value: theme.panelRadius,
            min: 0,
            max: 28,
            divisions: 14,
            format: (v) => '${v.round()}',
            onChanged: (v) => notifier.edit((p) => p.copyWith(panelRadius: v)),
          ),
        ),
      ],
    ),

    // ─── NOTIFICATION BADGES ───────────────────────────────────────────
    //
    // Its own group rather than a row under Icons, because the first thing in
    // it is a PERMISSION and permissions deserve to be asked for somewhere the
    // user can read a sentence about what they are granting. Android's own
    // dialog is going to tell them this app can read every notification on the
    // phone, which is true of the API and not true of what we do with it, and
    // the only place to say so is here.
    _Group(
      label: 'Notification badges',
      query: q,
      rows: [
        const _FilterRow(
          ['badge', 'notification', 'unread', 'dot', 'count', 'permission'],
          _BadgeAccessRow(),
        ),
        _FilterRow(
          const ['badge', 'notification', 'dot', 'count', 'unread', 'style'],
          _BadgeStyleRow(
            theme: theme,
            onPick: (v) => v == null
                ? notifier.edit((p) => p.clearing(badgeStyle: true))
                : notifier.edit((p) => p.copyWith(badgeStyle: v)),
          ),
        ),
      ],
    ),

    _Group(
      label: context.t('settings.lightAndDark'),
      query: q,
      rows: [
        for (final e in const [
          ('system', 'Match the system', 'Follows the phone\'s own switch'),
          ('light', 'Always light', null),
          ('dark', 'Always dark', null),
        ])
          _FilterRow(
            const ['light', 'dark', 'theme mode', 'appearance', 'night'],
            _Row(
              icon: mode == e.$1
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              title: e.$2,
              subtitle: e.$3,
              // `trailing` is required on _Row, and the radio lives in the icon
              // slot here, so this stays empty rather than carrying a second
              // marker for the same piece of state.
              trailing: const SizedBox.shrink(),
              onTap: () => notifier.edit((p) => p.copyWith(themeMode: e.$1)),
            ),
          ),
        if (!hasLight)
          _FilterRow(
            const ['light', 'dark'],
            _Row(
              icon: Icons.info_outline,
              title: context.t('settings.distroDarkOnly', {'name': theme.spec.name}),
              subtitle: context.t('settings.appliesToBoth'),
              trailing: const SizedBox.shrink(),
            ),
          ),
      ],
    ),

    // ── Personalize ────────────────────────────────────────────────
    _Group(
      label: context.t('settings.personalize'),
      query: q,
      rows: [
        _FilterRow(
          const ['theme', 'distro', 'desktop look', 'appearance'],
          _Row(
            icon: Icons.palette_outlined,
            accent: true, // leads with the distro accent
            title: context.t('settings.distro'),
            subtitle: context.t('settings.theWholeDesktopLook'),
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
            title: context.t('settings.iconShape'),
            subtitle: _shapeLong(theme.prefs.iconTreatment),
            trailing: _Value(_shapeShort(theme.prefs.iconTreatment)),
            onTap: () => _showShapeSheet(context, notifier, theme),
          ),
        ),
        _FilterRow(
          // 'icon pack' kept as a search term even though the row is now called
          // Icons: it is what Play, Nova and Icon Pack Studio all call the
          // thing, so it is what someone will type.
          const ['icons', 'icon pack', 'icon theme', 'adaptive', 'yaru', 'nova'],
          _Row(
            icon: Icons.grid_view_outlined,
            // "Icons", because in Linux an icon set is an icon THEME and the
            // distro is the other thing on this screen. The old title said
            // "Icon pack", which is what an APK from Play is — one of the two
            // sources the page now shows, not the whole subject.
            title: context.t('settings.icons'),
            // ─── THIS ROW WAS TAP-INERT AND SAID SO ────────────────────────
            //
            // It read "Adaptive — every app covered" with no onTap, and its
            // comment said it would grow a picker "when downloadable hero packs
            // ship". They ship now, and `IconPackPage` — a picker for the
            // third-party half — had been sitting in the tree the whole time
            // with nothing importing it.
            //
            // Both halves now live in `IconThemeScreen`, because they are not
            // alternatives: a Nova pack covers what it has art for and the
            // distro's icon theme fills the rest. See the file's header.
            subtitle: _iconsLong(theme),
            trailing: _Value(_iconsShort(theme)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const IconThemeScreen()),
            ),
          ),
        ),
        _FilterRow(
          const ['wallpaper', 'background', 'photo', 'rotation'],
          _Row(
            icon: Icons.image_outlined,
            title: context.t('settings.wallpaper'),
            subtitle: context.t('settings.presetsYourPhotosRotation'),
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
            title: context.t('settings.verboseBoot'),
            // Off = the quick splash. On = the full [  OK  ] scroll every
            // time the shell opens, themed to this distro.
            subtitle: context.t('settings.playTheFullLinux'),
            // null = off; the toggle reads and writes an explicit bool.
            value: theme.prefs.verboseBoot ?? false,
            onChanged: (v) => notifier.edit((p) => p.copyWith(verboseBoot: v)),
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
    // ── Labels ─────────────────────────────────────────────────────
    _Group(
      label: context.t('settings.iconsAndBar'),
      query: q,
      rows: [
        _FilterRow(
          const ['icon size', 'size', 'bigger', 'smaller'],
          _Row(
            icon: Icons.photo_size_select_large_outlined,
            accent: true,
            title: context.t('settings.iconSize'),
            trailing: _Value(_iconSizeLabel(theme.iconSizeDp)),
            onTap: () => _showSliderSheet(
              context,
              title: context.t('settings.iconSize'),
              value: theme.iconSizeDp,
              min: 36,
              max: 72,
              format: (v) => '${v.round()} dp',
              onCommit: (v) => notifier.edit((p) => p.copyWith(iconSizeDp: v)),
            ),
          ),
        ),
        if (theme.icons.treatment.name == 'roundedSquare')
          _FilterRow(
            const ['corner roundness', 'corners', 'rounded'],
            _Row(
              icon: Icons.rounded_corner_outlined,
              accent: true,
              title: context.t('settings.cornerRoundness'),
              trailing: _Value('${(theme.icons.cornerRadius * 200).round()}%'),
              onTap: () => _showSliderSheet(
                context,
                title: context.t('settings.cornerRoundness'),
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
            title: context.t('settings.topBar'),
            value: theme.topBar,
            onChanged: (v) => notifier.edit((p) => p.copyWith(topBar: v)),
          ),
        ),
        // Directly under the switch that turns the bar on, which is where
        // someone deciding how the bar should look already is.
        _FilterRow(
          const ['opacity', 'bar', 'panel', 'transparency', 'top'],
          _OpacityRow(
            label: 'Top bar opacity',
            sub: 'Panels and menu bars. This distro paints no bar fill',
            subWhenInert: true,
            value: theme.barOpacity,
            following: theme.prefs.barOpacity == null,
            onChanged: (v) => notifier.edit((p) => p.copyWith(barOpacity: v)),
            onFollow: () => notifier.edit((p) => p.clearing(barOpacity: true)),
          ),
        ),
      ],
    ),
    _Group(
      label: context.t('settings.labels'),
      query: q,
      rows: [
        _FilterRow(
          const ['wrap', 'app names', 'labels', 'truncate'],
          _ToggleRow(
            icon: Icons.wrap_text,
            title: context.t('settings.wrapLongAppNames'),
            // Reversed default. One line is now the default, because two
            // costs a whole ROW of grid height on every page to
            // accommodate the one app in twenty whose name wraps: on a
            // 412dp phone a paged drawer fits six rows at one line and
            // five at two. The setting stays for the people who would
            // rather read "Secure Folder" than "Secure Fold…".
            subtitle: context.t('settings.twoLinesInsteadOf'),
            value: theme.labelLines > 1,
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(labelLines: v ? 2 : 1)),
          ),
        ),
        _FilterRow(
          const ['text size', 'font size', 'labels'],
          _Row(
            icon: Icons.format_size,
            title: context.t('settings.textSize'),
            trailing: _Value('${(theme.textScale * 100).round()}%'),
            onTap: () => _showSliderSheet(
              context,
              title: context.t('settings.textSize'),
              value: theme.textScale,
              min: 0.8,
              max: 1.4,
              format: (v) => '${(v * 100).round()}%',
              onCommit: (v) => notifier.edit((p) => p.copyWith(textScale: v)),
            ),
          ),
        ),
      ],
    ),
  ];
}

/// Desktop and drawer: dock, grid, workspaces, drawer layout.
///
/// Sliced VERBATIM out of the old single build method. The rows, their
/// `_FilterRow` keywords and their order are byte-identical to what shipped;
/// only where they are mounted changed. That was the whole risk in this
/// refactor: a row that loses its keywords stops being findable by search and
/// nothing fails, so nothing here was retyped.
/// Desktop and dock: where things sit, not what they look like.
/// Sliced VERBATIM out of the old Layout group. Every `_FilterRow`, its
/// keywords and its order are untouched; only which group they sit in
/// changed. A row that loses its keywords stops being findable by search
/// and nothing fails, so nothing here was retyped.
List<Widget> _desktopSection(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  int workspaces,
  String q,
) {
  // Derived here rather than passed, so the signature never has to name the
  // Pigeon host API type, which this file does not import.
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  ref.read(launcherHostApiProvider);

  return [
    if (q.isEmpty) _LayoutPreview(theme: theme),

    // ── Layout ─────────────────────────────────────────────────────
    _Group(
      label: context.t('settings.layout'),
      query: q,
      rows: [
        _FilterRow(
          const ['dock', 'dock position', 'left', 'bottom'],
          _Row(
            icon: Icons.dashboard_outlined,
            accent: true,
            title: context.t('settings.dockPosition'),
            trailing: _Seg(
              // theme.dock is already the effective value (pref or default).
              value: theme.dock.name,
              options: const {
                'left': 'Left',
                'bottom': 'Bottom',
                'off': 'Off',
              },
              onChanged: (v) => notifier.edit((p) => p.copyWith(dockSide: v)),
            ),
          ),
        ),
        // Beside the dock's position, because it is the dock's own look. The
        // main slider under Surfaces still governs it until this is moved.
        _FilterRow(
          const ['opacity', 'dock', 'transparency', 'panel'],
          _OpacityRow(
            label: 'Dock opacity',
            sub: 'The dock or task strip',
            value: theme.dockOpacity,
            following: theme.prefs.dockOpacity == null,
            onChanged: (v) => notifier.edit((p) => p.copyWith(dockOpacity: v)),
            onFollow: () =>
                notifier.edit((p) => p.clearing(dockOpacity: true)),
          ),
        ),
        _FilterRow(
          const ['activities', 'grid button', 'app button', 'dock'],
          _Row(
            icon: Icons.apps_outlined,
            accent: true,
            title: context.t('settings.activitiesButton'),
            subtitle: context.t('settings.whereTheAppGrid'),
            trailing: _Seg(
              value: theme.prefs.dockGridButton ?? 'end', // Ubuntu default
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
            title: context.t('settings.desktopGrid'),
            subtitle: context.t('settings.rowsColumns'),
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
            title: context.t('settings.workspaces'),
            subtitle: context.t('settings.verticalDesktopsYouSwipe'),
            trailing: _Value('$workspaces'),
            onTap: () => _showStepperSheet(
              context,
              title: context.t('settings.workspaces'),
              value: workspaces,
              min: WorkspaceCount.min,
              max: WorkspaceCount.max,
              onChanged: (v) =>
                  ref.read(workspaceCountProvider.notifier).set(v),
            ),
          ),
        ),
      ],
    ),
  ];
}

/// Applications: the app drawer and its folders.
/// Sliced VERBATIM out of the old Layout group. Every `_FilterRow`, its
/// keywords and its order are untouched; only which group they sit in
/// changed. A row that loses its keywords stops being findable by search
/// and nothing fails, so nothing here was retyped.
List<Widget> _applicationsSection(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  int workspaces,
  String q,
) {
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  // Read for symmetry with the other sections; the drawer rows write prefs
  // rather than calling native. Kept so the four builders have one shape.
  // ignore: unused_local_variable
  final api = ref.read(launcherHostApiProvider);

  return [
    _Group(
      label: context.t('settings.appDrawer_2'),
      query: q,
      rows: [
        _FilterRow(
          const ['opacity', 'drawer', 'transparency', 'apps'],
          _OpacityRow(
            label: 'Opacity',
            sub: 'The wash behind the app list',
            value: theme.drawerOpacity,
            following: theme.prefs.drawerOpacity == null,
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(drawerOpacity: v)),
            onFollow: () =>
                notifier.edit((p) => p.clearing(drawerOpacity: true)),
          ),
        ),
        _FilterRow(
          const ['drawer columns', 'app drawer', 'columns'],
          _Row(
            icon: Icons.view_column_outlined,
            accent: true,
            title: context.t('settings.drawerColumns'),
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
              title: context.t('settings.drawerColumns'),
              value: theme.drawerCols,
              min: 3,
              max: 8,
              onChanged: (v) => notifier.edit((p) => p.copyWith(drawerCols: v)),
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
            title: context.t('settings.drawerScrolls'),
            subtitle: context.t('settings.oneLongListOr'),
            // Inline segments, not a sheet: this is three options that
            // change instantly and are worth trying against each other.
            // Making someone open a sheet to compare them is the friction
            // that stops anyone discovering the cube at all.
            trailing: _Seg(
              value: theme.drawerScrollStyle,
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

        // ── GROUPING, AND WHY IT IS A SEPARATE ROW ──────────────────
        //
        // A-to-Z needs letter headings, and letter headings need a
        // continuous scroll to sit in: there is nowhere to put "M" on a
        // page that turns. As a fourth value of the row above, choosing
        // it would have had to silently also mean "stop being paged",
        // and two options in one control would have disabled each other.
        //
        // SHOWN DISABLED rather than hidden when the layout is paged.
        // Hiding it means someone who read about the feature concludes
        // it does not exist; disabling it with the reason attached
        // teaches the rule in one glance.
        _FilterRow(
          const ['a to z', 'az', 'alphabet', 'grouping', 'sections'],
          _ToggleRow(
            icon: Icons.sort_by_alpha,
            title: context.t('settings.groupAToZ'),
            subtitle: theme.drawerScrollStyle == 'vertical'
                ? 'Letter headings down the list'
                : 'Only on the list layout',
            value: theme.drawerGrouping == 'az',
            enabled: theme.drawerScrollStyle == 'vertical',
            onChanged: (v) => notifier.edit(
              (p) => p.copyWith(drawerGrouping: v ? 'az' : 'none'),
            ),
          ),
        ),

        // Three positions, not two. 'off' hides the bar for people who
        // reach search by gesture or by the desktop search desklet; the
        // drawer keeps its empty first row either way, because that gap
        // clears the status bar rather than the search field.
        _FilterRow(
          const ['search', 'search bar', 'search position'],
          _Row(
            icon: Icons.search,
            accent: true,
            title: context.t('settings.searchBar'),
            subtitle: context.t('settings.whereDrawerSearch'),
            trailing: _Seg(
              value: theme.prefs.drawerSearchPosition ?? 'bottom',
              options: const {
                'top': 'Top',
                'bottom': 'Bottom',
                'off': 'Off',
              },
              onChanged: (v) => notifier.edit(
                (p) => p.copyWith(drawerSearchPosition: v),
              ),
            ),
          ),
        ),
        _FilterRow(
          const [
            'folders',
            'folder',
            // The hidden-apps section lives on the Folders page, so the words
            // people actually search for have to surface THIS row. Without
            // them, typing "hidden" in Settings finds nothing and the feature
            // looks absent.
            'hide',
            'hidden',
            'hidden apps',
            'hide app',
            'social',
            'grouping',
            'group apps',
            'suggestions',
            'games folder',
          ],
          _Row(
            icon: Icons.folder_outlined,
            accent: true,
            title: context.t('settings.appsAndFolders'),
            subtitle: context.t('settings.gridShapeAndSuggested'),
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
      ],
    ),
  ];
}

/// Gestures, plus the accessibility opt-in card they need.
///
/// Sliced VERBATIM out of the old single build method. The rows, their
/// `_FilterRow` keywords and their order are byte-identical to what shipped;
/// only where they are mounted changed. That was the whole risk in this
/// refactor: a row that loses its keywords stops being findable by search and
/// nothing fails, so nothing here was retyped.
List<Widget> _gesturesSection(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  int workspaces,
  String q,
) {
  // Derived here rather than passed, so the signature never has to name the
  // Pigeon host API type, which this file does not import.
  //
  // The prefs notifier is BOUND now: the group's Reset writes through it. It
  // was a bare `ref.read(...)` with the result discarded, which reads as a
  // deliberate warm-up and is really just a leftover.
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  ref.read(launcherHostApiProvider);

  return [
    // ── Gestures ───────────────────────────────────────────────────
    const _GestureServiceCard(),
    _Group(
      label: context.t('settings.gestures'),
      query: q,
      rows: [
        for (final g in Gesture.values)
          _FilterRow(
            [g.label.toLowerCase(), 'gesture', 'swipe'],
            _GestureRow(theme: theme, gesture: g),
          ),
      ],
    ),
  ];
}

/// System hand-offs to Android, and maintenance.
///
/// Sliced VERBATIM out of the old single build method. The rows, their
/// `_FilterRow` keywords and their order are byte-identical to what shipped;
/// only where they are mounted changed. That was the whole risk in this
/// refactor: a row that loses its keywords stops being findable by search and
/// nothing fails, so nothing here was retyped.
List<Widget> _systemSection(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  int workspaces,
  String q,
) {
  // Derived here rather than passed, so the signature never has to name the
  // Pigeon host API type, which this file does not import.
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  final api = ref.read(launcherHostApiProvider);

  return [
    // ── System (hands off to Android) ──────────────────────────────
    _Group(
      label: context.t('settings.systemOpensAndroidSettings'),
      query: q,
      rows: [
        _FilterRow(
          const ['default launcher', 'home app', 'set default'],
          _Row(
            icon: Icons.home_outlined,
            title: context.t('settings.setAsDefaultLauncher'),
            trailing: const _SysBadge(),
            onTap: api.requestDefaultLauncher,
          ),
        ),
        _FilterRow(
          const ['notifications', 'access', 'permissions'],
          _Row(
            icon: Icons.notifications_outlined,
            title: context.t('settings.notificationsAccess'),
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
      label: context.t('settings.maintenance'),
      query: q,
      rows: [
        _FilterRow(
          const ['rebuild icon cache', 'icons', 'stale', 'cache'],
          _Row(
            icon: Icons.refresh,
            title: context.t('settings.rebuildIconCache'),
            subtitle: context.t('settings.ifIconsLookWrong'),
            trailing: const _Chevron(),
            onTap: () async {
              await api.clearIconCache();
              if (context.mounted) {
                context.showMessage(context.t('settings.iconCacheCleared'));
              }
            },
          ),
        ),
        _FilterRow(
          const ['backup', 'export', 'restore', 'drive', 'transfer', 'new phone'],
          _Row(
            icon: Icons.backup_outlined,
            title: 'Backup',
            subtitle: 'Save your settings, or bring them to a new phone',
            trailing: const _Chevron(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
            ),
          ),
        ),
        _FilterRow(
          const ['restore', 'defaults', 'reset', 'sections'],
          _Row(
            icon: Icons.settings_backup_restore,
            title: 'Restore defaults',
            subtitle: 'One section at a time, or everything',
            trailing: const _Chevron(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RestoreScreen(),
              ),
            ),
          ),
        ),
        _FilterRow(
          ['reset', 'defaults', theme.spec.name.toLowerCase()],
          _Row(
            icon: Icons.settings_backup_restore,
            title: context.t('settings.resetDistro', {'name': theme.spec.name}),
            // Per-theme, per §5.3 — resetting Ubuntu must not touch KDE.
            subtitle: context.t('settings.layoutIconShapeAnd'),
            trailing: const _Chevron(),
            onTap: () => _confirmReset(context, notifier, theme),
          ),
        ),
      ],
    ),
  ];
}

/// Push one section as its own page.
typedef _SectionBuilder = List<Widget> Function(
  BuildContext,
  WidgetRef,
  EffectiveTheme,
  int,
  String,
);

void _openSection(
  BuildContext context,
  String title,
  _SectionBuilder builder,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _SectionPage(title: title, builder: builder),
    ),
  );
}

/// A section on its own page.
///
/// Re-reads the theme rather than receiving it. The pushed route lives outside
/// the parent's build, so a snapshot passed in would go stale the moment a
/// control on THIS page changed something, and every row here changes
/// something. `q` is empty by construction: search happens on the landing page
/// and never lands you here.
class _SectionPage extends ConsumerWidget {
  const _SectionPage({required this.title, required this.builder});

  final String title;
  final _SectionBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // THIS ONE WAS THE WORST OF THE SET.
    //
    // With `asData` and no fallback, every settings sub-page rendered
    // `SizedBox.shrink()` for the duration of a reload, and a reload is what
    // every prefs write causes. So flipping any toggle on this page BLANKED THE
    // PAGE THE TOGGLE WAS ON, then brought it back. `hasValue` holds the
    // previous theme through the reload, so the page stays put and the row
    // simply updates.
    //
    // The null branch survives for the genuine first-load case, where there is
    // no previous value to hold.
    final async = ref.watch(effectiveThemeProvider);
    if (!async.hasValue) return const SizedBox.shrink();
    final theme = async.requireValue;
    final workspaces = ref.watch(workspaceCountProvider);

    return ThemedScaffold(
      title: title,
      body: _RowIcons(
        show: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 28),
          children: builder(context, ref, theme, workspaces, ''),
        ),
      ),
    );
  }
}

/// A value and a disclosure arrow, for a row that both reports and navigates.
///
/// The value is what makes the Device group a settings sidebar rather than a
/// menu. Absent when the figure has not landed yet, which is the same rule the
/// desklets follow: a device that will not answer shows a bare chevron rather
/// than a placeholder.
class _ValueChevron extends StatelessWidget {
  const _ValueChevron({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final s = _Skin.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text != null) ...[
          Text(text!, style: TextStyle(color: s.mut, fontSize: 13)),
          const SizedBox(width: 8),
        ],
        Icon(Icons.chevron_right, size: 20, color: s.mut),
      ],
    );
  }
}

/// Whether a [_Row] draws its leading icon circle.
///
/// True everywhere by default, so the landing page and the flat search results
/// keep their icons with no wrapper. [_SectionPage] sets it false, which is the
/// GNOME split: icons in the sidebar, none on the rows inside a page.
class _RowIcons extends InheritedWidget {
  const _RowIcons({required this.show, required super.child});

  final bool show;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowIcons>()?.show ?? true;

  @override
  bool updateShouldNotify(_RowIcons oldWidget) => oldWidget.show != show;
}


/// The surface opacity slider.
///
/// Its own widget because a `_Row` is an icon, two lines of text and a trailing
/// slot, and a slider is none of those. Built from chrome tokens the same way
/// `_SuggestionRow` in folders_screen is, which is the established way this app
/// makes a row that the primitive does not cover.
class _OpacityRow extends StatelessWidget {
  const _OpacityRow({
    required this.value,
    required this.onChanged,
    this.label,
    this.sub,
    this.subWhenInert = false,
    this.following = false,
    this.onFollow,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Null for the main slider, which keeps its translated strings. The three
  /// section rows pass their own; those join the i18n backlog with the rest of
  /// this round's copy rather than minting keys ahead of the sweep.
  final String? label;
  final String? sub;

  /// Marks a row whose subtitle names a case where it does nothing on the
  /// shell currently on screen. Drawn quieter, and never hidden: a row that
  /// vanishes per distro is worse than one that says why it is idle.
  final bool subWhenInert;

  /// True while this section has no value of its own and is tracking the main
  /// slider. The Follow action only appears once it has stopped.
  final bool following;

  /// Clears the section's own value so it tracks the main slider again.
  /// Without it a section could be split out and never rejoined, which is the
  /// state that makes a settings screen feel like a one-way door.
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.opacity, size: 20, color: c.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label ?? context.t('settings.surfaceOpacity'),
                    style: d.text.body),
              ),
              if (!following && onFollow != null)
                GestureDetector(
                  onTap: onFollow,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text('Follow',
                        style: d.text.caption.copyWith(color: c.accent)),
                  ),
                ),
              Text('${(value * 100).round()}%',
                  style: d.text.value.copyWith(color: c.textMuted)),
            ],
          ),
          ThemedSlider(
            value: value,
            // 0.6 to 1.0, and the floor is the point. Below it a settings page
            // stops being readable over an arbitrary photograph, and
            // EffectiveTheme.surfaceOpacity clamps to the same bounds so a
            // value from anywhere else cannot get past it either.
            min: 0.6,
            max: 1.0,
            divisions: 8,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 4),
            child: Text(
              sub ?? context.t('settings.surfaceOpacitySub'),
              style: d.text.caption.copyWith(
                color: subWhenInert ? c.textFaint : c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A live panel, drawn with the settings currently being dragged.
///
/// ─── WHY A PREVIEW AND NOT THREE SUBTITLES ──────────────────────────────────
///
/// Blur, tint and corner radius are the three settings in this app whose effect
/// cannot be put into words that mean anything. "18" is not a blur, "72%" is
/// not a tint, and the surface all three describe is one that by definition is
/// not on screen while you are on this screen: you can only see a sheet by
/// leaving the page that configures it.
///
/// So the group opens with one. It is a REAL [GlassPanel] under a real
/// [ChromeScope], not a mock painted to look like one, which is what makes it
/// trustworthy: if the preview and the sheet ever disagreed, the preview would
/// be worse than nothing.
///
/// The strip behind it exists because a panel is a translucent thing and a
/// translucent thing over a flat settings page shows nothing at all. Bands of
/// the distro's own palette stand in for a wallpaper, so the blur has edges to
/// soften and the tint has something to sit over.
class _PanelPreview extends StatelessWidget {
  const _PanelPreview({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 132,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The stand-in wallpaper. Diagonal so the blur has edges running
              // through the panel rather than a flat field, which is the only
              // way a blur is visible at all.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.palette.bgTop,
                      theme.palette.accent,
                      theme.palette.bgBottom,
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),

              // A REAL scope carrying the live values, so this panel resolves
              // exactly what a sheet will. Built here rather than inherited
              // because the settings screen's own chrome is the page's, and
              // the page is not what is being previewed.
              Positioned(
                left: 18,
                right: 18,
                bottom: 0,
                child: ChromeScope(
                  data: ChromeData.fromPalette(
                    theme.palette,
                    typography: theme.typography,
                    textScale: theme.textScale,
                    family: theme.chromeFamily,
                    opacity: theme.panelOpacity,
                    panelBlur: theme.panelBlur,
                    panelTint: theme.panelTint,
                    panelRadius: theme.panelRadius,
                  ),
                  child: Builder(
                    builder: (inner) {
                      final p = ChromeScope.of(inner);
                      return GlassPanel(
                        // Top corners only, the shape a real sheet takes.
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(p.panelRadius),
                        ),
                        border: Border(
                          top: BorderSide(color: p.colors.lineStrong),
                        ),
                        child: SizedBox(
                          height: 86,
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 10, bottom: 8),
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: p.colors.lineStrong,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 18),
                                  child: Text('Sheet', style: p.text.title),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 18),
                                  child: Text(
                                    'Menus and dialogs match this',
                                    style: p.text.caption,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

/// A labelled slider for one panel setting.
///
/// Shaped like [_OpacityRow] on purpose, since they sit in the same group and
/// two slider layouts a row apart is the sort of inconsistency nobody names and
/// everybody feels. It carries no Follow action because these three have no
/// parent slider to follow: the panel OPACITY does, and it uses the existing
/// row for exactly that reason.
class _PanelSlider extends StatelessWidget {
  const _PanelSlider({
    required this.icon,
    required this.label,
    required this.sub,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String sub;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: c.textMuted),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: d.text.body)),
              Text(
                format(value),
                style: d.text.value.copyWith(color: c.textMuted),
              ),
            ],
          ),
          ThemedSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 4),
            child: Text(sub, style: d.text.caption.copyWith(color: c.textMuted)),
          ),
        ],
      ),
    );
  }
}


/// Notification access: the state, and the way to change it.
///
/// ─── WHY THIS ROW SAYS MORE THAN "ALLOW" ────────────────────────────────────
///
/// Tapping it opens Android's notification-access page, which presents a
/// confirmation dialog warning that this app will be able to read every
/// notification, including personal information. That warning is accurate about
/// the API and wrong about this launcher, which counts notifications per package
/// and reads no title, body, sender or image.
///
/// A user who reads that dialog and backs out has made a sensible decision on
/// bad information. The subtitle here is the only chance to give them the real
/// one, so it says what is read rather than reassuring them in the abstract.
///
/// The state is asked FRESH rather than stored, because access is revocable
/// from Android's settings at any moment and nothing tells us. A cached flag
/// would leave this row claiming badges are on while none were drawn.
class _BadgeAccessRow extends ConsumerWidget {
  const _BadgeAccessRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(notificationAccessProvider);
    final on = granted.asData?.value ?? false;

    return _Row(
      icon: on ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
      accent: true,
      title: on ? 'Notification access is on' : 'Allow notification access',
      subtitle: on
          ? 'Counts only. No message content is read or stored'
          : 'Needed to show badges. Counts only, never message content',
      // ALWAYS a widget: _Row.trailing is required and non-nullable. An empty
      // box when access is granted, because there is nothing left to tap
      // through to and a chevron would promise a screen that is not there.
      trailing: on ? const SizedBox.shrink() : const _Chevron(),
      onTap: () async {
        await openNotificationAccessSettings();

        // NOTHING TELLS US A GRANT HAPPENED. There is no result to await and
        // no broadcast to listen for, so the state is re-asked when the user
        // comes back. Invalidating alone is not enough: the counts themselves
        // were cached by the bridge while the service was unbound, so they are
        // pulled too or the row would say granted over an empty drawer.
        ref.invalidate(notificationAccessProvider);
        await ref.read(badgeCountsProvider.notifier).refresh();
      },
    );
  }
}

/// Dot, count, or off, with the distro's own answer as the default.
///
/// Written here rather than reaching for the shape sheet, the same call
/// `_Choices` in desklet_settings makes: four mutually exclusive options is a
/// segmented row, and a sheet for it is a route push to answer a question that
/// fits on one line.
///
/// The first option is AUTO and it clears the stored value rather than writing
/// today's resolved answer. A user on auto who switches from Ubuntu to Plasma
/// should get Plasma's numbers, not the dot they were silently frozen into.
class _BadgeStyleRow extends StatelessWidget {
  const _BadgeStyleRow({required this.theme, required this.onPick});

  final EffectiveTheme theme;

  /// Null means auto, which clears the preference.
  final ValueChanged<String?> onPick;

  static const _options = <({String? value, String label})>[
    (value: null, label: 'Auto'),
    (value: 'dot', label: 'Dot'),
    (value: 'count', label: 'Count'),
    (value: 'off', label: 'Off'),
  ];

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    final stored = theme.prefs.badgeStyle;
    // An unknown string from a newer build reads as auto here, which is the
    // same way badgeStyleFor resolves it. Two places, one answer.
    final selected = _options.indexWhere((o) => o.value == stored);
    final index = selected < 0 ? 0 : selected;

    // What auto currently resolves to, named rather than left implicit. "Auto"
    // on its own tells the user nothing about what they are about to see.
    // Only ever READ on the auto branch below, where the stored value is null
    // and badgeStyleFor therefore returns the distro's own answer. That is why
    // it can be computed straight from the theme without stripping anything.
    final resolved = switch (badgeStyleFor(theme)) {
      BadgeStyle.dot => 'a dot',
      BadgeStyle.count => 'a number',
      BadgeStyle.none => 'nothing',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle_notifications_outlined,
                  size: 20, color: c.textMuted),
              const SizedBox(width: 14),
              Expanded(child: Text('Badge style', style: d.text.body)),
            ],
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _options.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onPick(_options[i].value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: i == index ? c.accent : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _options[i].label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: d.text.caption.copyWith(
                            color: i == index ? c.onAccent : c.text,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 8),
            child: Text(
              stored == null
                  ? 'This distro shows $resolved'
                  : 'Every distro, whichever desktop you are wearing',
              style: d.text.caption.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
