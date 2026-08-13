import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_card.dart';
import 'chapter_page.dart';
import 'state/learn_model.dart';
import 'state/learn_providers.dart';
import '../../core/i18n/g_strings.dart';

/// The chapter list.
///
/// Not a side feature. This is what makes a "gone" verdict believable: a user
/// told their photo cannot be recovered has no reason to accept that from an
/// app unless the app can explain why, in terms they can check.
class LearnPage extends ConsumerWidget {
  const LearnPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const LearnPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final LearnBook? book = ref.watch(learnBookProvider).value;

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
              title: context.s('How Android storage works'),
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Text(
              context.s(
                'Seven short chapters on where your files live, what deleting '
                'actually does, and why some things can be brought back and '
                'others cannot.',
              ),
              style: GType.bodySmall.copyWith(color: t.muted, height: 1.6),
            ),
            const SizedBox(height: GSpace.lg),
            if (book == null)
              Text(
                context.s('Loading'),
                style: GType.bodySmall.copyWith(color: t.dim),
              )
            else
              for (int i = 0; i < book.chapters.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: GSpace.sm + 2),
                  child: _ChapterCard(chapter: book.chapters[i]),
                ),
          ],
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter});

  final LearnChapter chapter;

  /// One glyph per chapter, keyed on the id rather than the position, so
  /// reordering the book cannot silently give a chapter the wrong picture.
  static IconData _icon(String id) => switch (id) {
    LearnIds.whereFilesLive => Icons.smartphone_rounded,
    LearnIds.standardFolders => Icons.folder_rounded,
    LearnIds.androidData => Icons.lock_outline_rounded,
    LearnIds.theTrash => Icons.delete_outline_rounded,
    LearnIds.thumbnails => Icons.photo_size_select_small_rounded,
    LearnIds.scopedStorage => Icons.shield_outlined,
    LearnIds.factoryReset => Icons.restart_alt_rounded,
    _ => Icons.menu_book_outlined,
  };

  static Color _hue(GTokens t, String id) => switch (id) {
    LearnIds.whereFilesLive => t.chat,
    LearnIds.standardFolders => t.photo,
    LearnIds.androidData => t.apps,
    LearnIds.theTrash => t.danger,
    LearnIds.thumbnails => t.video,
    LearnIds.scopedStorage => t.docs,
    LearnIds.factoryReset => t.audio,
    _ => t.muted,
  };

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return GCard(
      onTap: () => Navigator.of(context).push(ChapterPage.route(chapter.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // A GLYPH, not a number.
          //
          // "01" told a reader the order, which the list already showed. A bin,
          // a folder or a padlock tells them what the chapter is about before
          // they read the title, which is the only thing a chapter list is for.
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hue(t, chapter.id).withValues(alpha: 0.16),
              borderRadius: GRadius.all(13),
            ),
            child: Icon(
              _icon(chapter.id),
              size: 19,
              color: _hue(t, chapter.id),
            ),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  chapter.title,
                  style: GType.heading.copyWith(color: t.text),
                ),
                const SizedBox(height: 3),
                Text(
                  chapter.summary,
                  style: GType.bodySmall.copyWith(color: t.muted, height: 1.5),
                ),
                const SizedBox(height: GSpace.sm),
                Text(
                  '${chapter.minutes} min read',
                  style: GType.micro.copyWith(color: t.dim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
