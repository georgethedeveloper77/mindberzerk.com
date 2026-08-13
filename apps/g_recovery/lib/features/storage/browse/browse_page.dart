import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/category_colors.dart';
import '../../../app/theme/tokens.dart';
import '../../../bridge/storage_api.g.dart';
import '../../../core/format.dart';
import '../../../ui/g_app_bar.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_enter.dart';
import '../../learn/chapter_page.dart';
import '../../learn/learn_page.dart';
import '../state/storage_providers.dart';
import 'folder_notes.dart';
import '../../../core/i18n/g_strings.dart';

/// One level of the real filesystem.
final browseProvider = FutureProvider.family<List<DirEntry>, String?>(
  (Ref ref, String? path) =>
      ref.watch(storageBridgeProvider).listDirectory(path),
);

/// Whether dot folders are shown. Off by default, on when the user asks.
class HiddenController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final NotifierProvider<HiddenController, bool> showHiddenProvider =
    NotifierProvider<HiddenController, bool>(HiddenController.new);

/// BROWSING THE PHONE, AND LEARNING IT.
///
/// This replaces nothing and completes something. Learn already had chapters on
/// scoped storage, the trash and Android/data, and no route into them from a
/// moment when a person is actually curious. Standing in a folder is that
/// moment.
///
/// ─── IT SHOWS WHAT IS THERE, NOT WHAT IS INDEXED ─────────────────────────────
///
/// Every other list in this app comes from MediaStore. This one reads the disk,
/// so it includes the zip a file manager wrote, the folders no app registered,
/// and the two directories Android refuses to open. A browser that quietly
/// omitted those would teach a filesystem that does not exist.
///
/// ─── THE LOCKED FOLDER IS THE POINT ──────────────────────────────────────────
///
/// Android/data appears, greyed, with a padlock and one line saying why. It is
/// the same folder that makes a deleted chat message unrecoverable, so seeing it
/// closed explains the recovery limits better than the page about them does.
class BrowsePage extends ConsumerWidget {
  const BrowsePage({super.key, this.path, this.title});

  /// Null at the roots.
  final String? path;
  final String? title;

  static Route<void> route({String? path, String? title}) =>
      MaterialPageRoute<void>(
        builder: (BuildContext context) => BrowsePage(path: path, title: title),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final bool showHidden = ref.watch(showHiddenProvider);
    final AsyncValue<List<DirEntry>> listing = ref.watch(browseProvider(path));

    final List<DirEntry> all = listing.value ?? const <DirEntry>[];
    final List<DirEntry> entries = showHidden
        ? all
        : all.where((DirEntry e) => !e.hidden).toList();
    final int hiddenCount = all.length - entries.length;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            0,
            GSpace.gutter,
            GSpace.xl,
          ),
          children: <Widget>[
            GAppBar(
              title: title ?? 'Files',
              subtitle: path,
              leading: path == null
                  ? null
                  : GIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
              actions: <Widget>[
                if (hiddenCount > 0 || showHidden)
                  GIconButton(
                    icon: showHidden
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    onTap: () => ref.read(showHiddenProvider.notifier).toggle(),
                  ),
              ],
            ),

            // AT THE ROOT ONLY.
            //
            // The chapters explain what these folders are, which is a question
            // someone asks standing at the top of the tree, not four levels
            // into WhatsApp Images. Repeating it on every screen would make it
            // furniture.
            if (path == null) ...<Widget>[
              GCard(
                onTap: () => Navigator.of(context).push(LearnPage.route()),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.docs.withValues(alpha: 0.16),
                        borderRadius: GRadius.all(11),
                      ),
                      child: Icon(
                        Icons.menu_book_outlined,
                        size: 17,
                        color: t.docs,
                      ),
                    ),
                    const SizedBox(width: GSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.s('How Android storage works'),
                            style: GType.body.copyWith(color: t.text),
                          ),
                          Text(
                            context.s(
                              'Seven chapters on what these folders are',
                            ),
                            style: GType.micro.copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
                  ],
                ),
              ),
              const SizedBox(height: GSpace.md - 1),
            ],

            if (listing.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: GSpace.xl),
                child: Center(
                  child: Text(
                    context.s('Reading'),
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
                ),
              )
            else if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: GSpace.xl),
                child: Center(
                  child: Text(
                    // Distinguishes the two cases that look identical. An
                    // unreadable folder is not an empty one, and saying "empty"
                    // about a locked directory is the exact false picture this
                    // screen exists to prevent.
                    all.isEmpty
                        ? 'Nothing here, or this phone will not let any app '
                              'look inside.'
                        : 'Only hidden items here.',
                    textAlign: TextAlign.center,
                    style: GType.bodySmall.copyWith(color: t.muted),
                  ),
                ),
              )
            else
              for (int i = 0; i < entries.length; i++)
                GEnter(
                  index: i,
                  child: _Row(
                    entry: entries[i],
                    onOpen: () => Navigator.of(context).push(
                      BrowsePage.route(
                        path: entries[i].path,
                        title: entries[i].name,
                      ),
                    ),
                  ),
                ),

            if (hiddenCount > 0 && !showHidden)
              Padding(
                padding: const EdgeInsets.only(top: GSpace.md),
                child: Text(
                  '$hiddenCount hidden ${hiddenCount == 1 ? 'item' : 'items'}, '
                  'names starting with a dot.',
                  textAlign: TextAlign.center,
                  style: GType.micro.copyWith(color: t.dim),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.onOpen});

  final DirEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final FolderNote? note = entry.isDirectory ? noteFor(entry.path) : null;
    final bool locked = entry.isDirectory && !entry.readable;

    final Color hue = locked
        ? t.dim
        : entry.isDirectory
        ? categoryTint(t, _folderKey(entry.name))
        : categoryTint(t, _fileKey(entry.name));

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: GCard(
        // A locked folder is still tappable, and opening it lands on the honest
        // empty state rather than doing nothing. A row that ignores a tap reads
        // as a bug; a row that explains itself teaches something.
        onTap: entry.isDirectory ? onOpen : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hue.withValues(alpha: 0.18),
                borderRadius: GRadius.all(11),
              ),
              child: Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : entry.isDirectory
                    ? Icons.folder_rounded
                    : Icons.insert_drive_file_outlined,
                size: 17,
                color: hue,
              ),
            ),
            const SizedBox(width: GSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.body.copyWith(
                      color: locked ? t.muted : t.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _meta(entry),
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
                  if (note != null) ...<Widget>[
                    const SizedBox(height: GSpace.sm - 2),
                    Text(
                      note.text,
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                    if (note.chapterId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: GSpace.xs + 1),
                        child: GestureDetector(
                          // Straight to the chapter, not the Learn index. The
                          // question was asked standing in a folder, and making
                          // someone find the right chapter afterwards is how a
                          // link stops being followed.
                          onTap: () => Navigator.of(
                            context,
                          ).push(ChapterPage.route(note.chapterId!)),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            context.s('Read more'),
                            style: GType.micro.copyWith(color: t.accentText),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (entry.isDirectory && !locked)
              Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
          ],
        ),
      ),
    );
  }

  /// Count for a folder, size for a file, and never a made up total.
  ///
  /// A directory reports no size because totalling one means walking it, and a
  /// browser that stalled on every folder would be unusable.
  static String _meta(DirEntry entry) {
    if (!entry.isDirectory) {
      return '${GFormat.bytes(entry.sizeBytes)}  ·  '
          '${_when(entry.modifiedMillis)}';
    }
    final int? count = entry.childCount;
    if (count == null) return 'Locked by Android';
    return '${GFormat.count(count)} ${count == 1 ? 'item' : 'items'}  ·  '
        '${_when(entry.modifiedMillis)}';
  }

  static String _when(int millis) {
    if (millis <= 0) return 'unknown';
    final DateTime at = DateTime.fromMillisecondsSinceEpoch(millis);
    final int days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '$days days ago';
    return '${at.day}/${at.month}/${at.year}';
  }

  static String _folderKey(String name) {
    switch (name.toLowerCase()) {
      case 'dcim':
      case 'pictures':
        return 'image';
      case 'movies':
        return 'video';
      case 'music':
      case 'ringtones':
        return 'audio';
      case 'documents':
        return 'document';
      default:
        return 'other';
    }
  }

  static String _fileKey(String name) {
    final String lower = name.toLowerCase();
    bool ends(List<String> exts) => exts.any(lower.endsWith);
    if (ends(<String>['.jpg', '.jpeg', '.png', '.webp', '.heic', '.gif'])) {
      return 'image';
    }
    if (ends(<String>['.mp4', '.mkv', '.3gp', '.webm', '.mov'])) return 'video';
    if (ends(<String>['.mp3', '.m4a', '.ogg', '.wav', '.opus'])) return 'audio';
    if (ends(<String>['.pdf', '.txt', '.doc', '.docx', '.csv', '.xlsx'])) {
      return 'document';
    }
    return 'other';
  }
}
