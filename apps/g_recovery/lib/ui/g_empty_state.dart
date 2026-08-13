import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';
import 'art/escape_art.dart';
import 'g_button.dart';
import '../core/i18n/g_strings.dart';

/// NOTHING HERE, said with the art rather than a sentence.
///
/// An empty category is the commonest screen in this app: most phones, most of
/// the time, have nothing in most bins. It was a line of grey text, which made
/// the most frequent state the least considered one.
///
/// ─── THE ACTION IS A BUTTON ──────────────────────────────────────────────────
///
/// It used to be a coloured word inside a paragraph, which is a link pretending
/// to be a link. If running a scan is the useful thing to do from here, it gets
/// the same button the hero uses.
class GEmptyState extends StatelessWidget {
  const GEmptyState({
    required this.title,
    required this.body,
    super.key,
    this.shape = EscapeShape.files,
    this.actionLabel,
    this.onAction,
    this.onExplain,
  });

  final String title;

  /// One sentence. Anything longer belongs behind [onExplain].
  final String body;

  final EscapeShape shape;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Opens a sheet with the detail. Null hides the link entirely.
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: GSpace.xl,
          vertical: GSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            EscapeArt(height: 168, shape: shape),
            const SizedBox(height: GSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GType.title.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GType.bodySmall.copyWith(color: t.muted),
            ),
            if (onAction != null && actionLabel != null) ...<Widget>[
              const SizedBox(height: GSpace.lg),
              GButton(
                label: actionLabel!,
                icon: Icons.travel_explore_rounded,
                expand: false,
                onPressed: onAction,
              ),
            ],
            if (onExplain != null) ...<Widget>[
              const SizedBox(height: GSpace.md),
              GestureDetector(
                onTap: onExplain,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(GSpace.sm),
                  child: Text(
                    context.s('Why is this empty'),
                    style: GType.micro.copyWith(color: t.accentText),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The art for a category, so no caller has to remember the mapping.
EscapeShape shapeForKind(String? kind) {
  switch (kind) {
    case 'image':
      return EscapeShape.photos;
    case 'video':
      return EscapeShape.photos;
    case 'audio':
      return EscapeShape.audio;
    case 'document':
      return EscapeShape.documents;
    case 'messages':
      return EscapeShape.messages;
    default:
      return EscapeShape.files;
  }
}
