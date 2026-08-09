import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';

enum GButtonKind { primary, ghost, danger }

class GButton extends StatelessWidget {
  const GButton({
    required this.label,
    super.key,
    this.onPressed,
    this.kind = GButtonKind.primary,
    this.expand = true,
    this.padding =
        const EdgeInsets.symmetric(horizontal: GSpace.lg, vertical: 14),
  });

  const GButton.ghost({
    required String label,
    Key? key,
    VoidCallback? onPressed,
    bool expand = true,
  }) : this(
          label: label,
          key: key,
          onPressed: onPressed,
          kind: GButtonKind.ghost,
          expand: expand,
        );

  final String label;
  final VoidCallback? onPressed;
  final GButtonKind kind;
  final bool expand;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool enabled = onPressed != null;
    final BorderRadius radius = GRadius.all(GRadius.button);

    final Color fill;
    final Color ink;
    final Color? border;
    switch (kind) {
      case GButtonKind.primary:
        fill = t.accent;
        ink = t.onAccent;
        border = null;
      case GButtonKind.ghost:
        fill = const Color(0x00000000);
        ink = t.text;
        border = t.lineStrong;
      case GButtonKind.danger:
        fill = t.danger;
        ink = t.onAccent;
        border = null;
    }

    final Widget button = Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: fill,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: border == null ? null : Border.all(color: border),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GType.body.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
