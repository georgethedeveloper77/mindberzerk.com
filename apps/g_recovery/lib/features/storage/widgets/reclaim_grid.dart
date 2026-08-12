import 'package:flutter/material.dart';

import '../../../app/theme/category_colors.dart';
import '../../../app/theme/tokens.dart';
import '../../../ui/art/tile_motifs.dart';
import '../../../ui/g_enter.dart';
import '../model/storage_view.dart';

/// The four things worth doing, in the mosaic's language.
///
/// The bar above answers where the space went. These answer what to do about
/// it, which is the only question a person opens a storage screen to ask. The
/// OS already ships the breakdown; nothing ships an honest list of what is safe
/// to remove.
///
/// A two by two rather than a scrolling list, because four is the whole set and
/// a list of four invites a fifth.
class ReclaimGrid extends StatelessWidget {
  const ReclaimGrid({required this.actions, required this.onOpen, super.key});

  final List<ReclaimAction> actions;
  final void Function(ReclaimAction) onOpen;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = GSpace.sm + 1;
        final double width = (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (int i = 0; i < actions.length; i++)
              SizedBox(
                width: width,
                child: GEnter(
                  index: i,
                  child: _Card(
                    action: actions[i],
                    onTap: () => onOpen(actions[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.action, required this.onTap});

  final ReclaimAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool dark = t.brightness == Brightness.dark;
    final Color hue = categoryTint(t, action.id);
    final bool quiet = !action.ready;

    // The same figures the home mosaic uses. Two screens tinted by two different
    // sets of alphas is how a design language stops being one.
    final double head = dark ? 0.42 : 0.20;
    final double tail = dark ? 0.16 : 0.07;
    final double edge = dark ? 0.5 : 0.3;
    final double ghost = dark ? 0.13 : 0.14;
    final BorderRadius radius = GRadius.all(GRadius.tile + 2);

    return DecoratedBox(
      decoration: quiet
          ? BoxDecoration(
              color: t.panel,
              border: Border.all(color: t.line),
              borderRadius: radius,
            )
          : BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const <double>[0, 0.55, 1],
                colors: <Color>[
                  hue.withValues(alpha: head),
                  hue.withValues(alpha: (head + tail) / 2),
                  hue.withValues(alpha: tail),
                ],
              ),
              border: Border.all(color: hue.withValues(alpha: edge)),
              borderRadius: radius,
            ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: <Widget>[
                // Drawn, not an enlarged copy of the badge glyph. Same set the
                // home tiles use, so a stack of sheets means duplicates on both
                // screens.
                Positioned(
                  right: -12,
                  bottom: -16,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: CustomPaint(
                        painter: motifFor(
                          action.id,
                          quiet
                              ? t.dim.withValues(alpha: ghost * 0.5)
                              : hue.withValues(alpha: ghost),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(GSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: quiet ? t.panelAlt : t.scrim,
                          borderRadius: GRadius.all(10),
                        ),
                        child: Icon(
                          _glyph(action.id),
                          size: 16,
                          color: quiet ? t.dim : t.text,
                        ),
                      ),
                      const SizedBox(height: GSpace.md),
                      Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GType.heading.copyWith(color: t.text),
                      ),
                      Text(
                        action.value,
                        style: GType.monoNumber.copyWith(
                          // Plain text, not the hue. A mint number on a card
                          // that is now genuinely mint read fine at 0.15 and
                          // turns to soup at 0.42.
                          color: quiet ? t.dim : t.text,
                          fontSize: 19,
                        ),
                      ),
                      Text(
                        action.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GType.micro.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _glyph(String id) {
    switch (id) {
      case 'duplicates':
        return Icons.content_copy_rounded;
      case 'large':
        return Icons.data_usage_rounded;
      case 'similar':
        return Icons.burst_mode_outlined;
      case 'stale':
        return Icons.hourglass_empty_rounded;
      case 'blurred':
        return Icons.blur_on_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
