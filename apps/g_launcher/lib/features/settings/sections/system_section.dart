/// System: Android's own settings, and maintenance.
///
/// A section builder. The rule this page exists to keep is the one from the
/// screen's header: anything the OS owns is a deep link out, never a
/// reimplementation, because a launcher that grows its own display or storage
/// page is wrong on the next OEM skin and stale on the next Android release.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/prefs_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/update/update_repository.dart';
import '../../../design/branded_message.dart';
import '../../../engine/effective_theme.dart';
import '../backup_screen.dart';
import '../restore_screen.dart';
import '../language_settings.dart';
import '../settings_rows.dart';
import '../settings_sheets.dart';

/// System hand-offs to Android, and maintenance.
///
/// Sliced VERBATIM out of the old single build method. The rows, their
/// `FilterRow` keywords and their order are byte-identical to what shipped;
/// only where they are mounted changed.
List<Widget> systemSection(
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

  // WATCHED, so the About row appears the moment the package-manager read
  // lands rather than on the next visit to this page.
  //
  // `hasValue` / `requireValue`, NOT `valueOrNull`, which Riverpod 3 removed,
  // and not `asData` either. `crash_context.dart` argues the second half of
  // that at length: `asData` is null while a provider is REFRESHING, not only
  // while it is loading, so it blanks a value that is perfectly well known.
  // This provider resolves once and never refreshes, so the two behave
  // identically here, and using the form that is correct under refresh is what
  // stops the wrong one being copied to somewhere it matters.
  //
  // Null renders as no row at all. A number that has not arrived is not a
  // number, and "Loading" in a value slot reads as a stuck screen.
  final versionAsync = ref.watch(appVersionProvider);
  final version = versionAsync.hasValue ? versionAsync.requireValue : null;

  return [
    // ── System (hands off to Android) ──────────────────────────────
    SettingsGroup(
      label: context.t('settings.systemOpensAndroidSettings'),
      query: q,
      rows: [
        FilterRow(
          const ['default launcher', 'home app', 'set default'],
          SettingsRow(
            icon: Icons.home_outlined,
            title: context.t('settings.setAsDefaultLauncher'),
            trailing: const SysBadge(),
            onTap: api.requestDefaultLauncher,
          ),
        ),
        FilterRow(
          const ['notifications', 'access', 'permissions'],
          SettingsRow(
            icon: Icons.notifications_outlined,
            title: context.t('settings.notificationsAccess'),
            trailing: const SysBadge(),
            onTap: () => api.openAndroidSettings(
              'android.settings.APP_NOTIFICATION_SETTINGS',
            ),
          ),
        ),
      ],
    ),

    // ── Maintenance ────────────────────────────────────────────────
    // ── Language ───────────────────────────────────────────────────
    //
    // MOVED OFF THE LANDING, where it was a group of one sitting between the
    // five section rows and System. Language is a property of the person
    // rather than of a distro, which is the argument for it being global; it
    // is not an argument for it being the only leaf on a page whose job is
    // routing. Here it sits with the other things the phone owns.
    SettingsGroup(
      label: context.t('settings.language.title'),
      query: q,
      rows: [
        FilterRow(
          const ['language', 'idioma', 'locale', 'translate', 'lugha'],
          SettingsRow(
            icon: Icons.language_outlined,
            accent: true,
            title: context.t('settings.language.title'),
            subtitle: ref.watch(i18nProvider).selectedLocale?.nativeName ??
                context.t('settings.language.system'),
            trailing: const Chevron(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LanguageSettingsPage(),
              ),
            ),
          ),
        ),
      ],
    ),

    SettingsGroup(
      label: context.t('settings.maintenance'),
      query: q,
      rows: [
        FilterRow(
          const ['rebuild icon cache', 'icons', 'stale', 'cache'],
          SettingsRow(
            icon: Icons.refresh,
            title: context.t('settings.rebuildIconCache'),
            subtitle: context.t('settings.ifIconsLookWrong'),
            trailing: const Chevron(),
            onTap: () async {
              await api.clearIconCache();
              if (context.mounted) {
                context.showMessage(context.t('settings.iconCacheCleared'));
              }
            },
          ),
        ),
        FilterRow(
          const ['backup', 'export', 'restore', 'drive', 'transfer', 'new phone'],
          SettingsRow(
            icon: Icons.backup_outlined,
            title: 'Backup',
            subtitle: 'Save your settings, or bring them to a new phone',
            trailing: const Chevron(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
            ),
          ),
        ),
        FilterRow(
          const ['restore', 'defaults', 'reset', 'sections'],
          SettingsRow(
            icon: Icons.settings_backup_restore,
            title: 'Restore defaults',
            subtitle: 'One section at a time, or everything',
            trailing: const Chevron(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RestoreScreen(),
              ),
            ),
          ),
        ),
        FilterRow(
          ['reset', 'defaults', theme.spec.name.toLowerCase()],
          SettingsRow(
            icon: Icons.settings_backup_restore,
            title: context.t('settings.resetDistro', {'name': theme.spec.name}),
            // Per-theme, per §5.3 — resetting Ubuntu must not touch KDE.
            subtitle: context.t('settings.layoutIconShapeAnd'),
            trailing: const Chevron(),
            onTap: () => confirmReset(context, notifier, theme),
          ),
        ),
      ],
    ),

    // ── About ──────────────────────────────────────────────────────
    //
    // The first group on this page that is about the APP rather than about the
    // phone or about a distro. It is two rows and it is at the bottom, which is
    // where a version number belongs: nobody comes looking for it until
    // something has gone wrong, and then they know to scroll.
    //
    // The version row is ABSENT until the number resolves, rather than showing
    // a placeholder. Same rule the device stats follow: a figure that is not
    // measured yet is not a figure, and "Loading" in a value slot reads as a
    // stuck screen.
    SettingsGroup(
      label: context.t('settings.about'),
      query: q,
      rows: [
        if (version != null)
          FilterRow(
            const ['version', 'about', 'g launcher'],
            SettingsRow(
              icon: Icons.info_outline,
              // NOT translated, and not a missed key. It is the product name.
              title: 'G Launcher',
              trailing: _MutedValue(version),
            ),
          ),
        const FilterRow(
          ['update', 'updates', 'play', 'upgrade', 'new version'],
          _UpdateRow(),
        ),
      ],
    ),
  ];
}

/// A value with no chevron, for a row that reports and does not navigate.
///
/// [ValueLabel] and [ValueChevron] both carry a disclosure arrow, which is a
/// promise that tapping goes somewhere. The version row goes nowhere.
class _MutedValue extends StatelessWidget {
  const _MutedValue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = SettingsSkin.of(context);
    return Text(text, style: TextStyle(color: s.mut, fontSize: 12.5));
  }
}

/// Check for updates, in whichever of the seven states it is in.
///
/// ─── ITS OWN WIDGET BECAUSE OF WHERE THE SKIN COMES FROM ────────────────────
///
/// The section builder's `context` is the one `_SectionPage.build` was handed,
/// which sits ABOVE the `ThemedScaffold` and therefore above the `ChromeScope`.
/// `SettingsSkin.of` called out there resolves to the bootstrap floor rather
/// than to the live theme, silently, and the row would be painted in the wrong
/// distro's colours. Every row that needs the skin reads it from its own build
/// context, which is what this class exists to have.
class _UpdateRow extends ConsumerWidget {
  const _UpdateRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);

    final check = context.t('settings.update.check');

    final (String title, String? subtitle, String? value, VoidCallback? tap) =
        switch (update.status) {
      UpdateStatus.checking => (
          check,
          context.t('settings.update.checking'),
          null,
          null,
        ),
      UpdateStatus.available => (
          check,
          context.t('settings.update.available'),
          context.t('settings.download'),
          notifier.startDownload,
        ),
      UpdateStatus.downloading => (
          context.t('settings.update.downloading'),
          context.t('settings.update.keepUsing'),
          null,
          null,
        ),
      UpdateStatus.readyToInstall => (
          context.t('settings.update.readyRow'),
          context.t('settings.update.willReload'),
          context.t('settings.update.restart'),
          () => confirmUpdateRestart(context, notifier),
        ),
      // NOT AN ERROR, AND NOT TAPPABLE. Play will not talk to a sideloaded or
      // debug build, which is the permanent condition of every test device and
      // of a de-Googled ROM. A retry button here would fail identically every
      // time it was pressed.
      UpdateStatus.unavailable => (
          check,
          context.t('settings.update.unavailable'),
          null,
          null,
        ),
      UpdateStatus.upToDate => (
          check,
          _checkedAgo(context, update.lastCheckedAt),
          context.t('settings.update.upToDate'),
          notifier.check,
        ),
      UpdateStatus.unknown => (check, null, null, notifier.check),
    };

    return SettingsRow(
      icon: Icons.system_update_alt,
      title: title,
      subtitle: subtitle,
      trailing: value == null ? const SizedBox.shrink() : _MutedValue(value),
      onTap: tap,
    );
  }
}

/// When the last answer came back, in words.
///
/// Null until a check has completed, and rendered as no subtitle at all rather
/// than as "Never". The row already says what it does.
String? _checkedAgo(BuildContext context, DateTime? at) {
  if (at == null) return null;
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 2) return context.t('settings.update.checkedJustNow');
  if (d.inHours < 1) {
    return context.t('settings.update.checkedMinutes', {'n': '${d.inMinutes}'});
  }
  if (d.inHours < 2) return context.t('settings.update.checkedHour');
  if (d.inDays < 1) {
    return context.t('settings.update.checkedHours', {'n': '${d.inHours}'});
  }
  if (d.inDays < 2) return context.t('settings.update.checkedYesterday');
  return context.t('settings.update.checkedDays', {'n': '${d.inDays}'});
}
