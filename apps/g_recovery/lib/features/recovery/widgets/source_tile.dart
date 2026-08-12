import 'package:flutter/material.dart';

import '../../../app/theme/category_colors.dart';
import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../core/format.dart';

/// One row of the recovery ledger.
///
/// The fidelity stamp is not decoration. It is the promise the app is built on:
/// you always know what quality you are getting back before you tap restore, and
/// a source that can return nothing says so instead of being hidden.
///
/// Drawn in the same language as the home mosaic, and for the same reason a
/// plain row was not enough there. A ledger of five near identical grey cards is
/// a table, and a table does not tell you at a glance that one of these places
/// holds eight gigabytes of full quality files and another holds fourteen
/// megabytes of thumbnails.
///
/// COLOUR HERE MEANS A PLACE, not a status. The status is the stamp, which
/// keeps its own fixed palette so that "Preview only" reads the same amber no
/// matter which source it lands on.
class SourceTile extends StatelessWidget {
  const SourceTile({
    required this.source,
    required this.expanded,
    required this.onTap,
    this.share = 0,
    super.key,
  });

  final RecoverySource source;
  final bool expanded;
  final VoidCallback onTap;

  /// This source's size as a fraction of the largest one, 0 to 1.
  ///
  /// Relative rather than absolute, because absolute would render every bar on a
  /// tidy phone as a sliver. The bar answers "which of these is the big one",
  /// which is the only question a bar can answer honestly at this size.
  final double share;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool dark = t.brightness == Brightness.dark;
    final bool quiet = !source.available || source.itemCount == 0;

    final Color hue = categoryTint(t, source.sourceId);
    final double fill = dark ? 0.15 : 0.095;
    final double wash = dark ? 0.055 : 0.04;
    final double edge = dark ? 0.34 : 0.26;
    final double ghost = dark ? 0.075 : 0.10;

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
                stops: const <double>[0, 0.68],
                colors: <Color>[
                  hue.withValues(alpha: fill + wash),
                  hue.withValues(alpha: fill - wash),
                ],
              ),
              border: Border.all(
                color: expanded ? t.accent : hue.withValues(alpha: edge),
              ),
              borderRadius: radius,
            ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: source.available ? onTap : null,
          borderRadius: radius,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -14,
                  bottom: -18,
                  child: IgnorePointer(
                    child: Icon(
                      _glyph(),
                      size: 92,
                      color: quiet
                          ? t.dim.withValues(alpha: ghost * 0.5)
                          : hue.withValues(alpha: ghost),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(GSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: quiet
                                  ? t.panelAlt
                                  : hue.withValues(alpha: 0.2),
                              borderRadius: GRadius.all(12),
                            ),
                            child: Icon(
                              _glyph(),
                              size: 18,
                              color: quiet ? t.dim : hue,
                            ),
                          ),
                          const SizedBox(width: GSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  source.label,
                                  style: GType.heading.copyWith(color: t.text),
                                ),
                                Text(
                                  <String>[
                                    GFormat.bytes(source.totalBytes),
                                    if (source.retentionDays != null)
                                      'up to ${source.retentionDays} days',
                                  ].join('  /  '),
                                  style: GType.monoSmall.copyWith(
                                    color: t.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: GSpace.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                GFormat.count(source.itemCount),
                                style: GType.monoNumber.copyWith(
                                  color: quiet ? t.dim : hue,
                                  fontSize: 19,
                                ),
                              ),
                              Text(
                                'items',
                                style: GType.micro.copyWith(color: t.dim),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: GSpace.sm + 2),

                      // The bar is the graph. Full width, two pixels, and it is
                      // the one element here that compares sources to each other
                      // rather than describing one in isolation.
                      ClipRRect(
                        borderRadius: GRadius.all(2),
                        child: SizedBox(
                          height: 3,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: ColoredBox(color: t.panelAlt),
                              ),
                              // Positioned.fill AND heightFactor. A Stack gives
                              // a non positioned child loose constraints and
                              // ColoredBox has no size of its own, so without
                              // both of these the fill is laid out at zero
                              // height and only the grey track is ever seen.
                              Positioned.fill(
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: quiet ? 0 : share.clamp(0.02, 1),
                                  heightFactor: 1,
                                  child: ColoredBox(color: hue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: GSpace.sm + 2),

                      Row(
                        children: <Widget>[
                          _stamp(t),
                          if (source.detail != null) ...<Widget>[
                            const SizedBox(width: GSpace.sm),
                            Expanded(
                              child: Text(
                                source.detail!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GType.micro.copyWith(color: t.dim),
                              ),
                            ),
                          ],
                        ],
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

  IconData _glyph() {
    switch (source.sourceId) {
      case 'media_trash':
        return Icons.delete_outline_rounded;
      case 'app_trash':
        return Icons.folder_open_rounded;
      case 'thumbnails':
        return Icons.grain_rounded;
      case 'live_files':
        return Icons.schedule_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  /// The honesty stamp keeps its own palette. Full is always the success
  /// colour and preview is always the warning colour, whatever place they sit
  /// on, because a user learning this vocabulary must be able to trust it.
  Widget _stamp(GTokens t) {
    final (String label, Color tone) = switch (source.fidelity) {
      'full' => ('Full quality', t.success),
      'preview' => ('Preview only', t.warning),
      _ => ('Gone', t.dim),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.sm + 1,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.16),
        borderRadius: GRadius.all(GRadius.chip),
      ),
      child: Text(label, style: GType.micro.copyWith(color: tone)),
    );
  }
}
