import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/prefs_backup.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/wallpaper_collections.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';

/// Back up every setting to a file, and put one back.
///
/// ─── THE FILE IS THEIRS AND GOES WHERE THEY SAY ─────────────────────────────
///
/// Export opens Android's own create-document dialog, so Drive, Downloads, an
/// SD card or their own server are all one tap and none of them are ours. There
/// is no first-party cloud here and there will not be one; the same commitment
/// the rest of the ecosystem makes.
///
/// A save dialog rather than a share sheet, and not only because it removed a
/// dependency conflict: a backup is something you FILE, not something you send,
/// and the share sheet's verbs are all about sending. It also lands the file
/// exactly where the user pointed instead of wherever the receiving app decides
/// to put an attachment, which matters when they come looking in a year.
///
/// See [PrefsBackup] for what the file contains and, more importantly, what it
/// deliberately does not: photos travel as paths, not as images.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// Both actions cross a platform channel and can take a moment on a budget
  /// phone. Without this, a second tap starts a second export.
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final json = await PrefsBackup.encode(
        store: ref.read(prefsStoreProvider),
        repo: ref.read(prefsRepositoryProvider),
        // Awaited here rather than inside the service, so the service takes a
        // plain list and never has to know a provider exists.
        collections: await ref.read(wallpaperCollectionsProvider.future),
      );

      // ── STATIC, NOT `.platform` ──────────────────────────────────────
      //
      // file_picker 12 made `FilePicker` an `abstract final class` whose
      // methods are static, and dropped the `.platform` accessor that fronted
      // the platform interface in 11. Named arguments are unchanged, so this
      // is the whole of the difference.
      //
      // `bytes` is REQUIRED on Android. Without it the plugin returns a path
      // and expects the caller to write there, which cannot work against a
      // SAF document URI; with it, the plugin writes the file itself.
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save backup',
        fileName: PrefsBackup.suggestedFileName(),
        bytes: Uint8List.fromList(utf8.encode(json)),
      );

      // Null is CANCELLED, not failed. A message either way would congratulate
      // someone for backing out.
      if (saved != null && mounted) {
        context.showMessage('Backup saved');
      }
    } catch (e) {
      if (mounted) context.showMessage('Could not create the backup');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // NO type filter, deliberately. Several Android document providers hand
      // back a URI whose display name carries no extension, and a
      // `FileType.custom` filter on 'json' then hides the file the user is
      // looking straight at. The contents are validated below, which is the
      // check that actually matters.
      //
      // `withData` so the BYTES come back, not only a path. file_picker
      // normally copies a picked document into the cache and hands over a real
      // path, but a provider can decline to give one, and a backup that
      // silently fails to import for some file managers and not others is the
      // worst shape this bug could take. The path is the fallback, not the
      // primary.
      //
      // `allowMultiple: false` is EXPLICIT because 12 flipped the default to
      // multiple. This code takes `.first` regardless, so the flip would not
      // have crashed anything; it would have shown a multi-select dialog for
      // an action that can only ever use one file, and silently discarded the
      // rest. A wrong dialog nobody can explain is worse than a compile error.
      //
      // `withData` is deprecated in 12 and still honoured. Kept because it is
      // what guarantees bytes from the providers that decline a path, and the
      // day it goes the path branch below already covers that case, so nothing
      // here has to change with it.
      final picked = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      final file = picked?.files.isNotEmpty == true ? picked!.files.first : null;
      if (file == null) return;

      final bytes = file.bytes;
      final path = file.path;
      final String text;
      if (bytes != null) {
        text = utf8.decode(bytes);
      } else if (path != null) {
        text = await File(path).readAsString();
      } else {
        if (mounted) context.showMessage('Could not read that file');
        return;
      }

      final summary = PrefsBackup.inspect(text);
      if (summary == null) {
        if (mounted) {
          context.showMessage('That is not a G Launcher backup');
        }
        return;
      }

      if (!mounted) return;
      final ok = await ThemedDialog.confirm(
        context,
        title: 'Restore this backup?',
        // SPECIFIC, because this overwrites every setting on the phone. A
        // dialog that just says "Restore backup?" is one nobody can weigh.
        message: 'From ${summary.day}: ${summary.themeCount} '
            '${summary.themeCount == 1 ? 'distro' : 'distros'} and '
            '${summary.collectionCount} '
            '${summary.collectionCount == 1 ? 'collection' : 'collections'}. '
            'Every setting on this phone is replaced. Photos are not carried '
            'in a backup, so a collection restored onto a different phone '
            'comes back with its name and without its images.',
        confirmLabel: 'Restore',
        danger: true,
      );
      if (ok != true) return;

      await PrefsBackup.apply(
        summary.data,
        store: ref.read(prefsStoreProvider),
        repo: ref.read(prefsRepositoryProvider),
      );

      // Invalidated HERE rather than inside apply, so every key is on disk
      // before anything re-reads. Doing it per write would repaint the shell
      // repeatedly through a half-applied state.
      ref.invalidate(globalPrefsProvider);
      ref.invalidate(prefsProvider);
      ref.invalidate(selectedThemeIdProvider);
      ref.invalidate(wallpaperCollectionsProvider);

      if (mounted) context.showMessage('Backup restored');
    } catch (e) {
      if (mounted) context.showMessage('Could not read that file');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    final async = ref.watch(effectiveThemeProvider);
    final name = async.hasValue ? async.requireValue.spec.name : 'this distro';

    return ThemedScaffold(
      title: 'Backup',
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'A backup carries every distro you have set up, not just $name, '
              'along with the settings shared between them and your wallpaper '
              'collections.',
              style: TextStyle(color: c.textFaint),
            ),
          ),
          ThemedListRow(
            icon: Icons.ios_share,
            title: 'Back up settings',
            subtitle: 'Choose where to keep it',
            onTap: _export,
          ),
          ThemedListRow(
            icon: Icons.settings_backup_restore,
            title: 'Restore from a backup',
            subtitle: 'Replaces every setting on this phone',
            onTap: _import,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Text(
              'Photos are not inside the backup, only the list of them. '
              'Restoring onto the same phone finds them again; onto a new one, '
              'your collections come back empty and ready to fill.',
              style: TextStyle(color: c.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}
