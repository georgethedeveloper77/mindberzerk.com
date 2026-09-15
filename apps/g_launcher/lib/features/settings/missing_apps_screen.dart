import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/backup_apps.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import 'backup_format.dart';

/// The apps a restored layout expects and this phone does not have.
///
/// ─── A CHECKLIST, BECAUSE ANDROID HAS NO BULK INSTALL ───────────────────────
///
/// There is no sanctioned way to hand Play a list of packages and get them all.
/// The APIs that can do it belong to device-owner setup flows, which a launcher
/// installed from the store is not and should not pretend to be.
///
/// So this is eleven trips to Play, and the only thing worth designing is
/// making the trips cheap: the list stays put, each row opens Play directly at
/// that app, and coming back marks it done without anybody tapping anything.
///
/// ─── WHICH IS WHY IT WATCHES THE APP LIST ───────────────────────────────────
///
/// `AppChangeWatcher` already pushes the full list to Dart on every install,
/// and [appListProvider] already holds it. Watching that is the entire
/// completion mechanism: an app that arrives while this screen is open moves
/// itself to done between frames. No polling, no manual refresh, and no
/// "I installed it" button that can be pressed dishonestly.
class MissingAppsScreen extends ConsumerWidget {
  const MissingAppsScreen({
    super.key,
    required this.installable,
    required this.unavailable,
  });

  /// Not here, and worth offering Play for.
  final List<BackupApp> installable;

  /// Not here, and preinstalled on the phone that made the backup. An OEM app
  /// from another brand is not for sale anywhere.
  final List<BackupApp> unavailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(appListProvider);
    final here = apps.hasValue
        ? {for (final a in apps.requireValue) a.packageName}
        : const <String>{};

    final waiting =
        installable.where((a) => !here.contains(a.packageName)).toList();
    final done =
        installable.where((a) => here.contains(a.packageName)).toList();

    return ThemedScaffold(
      title: context.t('settings.apps'),
      body: ListView(
        padding: EdgeInsets.only(bottom: context.bottomInset),
        children: [
          if (waiting.isNotEmpty) ...[
            ThemedSectionHeader(
              plural(context, waiting.length, 'settings.backup.appToGetOne',
                  'settings.backup.appToGetOther'),
            ),
            ThemedListCard(children: [
              for (final app in waiting)
                ThemedListRow(
                  icon: Icons.download,
                  title: app.label,
                  subtitle: app.packageName,
                  onTap: () => _open(context, ref, app),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: ChromeScope.of(context).colors.textFaint,
                  ),
                ),
            ]),
          ],

          // Absent until something is actually done, rather than an empty
          // heading sitting there from the moment the screen opens.
          if (done.isNotEmpty) ...[
            ThemedSectionHeader(
              plural(context, done.length, 'settings.backup.appInstalledOne',
                  'settings.backup.appInstalledOther'),
            ),
            ThemedListCard(children: [
              for (final app in done)
                ThemedListRow(
                  icon: Icons.check_circle,
                  title: app.label,
                  enabled: false,
                ),
            ]),
          ],

          if (unavailable.isNotEmpty) ...[
            ThemedSectionHeader(
              plural(context, unavailable.length,
                  'settings.backup.appUnavailableOne',
                  'settings.backup.appUnavailableOther'),
            ),
            ThemedListCard(children: [
              for (final app in unavailable)
                ThemedListRow(
                  icon: Icons.block,
                  title: app.label,
                  // The reason, in three words, because this is the one bucket
                  // where the person will otherwise go looking and not find it.
                  subtitle: context.t('settings.backup.builtIntoOtherPhone'),
                  enabled: false,
                ),
            ]),
          ],
        ],
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    BackupApp app,
  ) async {
    final ok = await ref.read(openPlayListingProvider)(app.packageName);
    if (!context.mounted) return;
    // False means neither the Play app nor a browser took it, which is a real
    // state on a de-Googled ROM. Saying so beats a tap that does nothing.
    if (!ok) context.showMessage(context.t('settings.backup.noPlay'));
  }
}
