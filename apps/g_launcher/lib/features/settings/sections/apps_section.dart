/// Apps: the drawer, folders, and what a tile shows.
///
/// A section builder. See `appearance_section.dart` for why these are functions
/// returning widget lists rather than pages.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/home_layout.dart';
import '../../../data/prefs/prefs_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/shell_apps.dart';
import '../../../design/branded_message.dart';
import '../../../design/components/components.dart';
import '../../../design/device_preview.dart';
import '../../../design/drawer_transition.dart';
import '../../../design/setting_previews.dart';
import '../../../engine/capabilities.dart';
import '../../../engine/effective_theme.dart';
import '../../../system/notification_badges.dart';
import '../folders_screen.dart';
import '../settings_rows.dart';
import '../settings_sheets.dart';

/// Applications: the app drawer and its folders.
///
/// Sliced VERBATIM out of the old Layout group. Every `FilterRow`, its
/// keywords and its order are untouched; only which group they sit in
/// changed. A row that loses its keywords stops being findable by search
/// and nothing fails, so nothing here was retyped.
List<Widget> applicationsSection(
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
    // The columns stepper, the scroll style and the grouping all describe this
    // one picture, and none of them is legible as a number. The stepper's own
    // ChipValue already shows a thumbnail while you drag it; this is the same
    // grid at rest, so the page opens on the thing it is about.
    SettingPreview(
      query: q,
      caption: 'Drawer, live',
      child: SinglePreview(
        child: DevicePreview(
          palette: theme.palette,
          mode: DevicePreviewMode.drawer,
          cols: theme.drawerCols,
        ),
      ),
    ),

    SettingsGroup(
      label: context.t('settings.appDrawer_2'),
      scope: 'All distros',
      query: q,
      rows: [
        FilterRow(
          const ['opacity', 'drawer', 'transparency', 'apps'],
          OpacityRow(
            label: context.t('settings.drawerOpacity'),
            sub: context.t('settings.drawerOpacitySub'),
            value: theme.drawerOpacity,
            following: theme.prefs.drawerOpacity == null,
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(drawerOpacity: v)),
            onFollow: () =>
                notifier.edit((p) => p.clearing(drawerOpacity: true)),
          ),
        ),
        FilterRow(
          const ['drawer columns', 'app drawer', 'columns'],
          SettingsRow(
            icon: Icons.view_column_outlined,
            accent: true,
            title: context.t('settings.drawerColumns'),
            // ── THE ONE ROW THAT DISAGREES WITH ITS GROUP ──────────────
            //
            // The group says "All distros" and means it for scrolling,
            // grouping, sorting and the search bar, all of which are promoted.
            // Column count is not: how wide the grid is belongs to the distro
            // the same way its home grid does, and a Plasma Kickoff list and a
            // GNOME page grid do not want the same number.
            //
            // Marked on the row rather than by splitting the group, because a
            // group of one exists to carry a heading nobody needed. Three or
            // four rows in the whole app need this and none of them is worth a
            // heading of its own.
            // ── AND THE OTHER REASON IT CAN BE INERT ───────────────────
            //
            // Library was the only cause this row knew about, because it was
            // the only one anything computed. A Kickoff list, a dmenu line and
            // the tool menu all have exactly one column too, and on those the
            // row was live and did nothing. See [ThemeCapabilities].
            subtitle: !theme.canChooseDrawerColumns.available
                ? context.t(theme.canChooseDrawerColumns.why!)
                : theme.drawerGrouping == 'library'
                    ? 'The library is two columns'
                    : 'This distro',
            subtitleTint: (!theme.canChooseDrawerColumns.available ||
                    theme.drawerGrouping == 'library')
                ? SettingsSkin.of(context).warn
                : null,
            trailing: ChipValue(
              label: '${theme.drawerCols}',
              preview: DevicePreview(
                palette: theme.palette,
                mode: DevicePreviewMode.drawer,
                cols: theme.drawerCols,
              ),
            ),
            // ── INERT UNDER LIBRARY ────────────────────────────────
            //
            // The library is two columns and its tile is drawn for two: three
            // large icons plus a cluster does not survive being squeezed to a
            // fifth of the screen. So the number is not a preference there, it
            // is a property of the layout.
            //
            // A null `onTap` is how `SettingsRow` says inert; it has no
            // `enabled` flag. The tinted subtitle carries the reason, the same
            // way `_GestureRow` tints its workspace-scrolling warning.
            onTap: (theme.drawerGrouping == 'library' ||
                    !theme.canChooseDrawerColumns.available)
                ? null
                : () => showStepperSheet(
                      context,
                      title: context.t('settings.drawerColumns'),
                      value: theme.drawerCols,
                      min: 3,
                      max: 8,
                      onChanged: (v) =>
                          notifier.edit((p) => p.copyWith(drawerCols: v)),
                    ),
          ),
        ),
        // ── THE PICTURE IS THE CONTROL ─────────────────────────────
        //
        // The old segmented control's own comment made the case for this and
        // stopped one step short: it said these are three options worth trying
        // against each other and that a sheet is the friction stopping anyone
        // finding the cube. Both true, and "List / Pages / Cube" still names
        // three things rather than showing them.
        //
        // See [ScrollStyleTile] for why these are hand-drawn rather than
        // DevicePreview modes: the difference is motion, so each tile shows
        // the artefact that gives the style away instead.
        FilterRow(
          const [
            'drawer',
            'scroll',
            'pages',
            'cube',
            'cylinder',
            'sphere',
            'depth',
            'stack',
            'list',
            'vertical',
          ],
          // ── A TAP PLAYS THE STYLE IT PICKS ────────────────────────────
          //
          // The tiles rest frozen a third of the way through their turn, which
          // is where the six look least alike, and a tap runs the tapped one
          // through. One controller for the whole row rather than one per tile:
          // six tickers is six wakeups a frame for a page that is meant to sit
          // still while it is read. See [ScrollStylePlayer].
          ScrollStylePlayer(
            // The current style demonstrates itself once when the page opens,
            // so "what is my drawer doing" is answered without a tap.
            initial: theme.drawerScrollStyle,
            builder: (context, phase, playing, play) => PreviewChoice<String>(
            title: context.t('settings.drawerScrolls'),
            // ── DIMMED UNDER LIBRARY ───────────────────────────────
            //
            // The library is one vertical run of tiles. Pages and Cube are
            // motions for a grid of app icons and there is no sensible way to
            // page a two-column folder list, so the choice has one answer
            // there and the row says so rather than offering three.
            subtitle: !theme.canChooseDrawerMotion.available
                ? context.t(theme.canChooseDrawerMotion.why!)
                : theme.drawerGrouping == 'library'
                    ? 'The library is always one list'
                    : context.t('settings.oneLongListOr'),
            enabled: theme.drawerGrouping != 'library' &&
                theme.canChooseDrawerMotion.available,
            // Shown as List regardless of what the pref holds, because that is
            // what the drawer is actually doing. Leaving the stored value
            // selected would put the ring on Cube while the screen renders a
            // list.
            value: theme.drawerGrouping == 'library'
                ? 'vertical'
                : theme.drawerScrollStyle,
            onSelect: (v) {
              notifier.edit((p) => p.copyWith(drawerScrollStyle: v));
              // PLAYED ON EVERY TAP, including a tap on the style already
              // selected. Driving this off the selected VALUE instead would
              // make that tap do nothing, which reads as the control having
              // stopped working.
              play(v);
            },
            // The third of the three drawer rows, and `PreviewChoice` has
            // carried this pair since `dockSide` needed it. Mint authors a
            // list; one tap on Pages ended that everywhere.
            following: theme.prefs.drawerScrollStyle == null,
            onFollow: () => notifier.edit(
              (p) => p.clearing(drawerScrollStyle: true),
            ),
            // ── LIST FIRST, THEN THE CATALOGUE ────────────────────────
            //
            // `vertical` is prepended rather than living in
            // [DrawerTransition.catalogue], because it is not a transition:
            // it selects a different widget and `app_drawer` branches on it
            // long before the pager is reached. The catalogue is the six
            // things that ARE transitions, in the order they should read.
            //
            // Six names and six blurbs live on the enum, not here. Setup lists
            // the same six, and two hand-written lists is how one of them ends
            // up a style short.
            options: [
              PreviewOption(
                value: 'vertical',
                label: 'List',
                child: ScrollStyleTile(
                  style: 'vertical',
                  palette: theme.palette,
                ),
              ),
              for (final t in DrawerTransition.catalogue)
                PreviewOption(
                  value: t.value,
                  label: t.copy.$1,
                  child: ScrollStyleTile(
                    style: t.value,
                    palette: theme.palette,
                    // Only the tile being demonstrated moves. The rest hold
                    // their frozen pose, which is what makes the moving one
                    // legible.
                    phase: playing == t.value
                        ? phase
                        : ScrollStyleTile.restPhase,
                  ),
                ),
            ],
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
        // ── THREE VALUES, SO NOT A SWITCH ANY MORE ────────────────────
        //
        // This was a toggle reading `drawerGrouping == 'az'`, which was exact
        // while the field held two values. It holds three now, and a switch
        // cannot express the third: turning it off from Library would have to
        // pick between 'none' and 'az' on the user's behalf, and there is no
        // right answer to that.
        //
        // `Seg` is the same control the search-bar row directly below uses for
        // its own three positions, so this is the house pattern rather than a
        // new one.
        //
        // ENABLED ON EVERY LAYOUT, unlike before. A to Z headings genuinely
        // only make sense down a list, but FOLDERS work in a paged grid as
        // well as a scroll, so gating the whole row on `vertical` would have
        // hidden Library from the layouts that can use it. The subtitle
        // carries the caveat instead.
        FilterRow(
          const [
            'a to z',
            'az',
            'alphabet',
            'grouping',
            'sections',
            'library',
            'folders',
            'categories',
          ],
          SettingsRow(
            icon: Icons.sort_by_alpha,
            title: context.t('settings.groupAToZ'),
            subtitle: !theme.canChooseDrawerGrouping.available &&
                    theme.drawerGrouping != 'library'
                ? context.t(theme.canChooseDrawerGrouping.why!)
                : switch (theme.drawerGrouping) {
                    'library' => 'Apps filed into category folders',
                    'az' => theme.drawerScrollStyle == 'vertical'
                        ? 'Letter headings down the list'
                        : 'Headings need the list layout',
                    _ => 'One flat run of apps',
                  },
            trailing: Seg(
              enabled: theme.canChooseDrawerGrouping.available ||
                  theme.drawerGrouping == 'library',
              value: theme.drawerGrouping,
              // elementary authors `library` and Zorin authors it too. One tap
              // here buried both, on every distro, with nothing saying so.
              following: theme.prefs.drawerGrouping == null,
              onFollow: () => notifier.edit(
                (p) => p.clearing(drawerGrouping: true),
              ),
              options: const {
                'none': 'Off',
                'az': 'A to Z',
                'library': 'Library',
              },
              onChanged: (v) => notifier.edit(
                (p) => p.copyWith(drawerGrouping: v),
              ),
            ),
          ),
        ),

        // Three positions, not two. 'off' hides the bar for people who
        // reach search by gesture or by the desktop search desklet; the
        // drawer keeps its empty first row either way, because that gap
        // clears the status bar rather than the search field.
        FilterRow(
          const ['search', 'search bar', 'search position'],
          SettingsRow(
            icon: Icons.search,
            accent: true,
            title: context.t('settings.searchBar'),
            subtitle: theme.canMoveSearchBar.available
                ? context.t('settings.whereDrawerSearch')
                : context.t(theme.canMoveSearchBar.why!),
            trailing: Seg(
              enabled: theme.canMoveSearchBar.available,
              // ─── THE RESOLVED VALUE, LIKE EVERY ROW AROUND IT ─────────
              //
              // This read `theme.prefs.drawerSearchPosition ?? 'bottom'`: the
              // raw pref, with the engine default written out as a literal.
              // The grouping row directly above reads `theme.drawerGrouping`
              // and the layout row reads `theme.drawerScrollStyle`, both
              // resolved, and this was the one that did not.
              //
              // It could not report a distro's answer, so Deepin authoring
              // `drawerSearchPosition: "top"` left this segment insisting on
              // Bottom. The same expression was in `AppDrawer`, which is how
              // the bar and the row managed to agree while both were wrong.
              value: theme.drawerSearchPosition,
              // ─── AND THE WAY BACK TO THE DISTRO ───────────────────────
              //
              // Deepin authors `top`. Without this pair, one tap on Bottom
              // buries that on this device forever, and every distro the user
              // tries afterwards wears the choice they made on Deepin. Same
              // pair and same argument as `dockSide` in `desktop_section`.
              following: theme.prefs.drawerSearchPosition == null,
              onFollow: () => notifier.edit(
                (p) => p.clearing(drawerSearchPosition: true),
              ),
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
        FilterRow(
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
          SettingsRow(
            icon: Icons.folder_outlined,
            accent: true,
            title: context.t('settings.appsAndFolders'),
            subtitle: context.t('settings.gridShapeAndSuggested'),
            trailing: ChipValue(
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
    // ── THE WAY BACK ───────────────────────────────────────────────
    //
    // An app removed from the dock is otherwise gone with nothing on screen
    // saying so, which is the same shape as a hidden wallpaper and gets the
    // same treatment: a count, and a tap to put one back. Absent entirely when
    // nothing has been removed, rather than a row reading zero.
    if (theme.prefs.dockExcluded.isNotEmpty)
      SettingsGroup(
        // Raw, because there is no key for it yet and filing a DOCK row under
        // the App drawer heading is exactly the misplacement the regroup just
        // undid. It joins the i18n sweep with the scope labels.
        label: 'Dock',
        scope: 'This distro',
        query: q,
        rows: [
          FilterRow(
            const ['dock', 'removed', 'hidden', 'restore', 'put back'],
            SettingsRow(
              icon: Icons.remove_circle_outline,
              title: 'Removed from the dock',
              subtitle: theme.prefs.dockExcluded.length == 1
                  ? '1 app will not be filled in'
                  : '${theme.prefs.dockExcluded.length} apps will not be '
                      'filled in',
              trailing: const Chevron(),
              onTap: () => _showRemovedFromDock(context, ref, theme),
            ),
          ),
        ],
      ),

    // ── Badges ─────────────────────────────────────────────────────
    //
    // MOVED FROM APPEARANCE. A badge is not a look, it is a behaviour: it
    // says an app has something waiting. It belongs beside the drawer whose
    // tiles carry it, and the permission that makes it possible belongs
    // beside the setting it enables rather than in a Permissions group of
    // one, three pages away from anything it affects.
    SettingsGroup(
      label: context.t('settings.badges'),
      scope: 'All distros',
      query: q,
      rows: [
        FilterRow(
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

    SettingsGroup(
      label: context.t('settings.permissions'),
      scope: 'All distros',
      query: q,
      rows: const [
        FilterRow(
          ['permission', 'notification', 'access', 'badge', 'allow', 'grant'],
          _BadgeAccessRow(),
        ),
      ],
    ),
  ];
}

/// Gestures, plus the accessibility opt-in card they need.
///
/// Sliced VERBATIM out of the old single build method. The rows, their
/// `FilterRow` keywords and their order are byte-identical to what shipped;
/// only where they are mounted changed. That was the whole risk in this
/// refactor: a row that loses its keywords stops being findable by search and
/// nothing fails, so nothing here was retyped.

/// Notification access: the state, and the way to change it.
class _BadgeAccessRow extends ConsumerWidget {
  const _BadgeAccessRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(notificationAccessProvider);
    final on = granted.asData?.value ?? false;

    return SettingsRow(
      icon: on
          ? Icons.notifications_active_outlined
          : Icons.notifications_off_outlined,
      accent: true,
      title: context.t(
        on ? 'settings.badges.accessOn' : 'settings.badges.accessOff',
      ),
      subtitle: context.t(
        on ? 'settings.badges.accessOnSub' : 'settings.badges.accessOffSub',
      ),
      // ALWAYS a widget: SettingsRow.trailing is required and non-nullable. An empty
      // box when access is granted, because there is nothing left to tap
      // through to and a chevron would promise a screen that is not there.
      trailing: on ? const SizedBox.shrink() : const Chevron(),
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

  /// KEYS, not sentences. A top-level `const` list is built before any widget
  /// exists, so it cannot call `context.t` at all; the labels resolve where they
  /// are drawn. Same shape `_cornerChoices` takes in desklet_settings and for
  /// the same reason.
  static const _options = <({String? value, String labelKey})>[
    (value: null, labelKey: 'settings.badges.auto'),
    (value: 'dot', labelKey: 'settings.badges.dot'),
    (value: 'count', labelKey: 'settings.badges.count'),
    (value: 'off', labelKey: 'settings.badges.off'),
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
    //
    // Only ever READ on the auto branch below, where the stored value is null
    // and badgeStyleFor therefore returns the distro's own answer. That is why
    // it can be computed straight from the theme without stripping anything.
    //
    // WHOLE SENTENCES behind the switch, rather than a fragment interpolated
    // into a stem. "This distro shows" plus "a dot" composes in English and
    // falls apart in a language that inflects the noun or moves the verb, and a
    // translator handed "a dot" alone cannot see which sentence it lands in.
    final resolved = context.t(switch (badgeStyleFor(theme)) {
      BadgeStyle.dot => 'settings.badges.showsDot',
      BadgeStyle.count => 'settings.badges.showsCount',
      BadgeStyle.none => 'settings.badges.showsNone',
    });

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
              Expanded(
                child: Text(context.t('settings.badges.style'),
                    style: d.text.body),
              ),
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
                          context.t(_options[i].labelKey),
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
                  ? resolved
                  : context.t('settings.badges.everyDistro'),
              style: d.text.caption.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every app taken out of the auto-filled dock, with a tap to put one back.
///
/// ─── LABELS, NOT COMPONENT KEYS ─────────────────────────────────────────────
///
/// The excluded set stores component keys, which are the right thing to store
/// and the wrong thing to show: `com.whatsapp/com.whatsapp.Main` is not what
/// anyone calls WhatsApp. So the live app list resolves them, and a key with no
/// installed app falls back to the key itself rather than vanishing from the
/// list. It should not normally happen, since `HomeLayout.prune` drops dead
/// keys, but a row nobody can see is a setting nobody can undo.
void _showRemovedFromDock(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
) {
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  final apps = ref.read(shellAppsProvider(theme));
  final labels = {for (final a in apps) a.componentKey: a.label};
  final removed = theme.prefs.dockExcluded.toList()
    ..sort((a, b) => (labels[a] ?? a).compareTo(labels[b] ?? b));

  ThemedSheet.show<void>(
    context,
    title: 'Removed from the dock',
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final key in removed)
          ThemedListRow(
            icon: Icons.add_circle_outline,
            title: labels[key] ?? key,
            // Says what putting it back actually does. The dock fills from
            // frequency, so this restores eligibility rather than a slot, and
            // promising the app returns would be a promise the filler does not
            // keep for something the user rarely opens.
            subtitle: 'Can be filled in again',
            onTap: () {
              Navigator.pop(sheet);
              notifier.edit((p) => HomeLayout.restoreToDock(p, key));
              context
                  .showMessage('${labels[key] ?? key} can return to the dock');
            },
          ),
        if (removed.length > 1)
          ThemedListRow(
            icon: Icons.restart_alt,
            title: 'Put them all back',
            onTap: () {
              Navigator.pop(sheet);
              notifier.edit(HomeLayout.restoreToDock);
              context.showMessage('The dock can fill from every app again');
            },
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
