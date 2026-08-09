import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../ui/g_card.dart';
import '../state/learn_model.dart';

/// Renders one block. An unrecognised type renders NOTHING.
///
/// Silently skipping beats showing raw JSON: published content is written by a
/// panel that can be ahead of the installed app, and a phone on an older build
/// meeting a block type it does not know should show a slightly shorter chapter
/// rather than a debug string.
class ContentBlockView extends StatelessWidget {
  const ContentBlockView({required this.block, super.key});

  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    switch (block.type) {
      case 'h':
        return Padding(
          padding: const EdgeInsets.only(top: GSpace.lg, bottom: GSpace.sm),
          child: Text(
            block.text ?? '',
            style: GType.heading.copyWith(color: t.text, fontSize: 16),
          ),
        );

      case 'p':
        return Padding(
          padding: const EdgeInsets.only(bottom: GSpace.md),
          child: Text(
            block.text ?? '',
            style: GType.body.copyWith(color: t.muted, height: 1.65),
          ),
        );

      case 'path':
        return Padding(
          padding: const EdgeInsets.only(bottom: GSpace.sm + 2),
          child: GCard(
            padding: const EdgeInsets.all(GSpace.md + 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  block.name ?? '',
                  style: GType.monoNumber.copyWith(color: t.accentText),
                ),
                const SizedBox(height: GSpace.sm - 2),
                Text(
                  block.text ?? '',
                  style: GType.bodySmall.copyWith(color: t.muted, height: 1.6),
                ),
              ],
            ),
          ),
        );

      case 'list':
        return Padding(
          padding: const EdgeInsets.only(bottom: GSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final String item in block.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: GSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: GSpace.md),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: GType.body.copyWith(
                            color: t.muted,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

      case 'note':
      case 'warn':
        final bool warn = block.type == 'warn';
        final Color tone = warn ? t.warning : t.video;
        return Padding(
          padding: const EdgeInsets.only(bottom: GSpace.md),
          child: GCard(
            tint: tone,
            borderColour: tone.withValues(alpha: 0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  warn
                      ? Icons.warning_amber_rounded
                      : Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: tone,
                ),
                const SizedBox(width: GSpace.md),
                Expanded(
                  child: Text(
                    block.text ?? '',
                    style: GType.bodySmall.copyWith(color: t.text, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
