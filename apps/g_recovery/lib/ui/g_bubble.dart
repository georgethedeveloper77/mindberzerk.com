import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// A category tile from the home grid.
///
/// The tint is passed in rather than derived from the accent, because the six
/// categories have to stay distinguishable from each other whatever accent the
/// user picked.
class GBubble extends StatelessWidget {
  const GBubble({
    required this.label,
    required this.icon,
    required this.tint,
    super.key,
    this.caption,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;

  /// Null renders no caption line at all. Never pass a placeholder string for
  /// data that has not loaded.
  final String? caption;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final BorderRadius radius = GRadius.all(GRadius.card);

    return Material(
      color: const Color(0x00000000),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: tint.withValues(alpha: 0.24)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                tint.withValues(alpha: 0.18),
                tint.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.2),
                  borderRadius: GRadius.all(GRadius.glyph),
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(height: 11),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GType.heading.copyWith(color: t.text, fontSize: 14),
              ),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.monoSmall.copyWith(color: t.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
