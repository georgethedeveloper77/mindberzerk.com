import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/backup_apps.dart';
import '../../data/prefs/backup_store.dart';
import '../../data/prefs/pending_apps.dart';
import '../../data/prefs/prefs_backup.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/wallpaper_collections.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import 'backup_format.dart';
import 'missing_apps_screen.dart';

/// What is in a backup, and which parts of it to put back.
///
/// ─── A SCREEN, NOT A DIALOG ─────────────────────────────────────────────────
///
/// This replaced a confirm dialog whose message ran to four lines and still
/// could not say which distros were in the file. A restore overwrites an hour
/// of somebody's arranging; it earns a page.
///
/// ─── BACK UP EVERYTHING, RESTORE WHAT YOU CHOOSE ────────────────────────────
///
/// Selectivity belongs here and not on the backup side. A backup with parts
/// missing is a trap that only springs months later, when the missing part is
/// the one you needed; a restore with parts left out is a choice made with the
/// contents in front of you. Unticked distros are LEFT ALONE rather than
/// cleared, which is why the button says what it says.
///
/// ─── NOT NAMED RestoreScreen ────────────────────────────────────────────────
///
/// `restore_screen.dart` already exists and restores DEFAULTS. Two screens
/// called Restore in one settings tree is how a wrong import ships.
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({
    super.key,
    required this.record,
    this.completesSetup = false,
  });

  final BackupRecord record;

  /// Opened from the setup wizard rather than from Settings.
  ///
  /// Changes two things and no behaviour: the action says what it will actually
  /// do, and a way out appears that returns to setup rather than to a page the
  /// user has never seen. The restore itself is identical, which is the point
  /// of it being the same screen.
  final bool completesSetup;

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  /// Read once, here, rather than by the list row that opened this screen. The
  /// row has counts from the index; the truth is in the file, and a file can
  /// have gone since the index was last reconciled.
  BackupSummary? _summary;
  bool _loading = true;
  bool _busy = false;

  /// Distro ids ticked for restore. Everything starts ticked: the common case
  /// is wanting the whole backup, and a screen that opens with nothing selected
  /// makes the common case the most work.
  final _selected = <String>{};
  bool _global = true;
  bool _collections = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await ref.read(backupsProvider.notifier).read(widget.record);
    final summary = bytes == null ? null : PrefsBackup.inspect(bytes);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _selected
        ..clear()
        ..addAll(summary?.themeIds ?? const []);
      _loading = false;
    });
  }

  Future<void> _restore(BackupSummary summary) async {
    if (_busy) return;

    final ok = await ThemedDialog.confirm(
      context,
      title: context.t('settings.restoreThisBackup'),
      message: _confirmMessage(summary),
      confirmLabel: context.t('settings.restore'),
      danger: true,
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await PrefsBackup.apply(
        summary,
        store: ref.read(prefsStoreProvider),
        repo: ref.read(prefsRepositoryProvider),
        themeIds: _selected,
        includeGlobal: _global,
        includeCollections: _collections,
      );

      // Invalidated HERE rather than inside apply, so every key is on disk
      // before anything re-reads. Doing it per write would repaint the shell
      // repeatedly through a half-applied state.
      ref.invalidate(globalPrefsProvider);
      ref.invalidate(prefsProvider);
      ref.invalidate(selectedThemeIdProvider);
      ref.invalidate(wallpaperCollectionsProvider);
      ref.invalidate(backupContentsProvider);

      // ─── WRITE DOWN WHAT IS MISSING, BEFORE THE FILE IS GONE ──────────
      //
      // The grid will rebuild in a moment and drop every key it cannot
      // resolve. It has no way to know which of those gaps were deliberate
      // and no way to name them, because the backup that knew is closed by
      // then. This is the only moment both facts are to hand.
      //
      // Installable only. A preinstalled app from another brand's phone can
      // never arrive here, so holding its slot would be a promise nothing can
      // keep.
      final apps = ref.read(appListProvider);
      if (apps.hasValue) {
        final r = reconcileApps(summary, apps.requireValue, themeIds: _selected);
        if (r.installable.isNotEmpty) {
          await ref.read(pendingAppsProvider.notifier).record(r.installable);
        }
      }

      if (!mounted) return;
      context.showMessage(context.t('settings.backupRestored'));
      // TRUE, so a caller can tell a completed restore from a dismissal. Setup
      // uses it to finish; Settings ignores it.
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The button says what it will do, and says so about the current ticks
  /// rather than about the file. Restoring only the shared settings is a real
  /// thing to want, and a button reading "Restore 0 distros" would deny it.
  String get _actionLabel {
    if (_selected.isEmpty && !_global && !_collections) {
      return context.t('settings.backup.nothingSelected');
    }
    // In setup the honest label is what happens next, which is the whole
    // wizard ending. Naming a distro count there would suggest more questions
    // are coming.
    if (widget.completesSetup) return context.t('setup.restore.andFinish');
    if (_selected.isEmpty) return context.t('settings.backup.restoreSettings');
    return plural(context, _selected.length,
        'settings.backup.restoreDistroOne',
        'settings.backup.restoreDistroOther');
  }

  /// Says what is about to be overwritten, and nothing else. The photo caveat
  /// appears only when it is true of THIS file, which is the whole gain of v2:
  /// a backup carrying images has nothing to apologise for.
  String _confirmMessage(BackupSummary summary) {
    final distros = plural(context, _selected.length,
        'settings.backup.distroOne', 'settings.backup.distroOther');
    if (_collections && summary.collectionCount > 0 && summary.photoCount == 0) {
      return context.t('settings.backup.replacesNoPictures', {'what': distros});
    }
    return context.t('settings.backup.replaces', {'what': distros});
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return ThemedScaffold(
      title: context.t('settings.restore'),
      body: _loading
          ? const Center(child: ThemedProgress.circular())
          : summary == null
              ? _Unreadable(message: context.t('settings.couldNotReadThat'))
              : _body(summary),
    );
  }

  Widget _body(BackupSummary summary) {
    final r = widget.record;

    return ListView(
      // Clears the navigation bar. Trailing padding rather than a SafeArea, so
      // the list still scrolls behind a transparent bar.
      padding: EdgeInsets.only(bottom: context.bottomInset),
      children: [
        _SourceCard(record: r, summary: summary),

        ThemedSectionHeader(
          plural(context, summary.themeIds.length,
              'settings.backup.distroInFileOne',
              'settings.backup.distroInFileOther'),
        ),
        ThemedListCard(children: [
          for (final id in summary.themeIds)
            ThemedListRow(
              icon: Icons.grid_view,
              title: summary.nameOf(id),
              enabled: !_busy,
              onTap: () => setState(() {
                if (!_selected.remove(id)) _selected.add(id);
              }),
              trailing: ThemedToggle(
                value: _selected.contains(id),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          if (v) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        }),
              ),
            ),
        ]),

        _Apps(summary: summary, themeIds: _selected),

        ThemedSectionHeader(context.t('settings.backup.alsoInFile')),
        ThemedListCard(children: [
          ThemedListRow(
            icon: Icons.tune,
            title: context.t('settings.backup.sharedSettings'),
            subtitle: context.t('settings.backup.sharedSettingsSubtitle'),
            enabled: !_busy,
            trailing: ThemedToggle(
              value: _global,
              onChanged: _busy ? null : (v) => setState(() => _global = v),
            ),
          ),
          // Absent rather than shown empty when the file has no collections at
          // all, per the rule that an absent thing is an absent row.
          if (summary.collectionCount > 0)
            ThemedListRow(
              icon: Icons.photo_outlined,
              title: plural(context, summary.collectionCount,
                  'settings.backup.collectionOne',
                  'settings.backup.collectionOther'),
              // The one place the photo distinction has to be stated, because
              // it changes what the person gets.
              subtitle: summary.photoCount > 0
                  ? plural(context, summary.photoCount,
                      'settings.backup.pictureIncludedOne',
                      'settings.backup.pictureIncludedOther')
                  : context.t('settings.backup.namesOnlyNoPictures'),
              enabled: !_busy,
              trailing: ThemedToggle(
                value: _collections,
                onChanged:
                    _busy ? null : (v) => setState(() => _collections = v),
              ),
            ),
        ]),

        if (widget.completesSetup)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ThemedButton(
              label: context.t('setup.restore.freshInstead'),
              kind: ThemedButtonKind.text,
              expand: true,
              // Back to WELCOME, not onward to the distro step. The home role
              // gate runs on the way out of welcome, and entering setup past it
              // would let someone finish the wizard having never been asked to
              // make this the home app. Nothing has been written at this point,
              // so backing out costs the user nothing either.
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: ThemedButton(
            label: _actionLabel,
            kind: ThemedButtonKind.danger,
            expand: true,
            onPressed: _busy ||
                    (_selected.isEmpty && !_global && !_collections)
                ? null
                : () => _restore(summary),
          ),
        ),
      ],
    );
  }
}

/// Which apps this layout expects, and which of them are here.
///
/// Recomputed against the CURRENT selection, so unticking a distro drops the
/// apps only that distro placed. Watching [appListProvider] means installing
/// something in another window updates these counts on return without the
/// screen doing anything.
class _Apps extends ConsumerWidget {
  const _Apps({required this.summary, required this.themeIds});

  final BackupSummary summary;
  final Set<String> themeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(appListProvider);
    if (!apps.hasValue) return const SizedBox.shrink();

    final r = reconcileApps(
      summary,
      apps.requireValue,
      themeIds: themeIds,
    );
    // Nothing placed, or a selection with no distros in it. An empty section
    // heading over an empty card is worse than no section.
    if (r.isEmpty) return const SizedBox.shrink();

    final missing = r.installable.length + r.unavailable.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ThemedSectionHeader(context.t('settings.backup.appsInLayouts')),
        ThemedListCard(children: [
          if (r.installed.isNotEmpty)
            ThemedListRow(
              icon: Icons.check_circle,
              title: plural(context, r.installed.length,
                  'settings.backup.appHereOne', 'settings.backup.appHereOther'),
              subtitle: context.t('settings.backup.placedAsTheyWere'),
            ),
          if (missing > 0)
            ThemedListRow(
              icon: Icons.download,
              title: plural(context, missing, 'settings.backup.appMissingOne',
                  'settings.backup.appMissingOther'),
              // The split is the useful part: eight you can go and get reads
              // very differently from eleven you cannot.
              subtitle: r.unavailable.isEmpty
                  ? context.t('settings.backup.spotsKept')
                  : context.t('settings.backup.installableAndNot', {
                      'installable': '${r.installable.length}',
                      'unavailable': '${r.unavailable.length}',
                    }),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MissingAppsScreen(
                    installable: r.installable,
                    unavailable: r.unavailable,
                  ),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: 18,
                color: ChromeScope.of(context).colors.textFaint,
              ),
            ),
        ]),
      ],
    );
  }
}

/// Where the file came from, when it was taken, and how big it is.
class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.record, required this.summary});

  final BackupRecord record;
  final BackupSummary summary;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    // The device name is stamped by v2 only. For a v1 file, or one whose
    // encoder could not read it, the line is simply the date: better a shorter
    // true sentence than "Unknown device", which reads as a fault.
    final from = summary.device;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            record.imported ? Icons.phonelink_ring : Icons.smartphone,
            size: 22,
            color: c.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  from == null
                      ? context.t('settings.backup.takenOn',
                          {'when': dayLabel(context, record.takenAt)})
                      : context.t('settings.backup.fromDeviceOn', {
                          'device': from,
                          'when': dayLabel(context, record.takenAt),
                        }),
                  style: d.text.body
                      .copyWith(color: c.text, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(sizeLabel(context, record.sizeBytes),
                    style: d.text.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The file is one of ours by extension but not by contents, or it has gone
/// since the list drew it.
class _Unreadable extends StatelessWidget {
  const _Unreadable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: d.text.body.copyWith(color: d.colors.textMuted),
        ),
      ),
    );
  }
}
