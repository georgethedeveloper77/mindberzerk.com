import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// A horizontal fill bar.
///
/// A null [fraction] renders the track alone, which is the correct picture for
/// a reading this device will not serve: the row exists, the shape is there,
/// and no number has been invented to fill it.
class GBar extends StatelessWidget {
  const GBar({super.key, this.fraction, this.colour, this.height = 6});

  final double? fraction;
  final Color? colour;
  final double height;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final double? clamped = fraction?.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: GRadius.all(height),
      child: Container(
        height: height,
        color: t.panelHigh,
        alignment: Alignment.centerLeft,
        child: clamped == null
            ? null
            : FractionallySizedBox(
                widthFactor: clamped,
                child: AnimatedContainer(
                  duration: GMotion.fast,
                  decoration: BoxDecoration(
                    color: colour ?? t.accent,
                    borderRadius: GRadius.all(height),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Label, bar, value. The row shape used throughout the Device tab.
class GMeterRow extends StatelessWidget {
  const GMeterRow({
    required this.label,
    super.key,
    this.value,
    this.fraction,
    this.colour,
    this.labelWidth = 46,
    this.valueWidth = 62,
  });

  final String label;

  /// Null renders an em-space-free blank rather than a dash.
  final String? value;

  final double? fraction;
  final Color? colour;
  final double labelWidth;
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GType.monoSmall.copyWith(color: t.dim),
            ),
          ),
          const SizedBox(width: GSpace.sm + 1),
          Expanded(
            child: GBar(fraction: fraction, colour: colour),
          ),
          const SizedBox(width: GSpace.sm + 1),
          SizedBox(
            width: valueWidth,
            child: Text(
              value ?? '',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GType.monoSmall.copyWith(
                color: value == null ? t.dim : t.text,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
