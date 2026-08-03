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
  ];
}
