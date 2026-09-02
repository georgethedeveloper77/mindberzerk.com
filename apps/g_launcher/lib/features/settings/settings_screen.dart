/// Settings: the landing, the search box, and the routes into each section.
///
/// ─── THIS FILE WAS 3232 LINES AND IS NOW NINE FILES ─────────────────────────
///
/// It held the screen, five section builders, twenty private widgets, five
/// sheet functions and two previews. Nothing was wrong with any of it
/// individually; the size was the problem. At that length a `str_replace`
/// against a `SettingsRow` opener has forty candidates, the pattern that has already cost this
/// project a split doc comment and an orphaned body, and every future edit to
/// one section rewrites a file that eight other concerns live in.
///
/// The split is BY SECTION, matching the pages the user actually navigates:
///
///   settings_screen.dart      this file: landing, search, section routing
///   settings_rows.dart        the row and group vocabulary, shared by all
///   settings_sheets.dart      the pickers those rows open
///   sections/…_section.dart   one file per page in the landing list
///   design/setting_previews.dart   the live pictures, next to DevicePreview
///
/// ─── AND THE PRIVATE NAMES HAD TO GO PUBLIC ─────────────────────────────────
///
/// Private in Dart means library-private, so the moment `_Row` lived in another
/// file every call site broke. `part of` would have avoided that and was
/// rejected: it welds the files back into one library, which is the thing being
/// undone, and it leaves the names unusable from the folders and wallpaper
/// screens, which currently rebuild rows of their own. So `_Group` is
/// `SettingsGroup`, `_Row` is `SettingsRow`, and the vocabulary is now
/// importable by anything that wants a settings row.
///
/// The names that stayed private are the ones with exactly one caller in one
/// file: the search field, the default-launcher banner, the section page, the
/// gesture card and the badge rows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/update/update_repository.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../system/system_stats.dart';
import '../home/workspaces/workspace_controller.dart';
import '../themes/themes_screen.dart';
import 'device_pages.dart';
import 'sections/appearance_section.dart';
import 'sections/apps_section.dart';
import 'sections/desktop_section.dart';
import 'sections/gestures_section.dart';
import 'sections/system_section.dart';
import 'settings_rows.dart';
import 'settings_sheets.dart';

/// Settings — Phase B, B1.
///
/// The look is no longer a fixed "One UI" skin. Every surface now derives from
/// the active theme via the chrome layer (see design/components): the accent is
/// the DISTRO's accent — Ubuntu orange, Fedora blue, KDE Breeze blue — not a
/// hardcoded Samsung blue, and the group framing forks on [ChromeFamily] so the
/// page reads as GNOME/Adwaita under Ubuntu and KDE/Breeze under Plasma. The old
/// `_Ou` palette (the one place that read Samsung-blue) is gone; its field names
/// survive on [SettingsSkin], which resolves them from the chrome instead.
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

  /// The SECOND of the two update checks, the first being at process start.
  ///
  /// Throttled by the same stamp, so opening Settings six times in an afternoon
  /// is six SharedPreferences reads and no Play traffic. What it buys is the
  /// case the cold-start check cannot cover: a launcher process that has been
  /// alive for three days, which on this app is the normal case rather than the
  /// exception.
  ///
  /// Deferred to a microtask because `initState` runs inside the build phase and
  /// `checkIfStale` sets state as its first act on the un-throttled path.
  /// `mounted` is checked because the frame it fires on is not guaranteed to
  /// still have this widget in it.
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(appUpdateProvider.notifier).checkIfStale();
    });
  }

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
          const _UpdateBanner(),

          // ── LANDING, OR A FLAT FILTERED LIST ──────────────────────────
          //
          // The screen was one list of about twenty rows across six groups.
          // Long enough that nobody scrolled it, and with no room for the
          // per-setting previews.
          //
          // SEARCH IS WHY THIS IS A BRANCH AND NOT A ROUTER. With a query
          // typed, every section is mounted flat and `SettingsGroup` filters them
          // exactly as before, so a search still reaches a row three taps
          // deep. Hiding rows behind sub-pages WITHOUT this would have made
          // the search box quietly less useful, which is the usual price of
          // splitting a settings screen and the one worth not paying.
          if (q.isNotEmpty) ...[
            ...appearanceSection(context, ref, theme, workspaces, q),
            ...desktopSection(context, ref, theme, workspaces, q),
            ...applicationsSection(context, ref, theme, workspaces, q),
            ...gesturesSection(context, ref, theme, workspaces, q),
            ...systemSection(context, ref, theme, workspaces, q),
          ] else ...[
            // ── THE DISTRO ────────────────────────────────────────────────
            //
            // Its own group, above everything. It is the setting that changes
            // every other setting on this screen, and grouping it with
            // wallpaper and icons undersells it. The label carries the version,
            // so the header doubles as the answer to "which Ubuntu is this".
            SettingsGroup(
              label: theme.spec.version.isEmpty
                  ? theme.spec.name
                  : '${theme.spec.name} ${theme.spec.version}',
              rows: [
                FilterRow(
                  const ['distro', 'theme', 'desktop', 'switch'],
                  SettingsRow(
                    icon: Icons.desktop_windows_outlined,
                    accent: true,
                    title: context.t('settings.changeDesktop'),
                    subtitle: context.t('settings.settingsBelowAreStored'),
                    trailing: const Chevron(),
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
              SettingsGroup(
                label: context.t('settings.device'),
                rows: [
                  for (final d in devices)
                    FilterRow(
                      [d.label.toLowerCase(), ...d.keywords],
                      SettingsRow(
                        icon: d.icon,
                        accent: true,
                        title: d.label,
                        trailing: ValueChevron(text: d.valueFor(stats)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => d.page),
                        ),
                      ),
                    ),
                ],
              ),

            SettingsGroup(
              label: context.t('setup.step.distro'),
              rows: [
                FilterRow(
                  const ['appearance', 'wallpaper', 'icons', 'boot', 'labels'],
                  SettingsRow(
                    icon: Icons.palette_outlined,
                    accent: true,
                    title: context.t('settings.appearance'),
                    trailing: const Chevron(),
                    onTap: () => _openSection(
                      context,
                      'Appearance',
                      appearanceSection,
                    ),
                  ),
                ),
                FilterRow(
                  const ['dock', 'grid', 'workspaces', 'widgets', 'desktop'],
                  SettingsRow(
                    icon: Icons.layers_outlined,
                    accent: true,
                    title: context.t('settings.desktopAndDock'),
                    trailing: const Chevron(),
                    onTap: () => _openSection(
                      context,
                      'Desktop and dock',
                      desktopSection,
                    ),
                  ),
                ),
                FilterRow(
                  const ['apps', 'drawer', 'folders', 'search', 'columns'],
                  SettingsRow(
                    icon: Icons.apps_outlined,
                    accent: true,
                    title: context.t('settings.applications'),
                    trailing: const Chevron(),
                    onTap: () => _openSection(
                      context,
                      'Applications',
                      applicationsSection,
                    ),
                  ),
                ),
                FilterRow(
                  const ['gestures', 'swipe', 'accessibility'],
                  SettingsRow(
                    icon: Icons.gesture_outlined,
                    accent: true,
                    title: context.t('settings.gestures'),
                    trailing: const Chevron(),
                    onTap: () =>
                        _openSection(context, 'Gestures', gesturesSection),
                  ),
                ),
              ],
            ),

            SettingsGroup(
              label: context.t('settings.system'),
              rows: [
                FilterRow(
                  const ['system', 'android', 'reset', 'about', 'default'],
                  SettingsRow(
                    icon: Icons.info_outline,
                    accent: true,
                    title: context.t('settings.system'),
                    subtitle: context.t('settings.androidSettingsMaintenanceReset'),
                    trailing: const Chevron(),
                    onTap: () =>
                        _openSection(context, 'System', systemSection),
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
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

class _DefaultLauncherBanner extends ConsumerWidget {
  const _DefaultLauncherBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(launcherHostApiProvider);
    final s = SettingsSkin.of(context);

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

/// An update from Play, offered rather than announced.
///
/// ─── ABSENT IN FOUR OF THE SEVEN STATES ─────────────────────────────────────
///
/// Nothing renders for unknown, checking, up to date or unavailable. The rule is
/// the one `_DefaultLauncherBanner` states directly above: a banner that nags
/// about something already handled teaches people to ignore banners. Checking is
/// excluded for a second reason, which is that a banner flickering in for the
/// length of one Play call on every Settings open is worse than no banner.
///
/// ─── AND ABSENT FROM THE DESKTOP ENTIRELY ───────────────────────────────────
///
/// This is the only surface that announces an update. Not the desktop, not a
/// boot message, not a badge on the drawer. A launcher that interrupts the home
/// screen to talk about itself is the behaviour the no-ads rule exists to
/// prevent, and an update notice is not exempt because it is ours.
class _UpdateBanner extends ConsumerWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider);
    if (!update.hasUpdate) return const SizedBox.shrink();

    final s = SettingsSkin.of(context);
    final notifier = ref.read(appUpdateProvider.notifier);
    final (String title, String subtitle) = switch (update.status) {
      UpdateStatus.downloading => (
          context.t('settings.update.downloading'),
          context.t('settings.update.keepUsing'),
        ),
      UpdateStatus.readyToInstall => (
          context.t('settings.update.ready'),
          context.t('settings.update.willReloadOnRestart'),
        ),
      _ => (
          context.t('settings.update.available'),
          context.t('settings.update.fromPlay'),
        ),
    };

    return Container(
      margin:
          EdgeInsets.fromLTRB(s.framing.cardInset, 0, s.framing.cardInset, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: s.acc.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(s.framing.cardRadius),
        border: Border.all(color: s.acc.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_alt, color: s.acc),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: s.tx,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: s.mut, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (update.status != UpdateStatus.downloading) ...[
                const SizedBox(width: 8),
                ThemedButton(
                  label: update.status == UpdateStatus.readyToInstall
                      ? context.t('settings.update.restart')
                      : context.t('settings.download'),
                  onPressed: () => update.status == UpdateStatus.readyToInstall
                      ? confirmUpdateRestart(context, notifier)
                      : notifier.startDownload(),
                ),
              ],
            ],
          ),
          // INDETERMINATE, and that is not laziness. The plugin does not surface
          // `bytesDownloaded`, so a percentage here would be invented. See the
          // header of update_repository.dart.
          if (update.status == UpdateStatus.downloading) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: s.card2,
                valueColor: AlwaysStoppedAnimation<Color>(s.acc),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The accessibility opt-in. Blunt about what the permission does on purpose —
/// the system dialog is scary, and a vague explanation makes people refuse, or
/// worse, accept without understanding, which is not consent.

typedef _SectionBuilder = List<Widget> Function(
  BuildContext,
  WidgetRef,
  EffectiveTheme,
  int,
  String,
);

/// Push one section as its own page.
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
      body: RowIcons(
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
