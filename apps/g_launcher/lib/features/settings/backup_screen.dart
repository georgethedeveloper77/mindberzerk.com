import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/backup_schedule.dart';
import '../../data/prefs/backup_store.dart';
import '../../data/prefs/prefs_backup.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/wallpaper_collections.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import 'backup_format.dart';
import 'backup_restore_screen.dart';

/// Back up every setting, and put one back.
///
/// ─── STATE FIRST, ACTIONS SECOND ────────────────────────────────────────────
///
/// The page this replaced opened with three paragraphs explaining what a backup
/// contains and led with two verbs. Nobody arriving here is asking what a
/// backup is; they are asking whether they have one. So it opens with the
/// answer, and every line below it is a name or a number rather than a
/// sentence. The explanations moved to the moment they matter: what a restore
/// replaces is said on the restore screen, not as a preamble here.
///
/// ─── BACKING UP DOES NOT OPEN A PICKER ──────────────────────────────────────
///
/// "Back up now" writes into app storage through [BackupsNotifier] and nothing
/// else. Choosing a folder every single time is the friction that stops people
/// backing up at all, and a saved copy the launcher can read back is the only
/// kind that can fill a list of restorable backups. See [BackupRecord] for why
/// a list of SAF destinations cannot do that job.
///
/// Exporting is therefore a separate act on a file that already exists, and it
/// is still the user's own document picker with no first-party cloud behind it.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// Every action here crosses either storage or a platform channel and can
  /// take a moment on a budget phone. Without this, a second tap starts a
  /// second backup.
  bool _busy = false;

  /// Whether a sent copy leaves the wallpapers behind.
  ///
  /// SCREEN STATE, not a stored preference, and separate from the wallpaper
  /// switch on the page. Those answer different questions: what a backup keeps,
  /// and what is small enough to get through whatever channel this particular
  /// send is going down. 28 MB is fine over Quick Share and refused by most
  /// messaging apps, and only the person sending knows which this is.
  bool _sendSettingsOnly = true;

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── BACK UP ──────────────────────────────────────────────────────────────

  Future<void> _backUp() => _guard(() async {
        final record = await ref.read(backupsProvider.notifier).create();
        if (!mounted) return;
        context.showMessage(
          record == null
              ? context.t('settings.backup.failed')
              : context.t('settings.backup.done'),
        );
      });

  /// Copy the newest backup out to wherever the user keeps things.
  ///
  /// A save dialog rather than a share sheet: a backup is something you file,
  /// not something you send, and it lands exactly where the user pointed rather
  /// than wherever a receiving app decides to put an attachment.
  Future<void> _export(BackupRecord record) => _guard(() async {
        // Read BEFORE the first await. This is the dialog's title, so it is
        // wanted regardless of what happens to this widget in the meantime,
        // and a `mounted` guard after the read would mean a rebuild during it
        // silently cancels the save the user asked for.
        final title = context.t('settings.backup.saveCopy');

        final bytes = await ref.read(backupsProvider.notifier).read(record);
        if (bytes == null) {
          if (mounted) {
            context.showMessage(context.t('settings.backup.gone'));
          }
          return;
        }

        // ── STATIC, NOT `.platform` ─────────────────────────────────────
        //
        // file_picker 12 made `FilePicker` an `abstract final class` whose
        // methods are static, and dropped the `.platform` accessor that fronted
        // the platform interface in 11.
        //
        // `bytes` is REQUIRED on Android. Without it the plugin returns a path
        // and expects the caller to write there, which cannot work against a
        // SAF document URI; with it, the plugin writes the file itself. That
        // also means a multi-megabyte v2 container crosses the channel in one
        // piece rather than being streamed, which is the cost of not owning
        // the write.
        final saved = await FilePicker.saveFile(
          dialogTitle: title,
          fileName: PrefsBackup.suggestedFileName(),
          bytes: bytes,
        );

        // Null is CANCELLED, not failed. A message either way would
        // congratulate someone for backing out.
        if (saved != null && mounted) {
          context.showMessage(context.t('settings.backup.copySaved'));
        }
      });

  /// Hand a copy to Android's share sheet.
  ///
  /// ─── ENCODED FRESH, AND NEVER RECORDED ────────────────────────────────
  ///
  /// Not the newest snapshot re-read, because a settings-only send is a
  /// different file rather than a filtered one, and because the thing worth
  /// sending is the setup as it is right now.
  ///
  /// The result does not go into the snapshot store. A sent file is a copy in
  /// flight: listing it would claim this phone is protected by something that
  /// has left, and the status card would start counting a backup nobody here
  /// can restore from.
  Future<void> _send() => _guard(() async {
        final Uint8List bytes;
        try {
          bytes = await PrefsBackup.encode(
            store: ref.read(prefsStoreProvider),
            repo: ref.read(prefsRepositoryProvider),
            collections: await ref.read(wallpaperCollectionsProvider.future),
            includeWallpapers: !_sendSettingsOnly,
            deviceLabel: await ref.read(deviceLabelProvider.future),
            installedApps: const {},
          );
        } catch (_) {
          if (mounted) {
            context.showMessage(context.t('settings.backup.prepareFailed'));
          }
          return;
        }

        final ok = await ref
            .read(launcherHostApiProvider)
            .shareBackup(PrefsBackup.suggestedFileName(), bytes);

        // False is "nothing on this phone can take a file", which is a real
        // state on a stripped ROM. Dismissing the sheet is not false, so this
        // never fires for a user who simply changed their mind.
        if (!ok && mounted) {
          context.showMessage(context.t('settings.backup.sendFailed'));
        }
      });

  // ── OPEN ─────────────────────────────────────────────────────────────────

  /// Read a backup from anywhere, keep a copy, and open it for restore.
  ///
  /// The copy is taken BEFORE the restore screen appears, and kept whether or
  /// not a restore follows. A file opened once should still be in the list
  /// tomorrow, and the picker's own path cannot be relied on to find it again.
  Future<void> _open() => _guard(() async {
        // NO type filter, deliberately. Several Android document providers hand
        // back a URI whose display name carries no extension, and a
        // `FileType.custom` filter would then hide the file the user is looking
        // straight at. Worse now than in v1: `.glbak` is ours alone, so a
        // provider that classifies by extension has nothing to match. The
        // contents are sniffed below, which is the check that actually matters.
        //
        // ─── pickFile, AND readAsBytes RATHER THAN `bytes` ──────────────
        //
        // `pickFile` forces `withData: false` internally, so `file.bytes` is
        // always null on this path. `readAsBytes` reads through the SAF-backed
        // XFile rather than through a cached path, so a provider that refuses
        // to give a path is still served. That refusal is the whole reason the
        // old path fallback existed, and the reason it is gone rather than
        // kept alongside.
        final file = await FilePicker.pickFile(type: FileType.any);
        if (file == null) return;

        final bytes = Uint8List.fromList(await file.readAsBytes());
        final summary = PrefsBackup.inspect(bytes);
        if (summary == null) {
          if (mounted) context.showMessage(context.t('settings.thatIsNotA'));
          return;
        }

        final record =
            await ref.read(backupsProvider.notifier).adopt(bytes, summary);
        if (!mounted) return;
        if (record == null) {
          context.showMessage(context.t('settings.couldNotReadThat'));
          return;
        }
        _openRestore(record);
      });

  void _openRestore(BackupRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BackupRestoreScreen(record: record),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final backups = ref.watch(backupsProvider);
    final records =
        backups.hasValue ? backups.requireValue : const <BackupRecord>[];

    // Null while loading, so the inventory rows stay absent rather than
    // rendering zeroes for the half second before the counts arrive.
    final async = ref.watch(backupContentsProvider);
    final contents = async.hasValue ? async.requireValue : null;

    // Same hasValue / requireValue pair the rest of the tree uses. Riverpod 3
    // has no `valueOrNull`.
    final scheduleAsync = ref.watch(backupScheduleProvider);
    final schedule = scheduleAsync.hasValue ? scheduleAsync.requireValue : null;

    final wallpapers = ref.watch(includeWallpapersProvider);
    final withPhotos = wallpapers.hasValue && wallpapers.requireValue;

    return ThemedScaffold(
      title: context.t('settings.backup'),
      body: ListView(
        // Clears the navigation bar. Trailing padding rather than a SafeArea,
        // so the list still scrolls behind a transparent bar.
        padding: EdgeInsets.only(bottom: context.bottomInset),
        children: [
          _StatusCard(
            latest: records.isEmpty ? null : records.first,
            busy: _busy,
            onBackUp: _backUp,
            onExport: records.isEmpty ? null : () => _export(records.first),
          ),
          _Sending(
            settingsOnly: _sendSettingsOnly,
            busy: _busy,
            onSettingsOnly: (v) => setState(() => _sendSettingsOnly = v),
            onSend: _send,
          ),
          _Schedule(
            schedule: schedule,
            busy: _busy,
            onEnabled: (v) =>
                ref.read(backupScheduleProvider.notifier).setEnabled(v),
            onFrequency: (f) =>
                ref.read(backupScheduleProvider.notifier).setFrequency(f),
          ),
          if (contents != null)
            _Contents(
              contents: contents,
              withPhotos: withPhotos,
              busy: _busy || !wallpapers.hasValue,
              onWallpapers: (v) =>
                  ref.read(includeWallpapersProvider.notifier).set(v),
            ),
          if (records.isNotEmpty) ...[
            ThemedSectionHeader(context.t('settings.backup.found')),
            ThemedListCard(children: [
              for (final r in records)
                ThemedListRow(
                  icon: r.imported ? Icons.phonelink_ring : Icons.smartphone,
                  title: _titleOf(context, r),
                  subtitle: _subtitleOf(context, r),
                  enabled: !_busy,
                  onTap: () => _openRestore(r),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: ChromeScope.of(context).colors.textFaint,
                  ),
                ),
            ]),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: ThemedButton(
              label: context.t('settings.backup.openFile'),
              icon: Icons.folder_open,
              kind: ThemedButtonKind.secondary,
              expand: true,
              onPressed: _busy ? null : _open,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ROW COPY ───────────────────────────────────────────────────────────────

/// The device name when the file carries one, which v2 stamps and v1 never
/// did. An imported v1 file therefore reads "Opened file", which is true and
/// short, rather than guessing at a phone it cannot know.
String _titleOf(BuildContext c, BackupRecord r) {
  final when = dayLabel(c, r.takenAt);
  if (!r.imported) {
    return c.t('settings.backup.thisPhoneOn', {'when': when});
  }
  return r.device == null
      ? c.t('settings.backup.openedFileOn', {'when': when})
      : c.t('settings.backup.deviceOn', {'device': r.device!, 'when': when});
}

String _subtitleOf(BuildContext c, BackupRecord r) {
  final parts = <String>[
    plural(c, r.themeCount, 'settings.backup.distroOne',
        'settings.backup.distroOther'),
    if (r.carriesPhotos)
      plural(c, r.photoCount, 'settings.backup.pictureOne',
          'settings.backup.pictureOther'),
    sizeLabel(c, r.sizeBytes),
  ];
  // Joined with a plain comma. A locale needing a different separator can put
  // one inside each phrase; a list separator key would be one more thing to
  // translate for a gain nobody can see.
  return parts.join(', ');
}

// ── AUTOMATIC BACKUP ───────────────────────────────────────────────────────

/// The switch, and the three intervals behind it.
///
/// Retention is stated rather than offered. Five is right for almost everyone,
/// and a picker here would be a setting whose only honest description is a
/// number the person has no basis to change.
class _Schedule extends StatelessWidget {
  const _Schedule({
    required this.schedule,
    required this.busy,
    required this.onEnabled,
    required this.onFrequency,
  });

  /// Null while the stored schedule loads. The switch renders in its stored
  /// position or not at all; a switch that flicks from off to on half a second
  /// after the page opens reads as the app changing a setting by itself.
  final BackupSchedule? schedule;

  final bool busy;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<BackupFrequency> onFrequency;

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    if (s == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ThemedSectionHeader(context.t('settings.backup.automatic')),
        ThemedListCard(children: [
          ThemedListRow(
            icon: Icons.schedule,
            title: context.t('settings.backup.keepUpToDate'),
            subtitle: _subtitle(context, s),
            enabled: !busy,
            trailing: ThemedToggle(
              value: s.enabled,
              onChanged: busy ? null : onEnabled,
            ),
          ),
          if (s.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  for (final f in BackupFrequency.values) ...[
                    Expanded(
                      child: ThemedButton(
                        label: _label(context, f),
                        expand: true,
                        // Selection by variant rather than by a custom
                        // segmented control: the chrome already defines what
                        // chosen and unchosen look like in every distro, and a
                        // new control would have to redefine both.
                        kind: f == s.frequency
                            ? ThemedButtonKind.primary
                            : ThemedButtonKind.secondary,
                        onPressed: busy ? null : () => onFrequency(f),
                      ),
                    ),
                    if (f != BackupFrequency.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ThemedListRow(
            icon: Icons.layers_outlined,
            title: context.t('settings.backup.retention'),
          ),
        ]),
      ],
    );
  }

  static String _label(BuildContext c, BackupFrequency f) => switch (f) {
        BackupFrequency.daily => c.t('settings.backup.daily'),
        BackupFrequency.weekly => c.t('settings.backup.weekly'),
        BackupFrequency.onChange => c.t('settings.backup.onChange'),
      };

  /// Status, not explanation. "Off" is the whole sentence when it is off.
  static String _subtitle(BuildContext c, BackupSchedule s) {
    if (!s.enabled) return c.t('settings.backup.off');
    final last = s.lastRunAt;
    final when = switch (s.frequency) {
      BackupFrequency.daily => c.t('settings.backup.everyDay'),
      BackupFrequency.weekly => c.t('settings.backup.everyWeek'),
      BackupFrequency.onChange => c.t('settings.backup.onAnyChange'),
    };
    return last == null
        ? when
        : c.t('settings.backup.checked',
            {'freq': when, 'ago': agoLabel(c, last)});
  }
}

// ── SENDING ────────────────────────────────────────────────────────────────

/// Send a copy to another phone.
///
/// ─── THE LAUNCHER DOES NOT MOVE THE FILE ────────────────────────────────────
///
/// Android already has a transport, and it is better than anything worth
/// building here: the share sheet carries Quick Share, Bluetooth, and every
/// messaging app, and Quick Share reaches a Samsung from an Infinix and back.
///
/// Writing our own would mean NEARBY_WIFI_DEVICES or BLUETOOTH_CONNECT and
/// BLUETOOTH_SCAN as runtime permissions, a pairing step, discovery, and a wire
/// protocol, to arrive somewhere worse. A launcher that sells itself on not
/// wanting anything asking for nearby-devices access to do what the share sheet
/// already does is a bad trade twice over.
class _Sending extends StatelessWidget {
  const _Sending({
    required this.settingsOnly,
    required this.busy,
    required this.onSettingsOnly,
    required this.onSend,
  });

  final bool settingsOnly;
  final bool busy;
  final ValueChanged<bool> onSettingsOnly;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ThemedSectionHeader(context.t('settings.backup.sendTitle')),
        ThemedListCard(children: [
          ThemedListRow(
            icon: Icons.folder_zip_outlined,
            title: context.t('settings.backup.settingsOnly'),
            // Says what is left out rather than what is included, because the
            // reason to leave it on is the size and the reason to turn it off
            // is the pictures.
            subtitle: settingsOnly
                ? context.t('settings.backup.noPictures')
                : context.t('settings.backup.picturesIncluded'),
            enabled: !busy,
            trailing: ThemedToggle(
              value: settingsOnly,
              onChanged: busy ? null : onSettingsOnly,
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ThemedButton(
            label: context.t('settings.backup.send'),
            icon: Icons.ios_share,
            kind: ThemedButtonKind.secondary,
            expand: true,
            onPressed: busy ? null : onSend,
          ),
        ),
      ],
    );
  }
}

// ── WHAT GOES IN ───────────────────────────────────────────────────────────

/// The inventory, and the one switch that changes it.
class _Contents extends StatelessWidget {
  const _Contents({
    required this.contents,
    required this.withPhotos,
    required this.busy,
    required this.onWallpapers,
  });

  final BackupContents contents;
  final bool withPhotos;
  final bool busy;
  final ValueChanged<bool> onWallpapers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ThemedSectionHeader(context.t('settings.backup.whatGoesIn')),
        ThemedListCard(children: [
          ThemedListRow(
            icon: Icons.grid_view,
            title: plural(context, contents.distroCount,
                'settings.backup.distroOne', 'settings.backup.distroOther'),
            subtitle: context.t('settings.backup.layoutsSubtitle'),
          ),
          ThemedListRow(
            icon: Icons.tune,
            title: context.t('settings.backup.sharedSettings'),
            subtitle: context.t('settings.backup.sharedSettingsSubtitle'),
          ),
          // Absent rather than shown empty when there is nothing to carry, per
          // the rule that an absent thing is an absent row.
          if (contents.collectionCount > 0)
            ThemedListRow(
              icon: Icons.photo_outlined,
              title: context.t('settings.backup.wallpaperFiles'),
              // The size is MEASURED by stat, never estimated, and it is the
              // number that justifies the switch existing at all: this is the
              // difference between a file you can message to yourself and one
              // you cannot.
              subtitle: withPhotos
                  ? '${plural(context, contents.photoCount, 'settings.backup.pictureOne', 'settings.backup.pictureOther')}, ${sizeLabel(context, contents.photoBytes)}'
                  : context.t('settings.backup.namesOnlySamePhone'),
              enabled: !busy,
              trailing: ThemedToggle(
                value: withPhotos,
                onChanged: busy ? null : onWallpapers,
              ),
            ),
        ]),
      ],
    );
  }
}

// ── STATUS CARD ────────────────────────────────────────────────────────────

/// The answer to the only question anyone opens this page with.
///
/// Not a [ThemedListRow]: a row is a thing you tap, and this is a thing you
/// read. It carries the state, the size, and the two actions that act on that
/// state, so the rest of the page can be nothing but names and numbers.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.latest,
    required this.busy,
    required this.onBackUp,
    required this.onExport,
  });

  final BackupRecord? latest;
  final bool busy;
  final VoidCallback onBackUp;

  /// Null when there is nothing to copy out yet, which renders the button
  /// disabled rather than hiding it and moving the primary action around.
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final r = latest;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                r == null ? Icons.shield_outlined : Icons.verified_user,
                size: 22,
                // Green would need a semantic token this chrome does not carry.
                // The accent is the distro's own, which reads as "good" inside
                // a theme that may be any colour at all.
                color: r == null ? c.textMuted : c.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r == null
                          ? context.t('settings.backup.none')
                          : context.t('settings.backup.lastRun',
                              {'ago': agoLabel(context, r.savedAt)}),
                      style: d.text.body.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (r != null) ...[
                      const SizedBox(height: 2),
                      Text(_subtitleOf(context, r), style: d.text.caption),
                    ],
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: ThemedProgress.circular(size: 18, strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ThemedButton(
                  label: context.t('settings.backup.backUpNow'),
                  expand: true,
                  onPressed: busy ? null : onBackUp,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ThemedButton(
                  label: context.t('settings.backup.saveCopy'),
                  kind: ThemedButtonKind.secondary,
                  expand: true,
                  onPressed: busy ? null : onExport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
