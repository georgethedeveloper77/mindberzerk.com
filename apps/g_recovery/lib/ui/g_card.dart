import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

/// The panel every surface in the app is built from.
class GCard extends StatelessWidget {
  const GCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(GSpace.lg - 1),
    this.background,
    this.borderColour,
    this.tint,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final Color? borderColour;

  /// Draws a soft diagonal wash of this colour over the panel. Used for the
  /// cards that need to pull attention without turning into a banner.
  final Color? tint;

  final VoidCallback? onTap;

  /// Long press enters selection mode on list rows. Separate from [onTap] so a
  /// card can be viewable and selectable at once without the two competing.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final BorderRadius radius = GRadius.all(GRadius.card);

    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? t.panel,
        borderRadius: radius,
        border: Border.all(color: borderColour ?? t.line),
        gradient: tint == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  tint!.withValues(alpha: 0.09),
                  tint!.withValues(alpha: 0.0),
                ],
              ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null && onLongPress == null) return body;

    // Material wrapper is mandatory: GCard is used inside showGeneralDialog
    // routes and shell overlays that have no Scaffold above them, where a bare
    // InkWell throws "No Material widget found".
    return Material(
      color: const Color(0x00000000),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: body,
      ),
    );
  }
}

/// Hairline used inside a card, bleeding past the card's own padding to meet
/// both edges.
///
/// The obvious implementation is a negative horizontal margin, and it is wrong:
/// Container asserts `margin.isNonNegative`, so it throws the moment the widget
/// is built rather than at compile time. OverflowBox is the supported way to
/// draw wider than the incoming constraints.
///
/// [inset] must match the padding of the GCard it sits in. Cards using a custom
/// padding have to pass it, or the line stops short on both sides.
class GCardDivider extends StatelessWidget {
  const GCardDivider({super.key, this.inset = GSpace.lg - 1});

  final double inset;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GSpace.md),
      child: SizedBox(
        // Height is pinned out here because OverflowBox sizes itself to the
        // constraints it is handed, and inside a Column those are unbounded
        // vertically.
        height: 1,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth + (inset * 2);
            return OverflowBox(
              minWidth: width,
              maxWidth: width,
              minHeight: 1,
              maxHeight: 1,
              child: ColoredBox(color: t.line),
            );
          },
        ),
      ),
    );
  }
}
