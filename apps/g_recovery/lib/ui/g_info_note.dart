import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';
import '../features/learn/chapter_page.dart';

/// One line with an info glyph that opens the chapter explaining it.
///
/// Replaces the paragraphs of small grey text that were sitting under Home and
/// the category screens. Those paragraphs were saying something true and
/// important, and burying it in six point type at the bottom of a scroll is the
/// same as not saying it. One line and a tap is more honest and takes less
/// room.
class GInfoNote extends StatelessWidget {
  const GInfoNote({
    required this.text,
    required this.chapterId,
    super.key,
  });

  final String text;

  /// A LearnIds constant, never a literal, so a chapter renamed in the panel
  /// breaks in one place instead of opening nothing here.
  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Material(
      color: const Color(0x00000000),
      borderRadius: GRadius.all(GRadius.chip),
      child: InkWell(
        onTap: () =>
            Navigator.of(context).push(ChapterPage.route(chapterId)),
        borderRadius: GRadius.all(GRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GSpace.md,
            vertical: GSpace.sm + 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.info_outline_rounded, size: 15, color: t.dim),
              const SizedBox(width: GSpace.sm),
              Flexible(
                child: Text(
                  text,
                  style: GType.micro.copyWith(color: t.dim),
                ),
              ),
              const SizedBox(width: GSpace.xs),
              Icon(Icons.chevron_right_rounded, size: 15, color: t.dim),
            ],
          ),
        ),
      ),
    );
  }
}
