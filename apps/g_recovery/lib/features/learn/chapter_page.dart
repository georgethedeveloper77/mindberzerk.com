import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../ui/g_app_bar.dart';
import 'state/learn_model.dart';
import 'state/learn_providers.dart';
import 'widgets/content_block_view.dart';
import '../../core/i18n/g_strings.dart';

class ChapterPage extends ConsumerWidget {
  const ChapterPage({required this.chapterId, super.key});

  final String chapterId;

  static Route<void> route(String chapterId) => MaterialPageRoute<void>(
    builder: (BuildContext context) => ChapterPage(chapterId: chapterId),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final LearnBook? book = ref.watch(learnBookProvider).value;
    final LearnChapter? chapter = book?.chapter(chapterId);

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            0,
            GSpace.gutter,
            GSpace.xl * 2,
          ),
          children: <Widget>[
            GAppBar(
              title: chapter?.title ?? 'Chapter',
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            if (chapter == null)
              Text(
                // Reachable when an info icon points at a chapter the installed
                // content does not have, which happens if the panel renames one.
                // Named as a content problem rather than shown as an error.
                context.s(
                  'This chapter is not in the version of the guide on this device.',
                ),
                style: GType.bodySmall.copyWith(color: t.muted),
              )
            else
              for (final ContentBlock block in chapter.blocks)
                ContentBlockView(block: block),
          ],
        ),
      ),
    );
  }
}
