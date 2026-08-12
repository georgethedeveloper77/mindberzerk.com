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
import '../../../design/setting_previews.dart';
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
            subtitle: 'This distro',
            trailing: ChipValue(
              label: '${theme.drawerCols}',
              preview: DevicePreview(
                palette: theme.palette,
                mode: DevicePreviewMode.drawer,
                cols: theme.drawerCols,
              ),
            ),
            onTap: () => showStepperSheet(
              context,
              title: context.t('settings.drawerColumns'),
              value: theme.drawerCols,
              min: 3,
              max: 8,
              onChanged: (v) => notifier.edit((p) => p.copyWith(drawerCols: v)),
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
          const ['drawer', 'scroll', 'pages', 'cube', 'list', 'vertical'],
          PreviewChoice<String>(
            title: context.t('settings.drawerScrolls'),
            subtitle: context.t('settings.oneLongListOr'),
            value: theme.drawerScrollStyle,
            onSelect: (v) =>
                notifier.edit((p) => p.copyWith(drawerScrollStyle: v)),
            options: [
              for (final o in const [
                ('vertical', 'List'),
                ('pages', 'Pages'),
                ('cube', 'Cube'),
              ])
                PreviewOption(
                  value: o.$1,
                  label: o.$2,
                  child: ScrollStyleTile(style: o.$1, palette: theme.palette),
                ),
            ],
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
        FilterRow(
          const ['a to z', 'az', 'alphabet', 'grouping', 'sections'],
          SettingsToggleRow(
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
        FilterRow(
          const ['search', 'search bar', 'search position'],
          SettingsRow(
            icon: Icons.search,
            accent: true,
            title: context.t('settings.searchBar'),
            subtitle: context.t('settings.whereDrawerSearch'),
            trailing: Seg(
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
